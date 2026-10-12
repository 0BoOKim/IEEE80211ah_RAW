function [Buffer, GID] = ED_Enqueue_MPDU( ...
    Buffer, GID, mpdu_bytes, generated_slot)
%ED_ENQUEUE_MPDU Append one MPDU to the event-driven circular queue.

    GID = GID + 1;
    Buffer = Ensure_MPDU_Capacity(Buffer);
    capacity = size(Buffer.ED_MPDU_Data, 1);
    tail = mod(Buffer.ED_MPDU_Head + Buffer.ED_MPDU_Count - 1, ...
        capacity) + 1;
    Buffer.ED_MPDU_Data(tail, :) = ...
        [GID, mpdu_bytes, generated_slot];
    Buffer.ED_MPDU_Count = Buffer.ED_MPDU_Count + 1;
    Buffer.Length = Buffer.ED_MPDU_Count;
end

function Buffer = Ensure_MPDU_Capacity(Buffer)
    count = Buffer.ED_MPDU_Count;
    capacity = size(Buffer.ED_MPDU_Data, 1);
    if count < capacity
        return;
    end

    new_data = zeros(max(1, 2 * capacity), 3);
    indices = mod(Buffer.ED_MPDU_Head - 1 + (0:count - 1), ...
        capacity) + 1;
    new_data(1:count, :) = Buffer.ED_MPDU_Data(indices, :);
    Buffer.ED_MPDU_Data = new_data;
    Buffer.ED_MPDU_Head = 1;
end
