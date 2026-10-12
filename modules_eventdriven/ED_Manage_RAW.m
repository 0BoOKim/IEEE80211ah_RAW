function SimState = ED_Manage_RAW(SimState, SimParams)
%ED_MANAGE_RAW Event-driven counterpart of Manage_RAW.

    i = SimState.Time;
    if ~SimParams.On_RAW
        return;
    end

    for bss_id = 1:SimParams.N_AP
        if i == SimState.Next_BTT(bss_id) + 1
            raw_slot_length = SimParams.BSS_T_RAW_Slot_in_Slot(bss_id);
            n_raw = SimParams.BSS_N_RAW(bss_id);
            beacon_interval = SimParams.BSS_Beacon_Interval(bss_id);

            Tab_RAW = zeros(n_raw, 3);
            Tab_RAW(1, :) = [i + 1, i + raw_slot_length, 0];
            for raw_idx = 2:n_raw
                Tab_RAW(raw_idx, 1) = Tab_RAW(raw_idx - 1, 2) + 1;
                Tab_RAW(raw_idx, 2) = ...
                    Tab_RAW(raw_idx, 1) + raw_slot_length;
            end

            sta_ids = SimState.BSS(bss_id).STA_IDs;
            [current_offset, fcs_lower16, next_prng_state] = ...
                Get_Beacon_RAW_Offset( ...
                SimState, SimParams, bss_id, n_raw);
            SimState = Record_RAW_Offset( ...
                SimState, bss_id, current_offset, ...
                fcs_lower16, next_prng_state);
            [assigned_sta, SimState] = Assign_STA_To_RAW( ...
                SimState, SimParams, sta_ids, n_raw, current_offset);
            SimState.List_Assigned_STA{bss_id} = assigned_sta;
            for raw_idx = 1:n_raw
                cached_ids = assigned_sta(raw_idx, :);
                SimState.ED_RAW_Assignment_Cache{bss_id}{raw_idx} = ...
                    cached_ids(cached_ids ~= 0);
            end
            SimState.Tab_RAW{bss_id} = Tab_RAW;
            SimState.Next_BTT(bss_id) = SimState.Next_BTT(bss_id) + ...
                beacon_interval + n_raw;
        end

        if SimParams.On_CSB ~= 0
            error('ED:UnsupportedCSB', ...
                'The independent event-driven engine currently supports On_CSB=0.');
        end

        Tab_RAW = SimState.Tab_RAW{bss_id};
        for raw_idx = 1:size(Tab_RAW, 1)
            if Tab_RAW(raw_idx, 1) == i
                if Tab_RAW(raw_idx, 3) ~= 0
                    error('ED:UnexpectedRAWState', ...
                        'RAW slot was already active at its start boundary.');
                end
                Tab_RAW(raw_idx, 3) = 1;
            end

            if Tab_RAW(raw_idx, 2) == i
                if Tab_RAW(raw_idx, 3) ~= 1
                    error('ED:UnexpectedRAWState', ...
                        'RAW slot was not active at its end boundary.');
                end
                Tab_RAW(raw_idx, 3) = 0;

                collect_remained = true;
                if isfield(SimParams, 'ED_Collect_RAW_Remained_Log')
                    collect_remained = ...
                        SimParams.ED_Collect_RAW_Remained_Log;
                end
                if collect_remained
                    ap_id = SimState.BSS(bss_id).AP_ID;
                    raw_slots = Tab_RAW(raw_idx, 1):Tab_RAW(raw_idx, 2);
                    channel_state = ED_Channel_Get( ...
                        SimState.ED_Channel, raw_slots, ap_id);
                    last_busy = find(channel_state ~= 0, 1, 'last');
                    if isempty(last_busy)
                        remained = numel(raw_slots) - 1;
                    else
                        remained = numel(raw_slots) - last_busy - 1;
                    end
                    SimState.List_Remained_Slot{bss_id} = [ ...
                        SimState.List_Remained_Slot{bss_id}; ...
                        remained, raw_idx]; %#ok<AGROW>
                end
            end
        end
        SimState.Tab_RAW{bss_id} = Tab_RAW;
    end
end

function [Assigned, SimState] = Assign_STA_To_RAW( ...
    SimState, SimParams, sta_ids, n_raw, current_offset)
    n_sta = numel(sta_ids);

    switch SimParams.RAW_Mode
        case 0
            shuffled = sta_ids(randperm(n_sta));
            width = max(1, ceil(max(n_sta, 1) / n_raw));
            Assigned = zeros(n_raw, width);
            for k = 1:n_sta
                raw_idx = min(n_raw, ceil(k / width));
                col_idx = mod(k - 1, width) + 1;
                Assigned(raw_idx, col_idx) = shuffled(k);
            end
            SimState.RAW_TX_Allowed(sta_ids) = true;

        case 3
            % Keep the Standard RAW per-Beacon offset. TX_LOG changes only
            % per-cycle contention admission, never RAW membership.
            Assigned = Build_Fixed_RAW_Assignment( ...
                sta_ids, n_raw, current_offset);
            for k = 1:n_sta
                sta_id = sta_ids(k);
                if ~isfield(SimState, 'ED_Measure')
                    error('ED:MissingTXLogMeasurement', ...
                        'RAW_Mode 3 requires congestion measurements.');
                end

                ch_bin = ceil( ...
                    SimState.ED_Measure.CH_Util(sta_id) / ...
                    SimParams.Bin_CH_Usage) * SimParams.Bin_CH_Usage;
                ack_bin = ceil( ...
                    SimState.ED_Measure.N_ACK(sta_id) / ...
                    SimParams.Bin_N_ACK) * SimParams.Bin_N_ACK;

                txlog_idx = find( ...
                    SimParams.TX_LOG(:, 1) == ch_bin & ...
                    SimParams.TX_LOG(:, 2) == ack_bin);
                if isempty(txlog_idx)
                    SimState.Cnt_NoLog(sta_id) = ...
                        SimState.Cnt_NoLog(sta_id) + 1;
                    distance = sqrt( ...
                        (SimParams.Norm_TX_LOG(:, 1) - ...
                         ch_bin / Safe_Max(SimParams.TX_LOG(:, 1))).^2 + ...
                        (SimParams.Norm_TX_LOG(:, 2) - ...
                         ack_bin / Safe_Max(SimParams.TX_LOG(:, 2))).^2);
                    [~, txlog_idx] = min(distance);
                end

                tx_probability = min(1, max(0, ...
                    SimParams.TX_LOG(txlog_idx(1), 11)));
                SimState.RAW_TX_Allowed(sta_id) = ...
                    Sample_TXLOG_Admission(tx_probability);
            end

        case 4
            Assigned = Build_Fixed_RAW_Assignment( ...
                sta_ids, n_raw, current_offset);
            SimState.RAW_TX_Allowed(sta_ids) = true;

        otherwise
            error('ED:UnsupportedRAWMode', ...
                'The event-driven engine supports RAW modes 0, 3, and 4.');
    end
end

function [current_offset, fcs_lower16, next_prng_state] = ...
    Get_Beacon_RAW_Offset(SimState, SimParams, bss_id, n_raw)

    if SimParams.RAW_Mode == 3 || SimParams.RAW_Mode == 4
        [current_offset, fcs_lower16, next_prng_state] = ...
            Draw_RAW_Beacon_Offset( ...
            SimParams, n_raw, ...
            SimState.BSS(bss_id).RAW_Offset_PRNG_State);
    else
        current_offset = SimParams.N_offset;
        fcs_lower16 = NaN;
        next_prng_state = SimState.BSS(bss_id).RAW_Offset_PRNG_State;
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
    if tx_probability <= 0
        admitted = false;
    elseif tx_probability >= 1
        admitted = true;
    else
        admitted = rand <= tx_probability;
    end
end

function value = Safe_Max(x)
    value = max(x);
    if isempty(value) || ~isfinite(value) || value <= 0
        value = 1;
    end
end
