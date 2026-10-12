function SimState = MAC_Access(SimState, SimParams)

    i = SimState.Time;

    % Identify STAs assigned to each BSS's currently active RAW slot.
    % A STA may contend only inside the active RAW slot of its Serving_AP.
    if SimParams.On_RAW
        RAW_Access_End_By_Node = zeros(1, SimParams.N_Node);
        Assigned_STA = [];
        Active_RAW_BSS = false(1, SimParams.N_AP);

        for bss_id = 1:SimParams.N_AP
            Tab_RAW = SimState.Tab_RAW{bss_id};
            Idx_Enabled_RAW = find(Tab_RAW(:,3) == 1);

            if length(Idx_Enabled_RAW) > 1
                error('only one RAW slot can be enabled in each BSS!');
            end

            if ~isempty(Idx_Enabled_RAW)
                Active_RAW_BSS(bss_id) = true;
                List_Assigned_STA = SimState.List_Assigned_STA{bss_id};
                if Idx_Enabled_RAW <= size(List_Assigned_STA, 1)
                    Temp_Assigned_STA = List_Assigned_STA(Idx_Enabled_RAW,:);
                    Temp_Assigned_STA(Temp_Assigned_STA == 0) = [];

                    if ~isempty(Temp_Assigned_STA)
                        Temp_Assigned_STA = unique(Temp_Assigned_STA, 'stable');
                        Temp_Assigned_STA = Temp_Assigned_STA( ...
                            SimState.RAW_TX_Allowed(Temp_Assigned_STA));

                        if any(SimState.Node.Serving_AP(Temp_Assigned_STA) ~= bss_id)
                            error('A STA is assigned to a RAW slot outside its serving BSS!');
                        end

                        if any(RAW_Access_End_By_Node(Temp_Assigned_STA) > 0)
                            error('A STA is assigned to multiple active RAW slots!');
                        end

                        RAW_Access_End_By_Node(Temp_Assigned_STA) = Tab_RAW(Idx_Enabled_RAW, 2);
                        Assigned_STA = [Assigned_STA Temp_Assigned_STA]; %#ok<AGROW>
                    end
                end
            end
        end

        SimState = Update_BSS_Overlap_Diagnostics(SimState, Active_RAW_BSS, 'RAW');

        Assigned_RAW_End = RAW_Access_End_By_Node(Assigned_STA);
        N_user_in_RAW_Slot = length(Assigned_STA);

        % ---------------------------------------------
        % 1. Decrement AIFS and Backoff
        % ---------------------------------------------
        % Decrement AIFS
        for j=1:N_user_in_RAW_Slot
            u = Assigned_STA(j);
            if (SimState.Node.aifs(u) > 0 && ...
                    SimState.Node.TX_Buffer(u).Length > 0 && ...
                    SimState.n_txnode(u) == 0 && ...
                    SimState.tx_status(u,1) == -1 && ...
                    SimState.Node.ACK_Timer(u,1) == -1)

                SimState.Node.aifs(u) = SimState.Node.aifs(u) - 1;
            end
        end

        % Decrement Backoff
        for j=1:N_user_in_RAW_Slot
            u = Assigned_STA(j);
            if (SimState.Node.aifs(u) == 0 && ...
                    SimState.Node.TX_Buffer(u).Length > 0 && ...
                    SimState.n_txnode(u) == 0 && ...
                    SimState.tx_status(u,1) == -1 && ...
                    SimState.Node.ACK_Timer(u,1) == -1)

                SimState.Node.bc(u) = SimState.Node.bc(u) -1;
            end
        end

        % ---------------------------------------------
        % 2. Attempt Transmission (Data)
        % ---------------------------------------------
        for j=1:N_user_in_RAW_Slot
            u = Assigned_STA(j);
            if (SimState.Node.bc(u) == 0 && ...
                    SimState.Node.TX_Buffer(u).Length > 0 && ...
                    SimState.n_txnode(u) == 0 && ...
                    SimState.tx_status(u,1) == -1)

                T_data = 8*SimState.Node.TX_Buffer(u).MPDU(1,2)/SimParams.R_data(u);
                T_txslot = ceil(T_data/SimParams.T_slot);

                SimState.Node.aifs(u) = SimState.Node.Init_aifs(u);

                if SimParams.On_CSB == 0

                    % Check if fits in RAW slot
                    if  T_txslot  < Assigned_RAW_End(j) - i

                        SimState.n_access(u) = SimState.n_access(u) + 1;

                        if  SimParams.Mode_Net_Congestion_Measure
                              SimState.Net_Congestion_Measure(u).N_Acc(size(SimState.Net_Congestion_Measure(u).N_Acc, 1), 2) ...
                                    = SimState.Net_Congestion_Measure(u).N_Acc(size(SimState.Net_Congestion_Measure(u).N_Acc, 1), 2) + 1;
                        end

                        if length(find(SimState.tx_status(u,:) == -1)) ~= 5
                            error('unexpected tx_status!');
                        else
                            Dest_AP = SimState.Node.Serving_AP(u);
                            if Dest_AP < 1 || Dest_AP > SimParams.N_AP
                                error('unexpected Serving_AP for node %d!', u);
                            end
                            SimState.tx_status(u,:) = [i i+T_txslot-1 Dest_AP 0 0];
                            SimState = Log_TX_Access_Attempt(SimState, SimParams, u, i);
                        end

                    else
                        % Transmission not allowed (not enough time in RAW slot)
                        % Logic implies we do nothing, just wait?
                        % Original code: sets T_data=0, T_txslot=0. Effectively no-op.
                    end
                end

                % Note: Logic to reset BC/AIFS was commented out in original code?
                % No, "bc(Assigned_STA(j)) = ceil(rand*CW(Assigned_STA(j)))" was commented out.
                % It is done at End of Transmission.
            end
        end
    end

    % ---------------------------------------------
    % 3. Attempt Transmission (ACK by AP)
    % ---------------------------------------------
    for j=1:SimParams.N_AP
        u = SimParams.idx_AP(j);

        if SimState.Node.TX_Buffer(u).ACK_Length > 0 && SimState.tx_status(u, 1) == -1
            if ~isempty(SimState.Node.TX_Buffer(u).ACK(1))

                % Check if ACK Transmission Time Reached
                if SimState.Node.TX_Buffer(u).ACK(1,5) + SimParams.SIFSN <= i

                   % Check Channel Idle
                   if SimState.n_txnode(u) == 0

                      % Transmit ACK
                      SimState.tx_state(i:(i+SimParams.T_ackN-1), u) = 1; % STATE_TX = 1

                      SimState.tx_status(u, :) = [i i+SimParams.T_ackN-1 SimState.Node.TX_Buffer(u).ACK(1,3) 0 1];

                      % Deque ACK
                      SimState.Node.TX_Buffer(u) = Deque_ACK(SimState.Node.TX_Buffer(u));

                      SimState.n_access(u) = SimState.n_access(u) + 1;
                   end
                end
            end
        end
    end

    % ---------------------------------------------
    % 4. Propagate Transmission Effects (Start of TX)
    % ---------------------------------------------
    % Original code loops N_Node checking tx_status(j,1) == i

    STATE_CS = uint8(2);
    STATE_TX = uint8(1);

    StartTxNodes = find(SimState.tx_status(:,1) == i).';
    OngoingTxNodes = find(SimState.tx_status(:,1) ~= -1 & SimState.tx_status(:,1) < i).';
    Use_Legacy_Collision = Is_Legacy_Collision_Mode(SimParams);
    for j = StartTxNodes
        if isfield(SimState, 'Cached_CarrierSenseNodes')
            Idx_CSNode = SimState.Cached_CarrierSenseNodes{j};
        else
            [Idx_CSSTA, Idx_CSAP] = Get_InteferedSTAs( ...
                SimState.MAP_RSS, j, SimParams.CSTh, SimParams.N_AP);
            Idx_CSNode = unique([Idx_CSSTA; Idx_CSAP]);
        end
        if isfield(SimState, 'Cached_Interferers')
            Idx_IntfNode = SimState.Cached_Interferers{j};
        else
            interference_threshold = Get_Interference_Threshold(SimParams);
            [Idx_IntfSTA, Idx_IntfAP] = Get_InteferedSTAs( ...
                SimState.MAP_RSS, j, interference_threshold, SimParams.N_AP);
            Idx_IntfNode = unique([Idx_IntfSTA; Idx_IntfAP]);
        end

        % Update self tx_state
        SimState.tx_state(i:SimState.tx_status(j,2), j) = STATE_TX;

        if ~isempty(Idx_CSNode)
            % Update neighbors tx_state (Accumulate CS)
            SimState.tx_state(i:SimState.tx_status(j,2),Idx_CSNode) = ...
                SimState.tx_state(i:SimState.tx_status(j,2),Idx_CSNode) + STATE_CS;

            SimState.Node.aifs(Idx_CSNode) = SimState.Node.Init_aifs(Idx_CSNode);
        end

        if Use_Legacy_Collision
            ActiveTxNodes = find(SimState.tx_status(:,1) ~= -1).';
            ActiveTxNodes(ActiveTxNodes == j) = [];
            if ~isempty(ActiveTxNodes) && ~isempty(Idx_IntfNode)
                HitMask = ismember(SimState.tx_status(ActiveTxNodes,3), Idx_IntfNode);
                HitTxNodes = ActiveTxNodes(HitMask);
                for hit_idx = 1:length(HitTxNodes)
                    SimState = Register_Interference_Collision(SimState, HitTxNodes(hit_idx), j);
                end
            end
            continue;
        end

        % Count interferences between this new TX and already ongoing TXs.
        % A collision is registered at the victim TX when its destination
        % receiver is inside the interferer's affected receiver set.
        if ~isempty(OngoingTxNodes)
            if ~isempty(Idx_IntfNode)
                HitMask = ismember(SimState.tx_status(OngoingTxNodes,3), Idx_IntfNode);
                HitTxNodes = OngoingTxNodes(HitMask);
                for hit_idx = 1:length(HitTxNodes)
                    SimState = Register_Interference_Collision(SimState, HitTxNodes(hit_idx), j);
                end
            end

            Dest_J = SimState.tx_status(j,3);
            for active_idx = 1:length(OngoingTxNodes)
                active_tx = OngoingTxNodes(active_idx);
                if isfield(SimState, 'Cached_Interferers')
                    Active_IntfNode = SimState.Cached_Interferers{active_tx};
                else
                    interference_threshold = Get_Interference_Threshold(SimParams);
                    [Idx_IntfSTA, Idx_IntfAP] = Get_InteferedSTAs( ...
                        SimState.MAP_RSS, active_tx, interference_threshold, SimParams.N_AP);
                    Active_IntfNode = unique([Idx_IntfSTA; Idx_IntfAP]);
                end

                if ismember(Dest_J, Active_IntfNode)
                    SimState = Register_Interference_Collision(SimState, j, active_tx);
                end
            end
        end
    end

    if ~Use_Legacy_Collision
        % Count same-slot hidden/interfering transmissions once per pair.
        for idx_a = 1:length(StartTxNodes)-1
            tx_a = StartTxNodes(idx_a);
            if isfield(SimState, 'Cached_Interferers')
                Intf_A = SimState.Cached_Interferers{tx_a};
            else
                interference_threshold = Get_Interference_Threshold(SimParams);
                [Idx_IntfSTA, Idx_IntfAP] = Get_InteferedSTAs( ...
                    SimState.MAP_RSS, tx_a, interference_threshold, SimParams.N_AP);
                Intf_A = unique([Idx_IntfSTA; Idx_IntfAP]);
            end

            for idx_b = idx_a+1:length(StartTxNodes)
                tx_b = StartTxNodes(idx_b);
                if isfield(SimState, 'Cached_Interferers')
                    Intf_B = SimState.Cached_Interferers{tx_b};
                else
                    interference_threshold = Get_Interference_Threshold(SimParams);
                    [Idx_IntfSTA, Idx_IntfAP] = Get_InteferedSTAs( ...
                        SimState.MAP_RSS, tx_b, interference_threshold, SimParams.N_AP);
                    Intf_B = unique([Idx_IntfSTA; Idx_IntfAP]);
                end

                if ismember(SimState.tx_status(tx_b,3), Intf_A)
                    SimState = Register_Interference_Collision(SimState, tx_b, tx_a);
                end

                if ismember(SimState.tx_status(tx_a,3), Intf_B)
                    SimState = Register_Interference_Collision(SimState, tx_a, tx_b);
                end
            end
        end
    end

    if ~isempty(StartTxNodes)
        SimState.n_txnode = Rebuild_CarrierSense_Counts( ...
            SimState, SimParams);
    end

    ActiveTxNodes = find(SimState.tx_status(:,1) ~= -1).';
    Active_TX_BSS = false(1, SimParams.N_AP);
    if ~isempty(ActiveTxNodes)
        Active_TX_BSS(unique(SimState.Node.BSS_ID(ActiveTxNodes))) = true;
    end
    SimState = Update_BSS_Overlap_Diagnostics(SimState, Active_TX_BSS, 'TX');

end

function SimState = Register_Interference_Collision(SimState, victim_tx, interferer_tx)
    SimState.tx_status(victim_tx,4) = SimState.tx_status(victim_tx,4) + 1;

    if ~isfield(SimState, 'BSS_Interference')
        return;
    end

    victim_bss = SimState.Node.BSS_ID(victim_tx);
    interferer_bss = SimState.Node.BSS_ID(interferer_tx);
    if victim_bss > 0 && interferer_bss > 0
        SimState.BSS_Interference.Collision_Matrix(victim_bss, interferer_bss) = ...
            SimState.BSS_Interference.Collision_Matrix(victim_bss, interferer_bss) + 1;
    end

    victim_rx = SimState.tx_status(victim_tx,3);
    link_type_idx = Get_Interference_Link_Type(SimState.Node.Type(interferer_tx), SimState.Node.Type(victim_rx));
    SimState.BSS_Interference.Link_Type_Count(link_type_idx) = ...
        SimState.BSS_Interference.Link_Type_Count(link_type_idx) + 1;
end

function SimState = Log_TX_Access_Attempt(SimState, SimParams, node_id, now_slot)
    if ~isfield(SimParams, 'On_Save_TX_Log') || ~SimParams.On_Save_TX_Log
        return;
    end

    if ~isfield(SimState, 'TX_LOG_Access_Log')
        SimState.TX_LOG_Access_Log = zeros(0, 11);
        SimState.TX_LOG_Pending_Access_Idx = zeros(1, SimParams.N_Node);
    end

    ch_util = 0;
    n_ack = 0;
    if isfield(SimState, 'Net_Congestion_Measure') && ...
       numel(SimState.Net_Congestion_Measure) >= node_id && ...
       ~isempty(SimState.Net_Congestion_Measure(node_id).CH_Util)
        current_idx = size(SimState.Net_Congestion_Measure(node_id).CH_Util, 1);
        ch_util = SimState.Net_Congestion_Measure(node_id).CH_Util(current_idx, 2);
        n_ack = SimState.Net_Congestion_Measure(node_id).N_ACK(current_idx, 2);
    end

    if SimState.Node.TX_Buffer(node_id).Length > 0 && ...
       ~isempty(SimState.Node.TX_Buffer(node_id).MPDU)
        mpdu_gid = SimState.Node.TX_Buffer(node_id).MPDU(1, 1);
    else
        mpdu_gid = NaN;
    end

    bss_id = SimState.Node.BSS_ID(node_id);
    row_idx = size(SimState.TX_LOG_Access_Log, 1) + 1;
    SimState.TX_LOG_Access_Log(row_idx, :) = [ ...
        node_id, bss_id, now_slot, ch_util, n_ack, mpdu_gid, ...
        0, 0, 0, 0, 0];
    SimState.TX_LOG_Pending_Access_Idx(node_id) = row_idx;
end

function use_legacy = Is_Legacy_Collision_Mode(SimParams)
    if ~isfield(SimParams, 'Collision_Check_Mode') || isempty(SimParams.Collision_Check_Mode)
        mode = 'auto';
    else
        mode = SimParams.Collision_Check_Mode;
    end

    if isstring(mode)
        mode = char(mode);
    end

    switch lower(mode)
        case 'auto'
            use_legacy = SimParams.N_AP == 1;
        case 'legacy'
            use_legacy = true;
        case {'rx-centric', 'rx_centric', 'receiver-centric'}
            use_legacy = false;
        otherwise
            error('Unsupported Collision_Check_Mode: %s', mode);
    end
end

function threshold = Get_Interference_Threshold(SimParams)
    if isfield(SimParams, 'Interference_RSS_Threshold') && ...
       ~isempty(SimParams.Interference_RSS_Threshold)
        threshold = SimParams.Interference_RSS_Threshold;
    else
        threshold = SimParams.CSTh;
    end
end

function link_type_idx = Get_Interference_Link_Type(interferer_tx_type, victim_rx_type)
    if interferer_tx_type == -1 && victim_rx_type == -1
        link_type_idx = 3; % AP_to_AP
    elseif interferer_tx_type == -1
        link_type_idx = 2; % AP_to_STA
    elseif victim_rx_type == -1
        link_type_idx = 1; % STA_to_AP
    else
        link_type_idx = 4; % STA_to_STA
    end
end

function SimState = Update_BSS_Overlap_Diagnostics(SimState, Active_BSS, metric_type)
    if ~isfield(SimState, 'BSS_Interference') || ~any(Active_BSS)
        return;
    end

    active_idx = find(Active_BSS);
    if strcmp(metric_type, 'RAW')
        SimState.BSS_Interference.RAW_Active_Slots(active_idx) = ...
            SimState.BSS_Interference.RAW_Active_Slots(active_idx) + 1;
        SimState.BSS_Interference.RAW_Overlap_Slots(active_idx, active_idx) = ...
            SimState.BSS_Interference.RAW_Overlap_Slots(active_idx, active_idx) + 1;
    elseif strcmp(metric_type, 'TX')
        SimState.BSS_Interference.TX_Active_Slots(active_idx) = ...
            SimState.BSS_Interference.TX_Active_Slots(active_idx) + 1;
        SimState.BSS_Interference.TX_Overlap_Slots(active_idx, active_idx) = ...
            SimState.BSS_Interference.TX_Overlap_Slots(active_idx, active_idx) + 1;
    else
        error('Unexpected BSS overlap diagnostic type.');
    end
end
