function SimState = ED_Handle_Tx_Events(SimState, SimParams)
%ED_HANDLE_TX_EVENTS Complete TX, ACK timeout, and congestion events.

    i = SimState.Time;
    end_tx_nodes = find(SimState.tx_status(:, 2) == i).';

    for tx_id = end_tx_nodes
        cs_nodes = SimState.Cached_CarrierSenseNodes{tx_id};
        collided = SimState.tx_status(tx_id, 4) > 0;
        is_ack = SimState.tx_status(tx_id, 5) == 1;
        if ~isempty(cs_nodes)
            SimState.Node.aifs(cs_nodes) = ...
                SimState.Node.Init_aifs(cs_nodes);
        end

        if collided
            if ~is_ack
                if SimState.ED_TXOP.Active(tx_id)
                    SimState.ED_TXOP.ReservationEstablished(tx_id) = false;
                end
                mpdu = ED_Peek_MPDU( ...
                    SimState.Node.TX_Buffer(tx_id));
                gid = mpdu(1);
                SimState = Mark_TX_Log_Data_Collision( ...
                    SimState, SimParams, tx_id);
                SimState.Node.ACK_Timer(tx_id, :) = Set_AckTimer( ...
                    SimParams.T_ack_Timeout, SimParams.T_slot, i, gid);
            end
            SimState.n_collision(tx_id) = ...
                SimState.n_collision(tx_id) + 1;

        elseif ~is_ack
            destination = SimState.tx_status(tx_id, 3);
            if SimState.Node.TX_Buffer(tx_id).Length <= 0
                error('ED:DataTXCompletedWithEmptyQueue', ...
                    ['DATA node %d completed at slot %d with an empty ' ...
                     'queue (start=%d, destination=%d, ACK timer=%d).'], ...
                    tx_id, i, SimState.tx_status(tx_id, 1), destination, ...
                    SimState.Node.ACK_Timer(tx_id, 1));
            end
            mpdu = ED_Peek_MPDU( ...
                SimState.Node.TX_Buffer(tx_id));
            gid = mpdu(1);
            [SimState.Node.TX_Buffer(destination), SimState.GID] = ...
                ED_Enqueue_ACK(SimState.Node.TX_Buffer(destination), ...
                SimState.GID, gid, tx_id, SimParams.L_ack, i);
            SimState.n_success(tx_id) = ...
                SimState.n_success(tx_id) + 1;
            SimState.Node.ACK_Timer(tx_id, :) = Set_AckTimer( ...
                SimParams.T_ack_Timeout, SimParams.T_slot, i, gid);

        else
            data_node = SimState.tx_status(tx_id, 3);
            arriving_source_gid = SimState.ED_ACK_Source_GID(tx_id);
            if SimState.Node.ACK_Timer(data_node, 1) >= i && ...
               SimState.tx_status(data_node, 1) == -1
                mpdu = ED_Peek_MPDU( ...
                    SimState.Node.TX_Buffer(data_node));
                source_gid = mpdu(1);
                if SimState.Node.ACK_Timer(data_node, 2) == ...
                        arriving_source_gid && ...
                   source_gid == arriving_source_gid
                    generated = mpdu(3);
                    SimState.Delay(data_node) = ED_Append_Delay( ...
                        SimState.Delay(data_node), generated, i);
                    SimState.L_success(data_node) = ...
                        SimState.L_success(data_node) + ...
                        mpdu(2);
                    SimState.n_success2(data_node) = ...
                        SimState.n_success2(data_node) + 1;
                    SimState.n_success(tx_id) = ...
                        SimState.n_success(tx_id) + 1;
                    SimState = Complete_TX_Log_Access( ...
                        SimState, SimParams, data_node, 'success', false);
                    SimState.Node.TX_Buffer(data_node) = ...
                        ED_Dequeue_MPDU( ...
                        SimState.Node.TX_Buffer(data_node));
                    SimState.Node.ACK_Timer(data_node, :) = ...
                        Init_ACK_Timers( ...
                        SimState.Node.ACK_Timer(data_node, :));
                    was_in_txop = SimState.ED_TXOP.Active(data_node);
                    SimState = ED_TXOP_After_ACK( ...
                        SimState, SimParams, data_node, i);
                    if ~was_in_txop
                        SimState = ED_Reset_Contention_After_Success( ...
                            SimState, data_node);
                    end

                    if SimParams.Mode_Net_Congestion_Measure
                        SimState = Count_Successful_ACK( ...
                            SimState, tx_id, data_node, cs_nodes);
                    end
                end
            end
        end
        SimState.tx_status(tx_id, :) = ...
            Init_tx_status(SimState.tx_status(tx_id, :));
        SimState.ED_ACK_Source_GID(tx_id) = -1;
    end

    if ~isempty(end_tx_nodes)
        SimState.n_txnode = Rebuild_CarrierSense_Counts( ...
            SimState, SimParams);
    end

    expired = find( ...
        SimState.Node.ACK_Timer(:, 1) ~= -1 & ...
        SimState.Node.ACK_Timer(:, 1) < i).';
    for node_id = expired
        SimState = ED_TXOP_End( ...
            SimState, node_id, 'abort', false);
        SimState.n_collision2(node_id) = ...
            SimState.n_collision2(node_id) + 1;
        SimState.Node.N_retry(node_id) = ...
            SimState.Node.N_retry(node_id) + 1;
        retry_loss = SimState.Node.N_retry(node_id) == ...
            SimState.Node.Retry_Limit(node_id);
        SimState = Complete_TX_Log_Access( ...
            SimState, SimParams, node_id, 'timeout', retry_loss);
        [SimState.Node.TX_Buffer(node_id), SimState.GID] = ...
            ED_Reset_MPDU_GID( ...
            SimState.Node.TX_Buffer(node_id), SimState.GID);
        SimState.Node.ACK_Timer(node_id, :) = ...
            Init_ACK_Timers(SimState.Node.ACK_Timer(node_id, :));

        if SimParams.Mode_Net_Congestion_Measure
            SimState.ED_Measure.N_Fail(node_id) = ...
                SimState.ED_Measure.N_Fail(node_id) + 1;
        end

        if SimParams.BEB_ENABLE
            SimState.Node.CW(node_id) = min( ...
                SimState.Node.CW(node_id) * 2, ...
                SimState.Node.CW_max(node_id));
            SimState.Node.bc(node_id) = ceil( ...
                rand * SimState.Node.CW(node_id));
        end
        if retry_loss
            SimState.Node.TX_Buffer(node_id) = ...
                ED_Dequeue_MPDU( ...
                SimState.Node.TX_Buffer(node_id));
            SimState.Node.N_retry(node_id) = 0;
            SimState.n_loss(node_id) = ...
                SimState.n_loss(node_id) + 1;
            if SimParams.BEB_ENABLE
                SimState.Node.CW(node_id) = ...
                    SimParams.CW_min(node_id);
                SimState.Node.bc(node_id) = ceil( ...
                    rand * SimState.Node.CW(node_id));
            end
        end
    end

    if SimParams.Mode_Net_Congestion_Measure && ...
       i > SimState.Next_Net_Congestion_Measure_Time
        SimState = Update_Congestion_Measurements( ...
            SimState, SimParams);
    end
end

function SimState = Count_Successful_ACK( ...
    SimState, ap_id, data_node, cs_nodes)

    SimState.ED_Measure.N_Suc(data_node) = ...
        SimState.ED_Measure.N_Suc(data_node) + 1;

    first_slot = SimState.tx_status(ap_id, 1);
    last_slot = SimState.tx_status(ap_id, 2);
    for node_id = cs_nodes(:).'
        state = ED_Channel_Get( ...
            SimState.ED_Channel, first_slot:last_slot, node_id);
        if all(state == uint8(2))
            SimState.ED_Measure.N_ACK(node_id) = ...
                SimState.ED_Measure.N_ACK(node_id) + 1;
        end
    end
end

function SimState = Update_Congestion_Measurements(SimState, SimParams)
    measure_end = SimState.Next_Net_Congestion_Measure_Time;
    measure_start = measure_end - ...
        SimParams.Net_Congestion_Measure_Interval + 1;
    sta_ids = SimParams.idx_STA;
    busy_count = ED_Channel_Busy_Count( ...
        SimState.ED_Channel, measure_start, measure_end, sta_ids);
    utilization = busy_count / ...
        SimParams.Net_Congestion_Measure_Interval;

    SimState.ED_Measure.TimeSlot = measure_end;
    SimState.ED_Measure.CH_Util(sta_ids) = utilization;
    SimState.ED_Measure.N_ACK(sta_ids) = 0;
    SimState.ED_Measure.N_Acc(sta_ids) = 0;
    SimState.ED_Measure.N_Fail(sta_ids) = 0;
    SimState.ED_Measure.N_Suc(sta_ids) = 0;
    SimState.Next_Net_Congestion_Measure_Time = ...
        measure_end + SimParams.Net_Congestion_Measure_Interval;
end

function SimState = Mark_TX_Log_Data_Collision( ...
    SimState, SimParams, node_id)
    if ~Should_Update_TX_Log(SimState, SimParams, node_id)
        return;
    end
    if isfield(SimState, 'TX_LOG_Aggregate_Bins')
        return;
    end
    row_idx = SimState.TX_LOG_Pending_Access_Idx(node_id);
    if row_idx > 0 && row_idx <= size(SimState.TX_LOG_Access_Log, 1)
        SimState.TX_LOG_Access_Log(row_idx, 10) = 1;
    end
end

function SimState = Complete_TX_Log_Access( ...
    SimState, SimParams, node_id, outcome, retry_loss)
    if ~Should_Update_TX_Log(SimState, SimParams, node_id)
        return;
    end
    if isfield(SimState, 'TX_LOG_Aggregate_Bins')
        bin_idx = SimState.TX_LOG_Pending_Bin_Idx(node_id);
        if bin_idx <= 0 || ...
                bin_idx > size(SimState.TX_LOG_Aggregate_Bins, 1)
            return;
        end
        SimState.TX_LOG_Aggregate_Bins(bin_idx, 4) = ...
            SimState.TX_LOG_Aggregate_Bins(bin_idx, 4) + 1;
        if strcmp(outcome, 'success')
            outcome_column = 6;
        elseif strcmp(outcome, 'timeout')
            outcome_column = 5;
        else
            error('ED:UnexpectedTXLogOutcome', ...
                'Unexpected TX_LOG outcome: %s', outcome);
        end
        SimState.TX_LOG_Aggregate_Bins(bin_idx, outcome_column) = ...
            SimState.TX_LOG_Aggregate_Bins( ...
                bin_idx, outcome_column) + 1;
        SimState.TX_LOG_Pending_Bin_Idx(node_id) = 0;
        return;
    end
    row_idx = SimState.TX_LOG_Pending_Access_Idx(node_id);
    if row_idx <= 0 || row_idx > size(SimState.TX_LOG_Access_Log, 1)
        return;
    end
    if strcmp(outcome, 'success')
        SimState.TX_LOG_Access_Log(row_idx, 8) = 1;
    elseif strcmp(outcome, 'timeout')
        SimState.TX_LOG_Access_Log(row_idx, 7) = 1;
    else
        error('ED:UnexpectedTXLogOutcome', ...
            'Unexpected TX_LOG outcome: %s', outcome);
    end
    if retry_loss
        SimState.TX_LOG_Access_Log(row_idx, 9) = 1;
    end
    SimState.TX_LOG_Access_Log(row_idx, 11) = 1;
    SimState.TX_LOG_Pending_Access_Idx(node_id) = 0;
end

function tf = Should_Update_TX_Log(SimState, SimParams, node_id)
    tf = isfield(SimParams, 'On_Save_TX_Log') && ...
        SimParams.On_Save_TX_Log && ...
        (isfield(SimState, 'TX_LOG_Access_Log') || ...
         isfield(SimState, 'TX_LOG_Aggregate_Bins')) && ...
        node_id >= 1 && ...
        node_id <= SimParams.N_Node;
end
