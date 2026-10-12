function SimState = Generate_Traffic(SimState, SimParams)

    i = SimState.Time;

    %----------------------------------------
    % Background Traffic Generation
    %----------------------------------------
    if SimParams.N_bkSTA > 0
       idx_STA_Type0 = SimParams.idx_STA_Type0;
       for j = 1:SimParams.N_bkSTA

           idx = idx_STA_Type0(j);

           if SimState.Next_Frame_Interval_bk(idx) <= i

                if rand <= SimParams.Prob_Frame_Generation_bk

                    SimState.GID = SimState.GID + 1;
                    SimState.Node.TX_Buffer(idx).Length = SimState.Node.TX_Buffer(idx).Length + 1;

                    SimState.Node.TX_Buffer(idx).MPDU = [SimState.Node.TX_Buffer(idx).MPDU; SimState.GID SimState.Next_Frame_Length_bk(idx) i];
                    SimState.n_enq(idx) = SimState.n_enq(idx) + 1;
                end

                % reset configurations for a next arrival frame
                SimState.Next_Frame_Length_bk(idx) = ceil( (SimParams.Range_Frame_Length_bk(2)-SimParams.Range_Frame_Length_bk(1))*rand + SimParams.Range_Frame_Length_bk(1) );
                SimState.Next_Frame_Interval_bk(idx) = i + ceil( (SimParams.Range_Frame_Interval_bk(2)-SimParams.Range_Frame_Interval_bk(1))*rand + SimParams.Range_Frame_Interval_bk(1) );

           end
       end
    end

    %----------------------------------------
    % Alarm Traffic Generation
    %----------------------------------------
    within_activation_window = SimParams.Opt_Start < i && ...
        SimParams.Opt_End >= i;
    continue_periodic_alarm = SimParams.Opt_Start < i && ...
        (SimParams.Traffic_Surge_Mode == 4 || ...
        (SimParams.Traffic_Surge_Mode == 3 && ...
        Is_Mode3_Periodic_Alarm_Enabled(SimParams)));
    if within_activation_window || continue_periodic_alarm
        SimState.Prev_Traffic_Event = i;
        idx_STA_Type1 = SimParams.idx_STA_Type1;

        if SimParams.Traffic_Surge_Mode == 1
            if SimParams.Traffic_Gen_Mode == 0
                for j = 1:SimParams.N_alarmSTA
                        idx = idx_STA_Type1(j);
                        if SimState.Next_Frame_Interval_al(idx) <= i
                            if rand <= SimParams.Prob_Frame_Generation_al
                                SimState.GID = SimState.GID + 1;
                                SimState.Node.TX_Buffer(idx).Length = SimState.Node.TX_Buffer(idx).Length + 1;
                                SimState.Node.TX_Buffer(idx).MPDU = [SimState.Node.TX_Buffer(idx).MPDU; SimState.GID SimState.Next_Frame_Length_al(idx) i];
                                SimState.n_enq(idx) = SimState.n_enq(idx) + 1;
                            end
                            SimState.Next_Frame_Length_al(idx) = ceil( (SimParams.Range_Frame_Length_al(2)-SimParams.Range_Frame_Length_al(1))*rand + SimParams.Range_Frame_Length_al(1) );
                            SimState.Next_Frame_Interval_al(idx) = i + ceil( (SimParams.Range_Frame_Interval_al(2)-SimParams.Range_Frame_Interval_al(1))*rand + SimParams.Range_Frame_Interval_al(1) );
                        end
                end

            elseif SimParams.Traffic_Gen_Mode == 1
                if SimState.Next_Frame_Interval_al <= i && rand <= SimParams.Prob_Frame_Generation_al
                   for j = 1:SimParams.N_alarmSTA
                        idx = idx_STA_Type1(j);
                        SimState.GID = SimState.GID + 1;
                        SimState.Node.TX_Buffer(idx).Length = SimState.Node.TX_Buffer(idx).Length + 1;
                        SimState.Node.TX_Buffer(idx).MPDU = [SimState.Node.TX_Buffer(idx).MPDU; SimState.GID SimState.Next_Frame_Length_al i];
                        SimState.n_enq(idx) = SimState.n_enq(idx) + 1;

                        % Note: In original code, these next updates were inside loop.
                        SimState.Next_Frame_Length_al = ceil( (SimParams.Range_Frame_Length_al(2)-SimParams.Range_Frame_Length_al(1))*rand + SimParams.Range_Frame_Length_al(1) );
                        SimState.Next_Frame_Interval_al = i + ceil( (SimParams.Range_Frame_Interval_al(2)-SimParams.Range_Frame_Interval_al(1))*rand + SimParams.Range_Frame_Interval_al(1) );
                   end
                end
            end

        elseif SimParams.Traffic_Surge_Mode == 2 || SimParams.Traffic_Surge_Mode == 3

               Activation_Order = idx_STA_Type1;
               if SimParams.Traffic_Surge_Mode == 3 && ...
                  isfield(SimParams, 'On_GeoAware_Activation_Mode3') && ...
                  SimParams.On_GeoAware_Activation_Mode3 == 1 && ...
                  isfield(SimState, 'Alarm_Activation_Order') && ...
                  ~isempty(SimState.Alarm_Activation_Order)
                   Activation_Order = SimState.Alarm_Activation_Order;
               end

               N_buffered_STAs = 0;
               if within_activation_window
                   model_idx = i - SimParams.Opt_Start + 1;
                   N_buffered_STAs = floor(SimParams.Tab_Traffic_Model(2, model_idx)) - ...
                       floor(SimParams.Tab_Traffic_Model(2, SimState.Last_Time));
               end

               uses_reference_fire_grid = SimParams.Traffic_Surge_Mode == 3 && ...
                   isfield(SimState, 'Alarm_Reference_Rank') && ...
                   ~isempty(SimState.Alarm_Reference_Rank);

               if uses_reference_fire_grid && within_activation_window
                   reference_active_count = floor( ...
                       SimParams.Tab_Traffic_Model(2, model_idx));
                   reference_active_count = min( ...
                       SimState.Fire_Reference_Alarm_Count, ...
                       max(0, reference_active_count));
                   due_local_idx = find( ...
                       SimState.Alarm_Reference_Rank <= reference_active_count);
                   [~, due_order] = sort( ...
                       SimState.Alarm_Reference_Rank(due_local_idx), 'ascend');
                   due_local_idx = due_local_idx(due_order);

                   N_new_triggered = 0;
                   for k = 1:numel(due_local_idx)
                       idx = idx_STA_Type1(due_local_idx(k));
                       if SimState.Node.TX_Buffer(idx).Triggered == 0
                           SimState.Node.TX_Buffer(idx).Triggered = 1;
                           SimState.Node.TX_Buffer(idx).Trigger_Time = i;
                           SimState.Mode3_Remaining_Burst_Count(idx) = ...
                               Get_Mode3_Initial_Burst_Count(SimParams);
                           SimState.Next_Frame_Interval_al(idx) = i;
                           N_new_triggered = N_new_triggered + 1;
                       end
                   end
                   SimState.Last_Time = model_idx;
                   SimState = Record_New_Triggered_STAs( ...
                       SimState, i, N_new_triggered);

               elseif N_buffered_STAs > 0
                   SimState.Last_Time = model_idx;

                   Temp_cnt = 0;
                   for idx_N_buffered_STAs = 1:length(Activation_Order)
                       idx = Activation_Order(idx_N_buffered_STAs);

                       if SimState.Node.TX_Buffer(idx).Triggered == 0
                          SimState.Node.TX_Buffer(idx).Triggered = 1;
                          SimState.Node.TX_Buffer(idx).Trigger_Time = i;

                          if SimParams.Traffic_Surge_Mode == 2
                              SimState.GID = SimState.GID + 1;
                              SimState.Next_Frame_Length_al(idx) = ceil( (SimParams.Range_Frame_Length_al(2)-SimParams.Range_Frame_Length_al(1))*rand + SimParams.Range_Frame_Length_al(1) );
                              SimState.Node.TX_Buffer(idx).Length = SimState.Node.TX_Buffer(idx).Length + 1;
                              SimState.Node.TX_Buffer(idx).MPDU = [SimState.Node.TX_Buffer(idx).MPDU; SimState.GID SimState.Next_Frame_Length_al(idx) i];
                              SimState.n_enq(idx) = SimState.n_enq(idx) + 1;
                          else
                              SimState.Mode3_Remaining_Burst_Count(idx) = ...
                                  Get_Mode3_Initial_Burst_Count(SimParams);
                              SimState.Next_Frame_Interval_al(idx) = i;
                          end

                          Temp_cnt = Temp_cnt + 1;
                          if Temp_cnt == N_buffered_STAs
                             break;
                          end
                       end
                   end

                   SimState = Record_New_Triggered_STAs( ...
                       SimState, i, Temp_cnt);
               end

               if SimParams.Traffic_Surge_Mode == 3
                   if Is_Mode3_Periodic_Alarm_Enabled(SimParams) || N_buffered_STAs > 0
                       SimState = Generate_Mode3_Periodic_Alarm(SimState, SimParams, idx_STA_Type1, i);
                   end
               end
        elseif SimParams.Traffic_Surge_Mode == 4
               trigger_slots = SimParams.Farsite_Model.Trigger_Time_Slot(:);
               due_local_idx = find(trigger_slots <= i);
               N_new_triggered = 0;

               for k = 1:length(due_local_idx)
                   alarm_local_idx = due_local_idx(k);
                   idx = idx_STA_Type1(alarm_local_idx);
                   if SimState.Node.TX_Buffer(idx).Triggered == 0
                      SimState.Node.TX_Buffer(idx).Triggered = 1;
                      SimState.Node.TX_Buffer(idx).Trigger_Time = i;
                      burst_count = Get_Farsite_Initial_Burst_Count(SimParams, alarm_local_idx);
                      SimState.Farsite_Remaining_Burst_Count(idx) = max(0, burst_count - 1);
                      [SimState, did_enqueue] = Enqueue_Farsite_Alarm_MPDU(SimState, SimParams, idx, i);
                      if did_enqueue
                          SimState.n_enq(idx) = SimState.n_enq(idx) + 1;
                      end
                      SimState = Schedule_Next_Farsite_Alarm(SimState, SimParams, idx, i);
                      N_new_triggered = N_new_triggered + 1;
                   end
               end

               if N_new_triggered > 0
                   prev_count = SimState.Measure_Cummulated_N_Triggerd_STAs(SimState.L_Measure_Cummulated_N_Triggerd_STAs,2);
                   SimState.Measure_Cummulated_N_Triggerd_STAs = ...
                       [SimState.Measure_Cummulated_N_Triggerd_STAs; i prev_count + N_new_triggered];
                   SimState.L_Measure_Cummulated_N_Triggerd_STAs = ...
                       SimState.L_Measure_Cummulated_N_Triggerd_STAs + 1;
               end

               for j = 1:SimParams.N_alarmSTA
                   idx = idx_STA_Type1(j);
                   if SimState.Next_Frame_Interval_al(idx) <= i && ...
                      SimState.Node.TX_Buffer(idx).Triggered == 1
                       [SimState, did_enqueue] = Enqueue_Farsite_Alarm_MPDU(SimState, SimParams, idx, i);
                       if did_enqueue
                           SimState.n_enq(idx) = SimState.n_enq(idx) + 1;
                       end
                       if SimState.Farsite_Remaining_Burst_Count(idx) > 0
                           SimState.Farsite_Remaining_Burst_Count(idx) = ...
                               SimState.Farsite_Remaining_Burst_Count(idx) - 1;
                       end
                       SimState = Schedule_Next_Farsite_Alarm(SimState, SimParams, idx, i);
                   end
               end
        end
    end
end

function enabled = Is_Mode3_Periodic_Alarm_Enabled(SimParams)
    if isfield(SimParams, 'Mode3_Periodic_Alarm_After_Activation')
        enabled = SimParams.Mode3_Periodic_Alarm_After_Activation == 1;
    else
        enabled = false;
    end
end

function SimState = Generate_Mode3_Periodic_Alarm(SimState, SimParams, idx_STA_Type1, i)
    for j = 1:SimParams.N_alarmSTA
        idx = idx_STA_Type1(j);
        if SimState.Next_Frame_Interval_al(idx) <= i && ...
           SimState.Node.TX_Buffer(idx).Triggered == 1
            if rand <= SimParams.Prob_Frame_Generation_al
                [SimState.Node.TX_Buffer(idx), SimState.GID] = ...
                    Enque_MPDU(SimState.Node.TX_Buffer(idx), SimState.GID, ...
                    SimState.Next_Frame_Length_al(idx), i);
                SimState.n_enq(idx) = SimState.n_enq(idx) + 1;
            end
            if SimState.Mode3_Remaining_Burst_Count(idx) > 0
                SimState.Mode3_Remaining_Burst_Count(idx) = ...
                    SimState.Mode3_Remaining_Burst_Count(idx) - 1;
            end
            SimState.Next_Frame_Length_al(idx) = Sample_Range(SimParams.Range_Frame_Length_al);
            if SimState.Mode3_Remaining_Burst_Count(idx) > 0
                interval_range = Get_Field_Or_Default(SimParams, ...
                    'Mode3_Alarm_Burst_Interval_Slots', [1 1]);
            else
                interval_range = SimParams.Range_Frame_Interval_al;
            end
            SimState.Next_Frame_Interval_al(idx) = i + Sample_Range(interval_range);
        end
    end
end

function burst_count = Get_Mode3_Initial_Burst_Count(SimParams)
    burst_count = Get_Field_Or_Default( ...
        SimParams, 'Mode3_Alarm_Burst_Count', 1);
    burst_count = max(1, round(burst_count));
end

function SimState = Record_New_Triggered_STAs(SimState, i, n_new)
    if n_new <= 0
        return;
    end
    prev_count = SimState.Measure_Cummulated_N_Triggerd_STAs( ...
        SimState.L_Measure_Cummulated_N_Triggerd_STAs, 2);
    SimState.Measure_Cummulated_N_Triggerd_STAs = ...
        [SimState.Measure_Cummulated_N_Triggerd_STAs; ...
        i, prev_count + n_new];
    SimState.L_Measure_Cummulated_N_Triggerd_STAs = ...
        SimState.L_Measure_Cummulated_N_Triggerd_STAs + 1;
end

function [SimState, did_enqueue] = Enqueue_Farsite_Alarm_MPDU(SimState, SimParams, idx, i)
    did_enqueue = false;
    SimState.Next_Frame_Length_al(idx) = Sample_Range(SimParams.Range_Frame_Length_al);
    if rand <= SimParams.Prob_Frame_Generation_al
        [SimState.Node.TX_Buffer(idx), SimState.GID] = ...
            Enque_MPDU(SimState.Node.TX_Buffer(idx), SimState.GID, ...
            SimState.Next_Frame_Length_al(idx), i);
        did_enqueue = true;
    end
end

function SimState = Schedule_Next_Farsite_Alarm(SimState, SimParams, idx, i)
    if SimState.Farsite_Remaining_Burst_Count(idx) > 0
        interval_range = Get_Field_Or_Default(SimParams, ...
            'Farsite_Alarm_Burst_Interval_Slots', [1 1]);
    else
        interval_range = SimParams.Range_Frame_Interval_al;
    end
    SimState.Next_Frame_Interval_al(idx) = i + Sample_Range(interval_range);
end

function burst_count = Get_Farsite_Initial_Burst_Count(SimParams, alarm_local_idx)
    if isfield(SimParams, 'Farsite_Initial_Burst_Count_Per_Alarm') && ...
       ~isempty(SimParams.Farsite_Initial_Burst_Count_Per_Alarm)
        burst_count = SimParams.Farsite_Initial_Burst_Count_Per_Alarm(alarm_local_idx);
    else
        burst_count = Get_Field_Or_Default(SimParams, 'Farsite_Alarm_Burst_Count', 1);
    end
    burst_count = max(1, round(burst_count));
end

function value = Sample_Range(range_vals)
    if numel(range_vals) == 1 || range_vals(1) == range_vals(2)
        value = ceil(range_vals(1));
    else
        value = ceil((range_vals(2)-range_vals(1))*rand + range_vals(1));
    end
end

function val = Get_Field_Or_Default(S, field_name, default_val)
    if isfield(S, field_name) && ~isempty(S.(field_name))
        val = S.(field_name);
    else
        val = default_val;
    end
end
