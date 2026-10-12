function SimState = ED_TXOP_After_ACK( ...
    SimState, SimParams, node_id, ack_end_slot)
%ED_TXOP_AFTER_ACK Schedule another MPDU after SIFS when it fully fits.

    if ~SimState.ED_TXOP.Active(node_id)
        return;
    end
    SimState.ED_TXOP.AcknowledgedMPDUs(node_id) = ...
        SimState.ED_TXOP.AcknowledgedMPDUs(node_id) + 1;
    SimState.ED_TXOP.ReservationEstablished(node_id) = true;

    max_mpdus = SimParams.EDCA_TXOP_Max_MPDUs(node_id);
    if SimState.ED_TXOP.MPDUsInCurrent(node_id) >= max_mpdus || ...
       SimState.Node.TX_Buffer(node_id).Length <= 0
        SimState = ED_TXOP_End( ...
            SimState, node_id, 'complete', true);
        return;
    end

    next_data_start = ack_end_slot + SimParams.SIFSN;
    data_slots = ED_Data_TX_Slots(SimState, SimParams, node_id);
    next_data_end = next_data_start + data_slots - 1;
    next_ack_start = next_data_end + SimParams.SIFSN;
    next_ack_end = next_ack_start + SimParams.T_ackN - 1;
    txop_end = SimState.ED_TXOP.EndSlot(node_id);

    if next_ack_end > txop_end
        SimState = ED_TXOP_End( ...
            SimState, node_id, 'limit', true);
        return;
    end

    SimState.ED_TXOP.NextDataSlot(node_id) = next_data_start;
end
