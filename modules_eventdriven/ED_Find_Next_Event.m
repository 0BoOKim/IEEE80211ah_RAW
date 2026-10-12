function next_slot = ED_Find_Next_Event( ...
    SimState, SimParams, next_report_slot)
%ED_FIND_NEXT_EVENT Find the earliest slot that can change simulation state.

    i = SimState.Time;
    candidates = SimParams.N_slot;

    candidates = Add_Future(candidates, ...
        SimState.Next_BTT + 1, i);
    for bss_id = 1:SimParams.N_AP
        tab = SimState.Tab_RAW{bss_id};
        candidates = Add_Future(candidates, tab(:, 1), i);
        candidates = Add_Future(candidates, tab(:, 2), i);
    end

    candidates = Add_Future(candidates, ...
        SimState.tx_status(:, 2), i);
    if isfield(SimState, 'ED_TXOP')
        candidates = Add_Future(candidates, ...
            SimState.ED_TXOP.NextDataSlot, i);
    end
    ack_expiry = SimState.Node.ACK_Timer(:, 1);
    ack_expiry(ack_expiry ~= -1) = ...
        ack_expiry(ack_expiry ~= -1) + 1;
    candidates = Add_Future(candidates, ack_expiry, i);

    for ap_id = SimParams.idx_AP
        if SimState.Node.TX_Buffer(ap_id).ACK_Length <= 0
            continue;
        end
        ack = ED_Peek_ACK(SimState.Node.TX_Buffer(ap_id));
        ack_due = ack(5) + ...
            SimParams.SIFSN;
        if ack_due > i
            candidates(end + 1) = ack_due; %#ok<AGROW>
        elseif SimState.tx_status(ap_id, 1) == -1 && ...
               SimState.n_txnode(ap_id) == 0
            candidates(end + 1) = i + 1; %#ok<AGROW>
        end
    end

    background_ids = SimState.ED_Background_STA_IDs;
    candidates = Add_Future(candidates, ...
        SimState.Next_Frame_Interval_bk(background_ids), i);
    if isfield(SimState, 'ED_Camera') && SimState.ED_Camera.Enabled
        camera_due = SimState.ED_Camera.Next_Frame_Slot;
        camera_due(camera_due > ...
            SimState.ED_Camera.Active_Until_Slot) = inf;
        candidates = Add_Future(candidates, camera_due, i);
    end
    active_alarm = SimState.ED_Active_Alarm_IDs( ...
        1:SimState.ED_Active_Alarm_Count);
    candidates = Add_Future(candidates, ...
        SimState.Next_Frame_Interval_al(active_alarm), i);

    event_idx = SimState.ED_Activation_Event_Index;
    if event_idx <= size(SimParams.ED_Beta_Activation_Events, 1)
        candidates = Add_Future(candidates, ...
            SimParams.ED_Beta_Activation_Events(event_idx, 1), i);
    end

    if SimParams.Mode_Net_Congestion_Measure
        candidates = Add_Future(candidates, ...
            SimState.Next_Net_Congestion_Measure_Time + 1, i);
    end
    if isfinite(next_report_slot)
        candidates = Add_Future(candidates, next_report_slot, i);
    end

    backoff_slot = Earliest_Backoff_Completion( ...
        SimState, SimParams);
    candidates = Add_Future(candidates, backoff_slot, i);

    next_slot = min(candidates);
    if isempty(next_slot) || ~isfinite(next_slot)
        next_slot = SimParams.N_slot;
    end
    if isfield(SimParams, 'ED_Max_Event_Gap_Slots') && ...
       ~isempty(SimParams.ED_Max_Event_Gap_Slots) && ...
       isfinite(SimParams.ED_Max_Event_Gap_Slots)
        next_slot = min(next_slot, ...
            i + max(1, SimParams.ED_Max_Event_Gap_Slots));
    end
    next_slot = min(SimParams.N_slot, max(i + 1, next_slot));
end

function candidates = Add_Future(candidates, values, current_slot)
    values = values(:).';
    values = values(isfinite(values) & values > current_slot);
    if ~isempty(values)
        candidates = [candidates, values]; %#ok<AGROW>
    end
end

function next_slot = Earliest_Backoff_Completion(SimState, SimParams)
    i = SimState.Time;
    next_slot = inf;
    [assigned, ~] = ED_Get_Active_RAW_Assignment( ...
        SimState, SimParams);
    assigned = ED_TXOP_Filter_NAV_Contenders( ...
        SimState, SimParams, assigned);
    if isempty(assigned)
        return;
    end

    lengths = [SimState.Node.TX_Buffer.Length];
    eligible = assigned( ...
        lengths(assigned) > 0 & ...
        ~SimState.ED_TXOP.Active(assigned) & ...
        SimState.n_txnode(assigned) == 0 & ...
        SimState.tx_status(assigned, 1).' == -1 & ...
        SimState.Node.ACK_Timer(assigned, 1).' == -1 & ...
        SimState.ED_RAW_Fit_Blocked_Until(assigned) < i);
    if isempty(eligible)
        return;
    end

    aifs = SimState.Node.aifs(eligible);
    backoff = SimState.Node.bc(eligible);
    if any(backoff == 0)
        % ED_MAC_Access marks a frame that cannot fit as blocked until the
        % current RAW ends, so this schedules at most one fit check.
        next_slot = i + 1;
        return;
    end

    positive = backoff > 0;
    if ~any(positive)
        return;
    end
    aifs = aifs(positive);
    backoff = backoff(positive);
    slots_until_attempt = backoff;
    with_aifs = aifs > 0;
    slots_until_attempt(with_aifs) = ...
        aifs(with_aifs) + backoff(with_aifs) - 1;
    valid = slots_until_attempt >= 1;
    if any(valid)
        next_slot = i + min(slots_until_attempt(valid));
    end
end
