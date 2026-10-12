function SimState = ED_Generate_Traffic(SimState, SimParams)
%ED_GENERATE_TRAFFIC Generate background and sparse Mode-3 alarm traffic.

    i = SimState.Time;
    SimState = Generate_Background_Traffic( ...
        SimState, SimParams, i);

    if SimParams.Traffic_Surge_Mode ~= 3
        error('ED:UnsupportedTrafficSurgeMode', ...
            'The independent event-driven engine currently supports Mode 3.');
    end

    [SimState, new_alarm_ids] = Apply_Activation_Events( ...
        SimState, SimParams, i);
    n_new = numel(new_alarm_ids);
    if n_new > 0
        previous = SimState.Measure_Cummulated_N_Triggerd_STAs( ...
            SimState.L_Measure_Cummulated_N_Triggerd_STAs, 2);
        SimState.Measure_Cummulated_N_Triggerd_STAs = [ ...
            SimState.Measure_Cummulated_N_Triggerd_STAs; ...
            i, previous + n_new]; %#ok<AGROW>
        SimState.L_Measure_Cummulated_N_Triggerd_STAs = ...
            SimState.L_Measure_Cummulated_N_Triggerd_STAs + 1;
    end

    if isfield(SimParams, 'ED_Camera') && ...
       isfield(SimState, 'ED_Camera')
        SimState = ED_Generate_Camera_Traffic( ...
            SimState, SimParams, new_alarm_ids, i);
    end

    active = SimState.ED_Active_Alarm_IDs( ...
        1:SimState.ED_Active_Alarm_Count);
    for node_id = active
        if SimState.Next_Frame_Interval_al(node_id) > i
            continue;
        end

        if rand <= SimParams.Prob_Frame_Generation_al
            [SimState.Node.TX_Buffer(node_id), SimState.GID] = ...
                ED_Enqueue_MPDU(SimState.Node.TX_Buffer(node_id), ...
                SimState.GID, ...
                SimState.Next_Frame_Length_al(node_id), i);
            SimState.n_enq(node_id) = SimState.n_enq(node_id) + 1;
        end

        if SimState.Mode3_Remaining_Burst_Count(node_id) > 0
            SimState.Mode3_Remaining_Burst_Count(node_id) = ...
                SimState.Mode3_Remaining_Burst_Count(node_id) - 1;
        end
        SimState.Next_Frame_Length_al(node_id) = ...
            Sample_Range(SimParams.Range_Frame_Length_al);
        if SimState.Mode3_Remaining_Burst_Count(node_id) > 0
            interval = SimParams.Mode3_Alarm_Burst_Interval_Slots;
        else
            interval = SimParams.Range_Frame_Interval_al;
        end
        SimState.Next_Frame_Interval_al(node_id) = ...
            i + Sample_Range(interval);
    end
end

function SimState = Generate_Background_Traffic(SimState, SimParams, i)
    background_ids = SimState.ED_Background_STA_IDs;
    for node_id = background_ids
        if SimState.Next_Frame_Interval_bk(node_id) > i
            continue;
        end
        if rand <= SimParams.Prob_Frame_Generation_bk
            [SimState.Node.TX_Buffer(node_id), SimState.GID] = ...
                ED_Enqueue_MPDU(SimState.Node.TX_Buffer(node_id), ...
                SimState.GID, ...
                SimState.Next_Frame_Length_bk(node_id), i);
            SimState.n_enq(node_id) = SimState.n_enq(node_id) + 1;
        end
        % Preserve legacy RNG consumption even for a zero-width range.
        length_range = SimParams.Range_Frame_Length_bk;
        interval_range = SimParams.Range_Frame_Interval_bk;
        SimState.Next_Frame_Length_bk(node_id) = ceil( ...
            (length_range(2) - length_range(1)) * rand + ...
            length_range(1));
        SimState.Next_Frame_Interval_bk(node_id) = i + ceil( ...
            (interval_range(2) - interval_range(1)) * rand + ...
            interval_range(1));
    end
end

function [SimState, new_alarm_ids] = Apply_Activation_Events( ...
    SimState, SimParams, i)

    events = SimParams.ED_Beta_Activation_Events;
    event_idx = SimState.ED_Activation_Event_Index;
    reference_count = SimState.ED_Reference_Active_Count;
    while event_idx <= size(events, 1) && events(event_idx, 1) <= i
        reference_count = events(event_idx, 2);
        event_idx = event_idx + 1;
    end
    SimState.ED_Activation_Event_Index = event_idx;
    SimState.ED_Reference_Active_Count = reference_count;

    alarm_ids = SimParams.idx_STA_Type1;
    activation_order = SimState.Alarm_Activation_Order;
    next_physical = SimState.ED_Next_Physical_Activation_Index;
    new_alarm_ids = zeros(1, numel(alarm_ids) - next_physical + 1);
    n_new = 0;
    while next_physical <= numel(activation_order)
        node_id = activation_order(next_physical);
        local_idx = find(alarm_ids == node_id, 1);
        if SimState.Alarm_Reference_Rank(local_idx) > reference_count
            break;
        end
        SimState.Node.TX_Buffer(node_id).Triggered = 1;
        SimState.Node.TX_Buffer(node_id).Trigger_Time = i;
        SimState.Mode3_Remaining_Burst_Count(node_id) = ...
            max(1, round(SimParams.Mode3_Alarm_Burst_Count));
        SimState.Next_Frame_Interval_al(node_id) = i;
        n_new = n_new + 1;
        new_alarm_ids(n_new) = node_id;
        SimState.ED_Active_Alarm_Count = ...
            SimState.ED_Active_Alarm_Count + 1;
        SimState.ED_Active_Alarm_IDs( ...
            SimState.ED_Active_Alarm_Count) = node_id;
        next_physical = next_physical + 1;
    end
    SimState.ED_Next_Physical_Activation_Index = next_physical;
    if n_new > 0
        count = SimState.ED_Active_Alarm_Count;
        SimState.ED_Active_Alarm_IDs(1:count) = sort( ...
            SimState.ED_Active_Alarm_IDs(1:count));
    end
    new_alarm_ids = new_alarm_ids(1:n_new);
end

function value = Sample_Range(range_values)
    if numel(range_values) == 1 || ...
       range_values(1) == range_values(2)
        value = ceil(range_values(1));
    else
        value = ceil( ...
            (range_values(2) - range_values(1)) * rand + ...
            range_values(1));
    end
end
