function SimState = Manage_RAW(SimState, SimParams)

    i = SimState.Time;

    if SimParams.On_RAW
        for bss_id = 1:SimParams.N_AP
            if i == SimState.Next_BTT(bss_id)+1  % at the begin of this BSS RAW period

               T_RAW_Slot_in_Slot = SimParams.BSS_T_RAW_Slot_in_Slot(bss_id);
               N_RAW = SimParams.BSS_N_RAW(bss_id);
               Beacon_Interval = SimParams.BSS_Beacon_Interval(bss_id);

               % configure the RAW slot
               Tab_RAW = [i+1 i+T_RAW_Slot_in_Slot 0];

               if N_RAW > 1
                   for idx_RAW = 2:N_RAW
                        Tab_RAW(idx_RAW, 1) = Tab_RAW(idx_RAW-1, 2) + 1;
                        Tab_RAW(idx_RAW, 2) = Tab_RAW(idx_RAW, 1)+T_RAW_Slot_in_Slot;
                        Tab_RAW(idx_RAW, 3)  = 0;
                   end
               end

               idx_STA = SimState.BSS(bss_id).STA_IDs;
               N_STA_BSS = length(idx_STA);
               current_offset = SimParams.N_offset;
               if SimParams.RAW_Mode == 3 || SimParams.RAW_Mode == 4
                   [current_offset, fcs_lower16, next_prng_state] = ...
                       Draw_RAW_Beacon_Offset( ...
                       SimParams, N_RAW, ...
                       SimState.BSS(bss_id).RAW_Offset_PRNG_State);
                   SimState = Record_RAW_Offset( ...
                       SimState, bss_id, current_offset, ...
                       fcs_lower16, next_prng_state);
               end

               if SimParams.RAW_Mode == 0
                  % Allocate STAs based on uniform random distribution
                  All_User = idx_STA(:);
                  SimState.List_Assigned_STA{bss_id} = [];

                  N_Assigned_STA = ceil(max(N_STA_BSS, 1)/N_RAW);

                   for idx_RAW = 1:N_RAW
                       for idx = 1:N_Assigned_STA
                          if isempty(All_User)
                              break;
                          end
                          Temp_Assigned_STA = All_User(ceil(rand*length(All_User)));
                          SimState.List_Assigned_STA{bss_id}(idx_RAW, idx) = Temp_Assigned_STA;
                           All_User(All_User == Temp_Assigned_STA) = [];
                       end
                   end
                   SimState.RAW_TX_Allowed(idx_STA) = true;

               elseif SimParams.RAW_Mode == 3

                   % All associated STAs use the same per-Beacon FCS-derived
                   % offset as Standard RAW. TX_LOG controls only whether a
                   % STA may contend in this RAW cycle.
                   SimState.List_Assigned_STA{bss_id} = ...
                       Build_Fixed_RAW_Assignment( ...
                       idx_STA, N_RAW, current_offset);

                   for j = 1:N_STA_BSS
                       sta_id = idx_STA(j);
                       % Net Congestion Logic
                       if isempty(SimState.Net_Congestion_Measure(sta_id).CH_Util)
                           error('There is no TX_Log!');
                       end

                       current_idx = size(SimState.Net_Congestion_Measure(sta_id).CH_Util, 1);
                       Temp_Bin_CH_Usage = ceil( ...
                           SimState.Net_Congestion_Measure(sta_id).CH_Util(current_idx,2) / ...
                           SimParams.Bin_CH_Usage) * SimParams.Bin_CH_Usage;
                       Temp_Bin_ACK = ceil( ...
                           SimState.Net_Congestion_Measure(sta_id).N_ACK(current_idx,2) / ...
                           SimParams.Bin_N_ACK) * SimParams.Bin_N_ACK;

                       Temp_Idx_TX_LOG = find( ...
                           SimParams.TX_LOG(:,1) == Temp_Bin_CH_Usage & ...
                           SimParams.TX_LOG(:,2) == Temp_Bin_ACK);

                       if isempty(Temp_Idx_TX_LOG)
                           SimState.Cnt_NoLog(sta_id) = ...
                               SimState.Cnt_NoLog(sta_id) + 1;

                           Max_TXLOG_CH = max(SimParams.TX_LOG(:,1));
                           Max_TXLOG_ACK = max(SimParams.TX_LOG(:,2));
                           if Max_TXLOG_CH <= 0 || ~isfinite(Max_TXLOG_CH)
                               Max_TXLOG_CH = 1;
                           end
                           if Max_TXLOG_ACK <= 0 || ~isfinite(Max_TXLOG_ACK)
                               Max_TXLOG_ACK = 1;
                           end

                           EuclDist = sqrt( ...
                               (SimParams.Norm_TX_LOG(:,1) - ...
                                Temp_Bin_CH_Usage/Max_TXLOG_CH).^2 + ...
                               (SimParams.Norm_TX_LOG(:,2) - ...
                                Temp_Bin_ACK/Max_TXLOG_ACK).^2);
                           [~, Temp_Idx_TX_LOG] = min(EuclDist);
                       end

                       TX_Prob = SimParams.TX_LOG(Temp_Idx_TX_LOG(1),11);

                       if SimParams.Enable_TxWeight
                          [PrevTxProb, PrevTxWeight] = ...
                              Get_PrevTxConfig(sta_id, SimState.Prev_TxConfig);

                          if PrevTxProb == -1 || PrevTxWeight == -1
                             TxWeight = SimParams.Init_TxWeight;
                          else
                             R_Suc = Calc_SucRatio( ...
                                 sta_id, SimState.Net_Congestion_Measure);
                             TxWeight = PrevTxWeight;

                             if R_Suc <= PrevTxProb
                                TxWeight = max( ...
                                    SimParams.Min_TxWeight, ...
                                    TxWeight - SimParams.Dec_TxWeight);
                             elseif R_Suc > PrevTxProb
                                TxWeight = min( ...
                                    SimParams.Max_TxWeight, ...
                                    TxWeight + SimParams.Inc_TxWeight);
                             elseif isnan(R_Suc)
                                TxWeight = PrevTxWeight;
                             else
                                 error('unexpected case of variable R_suc!');
                             end
                          end

                          TX_Prob = TxWeight * TX_Prob;
                          SimState.Prev_TxConfig = Set_PrevTxConfig( ...
                              sta_id, SimState.Prev_TxConfig, ...
                              TX_Prob, TxWeight);

                          if SimParams.On_Log_TxWeight
                              NodeID_Log_TxWeight = find( ...
                                  SimParams.Target_Node_Log_TxWeight == sta_id);
                              if i >= SimState.Next_Measure_Interval_Log_TxWeight && ...
                                      ~isempty(NodeID_Log_TxWeight)
                                 idx_row = SimState.Ptr_EachNodeLog(NodeID_Log_TxWeight);
                                 idx_col = NodeID_Log_TxWeight*3-2;
                                 SimState.Ptr_EachNodeLog(NodeID_Log_TxWeight) = ...
                                     SimState.Ptr_EachNodeLog(NodeID_Log_TxWeight) + 1;

                                 SimState.Log_TxWeight( ...
                                     idx_row, idx_col:idx_col+2) = ...
                                     [i TxWeight TX_Prob];
                                 SimState.Next_Measure_Interval_Log_TxWeight = ...
                                     SimState.Next_Measure_Interval_Log_TxWeight + ...
                                     SimParams.Measure_Interval_Log_TxWeight;
                              end
                          end
                       end

                       SimState.RAW_TX_Allowed(sta_id) = ...
                           Sample_TXLOG_Admission(TX_Prob);
                   end

               elseif SimParams.RAW_Mode == 4
                   % Standard RAW: every associated STA is mapped using the
                   % current Beacon FCS-derived offset. Empty STAs remain
                   % silent in MAC_Access.
                   SimState.List_Assigned_STA{bss_id} = ...
                       Build_Fixed_RAW_Assignment( ...
                       idx_STA, N_RAW, current_offset);
                  SimState.RAW_TX_Allowed(idx_STA) = true;
               end

               SimState.Tab_RAW{bss_id} = Tab_RAW;
               % update Next Beacon Transmission Time
               SimState.Next_BTT(bss_id) = SimState.Next_BTT(bss_id) + Beacon_Interval + (N_RAW-1) + 1;
            end

            % Check RAW Slot Boundaries (CSB Logic)
            if SimParams.On_CSB == 0
                Tab_RAW = SimState.Tab_RAW{bss_id};
                N_RAW = SimParams.BSS_N_RAW(bss_id);
                for idx_RAW = 1:N_RAW
                    if Tab_RAW(idx_RAW, 1) == i
                        if Tab_RAW(idx_RAW, 3) ~= 0
                             error('Unexpected RAW STATE!');
                        end
                        Tab_RAW(idx_RAW, 3) = 1;
                    end

                     if Tab_RAW(idx_RAW, 2) == i
                         if Tab_RAW(idx_RAW, 3) ~= 1
                             error('Unexpected RAW STATE!');
                         end
                         Tab_RAW(idx_RAW, 3) = 0;

                         ap_id = SimState.BSS(bss_id).AP_ID;
                         Temp_Channel_State = sum(SimState.tx_state(Tab_RAW(idx_RAW, 1):Tab_RAW(idx_RAW, 2), ap_id)');
                         idx_last_CH_access_time = find(Temp_Channel_State ~= 0, 1, 'last');

                         if isempty(idx_last_CH_access_time)
                             SimState.List_Remained_Slot{bss_id} = [SimState.List_Remained_Slot{bss_id}; length(Temp_Channel_State)-1 idx_RAW];
                         else
                             SimState.List_Remained_Slot{bss_id} = [SimState.List_Remained_Slot{bss_id}; length(Temp_Channel_State) - find(Temp_Channel_State ~= 0, 1, 'last')-1 idx_RAW];
                         end
                     end
                end
                SimState.Tab_RAW{bss_id} = Tab_RAW;
            end
        end
        % CSB=1 logic omitted as it says "not used longer" in original code (but logic was there).
    end
end

function SimState = Record_RAW_Offset( ...
    SimState, bss_id, current_offset, fcs_lower16, next_prng_state)

    beacon_count = SimState.BSS(bss_id).RAW_Offset_Beacon_Count;
    if beacon_count > 0
        previous_offset = SimState.BSS(bss_id).Current_N_offset;
        if current_offset == previous_offset
            SimState.BSS(bss_id).RAW_Offset_Repeat_Count = ...
                SimState.BSS(bss_id).RAW_Offset_Repeat_Count + 1;
        else
            SimState.BSS(bss_id).RAW_Offset_Change_Count = ...
                SimState.BSS(bss_id).RAW_Offset_Change_Count + 1;
        end
    end
    SimState.BSS(bss_id).Current_N_offset = current_offset;
    SimState.BSS(bss_id).Beacon_FCS_Lower16 = fcs_lower16;
    SimState.BSS(bss_id).RAW_Offset_PRNG_State = next_prng_state;
    SimState.BSS(bss_id).RAW_Offset_Beacon_Count = beacon_count + 1;
end

function admitted = Sample_TXLOG_Admission(tx_probability)
    tx_probability = min(1, max(0, tx_probability));
    if tx_probability <= 0
        admitted = false;
    elseif tx_probability >= 1
        admitted = true;
    else
        admitted = rand <= tx_probability;
    end
end
