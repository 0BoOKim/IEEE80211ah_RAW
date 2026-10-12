function [Buffer, GID] = ED_Enqueue_ACK( ...
    Buffer, GID, source_gid, source_id, ack_bytes, generated_slot)
%ED_ENQUEUE_ACK Append one ACK to the event-driven circular queue.

    GID = GID + 1;
    Buffer = Ensure_ACK_Capacity(Buffer);
    capacity = size(Buffer.ED_ACK_Data, 1);
    tail = mod(Buffer.ED_ACK_Head + Buffer.ED_ACK_Count - 1, ...
        capacity) + 1;
    Buffer.ED_ACK_Data(tail, :) = ...
        [GID, source_gid, source_id, ack_bytes, generated_slot];
    Buffer.ED_ACK_Count = Buffer.ED_ACK_Count + 1;
    Buffer.ACK_Length = Buffer.ED_ACK_Count;
end

function Buffer = Ensure_ACK_Capacity(Buffer)
    count = Buffer.ED_ACK_Count;
    capacity = size(Buffer.ED_ACK_Data, 1);
    if count < capacity
        return;
    end

    new_data = zeros(max(1, 2 * capacity), 5);
    indices = mod(Buffer.ED_ACK_Head - 1 + (0:count - 1), ...
        capacity) + 1;
    new_data(1:count, :) = Buffer.ED_ACK_Data(indices, :);
    Buffer.ED_ACK_Data = new_data;
    Buffer.ED_ACK_Head = 1;
end
