function period_end = ED_TXOP_Get_Period_End_Slot( ...
    SimState, SimParams, node_id)
%ED_TXOP_GET_PERIOD_END_SLOT Return the current RAW-period end slot.

    bss_id = SimState.Node.BSS_ID(node_id);
    if bss_id < 1 || bss_id > numel(SimState.Tab_RAW) || ...
            isempty(SimState.Tab_RAW{bss_id})
        error('ED:MissingTXOPRAWPeriod', ...
            'The TXOP has no RAW schedule for BSS %d.', bss_id);
    end

    tab = SimState.Tab_RAW{bss_id};
    period_end = min(tab(end, 2), SimParams.N_slot);
    if ~isfinite(period_end) || period_end < SimState.Time
        error('ED:InvalidTXOPRAWPeriod', ...
            ['The RAW-period end (%g) precedes the current simulation ' ...
             'slot (%g) for BSS %d.'], ...
            period_end, SimState.Time, bss_id);
    end
end
