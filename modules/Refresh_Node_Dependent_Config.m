function SimParams = Refresh_Node_Dependent_Config(SimParams)
%REFRESH_NODE_DEPENDENT_CONFIG Rebuild vectors that depend on node counts.

    SimParams.N_STA = SimParams.N_alarmSTA + SimParams.N_bkSTA;
    SimParams.N_AP = SimParams.N_BSS;
    SimParams.N_Node = SimParams.N_AP + SimParams.N_STA;

    SimParams.R_data = 0.3*10^6*ones(1,SimParams.N_Node);
    SimParams.CW_min = 16*ones(1,SimParams.N_Node);
    SimParams.CW_max = 1024*ones(1,SimParams.N_Node);
    SimParams.Retry_Limit = 7*ones(1,SimParams.N_Node);

    SimParams.L_data = 100*ones(1,SimParams.N_Node);
    SimParams.L_data(1:SimParams.N_AP) = 0;

    T_difs = SimParams.T_sifs + 2*SimParams.T_slot;
    SimParams.AIFSN = ceil(T_difs/SimParams.T_slot)*ones(1,SimParams.N_Node);

    SimParams.idx_AP = 1:SimParams.N_AP;
    SimParams.idx_STA_Type0 = SimParams.N_AP+1 : SimParams.N_AP+SimParams.N_bkSTA;
    SimParams.idx_STA_Type1 = SimParams.N_AP+SimParams.N_bkSTA+1 : SimParams.N_Node;
    SimParams.idx_STA = SimParams.N_AP+1 : SimParams.N_Node;

    if isfield(SimParams, 'On_RAW') && SimParams.On_RAW
        if ~isfield(SimParams, 'BSS_Opt_N_RAW') || numel(SimParams.BSS_Opt_N_RAW) ~= SimParams.N_AP
            SimParams.BSS_Opt_N_RAW = SimParams.Opt_N_RAW * ones(1, SimParams.N_AP);
        end
        if ~isfield(SimParams, 'BSS_Opt_Slot_Duration_Count') || ...
           numel(SimParams.BSS_Opt_Slot_Duration_Count) ~= SimParams.N_AP
            SimParams.BSS_Opt_Slot_Duration_Count = SimParams.Opt_Slot_Duration_Count * ones(1, SimParams.N_AP);
        end
        SimParams = Build_BSS_RAW_Config(SimParams);
    end
end
