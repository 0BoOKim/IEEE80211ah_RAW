function assigned = ED_TXOP_Filter_NAV_Contenders( ...
    SimState, SimParams, assigned)
%ED_TXOP_FILTER_NAV_CONTENDERS Freeze contenders in a NAV-reserved BSS.
%
% Full-period aggressive TXOP establishes the reservation only after its
% first DATA/ACK exchange succeeds. Other BSSs remain independently active.

    if isempty(assigned) || ...
            ~isfield(SimParams, 'EDCA_TXOP_NAV_Enabled') || ...
            ~SimParams.EDCA_TXOP_NAV_Enabled || ...
            ~isfield(SimState, 'ED_TXOP')
        return;
    end

    now_slot = SimState.Time;
    holders = find( ...
        SimState.ED_TXOP.Active & ...
        SimState.ED_TXOP.ReservationEstablished & ...
        SimState.ED_TXOP.EndSlot >= now_slot);
    if isempty(holders)
        return;
    end

    reserved_bss = unique(SimState.Node.BSS_ID(holders));
    assigned_bss = SimState.Node.BSS_ID(assigned);
    keep = ~ismember(assigned_bss, reserved_bss) | ...
        ismember(assigned, holders);
    assigned = assigned(keep);
end
