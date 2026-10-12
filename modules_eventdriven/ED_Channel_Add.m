function Channel = ED_Channel_Add(Channel, first_slot, last_slot, node_ids, value)
%ED_CHANNEL_ADD Add TX/CS state over a short future interval.

    if last_slot < first_slot || isempty(node_ids)
        return;
    end
    if last_slot - first_slot + 1 > Channel.RingLength
        error('ED:ChannelIntervalTooLong', ...
            'A channel-state interval cannot exceed the circular buffer length.');
    end

    node_ids = unique(node_ids(:).', 'stable');
    slots = first_slot:last_slot;
    for slot = slots
        row = mod(slot - 1, Channel.RingLength) + 1;
        if Channel.SlotTag(row) ~= slot
            Channel.State(row, :) = 0;
            Channel.SlotTag(row) = slot;
        end

        was_idle = Channel.State(row, node_ids) == 0;
        Channel.State(row, node_ids) = ...
            Channel.State(row, node_ids) + uint8(value);

        newly_busy_nodes = node_ids(was_idle);
        if ~isempty(newly_busy_nodes)
            bucket_id = floor((slot - 1) / Channel.MeasureInterval);
            bucket_row = mod(bucket_id, Channel.BucketCapacity) + 1;
            if Channel.BucketTag(bucket_row) ~= bucket_id
                Channel.BucketBusyCount(bucket_row, :) = 0;
                Channel.BucketTag(bucket_row) = bucket_id;
            end
            Channel.BucketBusyCount(bucket_row, newly_busy_nodes) = ...
                Channel.BucketBusyCount(bucket_row, newly_busy_nodes) + 1;
        end
    end
end
