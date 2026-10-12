function SimState = ED_TXOP_Begin( ...
    SimState, SimParams, node_id, raw_end_slot)
%ED_TXOP_BEGIN Record a TXOP obtained through normal EDCA contention.

    if ~Is_TXOP_Eligible(SimParams, node_id)
        return;
    end
    bss_id = SimState.Node.BSS_ID(node_id);
    if bss_id < 1 || ...
       bss_id > numel(SimParams.EDCA_TXOP_Limit_Slots_By_BSS)
        error('ED:InvalidTXOPBSS', ...
            'TXOP holder %d has an invalid BSS ID.', node_id);
    end
    limit_slots = ...
        SimParams.EDCA_TXOP_Limit_Slots_By_BSS(bss_id);
    if limit_slots <= 0
        return;
    end
    if SimState.ED_TXOP.Active(node_id)
        error('ED:NestedTXOP', ...
            'STA %d attempted to obtain a second active TXOP.', node_id);
    end

    now_slot = SimState.Time;
    guard_slots = SimParams.EDCA_TXOP_Guard_Slots;
    usable_raw_end = raw_end_slot - guard_slots;
    txop_end = ED_TXOP_Get_End_Slot( ...
        SimState, SimParams, node_id, raw_end_slot);
    first_data_end = SimState.tx_status(node_id, 2);
    first_ack_end = first_data_end + SimParams.SIFSN + ...
        SimParams.T_ackN - 1;
    if first_ack_end > txop_end
        % The already-started frame remains a normal single-MPDU access.
        return;
    end

    SimState.ED_TXOP.Active(node_id) = true;
    SimState.ED_TXOP.StartSlot(node_id) = now_slot;
    SimState.ED_TXOP.EndSlot(node_id) = txop_end;
    SimState.ED_TXOP.RAWEndSlot(node_id) = usable_raw_end;
    SimState.ED_TXOP.AcquisitionRAWEndSlot(node_id) = raw_end_slot;
    SimState.ED_TXOP.PeriodEndSlot(node_id) = ...
        ED_TXOP_Get_Period_End_Slot(SimState, SimParams, node_id);
    SimState.ED_TXOP.NextDataSlot(node_id) = inf;
    SimState.ED_TXOP.MPDUsInCurrent(node_id) = 1;
    SimState.ED_TXOP.ReservationEstablished(node_id) = false;
    SimState.ED_TXOP.Acquisitions(node_id) = ...
        SimState.ED_TXOP.Acquisitions(node_id) + 1;
end

function tf = Is_TXOP_Eligible(SimParams, node_id)
    tf = isfield(SimParams, 'EDCA_TXOP_Enabled') && ...
        SimParams.EDCA_TXOP_Enabled && ...
        isfield(SimParams, 'EDCA_TXOP_Eligible') && ...
        node_id <= numel(SimParams.EDCA_TXOP_Eligible) && ...
        SimParams.EDCA_TXOP_Eligible(node_id);
end
