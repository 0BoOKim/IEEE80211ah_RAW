function State = ED_Channel_Get(Channel, slots, node_ids)
%ED_CHANNEL_GET Read absolute slots from circular history.

    slots = slots(:);
    node_ids = node_ids(:).';
    State = zeros(numel(slots), numel(node_ids), 'uint8');

    for k = 1:numel(slots)
        row = mod(slots(k) - 1, Channel.RingLength) + 1;
        if Channel.SlotTag(row) == slots(k)
            State(k, :) = Channel.State(row, node_ids);
        end
    end
end
