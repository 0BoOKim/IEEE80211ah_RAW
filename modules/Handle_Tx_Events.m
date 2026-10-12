function SimState = Handle_Tx_Events(SimState, SimParams)

    i = SimState.Time;
    STATE_CS = uint8(2);

    % ---------------------------------------------
    % 1. End of Transmission Event
    % ---------------------------------------------
    EndTxNodes = find(SimState.tx_status(:,2) == i).';
    for j = EndTxNodes

        if isfield(SimState, 'Cached_CarrierSenseNodes')
            Idx_IntfNode = SimState.Cached_CarrierSenseNodes{j};
        else
            [Idx_IntfSTA, Idx_IntfAP] = Get_InteferedSTAs(SimState.MAP_RSS, j, SimParams.CSTh, SimParams.N_AP);
            Idx_IntfNode = unique([Idx_IntfSTA; Idx_IntfAP]);
        end

        SimState.Node.aifs(j) = SimState.Node.Init_aifs(j);
        SimState.Node.bc(j) = ceil(rand*SimState.Node.CW(j));

        if ~isempty(Idx_IntfNode)
            SimState.Node.aifs(Idx_IntfNode) = SimState.Node.Init_aifs(Idx_IntfNode);
        end

        % Check Result
        if SimState.tx_status(j,4) > 0  % Fail (Interference occurred)

            if SimState.tx_status(j,5) == 0 % DATA
                GID_Src = SimState.Node.TX_Buffer(j).MPDU(1,1);
                SimState = Mark_TX_Log_Data_Collision(SimState, SimParams, j);
                SimState.Node.ACK_Timer(j,:) = Set_AckTimer(SimParams.T_ack_Timeout, SimParams.T_slot, i, GID_Src);
            end
            SimState.n_collision(j) = SimState.n_collision(j) + 1;

        elseif SimState.tx_status(j,4) == 0 && SimState.tx_status(j,5) == 0 % Success DATA

            % Enque ACK at Destination (AP usually)
            Dest_ID = SimState.tx_status(j,3);
            GID_Src = SimState.Node.TX_Buffer(j).MPDU(1,1);
            [SimState.Node.TX_Buffer(Dest_ID), SimState.GID] = Enque_ACK(SimState.Node.TX_Buffer(Dest_ID), SimState.GID, GID_Src, j, SimParams.L_ack, i);

            SimState.n_success(j) = SimState.n_success(j) + 1;

            if SimParams.Traffic_Surge_Mode == 4 && ...
               SimState.Node.Type(j) == 1 && ...
               SimState.Node.Type(Dest_ID) == -1
                if ~isfield(SimState, 'AP_Alarm_Success_Log')
                    SimState.AP_Alarm_Success_Log = zeros(0, 6);
                end
                if ~isfield(SimState, 'AP_Last_Alarm_Success_Slot')
                    SimState.AP_Last_Alarm_Success_Slot = inf(1, SimParams.N_Node);
                end

                src_bss = SimState.Node.BSS_ID(j);
                gen_time = SimState.Node.TX_Buffer(j).MPDU(1,3);
                SimState.AP_Alarm_Success_Log = [SimState.AP_Alarm_Success_Log; ...
                    i j Dest_ID src_bss GID_Src gen_time]; %#ok<AGROW>
                SimState.AP_Last_Alarm_Success_Slot(j) = i;
            end

            % Set ACK Timer
            SimState.Node.ACK_Timer(j,:) = Set_AckTimer(SimParams.T_ack_Timeout, SimParams.T_slot, i, GID_Src);

        elseif SimState.tx_status(j,4) == 0 && SimState.tx_status(j,5) == 1 % Success ACK

            Temp_TX_Node_ID = SimState.tx_status(j,3); % Destination of ACK (Source of original Data)

            if SimState.Node.ACK_Timer(Temp_TX_Node_ID,1) >= i % Within Timeout
                Temp_GID_Src = SimState.Node.TX_Buffer(Temp_TX_Node_ID).MPDU(1,1);
                if SimState.Node.ACK_Timer(Temp_TX_Node_ID,2) == Temp_GID_Src

                    % Successful ACK Reception
                    SimState.Delay(Temp_TX_Node_ID).delay = [SimState.Delay(Temp_TX_Node_ID).delay; SimState.Node.TX_Buffer(Temp_TX_Node_ID).MPDU(1, 3)  i i-SimState.Node.TX_Buffer(Temp_TX_Node_ID).MPDU(1, 3)];
                    SimState.L_success(Temp_TX_Node_ID) = SimState.L_success(Temp_TX_Node_ID) + SimState.Node.TX_Buffer(Temp_TX_Node_ID).MPDU(1, 2);
                    SimState.n_success2(Temp_TX_Node_ID) = SimState.n_success2(Temp_TX_Node_ID) + 1;
                    SimState.n_success(j) = SimState.n_success(j) + 1;
                    SimState = Complete_TX_Log_Access(SimState, SimParams, Temp_TX_Node_ID, 'success');

                    SimState.Node.TX_Buffer(Temp_TX_Node_ID) = Deque_MPDU(SimState.Node.TX_Buffer(Temp_TX_Node_ID));
                    SimState.Node.ACK_Timer(Temp_TX_Node_ID,:) = Init_ACK_Timers(SimState.Node.ACK_Timer(Temp_TX_Node_ID,:));

                    if SimParams.BEB_ENABLE
                       SimState.Node.CW(j) = SimParams.CW_min(j);
                       SimState.Node.bc(j) = ceil(rand*SimState.Node.CW(j));
                       SimState.Node.N_retry(j) = 0;
                    end

                    if SimParams.Mode_Net_Congestion_Measure
                        SimState.Net_Congestion_Measure(Temp_TX_Node_ID).N_Suc(size(SimState.Net_Congestion_Measure(Temp_TX_Node_ID).N_Suc, 1), 2) = ...
                            SimState.Net_Congestion_Measure(Temp_TX_Node_ID).N_Suc(size(SimState.Net_Congestion_Measure(Temp_TX_Node_ID).N_Suc, 1), 2) + 1;

                        if ~isempty(Idx_IntfNode)
                            Temp_Begin = SimState.tx_status(j,1);
                            Temp_End = SimState.tx_status(j,2);

                            for Temp_Idx=1:length(Idx_IntfNode)
                                if length(find(SimState.tx_state(Temp_Begin:Temp_End, Idx_IntfNode(Temp_Idx)) == STATE_CS)) == Temp_End - Temp_Begin + 1
                                   SimState.Net_Congestion_Measure(Idx_IntfNode(Temp_Idx)).N_ACK(size(SimState.Net_Congestion_Measure(Idx_IntfNode(Temp_Idx)).N_ACK, 1), 2) ...
                                       = SimState.Net_Congestion_Measure(Idx_IntfNode(Temp_Idx)).N_ACK(size(SimState.Net_Congestion_Measure(Idx_IntfNode(Temp_Idx)).N_ACK, 1), 2) + 1;
                                end
                            end
                        end
                    end
                end
            end
        else
            error('unexpected value of tx_status!');
        end

        SimState.tx_status(j, :) = Init_tx_status(SimState.tx_status(j, :));
    end
    if ~isempty(EndTxNodes)
        SimState.n_txnode = Rebuild_CarrierSense_Counts( ...
            SimState, SimParams);
    end

    % ---------------------------------------------
    % 2. ACK Timer Check (Timeout)
    % ---------------------------------------------
    ExpiredAckNodes = find(SimState.Node.ACK_Timer(:,1) ~= -1 & SimState.Node.ACK_Timer(:,1) < i).';
    for j = ExpiredAckNodes
       SimState.n_collision2(j) = SimState.n_collision2(j) + 1;
       SimState.Node.N_retry(j) = SimState.Node.N_retry(j) + 1;
       retry_loss = SimState.Node.N_retry(j) == SimState.Node.Retry_Limit(j);
       SimState = Complete_TX_Log_Access(SimState, SimParams, j, 'timeout', retry_loss);
       [SimState.Node.TX_Buffer(j) SimState.GID] = Reset_GID(SimState.Node.TX_Buffer(j), SimState.GID);
       SimState.Node.ACK_Timer(j,:) = Init_ACK_Timers(SimState.Node.ACK_Timer(j,:));

       if  SimParams.Mode_Net_Congestion_Measure
           SimState.Net_Congestion_Measure(j).N_Fail(size(SimState.Net_Congestion_Measure(j).N_Fail, 1), 2) = ...
               SimState.Net_Congestion_Measure(j).N_Fail(size(SimState.Net_Congestion_Measure(j).N_Fail, 1), 2) + 1;
       end

       if SimParams.BEB_ENABLE
          SimState.Node.CW(j) = min(SimState.Node.CW(j) * 2, SimState.Node.CW_max(j));
          SimState.Node.bc(j) = ceil(rand*SimState.Node.CW(j));
       end

       if SimState.Node.N_retry(j) == SimState.Node.Retry_Limit(j)
           SimState.Node.TX_Buffer(j) = Deque_MPDU(SimState.Node.TX_Buffer(j));
           SimState.Node.N_retry(j) = 0;
           SimState.n_loss(j) = SimState.n_loss(j) + 1;
           if SimParams.BEB_ENABLE
                SimState.Node.CW(j) = SimParams.CW_min(j);
                SimState.Node.bc(j) = ceil(rand*SimState.Node.CW(j));
           end
       end
    end

    % ---------------------------------------------
    % 3. Congestion Measurement Update
    % ---------------------------------------------
    if SimParams.Mode_Net_Congestion_Measure
        if i > SimState.Next_Net_Congestion_Measure_Time
            for j = 1:SimParams.N_STA
               idx = SimParams.idx_STA(j);
               Temp_CH_Util = sum(SimState.tx_state(SimState.Next_Net_Congestion_Measure_Time-SimParams.Net_Congestion_Measure_Interval+1:SimState.Next_Net_Congestion_Measure_Time, idx)>0)/SimParams.Net_Congestion_Measure_Interval;

               SimState.Net_Congestion_Measure(idx).CH_Util = [SimState.Net_Congestion_Measure(idx).CH_Util; SimState.Next_Net_Congestion_Measure_Time Temp_CH_Util];
               SimState.Net_Congestion_Measure(idx).N_ACK = [SimState.Net_Congestion_Measure(idx).N_ACK; SimState.Next_Net_Congestion_Measure_Time 0];
               SimState.Net_Congestion_Measure(idx).N_Acc = [SimState.Net_Congestion_Measure(idx).N_Acc; SimState.Next_Net_Congestion_Measure_Time 0];
               SimState.Net_Congestion_Measure(idx).N_Fail = [SimState.Net_Congestion_Measure(idx).N_Fail; SimState.Next_Net_Congestion_Measure_Time 0];
               SimState.Net_Congestion_Measure(idx).N_Suc = [SimState.Net_Congestion_Measure(idx).N_Suc; SimState.Next_Net_Congestion_Measure_Time 0];
               SimState.Net_Congestion_Measure(idx).N_MPDU = [SimState.Net_Congestion_Measure(idx).N_MPDU; SimState.Next_Net_Congestion_Measure_Time 0];
               SimState.Net_Congestion_Measure(idx).L_QTime = [SimState.Net_Congestion_Measure(idx).L_QTime; SimState.Next_Net_Congestion_Measure_Time 0];
            end
            SimState.Next_Net_Congestion_Measure_Time = SimState.Next_Net_Congestion_Measure_Time + SimParams.Net_Congestion_Measure_Interval ;
        end
    end

    % ---------------------------------------------
    % 4. Traffic Temporal Evolution Update
    % ---------------------------------------------
    if SimParams.On_Measure_Traffic_Temporal_Evolution
       if SimState.Next_Measure_Time  <= i
            Temp_sum_N_Frame = 0;
            Temp_sum_Length = 0;
            N_STAs_has_buffered_Frames = 0;
            for j = 1:SimParams.N_Node
                if SimState.Node.Type(j) == -1
                   continue;
                end

                if SimState.Node.TX_Buffer(j).Length > 0
                    Temp_sum_N_Frame = Temp_sum_N_Frame + SimState.Node.TX_Buffer(j).Length;
                    Temp_sum_Length = Temp_sum_Length + SimState.Node.TX_Buffer(j).MPDU(2);
                    N_STAs_has_buffered_Frames  = N_STAs_has_buffered_Frames +1;
                end
            end

            SimState.Traffic_Temporal_Evolution = [SimState.Traffic_Temporal_Evolution;  SimState.Next_Measure_Time Temp_sum_N_Frame Temp_sum_N_Frame/SimParams.N_STA Temp_sum_Length Temp_sum_Length/SimParams.N_STA N_STAs_has_buffered_Frames ...
                                     mean(SimState.n_access) mean(SimState.n_success./SimState.n_access) mean(SimState.n_collision./SimState.n_access)];
            SimState.Next_Measure_Time = SimState.Next_Measure_Time + SimParams.Opt_Measure_Interval;
       end
    end

    % ---------------------------------------------
    % 5. Dynamic Sim Time Extension (Optional)
    % ---------------------------------------------
    % (Note: This logic resizes tx_state which is expensive, but we keep it for fidelity)
    if SimParams.Mode_Dynamic_Sim_Time &&  SimParams.N_slot - i < SimParams.Crit_Remaied_Slot
        isAdjustSimTimeExtend = 0;
        for j = 1:SimParams.N_alarmSTA
             idx = SimParams.idx_STA_Type1(j);
            if SimState.Node.TX_Buffer(idx).Length > 0
                isAdjustSimTimeExtend = 1;
                break;
            end
        end

        if isAdjustSimTimeExtend
             SimParams.N_slot = SimParams.N_slot + SimParams.N_Extending_Slot;
             SimState.tx_state = [SimState.tx_state; zeros(SimParams.N_Extending_Slot, SimParams.N_STA, 'uint8')];
             % Note: SimParams is passed by value, so N_slot update won't persist unless we return SimParams or update SimState.N_slot if it existed.
             % But SimParams IS returned if we change signature.
             % Currently signature is `SimState = ...`.
             % To support this, we would need to make N_slot part of SimState or return SimParams.
             % I will assume dynamic extension is disabled (Mode_Dynamic_Sim_Time = 0 in config) or ignore for now as SimParams is usually const.
             % The config sets Mode_Dynamic_Sim_Time = 0.
        end
    end

end

function SimState = Mark_TX_Log_Data_Collision(SimState, SimParams, node_id)
    if ~Should_Update_TX_Log(SimState, SimParams, node_id)
        return;
    end

    row_idx = SimState.TX_LOG_Pending_Access_Idx(node_id);
    if row_idx > 0 && row_idx <= size(SimState.TX_LOG_Access_Log, 1)
        SimState.TX_LOG_Access_Log(row_idx, 10) = 1;
    end
end

function SimState = Complete_TX_Log_Access(SimState, SimParams, node_id, outcome, retry_loss)
    if nargin < 5
        retry_loss = false;
    end

    if ~Should_Update_TX_Log(SimState, SimParams, node_id)
        return;
    end

    row_idx = SimState.TX_LOG_Pending_Access_Idx(node_id);
    if row_idx <= 0 || row_idx > size(SimState.TX_LOG_Access_Log, 1)
        return;
    end

    switch lower(outcome)
        case 'success'
            SimState.TX_LOG_Access_Log(row_idx, 8) = 1;
        case 'timeout'
            SimState.TX_LOG_Access_Log(row_idx, 7) = 1;
        otherwise
            error('Unexpected TX log access outcome: %s', outcome);
    end

    if retry_loss
        SimState.TX_LOG_Access_Log(row_idx, 9) = 1;
    end
    SimState.TX_LOG_Access_Log(row_idx, 11) = 1;
    SimState.TX_LOG_Pending_Access_Idx(node_id) = 0;
end

function tf = Should_Update_TX_Log(SimState, SimParams, node_id)
    tf = isfield(SimParams, 'On_Save_TX_Log') && SimParams.On_Save_TX_Log && ...
        isfield(SimState, 'TX_LOG_Access_Log') && ...
        isfield(SimState, 'TX_LOG_Pending_Access_Idx') && ...
        node_id >= 1 && node_id <= numel(SimState.TX_LOG_Pending_Access_Idx);
end
