function SimState = ED_MAC_Access(SimState, SimParams)
%ED_MAC_ACCESS Process MAC countdown and transmissions at one event slot.

    i = SimState.Time;
    [Assigned_STA, RAW_End_By_Node, Active_RAW_BSS] = ...
        ED_Get_Active_RAW_Assignment(SimState, SimParams);

    SimState = Expire_Idle_TXOPs(SimState, i);
    Assigned_STA = ED_TXOP_Filter_NAV_Contenders( ...
        SimState, SimParams, Assigned_STA);
    continuation_ids = find( ...
        SimState.ED_TXOP.Active & ...
        SimState.ED_TXOP.NextDataSlot == i);
    for sta_id = continuation_ids
        cross_slot = Is_Cross_Slot_TXOP(SimParams, sta_id);
        raw_eligible = cross_slot || ( ...
            ismember(sta_id, Assigned_STA) && ...
            RAW_End_By_Node(sta_id) > i);
        can_continue = raw_eligible && ...
            SimState.Node.TX_Buffer(sta_id).Length > 0 && ...
            SimState.n_txnode(sta_id) == 0 && ...
            SimState.tx_status(sta_id, 1) == -1 && ...
            SimState.Node.ACK_Timer(sta_id, 1) == -1;
        if ~can_continue
            SimState = ED_TXOP_End( ...
                SimState, sta_id, 'limit', true);
            continue;
        end

        tx_slots = ED_Data_TX_Slots( ...
            SimState, SimParams, sta_id);
        tx_end = i + tx_slots - 1;
        if (~cross_slot && tx_end >= RAW_End_By_Node(sta_id)) || ...
           tx_end > SimState.ED_TXOP.EndSlot(sta_id)
            SimState = ED_TXOP_End( ...
                SimState, sta_id, 'limit', true);
            continue;
        end

        SimState.ED_TXOP.NextDataSlot(sta_id) = inf;
        SimState.ED_TXOP.MPDUsInCurrent(sta_id) = ...
            SimState.ED_TXOP.MPDUsInCurrent(sta_id) + 1;
        SimState.ED_TXOP.ContinuationAttempts(sta_id) = ...
            SimState.ED_TXOP.ContinuationAttempts(sta_id) + 1;
        SimState = Record_Cross_Slot_Exchange( ...
            SimState, SimParams, sta_id, i, tx_end);
        SimState = Start_Data_Transmission( ...
            SimState, SimParams, sta_id, i, tx_slots);
    end

    lengths = [SimState.Node.TX_Buffer.Length];
    not_in_txop = ~SimState.ED_TXOP.Active(Assigned_STA);
    eligible = Assigned_STA( ...
        lengths(Assigned_STA) > 0 & ...
        not_in_txop & ...
        SimState.n_txnode(Assigned_STA) == 0 & ...
        SimState.tx_status(Assigned_STA, 1).' == -1 & ...
        SimState.Node.ACK_Timer(Assigned_STA, 1).' == -1 & ...
        SimState.ED_RAW_Fit_Blocked_Until(Assigned_STA) < i);

    decrement_aifs = eligible(SimState.Node.aifs(eligible) > 0);
    SimState.Node.aifs(decrement_aifs) = ...
        SimState.Node.aifs(decrement_aifs) - 1;
    decrement_backoff = eligible( ...
        SimState.Node.aifs(eligible) == 0);
    SimState.Node.bc(decrement_backoff) = ...
        SimState.Node.bc(decrement_backoff) - 1;

    attempt_ids = Assigned_STA( ...
        SimState.Node.bc(Assigned_STA) == 0 & ...
        ~SimState.ED_TXOP.Active(Assigned_STA) & ...
        SimState.n_txnode(Assigned_STA) == 0 & ...
        SimState.tx_status(Assigned_STA, 1).' == -1 & ...
        SimState.Node.ACK_Timer(Assigned_STA, 1).' == -1 & ...
        lengths(Assigned_STA) > 0 & ...
        SimState.ED_RAW_Fit_Blocked_Until(Assigned_STA) < i);
    for sta_id = attempt_ids
        if SimState.Node.bc(sta_id) ~= 0 || ...
           SimState.n_txnode(sta_id) ~= 0 || ...
           SimState.tx_status(sta_id, 1) ~= -1 || ...
           SimState.Node.TX_Buffer(sta_id).Length <= 0
            continue;
        end

        tx_slots = ED_Data_TX_Slots(SimState, SimParams, sta_id);
        SimState.Node.aifs(sta_id) = SimState.Node.Init_aifs(sta_id);
        fits_current_raw = ...
            tx_slots < RAW_End_By_Node(sta_id) - i;
        if ~fits_current_raw && ~Can_Start_Cross_Slot_TXOP( ...
                SimState, SimParams, sta_id, tx_slots, ...
                RAW_End_By_Node(sta_id))
            SimState.ED_RAW_Fit_Blocked_Until(sta_id) = ...
                RAW_End_By_Node(sta_id);
            continue;
        end
        SimState.ED_RAW_Fit_Blocked_Until(sta_id) = 0;

        SimState = Start_Data_Transmission( ...
            SimState, SimParams, sta_id, i, tx_slots);
        SimState = ED_TXOP_Begin( ...
            SimState, SimParams, sta_id, ...
            RAW_End_By_Node(sta_id));
        if SimState.ED_TXOP.Active(sta_id)
            SimState = Record_Cross_Slot_Exchange( ...
                SimState, SimParams, sta_id, i, i + tx_slots - 1);
        end
    end

    for ap_id = SimParams.idx_AP
        if SimState.Node.TX_Buffer(ap_id).ACK_Length <= 0 || ...
           SimState.tx_status(ap_id, 1) ~= -1
            continue;
        end
        ack = ED_Peek_ACK(SimState.Node.TX_Buffer(ap_id));
        if ack(5) + SimParams.SIFSN <= i && ...
           SimState.n_txnode(ap_id) == 0
            SimState.tx_status(ap_id, :) = ...
                [i, i + SimParams.T_ackN - 1, ack(3), 0, 1];
            SimState.ED_ACK_Source_GID(ap_id) = ack(2);
            SimState.Node.TX_Buffer(ap_id) = ...
                ED_Dequeue_ACK(SimState.Node.TX_Buffer(ap_id));
            SimState.n_access(ap_id) = SimState.n_access(ap_id) + 1;
            ack_destination = ack(3);
            SimState.ED_Airtime.ACK_Attempt_Slots_By_Destination( ...
                ack_destination) = ...
                SimState.ED_Airtime.ACK_Attempt_Slots_By_Destination( ...
                ack_destination) + SimParams.T_ackN;
        end
    end

    start_tx_nodes = find(SimState.tx_status(:, 1) == i).';
    ongoing_tx_nodes = find( ...
        SimState.tx_status(:, 1) ~= -1 & ...
        SimState.tx_status(:, 1) < i).';
    use_legacy_collision = Is_Legacy_Collision_Mode(SimParams);

    for tx_id = start_tx_nodes
        cs_nodes = Get_Cached_Nodes( ...
            SimState, SimParams, tx_id, true);
        interfered_nodes = Get_Cached_Nodes( ...
            SimState, SimParams, tx_id, false);
        tx_end = SimState.tx_status(tx_id, 2);

        SimState.ED_Channel = ED_Channel_Add( ...
            SimState.ED_Channel, i, tx_end, tx_id, 1);
        SimState.ED_Channel = ED_Channel_Add( ...
            SimState.ED_Channel, i, tx_end, cs_nodes, 2);
        if ~isempty(cs_nodes)
            SimState.Node.aifs(cs_nodes) = ...
                SimState.Node.Init_aifs(cs_nodes);
        end

        if use_legacy_collision
            active_tx = find(SimState.tx_status(:, 1) ~= -1).';
            active_tx(active_tx == tx_id) = [];
            hit = active_tx(ismember( ...
                SimState.tx_status(active_tx, 3), interfered_nodes));
            for victim = hit
                SimState = Register_Collision( ...
                    SimState, victim, tx_id);
            end
            continue;
        end

        hit = ongoing_tx_nodes(ismember( ...
            SimState.tx_status(ongoing_tx_nodes, 3), interfered_nodes));
        for victim = hit
            SimState = Register_Collision(SimState, victim, tx_id);
        end

        destination = SimState.tx_status(tx_id, 3);
        for interferer = ongoing_tx_nodes
            interferer_nodes = Get_Cached_Nodes( ...
                SimState, SimParams, interferer, false);
            if ismember(destination, interferer_nodes)
                SimState = Register_Collision( ...
                    SimState, tx_id, interferer);
            end
        end
    end

    if ~use_legacy_collision
        for a = 1:numel(start_tx_nodes) - 1
            tx_a = start_tx_nodes(a);
            intf_a = Get_Cached_Nodes( ...
                SimState, SimParams, tx_a, false);
            for b = a + 1:numel(start_tx_nodes)
                tx_b = start_tx_nodes(b);
                intf_b = Get_Cached_Nodes( ...
                    SimState, SimParams, tx_b, false);
                if ismember(SimState.tx_status(tx_b, 3), intf_a)
                    SimState = Register_Collision( ...
                        SimState, tx_b, tx_a);
                end
                if ismember(SimState.tx_status(tx_a, 3), intf_b)
                    SimState = Register_Collision( ...
                        SimState, tx_a, tx_b);
                end
            end
        end
    end

    SimState = ED_Record_TXOP_Reservation_Starts( ...
        SimState, SimParams, start_tx_nodes);

    if ~isempty(start_tx_nodes)
        SimState.n_txnode = Rebuild_CarrierSense_Counts( ...
            SimState, SimParams);
    end
    active_tx_bss = false(1, SimParams.N_AP);
    active_tx = find(SimState.tx_status(:, 1) ~= -1).';
    if ~isempty(active_tx)
        active_tx_bss(unique( ...
            SimState.Node.BSS_ID(active_tx))) = true;
    end
    SimState = Update_Overlap_Diagnostics( ...
        SimState, Active_RAW_BSS, active_tx_bss);
end

function tf = Is_Cross_Slot_TXOP(SimParams, node_id)
    tf = isfield(SimParams, 'EDCA_TXOP_Cross_Slot_Allowed') && ...
        SimParams.EDCA_TXOP_Cross_Slot_Allowed && ...
        isfield(SimParams, 'EDCA_TXOP_Eligible') && ...
        node_id <= numel(SimParams.EDCA_TXOP_Eligible) && ...
        SimParams.EDCA_TXOP_Eligible(node_id);
end

function tf = Can_Start_Cross_Slot_TXOP( ...
    SimState, SimParams, node_id, tx_slots, raw_end_slot)

    tf = false;
    if ~Is_Cross_Slot_TXOP(SimParams, node_id)
        return;
    end
    bss_id = SimState.Node.BSS_ID(node_id);
    if bss_id < 1 || ...
            bss_id > numel(SimParams.EDCA_TXOP_Limit_Slots_By_BSS)
        return;
    end
    limit_slots = SimParams.EDCA_TXOP_Limit_Slots_By_BSS(bss_id);
    first_ack_end = SimState.Time + tx_slots - 1 + ...
        SimParams.SIFSN + SimParams.T_ackN - 1;
    txop_end = ED_TXOP_Get_End_Slot( ...
        SimState, SimParams, node_id, raw_end_slot);
    tf = limit_slots > 0 && first_ack_end <= txop_end;
end

function SimState = Record_Cross_Slot_Exchange( ...
    SimState, SimParams, node_id, data_start_slot, data_end_slot)

    raw_end = SimState.ED_TXOP.AcquisitionRAWEndSlot(node_id);
    if raw_end < 0
        return;
    end
    exchange_end = data_end_slot + SimParams.SIFSN + ...
        SimParams.T_ackN - 1;
    period_end = SimState.ED_TXOP.PeriodEndSlot(node_id);
    usable_period_end = period_end - ...
        SimParams.EDCA_TXOP_Guard_Slots - 1;
    if period_end >= 0 && exchange_end > usable_period_end
        SimState.ED_TXOP.PeriodBoundaryViolations(node_id) = ...
            SimState.ED_TXOP.PeriodBoundaryViolations(node_id) + 1;
        SimState.ED_TXOP.PeriodBoundaryOverrunSlots(node_id) = ...
            SimState.ED_TXOP.PeriodBoundaryOverrunSlots(node_id) + ...
            exchange_end - usable_period_end;
    end
    overrun_start = max(data_start_slot, raw_end);
    overrun_slots = max(0, exchange_end - overrun_start + 1);
    if overrun_slots <= 0
        return;
    end
    SimState.ED_TXOP.CrossSlotExchanges(node_id) = ...
        SimState.ED_TXOP.CrossSlotExchanges(node_id) + 1;
    SimState.ED_TXOP.CrossSlotExchangeOverrunSlots(node_id) = ...
        SimState.ED_TXOP.CrossSlotExchangeOverrunSlots(node_id) + ...
        overrun_slots;
end

function SimState = Start_Data_Transmission( ...
    SimState, SimParams, sta_id, now_slot, tx_slots)

    SimState.n_access(sta_id) = SimState.n_access(sta_id) + 1;
    SimState.ED_Airtime.DATA_Attempt_Slots(sta_id) = ...
        SimState.ED_Airtime.DATA_Attempt_Slots(sta_id) + tx_slots;
    if SimParams.Mode_Net_Congestion_Measure
        SimState.ED_Measure.N_Acc(sta_id) = ...
            SimState.ED_Measure.N_Acc(sta_id) + 1;
    end

    dest_ap = SimState.Node.Serving_AP(sta_id);
    SimState.tx_status(sta_id, :) = ...
        [now_slot, now_slot + tx_slots - 1, dest_ap, 0, 0];
    SimState = Log_TX_Access_Attempt( ...
        SimState, SimParams, sta_id, now_slot);
end

function SimState = Expire_Idle_TXOPs(SimState, now_slot)
    expired = find( ...
        SimState.ED_TXOP.Active & ...
        SimState.ED_TXOP.EndSlot < now_slot & ...
        SimState.tx_status(:, 1).' == -1 & ...
        SimState.Node.ACK_Timer(:, 1).' == -1);
    for node_id = expired
        SimState = ED_TXOP_End( ...
            SimState, node_id, 'limit', true);
    end
end

function nodes = Get_Cached_Nodes(SimState, SimParams, tx_id, carrier_sense)
    if carrier_sense
        cache_name = 'Cached_CarrierSenseNodes';
        threshold = SimParams.CSTh;
    else
        cache_name = 'Cached_Interferers';
        if isfield(SimParams, 'Interference_RSS_Threshold')
            threshold = SimParams.Interference_RSS_Threshold;
        else
            threshold = SimParams.CSTh;
        end
    end

    if isfield(SimState, cache_name)
        nodes = SimState.(cache_name){tx_id};
    else
        [sta, ap] = Get_InteferedSTAs( ...
            SimState.MAP_RSS, tx_id, threshold, SimParams.N_AP);
        nodes = unique([sta; ap]);
    end
end

function SimState = Register_Collision(SimState, victim, interferer)
    SimState.tx_status(victim, 4) = ...
        SimState.tx_status(victim, 4) + 1;
    if ~isfield(SimState, 'BSS_Interference')
        return;
    end

    victim_bss = SimState.Node.BSS_ID(victim);
    interferer_bss = SimState.Node.BSS_ID(interferer);
    if victim_bss > 0 && interferer_bss > 0
        SimState.BSS_Interference.Collision_Matrix( ...
            victim_bss, interferer_bss) = ...
            SimState.BSS_Interference.Collision_Matrix( ...
            victim_bss, interferer_bss) + 1;
    end

    victim_rx = SimState.tx_status(victim, 3);
    tx_type = SimState.Node.Type(interferer);
    rx_type = SimState.Node.Type(victim_rx);
    if tx_type == -1 && rx_type == -1
        link_type = 3;
    elseif tx_type == -1
        link_type = 2;
    elseif rx_type == -1
        link_type = 1;
    else
        link_type = 4;
    end
    SimState.BSS_Interference.Link_Type_Count(link_type) = ...
        SimState.BSS_Interference.Link_Type_Count(link_type) + 1;
end

function SimState = Log_TX_Access_Attempt( ...
    SimState, SimParams, node_id, now_slot)

    if ~isfield(SimParams, 'On_Save_TX_Log') || ...
       ~SimParams.On_Save_TX_Log
        return;
    end

    if ~isfield(SimState, 'TX_LOG_Access_Log')
        if ~isfield(SimState, 'TX_LOG_Aggregate_Bins')
            SimState.TX_LOG_Access_Log = zeros(0, 11);
            SimState.TX_LOG_Pending_Access_Idx = ...
                zeros(1, SimParams.N_Node);
        end
    end

    ch_util = 0;
    n_ack = 0;
    if SimParams.Mode_Net_Congestion_Measure
        ch_util = SimState.ED_Measure.CH_Util(node_id);
        n_ack = SimState.ED_Measure.N_ACK(node_id);
    end

    if isfield(SimState, 'TX_LOG_Aggregate_Bins')
        ch_bin = ceil(ch_util / 0.1) * 0.1;
        ack_bin = ceil(n_ack / 5) * 5;
        bins = SimState.TX_LOG_Aggregate_Bins;
        bin_idx = find( ...
            bins(:, 1) == ch_bin & bins(:, 2) == ack_bin, 1);
        if isempty(bin_idx)
            bin_idx = size(bins, 1) + 1;
            bins(bin_idx, :) = [ch_bin, ack_bin, 0, 0, 0, 0];
        end
        bins(bin_idx, 3) = bins(bin_idx, 3) + 1;
        SimState.TX_LOG_Aggregate_Bins = bins;
        SimState.TX_LOG_Pending_Bin_Idx(node_id) = bin_idx;
        return;
    end

    mpdu = ED_Peek_MPDU(SimState.Node.TX_Buffer(node_id));
    mpdu_gid = mpdu(1);
    row_idx = size(SimState.TX_LOG_Access_Log, 1) + 1;
    SimState.TX_LOG_Access_Log(row_idx, :) = [ ...
        node_id, SimState.Node.BSS_ID(node_id), now_slot, ...
        ch_util, n_ack, mpdu_gid, zeros(1, 5)];
    SimState.TX_LOG_Pending_Access_Idx(node_id) = row_idx;
end

function use_legacy = Is_Legacy_Collision_Mode(SimParams)
    if ~isfield(SimParams, 'Collision_Check_Mode')
        mode = 'auto';
    else
        mode = lower(char(SimParams.Collision_Check_Mode));
    end
    if strcmp(mode, 'auto')
        use_legacy = SimParams.N_AP == 1;
    elseif strcmp(mode, 'legacy')
        use_legacy = true;
    elseif any(strcmp(mode, {'rx-centric', 'rx_centric', 'receiver-centric'}))
        use_legacy = false;
    else
        error('ED:UnsupportedCollisionMode', ...
            'Unsupported Collision_Check_Mode: %s', mode);
    end
end

function SimState = Update_Overlap_Diagnostics( ...
    SimState, Active_RAW_BSS, Active_TX_BSS)
    if ~isfield(SimState, 'BSS_Interference')
        return;
    end
    active = find(Active_RAW_BSS);
    if ~isempty(active)
        SimState.BSS_Interference.RAW_Active_Slots(active) = ...
            SimState.BSS_Interference.RAW_Active_Slots(active) + 1;
        SimState.BSS_Interference.RAW_Overlap_Slots(active, active) = ...
            SimState.BSS_Interference.RAW_Overlap_Slots(active, active) + 1;
    end

    active = find(Active_TX_BSS);
    if ~isempty(active)
        SimState.BSS_Interference.TX_Active_Slots(active) = ...
            SimState.BSS_Interference.TX_Active_Slots(active) + 1;
        SimState.BSS_Interference.TX_Overlap_Slots(active, active) = ...
            SimState.BSS_Interference.TX_Overlap_Slots(active, active) + 1;
    end
end
