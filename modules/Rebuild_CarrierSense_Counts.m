function n_txnode = Rebuild_CarrierSense_Counts(SimState, SimParams)
    % Derive carrier-sense occupancy from the authoritative TX status.

    n_txnode = zeros(1, SimParams.N_Node);
    active_tx = find(SimState.tx_status(:,1) ~= -1).';

    for tx_id = active_tx
        if isfield(SimState, 'Cached_CarrierSenseNodes')
            cs_nodes = SimState.Cached_CarrierSenseNodes{tx_id};
        else
            rss = SimState.MAP_RSS(tx_id,:);
            cs_nodes = find( ...
                rss >= SimParams.CSTh & isfinite(rss) & rss ~= 0);
        end

        if ~isempty(cs_nodes)
            n_txnode(cs_nodes) = n_txnode(cs_nodes) + 1;
        end
    end
end
