function BusyCount = ED_Channel_Busy_Count( ...
    Channel, first_slot, last_slot, node_ids)
%ED_CHANNEL_BUSY_COUNT Count busy slots for each requested node.

    node_ids = node_ids(:).';
    if last_slot < first_slot
        BusyCount = zeros(1, numel(node_ids));
        return;
    end

    interval = last_slot - first_slot + 1;
    aligned_bucket = interval == Channel.MeasureInterval && ...
        mod(first_slot - 1, Channel.MeasureInterval) == 0;

    if aligned_bucket
        bucket_id = floor((first_slot - 1) / Channel.MeasureInterval);
        bucket_row = mod(bucket_id, Channel.BucketCapacity) + 1;
        if Channel.BucketTag(bucket_row) == bucket_id
            BusyCount = double(Channel.BucketBusyCount(bucket_row, node_ids));
        else
            BusyCount = zeros(1, numel(node_ids));
        end
        return;
    end

    if interval > Channel.RingLength
        error('ED:ChannelHistoryExpired', ...
            ['Requested channel interval has %d slots, but the circular ' ...
             'history stores only %d slots.'], interval, Channel.RingLength);
    end
    State = ED_Channel_Get(Channel, first_slot:last_slot, node_ids);
    BusyCount = sum(State > 0, 1);
end
