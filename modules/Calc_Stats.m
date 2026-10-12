function Stats = Calc_Stats(SimState, SimParams)

    N_Node = SimParams.N_Node;
    N_STA = SimParams.N_STA;
    T_slot = SimParams.T_slot;
    idx_STA = SimParams.idx_STA;

    % Access Stats
    Stats.n_access = SimState.n_access;

    % Plot Cumulative Triggered STAs
    figure;
    hold on;
    plot(SimState.Measure_Cummulated_N_Triggerd_STAs(:,1), SimState.Measure_Cummulated_N_Triggerd_STAs(:,2),'.');
    title('Cumulative Triggered STAs');
    hold off;

    Diff_Measure_Cummulated_N_Triggerd_STAs = SimState.Measure_Cummulated_N_Triggerd_STAs(2:length(SimState.Measure_Cummulated_N_Triggerd_STAs(:,2)),2) ...
                                            - SimState.Measure_Cummulated_N_Triggerd_STAs(1:length(SimState.Measure_Cummulated_N_Triggerd_STAs(:,2))-1,2);
    figure;
    hold on;
    plot(SimState.Measure_Cummulated_N_Triggerd_STAs(2:length(SimState.Measure_Cummulated_N_Triggerd_STAs(:,2)),1), Diff_Measure_Cummulated_N_Triggerd_STAs);
    title('Differential Triggered STAs');
    hold off;

    % Delay Stats
    Avg_Delay = zeros(N_Node, 3);
    Avg_AccessDelay = zeros(N_Node, 3);
    cnt_empty_delay_measure = 0;

    for j = 1:N_Node
        if (isempty(SimState.Delay(j).delay))
            cnt_empty_delay_measure = cnt_empty_delay_measure + 1;
        else
            L_Delay_Data = length(SimState.Delay(j).delay(:,1));
            if L_Delay_Data == 1
                SimState.Delay(j).delay(1,4) =  SimState.Delay(j).delay(1,3);
            else
                SimState.Delay(j).delay(:,4) = SimState.Delay(j).delay(:,2)-[0;SimState.Delay(j).delay(1:L_Delay_Data-1,2)];
                SimState.Delay(j).delay(1,4) =  SimState.Delay(j).delay(1,3);
            end
            Avg_Delay(j, :) = [nanmean(SimState.Delay(j).delay(:,3))*T_slot nanmin(SimState.Delay(j).delay(:,3))*T_slot nanmax(SimState.Delay(j).delay(:,3))*T_slot];
            Avg_AccessDelay(j,:) = [nanmean(SimState.Delay(j).delay(:,4))*T_slot nanmin(SimState.Delay(j).delay(:,4))*T_slot nanmax(SimState.Delay(j).delay(:,4))*T_slot];
        end
    end

    Stats.cnt_empty_delay_measure = cnt_empty_delay_measure;
    Stats.Avg_Delay = Avg_Delay;

    % Throughput & Fairness
    if SimParams.Opt_Start == 0 && SimParams.Opt_End == SimParams.N_slot
        Temp_Solve_Time = SimParams.N_slot;
    else
        Idx_Solved_Time = find(SimState.Traffic_Temporal_Evolution(find(SimState.Traffic_Temporal_Evolution(:,1) > SimParams.Opt_End),6)==0,1);
        Temp_Solve_Time = SimState.Traffic_Temporal_Evolution(find(SimState.Traffic_Temporal_Evolution(:,1) > SimParams.Opt_End),1);
        if ~isempty(Idx_Solved_Time)
             Temp_Solve_Time = Temp_Solve_Time(Idx_Solved_Time);
        else
             Temp_Solve_Time = SimParams.Opt_End; % Fallback
        end
    end
    % Force overwrite as in original
    Temp_Solve_Time = SimParams.Opt_End;

    per_user_th = (SimState.L_success * 8) / ((SimParams.N_slot)*T_slot) / 10^6;  % Mb/s
    total_th = sum(SimState.L_success * 8) / ((SimParams.N_slot)*T_slot) / 10^6;
    normalized_th = total_th/(SimParams.R_data(1)*10^-6);
    fairness_index = total_th^2 / (N_STA * sum(per_user_th.*per_user_th));

    Stats.total_th = total_th;
    Stats.normalized_th = normalized_th;
    Stats.fairness_index = fairness_index;

    % Collision & Loss
    avg_collision_ratio = [nanmean(SimState.n_collision(idx_STA)./SimState.n_access(idx_STA)) nanmean(SimState.n_collision2(idx_STA)./SimState.n_access(idx_STA))];
    avg_n_access = mean(SimState.n_access(idx_STA));
    avg_success_ratio = [nanmean(SimState.n_success(idx_STA)./SimState.n_access(idx_STA)) nanmean(SimState.n_success2(idx_STA)./SimState.n_access(idx_STA))];

    loss_ratio = SimState.n_loss(idx_STA)./SimState.n_enq(idx_STA);
    avg_loss_ratio = nanmean(loss_ratio);
    avg_loss = mean(SimState.n_loss(idx_STA));

    Stats.avg_collision_ratio = avg_collision_ratio;
    Stats.avg_n_access = avg_n_access;
    Stats.avg_success_ratio = avg_success_ratio;
    Stats.avg_loss_ratio = avg_loss_ratio;

    % Multi-BSS performance and interference diagnostics
    if isfield(SimState, 'BSS_Interference') && SimParams.N_AP > 1
        PerBSS = zeros(SimParams.N_AP, 24);
        Collision_Matrix = SimState.BSS_Interference.Collision_Matrix;
        RAW_Overlap_Slots = SimState.BSS_Interference.RAW_Overlap_Slots;
        TX_Overlap_Slots = SimState.BSS_Interference.TX_Overlap_Slots;

        for bss_id = 1:SimParams.N_AP
            sta_ids = SimState.BSS(bss_id).STA_IDs;
            alarm_ids = SimState.BSS(bss_id).Alarm_STA_IDs;
            n_access_bss = sum(SimState.n_access(sta_ids));
            n_success_acked_bss = sum(SimState.n_success2(sta_ids));
            n_data_collision_bss = sum(SimState.n_collision(sta_ids));
            n_ack_timeout_bss = sum(SimState.n_collision2(sta_ids));
            n_loss_bss = sum(SimState.n_loss(sta_ids));
            n_enq_bss = sum(SimState.n_enq(sta_ids));
            bss_th = sum(SimState.L_success(sta_ids) * 8) / (SimParams.N_slot*T_slot) / 10^6;
            bss_success_ratio = Safe_Div(n_success_acked_bss, n_access_bss);
            bss_collision_ratio = Safe_Div(n_data_collision_bss, n_access_bss);
            bss_ack_timeout_ratio = Safe_Div(n_ack_timeout_bss, n_access_bss);
            bss_loss_ratio = Safe_Div(n_loss_bss, n_enq_bss);
            bss_delay = Collect_BSS_Delay(SimState.Delay, sta_ids, T_slot);
            active_alarm_count = Count_Triggered_Alarm_STAs(SimState, alarm_ids);
            intra_collision_events = Collision_Matrix(bss_id, bss_id);
            cross_collision_events = sum(Collision_Matrix(bss_id, :)) - intra_collision_events;
            caused_cross_collision_events = sum(Collision_Matrix(:, bss_id)) - intra_collision_events;
            raw_overlap_with_other = sum(RAW_Overlap_Slots(bss_id, :)) - RAW_Overlap_Slots(bss_id, bss_id);
            tx_overlap_with_other = sum(TX_Overlap_Slots(bss_id, :)) - TX_Overlap_Slots(bss_id, bss_id);

            PerBSS(bss_id,:) = [ ...
                bss_id, ...
                length(sta_ids), ...
                length(alarm_ids), ...
                active_alarm_count, ...
                bss_th, ...
                bss_success_ratio, ...
                bss_collision_ratio, ...
                bss_ack_timeout_ratio, ...
                bss_loss_ratio, ...
                bss_delay(1), ...
                bss_delay(2), ...
                bss_delay(3), ...
                n_access_bss, ...
                n_success_acked_bss, ...
                n_data_collision_bss, ...
                n_ack_timeout_bss, ...
                n_loss_bss, ...
                n_enq_bss, ...
                intra_collision_events, ...
                cross_collision_events, ...
                caused_cross_collision_events, ...
                SimState.BSS_Interference.RAW_Active_Slots(bss_id), ...
                raw_overlap_with_other, ...
                tx_overlap_with_other];
        end

        Stats.Per_BSS = array2table(PerBSS, 'VariableNames', { ...
            'BSS_ID', 'N_STA', 'N_Alarm_STA', 'Active_Alarm_STA_Count', ...
            'Throughput_Mbps', 'Success_Ratio_ACKed', 'Collision_Ratio_Data', ...
            'ACK_Timeout_Ratio', 'Loss_Ratio', 'Avg_Delay_s', 'Min_Delay_s', 'Max_Delay_s', ...
            'N_Access', 'N_Success_ACKed', 'N_Data_Collision', 'N_ACK_Timeout', 'N_Loss', 'N_Enqueued', ...
            'Intra_BSS_Collision_Events', ...
            'Cross_BSS_Collision_Events_As_Victim', 'Cross_BSS_Collision_Events_As_Interferer', ...
            'RAW_Active_Slots', 'RAW_Overlap_Slots_With_Other_BSS', 'TX_Overlap_Slots_With_Other_BSS'});

        bss_throughput = Stats.Per_BSS.Throughput_Mbps;
        bss_success_ratio = Stats.Per_BSS.Success_Ratio_ACKed;
        bss_collision_ratio = Stats.Per_BSS.Collision_Ratio_Data;
        bss_loss_ratio = Stats.Per_BSS.Loss_Ratio;
        bss_delay = Stats.Per_BSS.Avg_Delay_s;

        Stats.BSS_Fairness = struct();
        Stats.BSS_Fairness.Throughput_Jain = Jain_Index(bss_throughput);
        Stats.BSS_Fairness.Success_Ratio_Jain = Jain_Index(NaN_To_Zero(bss_success_ratio));
        Stats.BSS_Fairness.Active_Alarm_Count_Jain = Jain_Index(Stats.Per_BSS.Active_Alarm_STA_Count);

        [worst_th, worst_th_idx] = min(bss_throughput);
        [worst_success, worst_success_idx] = min(Ignore_NaN_For_Min(bss_success_ratio));
        [worst_collision, worst_collision_idx] = max(Ignore_NaN_For_Max(bss_collision_ratio));
        [worst_loss, worst_loss_idx] = max(Ignore_NaN_For_Max(bss_loss_ratio));
        [worst_delay, worst_delay_idx] = max(Ignore_NaN_For_Max(bss_delay));

        Stats.Worst_BSS = table( ...
            {'Throughput_Mbps'; 'Success_Ratio_ACKed'; 'Collision_Ratio_Data'; 'Loss_Ratio'; 'Avg_Delay_s'}, ...
            [worst_th; worst_success; worst_collision; worst_loss; worst_delay], ...
            [worst_th_idx; worst_success_idx; worst_collision_idx; worst_loss_idx; worst_delay_idx], ...
            'VariableNames', {'Metric', 'Worst_Value', 'BSS_ID'});

        BSS_Names = arrayfun(@(x) sprintf('BSS_%d', x), 1:SimParams.N_AP, 'UniformOutput', false);
        Stats.BSS_Collision_Matrix = array2table(Collision_Matrix, ...
            'VariableNames', BSS_Names, 'RowNames', BSS_Names);

        Stats.BSS_RAW_Overlap_Matrix = array2table(RAW_Overlap_Slots, ...
            'VariableNames', BSS_Names, 'RowNames', BSS_Names);
        Stats.BSS_TX_Overlap_Matrix = array2table(TX_Overlap_Slots, ...
            'VariableNames', BSS_Names, 'RowNames', BSS_Names);

        Stats.BSS_Interference_LinkType = table( ...
            SimState.BSS_Interference.Link_Type_Names(:), ...
            SimState.BSS_Interference.Link_Type_Count(:), ...
            'VariableNames', {'Interference_Link_Type', 'Collision_Event_Count'});
    end

    % Result Set
    Stats.RESULT_SET2 = [total_th normalized_th avg_n_access avg_success_ratio avg_collision_ratio avg_loss_ratio avg_loss mean(Avg_Delay)];

    % Print
    disp('Statistics:');
    disp(Stats.RESULT_SET2);

    if isfield(Stats, 'Per_BSS')
        disp('Per-BSS Performance and Interference Diagnostics:');
        disp(Stats.Per_BSS);
        disp('BSS Collision Matrix (rows=victim BSS, columns=interferer BSS):');
        disp(Stats.BSS_Collision_Matrix);
        disp('Interference Link Type Collision Events:');
        disp(Stats.BSS_Interference_LinkType);
        disp('BSS Fairness Summary:');
        disp(Stats.BSS_Fairness);
        disp('Worst-BSS Summary:');
        disp(Stats.Worst_BSS);
    end

    if(SimParams.RAW_Mode == 3)
        disp('Count No Log:');
        disp(sum(SimState.Cnt_NoLog));
        disp(mean(SimState.Cnt_NoLog(2:N_Node)));
    end

    if SimParams.On_Save_TX_Log
         % Unpack variables required by Anal_Congestion_Log script
         Net_Congestion_Measure = SimState.Net_Congestion_Measure;
         On_Save_TX_Log = SimParams.On_Save_TX_Log;
         N_alarmSTA = SimParams.N_alarmSTA;
         N_bkSTA = SimParams.N_bkSTA;
         if isfield(SimParams, 'N_RAW')
            N_RAW = SimParams.N_RAW;
         else
            N_RAW = SimParams.Opt_N_RAW;
         end
         C = SimParams.Opt_Slot_Duration_Count;
         if isfield(SimState, 'TX_LOG_Access_Log')
            TX_LOG_Access_Log = SimState.TX_LOG_Access_Log;
         else
            TX_LOG_Access_Log = [];
         end

         Anal_Congestion_Log;
    end

    if isfield(SimParams, 'On_Plot_Alarm_Activation_Validation') && ...
       SimParams.On_Plot_Alarm_Activation_Validation && ...
       (SimParams.Traffic_Surge_Mode == 3 || SimParams.Traffic_Surge_Mode == 4)
        try
            Plot_Alarm_Activation_Validation(SimState, SimParams);
        catch ME
            warning('Activation validation plot failed: %s', ME.message);
        end
    end

    if isfield(SimParams, 'On_Plot_MultiBSS_Results') && ...
       SimParams.On_Plot_MultiBSS_Results && ...
       SimParams.N_AP > 1
        try
            Plot_MultiBSS_Results(SimState, SimParams, Stats);
        catch ME
            warning('Multi-BSS result plotting failed: %s', ME.message);
        end
    end

    if isfield(SimParams, 'On_Plot_Farsite_Front_Animation') && ...
       SimParams.On_Plot_Farsite_Front_Animation && ...
       SimParams.Traffic_Surge_Mode == 4
        try
            Plot_Farsite_Front_Animation(SimState, SimParams);
        catch ME
            warning('FARSITE front animation failed: %s', ME.message);
        end
    end

end

function y = Safe_Div(num, den)
    if den == 0
        y = NaN;
    else
        y = num / den;
    end
end

function delay_stats = Collect_BSS_Delay(Delay, sta_ids, T_slot)
    all_delay_slots = [];
    for idx = sta_ids(:).'
        if ~isempty(Delay(idx).delay)
            all_delay_slots = [all_delay_slots; Delay(idx).delay(:,3)]; %#ok<AGROW>
        end
    end

    if isempty(all_delay_slots)
        delay_stats = [NaN NaN NaN];
    else
        delay_stats = [nanmean(all_delay_slots) nanmin(all_delay_slots) nanmax(all_delay_slots)] * T_slot;
    end
end

function n_triggered = Count_Triggered_Alarm_STAs(SimState, alarm_ids)
    n_triggered = 0;
    for idx = alarm_ids(:).'
        if isfield(SimState.Node.TX_Buffer(idx), 'Triggered') && SimState.Node.TX_Buffer(idx).Triggered == 1
            n_triggered = n_triggered + 1;
        end
    end
end

function jain = Jain_Index(x)
    x = x(:);
    x = x(isfinite(x));
    if isempty(x) || sum(x.^2) == 0
        jain = NaN;
    else
        jain = sum(x)^2 / (length(x) * sum(x.^2));
    end
end

function x = NaN_To_Zero(x)
    x(~isfinite(x)) = 0;
end

function x = Ignore_NaN_For_Min(x)
    x(~isfinite(x)) = Inf;
end

function x = Ignore_NaN_For_Max(x)
    x(~isfinite(x)) = -Inf;
end
