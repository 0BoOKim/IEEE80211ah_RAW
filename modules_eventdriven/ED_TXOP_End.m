function SimState = ED_TXOP_End( ...
    SimState, node_id, reason, reset_contention)
%ED_TXOP_END Release one active TXOP and optionally draw a new backoff.

    if ~SimState.ED_TXOP.Active(node_id)
        return;
    end

    if strcmp(reason, 'abort')
        SimState.ED_TXOP.Aborted(node_id) = ...
            SimState.ED_TXOP.Aborted(node_id) + 1;
    elseif strcmp(reason, 'limit')
        SimState.ED_TXOP.Completed(node_id) = ...
            SimState.ED_TXOP.Completed(node_id) + 1;
        SimState.ED_TXOP.LimitStops(node_id) = ...
            SimState.ED_TXOP.LimitStops(node_id) + 1;
    elseif strcmp(reason, 'complete')
        SimState.ED_TXOP.Completed(node_id) = ...
            SimState.ED_TXOP.Completed(node_id) + 1;
    else
        error('ED:InvalidTXOPEndReason', ...
            'Unknown TXOP end reason: %s', reason);
    end

    SimState.ED_TXOP.Active(node_id) = false;
    SimState.ED_TXOP.StartSlot(node_id) = -1;
    SimState.ED_TXOP.EndSlot(node_id) = -1;
    SimState.ED_TXOP.RAWEndSlot(node_id) = -1;
    SimState.ED_TXOP.AcquisitionRAWEndSlot(node_id) = -1;
    SimState.ED_TXOP.PeriodEndSlot(node_id) = -1;
    SimState.ED_TXOP.NextDataSlot(node_id) = inf;
    SimState.ED_TXOP.MPDUsInCurrent(node_id) = 0;
    SimState.ED_TXOP.ReservationEstablished(node_id) = false;

    if reset_contention
        if strcmp(reason, 'abort')
            SimState.Node.aifs(node_id) = ...
                SimState.Node.Init_aifs(node_id);
            SimState.Node.bc(node_id) = ceil( ...
                rand * SimState.Node.CW(node_id));
        else
            SimState = ED_Reset_Contention_After_Success( ...
                SimState, node_id);
        end
    end
end
