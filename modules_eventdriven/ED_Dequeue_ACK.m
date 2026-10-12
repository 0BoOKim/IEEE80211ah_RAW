function Buffer = ED_Dequeue_ACK(Buffer)
%ED_DEQUEUE_ACK Remove the oldest event-driven ACK in O(1) time.

    if Buffer.ED_ACK_Count <= 0
        error('ED:EmptyACKQueue', 'Cannot dequeue an empty ACK queue.');
    end
    capacity = size(Buffer.ED_ACK_Data, 1);
    Buffer.ED_ACK_Head = mod(Buffer.ED_ACK_Head, capacity) + 1;
    Buffer.ED_ACK_Count = Buffer.ED_ACK_Count - 1;
    Buffer.ACK_Length = Buffer.ED_ACK_Count;
    if Buffer.ED_ACK_Count == 0
        Buffer.ED_ACK_Head = 1;
    end
end
