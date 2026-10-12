function SimState = ED_Record_TXOP_Reservation_Starts( ...
    SimState, ~, start_tx_nodes)
%ED_RECORD_TXOP_RESERVATION_STARTS Count foreign starts inside active TXOPs.

    if isempty(start_tx_nodes) || ~isfield(SimState, 'ED_TXOP')
        return;
    end

    now_slot = SimState.Time;
    holders = find(SimState.ED_TXOP.Active & ...
        SimState.ED_TXOP.ReservationEstablished & ...
        SimState.ED_TXOP.StartSlot < now_slot & ...
        SimState.ED_TXOP.EndSlot >= now_slot);
    for holder = holders
        holder_ap = SimState.Node.Serving_AP(holder);
        holder_cs = SimState.Cached_CarrierSenseNodes{holder};
        ap_cs = SimState.Cached_CarrierSenseNodes{holder_ap};

        for tx_id = start_tx_nodes
            is_ack = SimState.tx_status(tx_id, 5) == 1;
            destination = SimState.tx_status(tx_id, 3);
            is_holder_data = ~is_ack && tx_id == holder;
            is_holder_ack = is_ack && tx_id == holder_ap && ...
                destination == holder;
            if is_holder_data || is_holder_ack
                continue;
            end

            SimState.ED_TXOP.ReservationForeignStarts(holder) = ...
                SimState.ED_TXOP.ReservationForeignStarts(holder) + 1;
            if is_ack
                SimState.ED_TXOP.ReservationForeignACKStarts(holder) = ...
                    SimState.ED_TXOP.ReservationForeignACKStarts(holder) + 1;
                continue;
            end

            SimState.ED_TXOP.ReservationForeignDataStarts(holder) = ...
                SimState.ED_TXOP.ReservationForeignDataStarts(holder) + 1;
            can_sense_exchange = ismember(tx_id, holder_cs) || ...
                ismember(tx_id, ap_cs);
            if can_sense_exchange
                field_name = 'ReservationSensedDataStarts';
            else
                field_name = 'ReservationHiddenDataStarts';
            end
            SimState.ED_TXOP.(field_name)(holder) = ...
                SimState.ED_TXOP.(field_name)(holder) + 1;
            if SimState.tx_status(tx_id, 4) > 0
                SimState.ED_TXOP.ReservationCollidedDataStarts(holder) = ...
                    SimState.ED_TXOP.ReservationCollidedDataStarts(holder) + 1;
            end
        end
    end
end
