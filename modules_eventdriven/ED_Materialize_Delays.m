function SimState = ED_Materialize_Delays(SimState)
%ED_MATERIALIZE_DELAYS Expose event-driven delay logs to legacy summaries.

    for node_id = 1:numel(SimState.Delay)
        count = SimState.Delay(node_id).ED_Count;
        SimState.Delay(node_id).delay = ...
            SimState.Delay(node_id).ED_Data(1:count, :);
    end
end
