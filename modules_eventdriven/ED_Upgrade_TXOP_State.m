function SimState = ED_Upgrade_TXOP_State(SimState, SimParams)
%ED_UPGRADE_TXOP_STATE Add diagnostics to an older resumed checkpoint.

    if ~isfield(SimState, 'ED_Airtime')
        SimState.ED_Airtime = struct( ...
            'DATA_Attempt_Slots', zeros(1, SimParams.N_Node), ...
            'ACK_Attempt_Slots_By_Destination', ...
                zeros(1, SimParams.N_Node));
    else
        if ~isfield(SimState.ED_Airtime, 'DATA_Attempt_Slots')
            SimState.ED_Airtime.DATA_Attempt_Slots = ...
                zeros(1, SimParams.N_Node);
        end
        if ~isfield(SimState.ED_Airtime, ...
                'ACK_Attempt_Slots_By_Destination')
            SimState.ED_Airtime.ACK_Attempt_Slots_By_Destination = ...
                zeros(1, SimParams.N_Node);
        end
    end

    if ~isfield(SimState, 'ED_TXOP')
        return;
    end
    n = numel(SimState.ED_TXOP.Active);
    if ~isfield(SimState.ED_TXOP, 'PeriodEndSlot')
        SimState.ED_TXOP.PeriodEndSlot = -ones(1, n);
    end
    if ~isfield(SimState.ED_TXOP, 'PeriodBoundaryViolations')
        SimState.ED_TXOP.PeriodBoundaryViolations = zeros(1, n);
    end
    if ~isfield(SimState.ED_TXOP, 'PeriodBoundaryOverrunSlots')
        SimState.ED_TXOP.PeriodBoundaryOverrunSlots = zeros(1, n);
    end

    active = find(SimState.ED_TXOP.Active);
    for node_id = active
        period_end = ED_TXOP_Get_Period_End_Slot( ...
            SimState, SimParams, node_id);
        SimState.ED_TXOP.PeriodEndSlot(node_id) = period_end;
        usable_period_end = period_end - ...
            SimParams.EDCA_TXOP_Guard_Slots - 1;
        SimState.ED_TXOP.EndSlot(node_id) = min( ...
            SimState.ED_TXOP.EndSlot(node_id), usable_period_end);
    end
end
