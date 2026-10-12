function ActivationPlan = ED_Build_Activation_Plan(SimState, SimParams)
%ED_BUILD_ACTIVATION_PLAN Describe reference and physical STA activations.
%
% The returned table is generated from the event-driven activation list and
% the geo-aware reference ranks used by ED_Generate_Traffic.

    idx_alarm = SimParams.idx_STA_Type1(:).';
    if isfield(SimState, 'Fire_Reference_Alarm_Pos')
        reference_pos = SimState.Fire_Reference_Alarm_Pos;
        reference_rank = SimState.Fire_Reference_Activation_Rank(:).';
        physical_reference_id = ...
            SimState.Physical_Alarm_Reference_ID(:).';
    else
        reference_pos = SimState.Node.Pos(idx_alarm, :);
        reference_rank = nan(1, numel(idx_alarm));
        reference_rank(SimState.Alarm_Reference_Rank) = ...
            1:numel(idx_alarm);
        physical_reference_id = 1:numel(idx_alarm);
    end

    n_reference = size(reference_pos, 1);
    trigger_slot_by_rank = inf(1, n_reference);
    events = SimParams.ED_Beta_Activation_Events;
    if ~isempty(events)
        ranks = round(events(:, 2));
        valid = ranks >= 1 & ranks <= n_reference;
        trigger_slot_by_rank(ranks(valid)) = events(valid, 1);
    end

    physical_local_by_reference = nan(1, n_reference);
    physical_local_by_reference(physical_reference_id) = ...
        1:numel(idx_alarm);
    ap_pos = SimState.Node.Pos(SimParams.idx_AP, :);

    reference_id = (1:n_reference).';
    activation_rank = reference_rank(reference_id).';
    trigger_slot = trigger_slot_by_rank(activation_rank).';
    planned = isfinite(trigger_slot);
    trigger_slot(~planned) = NaN;
    trigger_time_s = trigger_slot * SimParams.T_slot;
    fire_elapsed_s = min(SimParams.Fire_Physical_Window_s, ...
        max(0, trigger_time_s - SimParams.Opt_Start * ...
        SimParams.T_slot) * SimParams.Fire_Time_Compression);
    fire_elapsed_s(~planned) = NaN;

    physical_local_id = physical_local_by_reference(reference_id).';
    is_physical = isfinite(physical_local_id);
    node_id = nan(n_reference, 1);
    node_id(is_physical) = idx_alarm(physical_local_id(is_physical));
    bss_id = nan(n_reference, 1);
    bss_id(is_physical) = ...
        SimState.Node.BSS_ID(node_id(is_physical)).';
    virtual_id = find(~is_physical);
    for k = virtual_id(:).'
        delta = ap_pos - reference_pos(k, :);
        [~, bss_id(k)] = min(sum(delta.^2, 2));
    end

    ActivationPlan = table( ...
        reference_id, node_id, physical_local_id, is_physical, ...
        ~is_physical, bss_id, reference_pos(:, 1), ...
        reference_pos(:, 2), activation_rank, trigger_slot, ...
        trigger_time_s, fire_elapsed_s, planned, ...
        'VariableNames', { ...
        'Reference_Alarm_ID', 'Node_ID', 'Alarm_Local_ID', ...
        'Is_Physical', 'Is_Virtual', 'BSS_ID', 'X_m', 'Y_m', ...
        'Activation_Rank', 'Planned_Trigger_Slot', ...
        'Planned_Trigger_Time_s', 'Physical_Fire_Elapsed_s', ...
        'Is_Planned_Triggered'});
    ActivationPlan = sortrows(ActivationPlan, ...
        {'Is_Planned_Triggered', 'Activation_Rank'}, ...
        {'descend', 'ascend'});
end
