function Channel = ED_Channel_Init(n_node, ring_length, measure_interval)
%ED_CHANNEL_INIT Initialize bounded channel history and measurement buckets.

    validateattributes(n_node, {'numeric'}, {'scalar', 'integer', 'positive'});
    validateattributes(ring_length, {'numeric'}, {'scalar', 'integer', 'positive'});
    validateattributes(measure_interval, {'numeric'}, ...
        {'scalar', 'integer', 'positive'});

    Channel.RingLength = ring_length;
    Channel.NNode = n_node;
    Channel.State = zeros(ring_length, n_node, 'uint8');
    Channel.SlotTag = -ones(ring_length, 1);

    Channel.MeasureInterval = measure_interval;
    Channel.BucketCapacity = max(4, ceil(ring_length / measure_interval) + 4);
    Channel.BucketTag = -ones(Channel.BucketCapacity, 1);
    Channel.BucketBusyCount = zeros( ...
        Channel.BucketCapacity, n_node, 'uint32');
end
