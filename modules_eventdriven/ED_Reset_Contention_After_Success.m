function SimState = ED_Reset_Contention_After_Success(SimState, node_id)
%ED_RESET_CONTENTION_AFTER_SUCCESS Reset the successful DATA STA state.

    SimState.Node.CW(node_id) = SimState.Node.CW_min(node_id);
    SimState.Node.N_retry(node_id) = 0;
    SimState.Node.aifs(node_id) = SimState.Node.Init_aifs(node_id);
    SimState.Node.bc(node_id) = ceil( ...
        rand * SimState.Node.CW(node_id));
end
