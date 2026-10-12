function txop_end = ED_TXOP_Get_End_Slot( ...
    SimState, SimParams, node_id, raw_end_slot)
%ED_TXOP_GET_END_SLOT Resolve the inclusive TXOP end for one acquisition.

    bss_id = SimState.Node.BSS_ID(node_id);
    limit_slots = SimParams.EDCA_TXOP_Limit_Slots_By_BSS(bss_id);
    guard_slots = SimParams.EDCA_TXOP_Guard_Slots;
    period_end = ED_TXOP_Get_Period_End_Slot( ...
        SimState, SimParams, node_id);
    usable_period_end = period_end - guard_slots - 1;

    if Is_Dynamic_Full_Period(SimParams)
        txop_end = usable_period_end;
        return;
    end

    txop_end = min( ...
        SimState.Time + limit_slots - 1, usable_period_end);
    if ~Is_Cross_Slot_Allowed(SimParams)
        txop_end = min(txop_end, raw_end_slot - guard_slots - 1);
    end
end

function tf = Is_Dynamic_Full_Period(SimParams)
    tf = isfield(SimParams, 'EDCA_TXOP_Dynamic_Period_End') && ...
        SimParams.EDCA_TXOP_Dynamic_Period_End;
end

function tf = Is_Cross_Slot_Allowed(SimParams)
    tf = isfield(SimParams, 'EDCA_TXOP_Cross_Slot_Allowed') && ...
        SimParams.EDCA_TXOP_Cross_Slot_Allowed;
end
