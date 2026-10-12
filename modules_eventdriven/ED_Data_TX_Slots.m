function n_slots = ED_Data_TX_Slots(SimState, SimParams, node_id)
%ED_DATA_TX_SLOTS Return the modeled DATA duration for the queue head.

    mpdu = ED_Peek_MPDU(SimState.Node.TX_Buffer(node_id));
    n_slots = ceil( ...
        (8 * mpdu(2) / SimParams.R_data(node_id)) / ...
        SimParams.T_slot);
end
