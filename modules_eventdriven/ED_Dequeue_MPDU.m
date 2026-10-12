function Buffer = ED_Dequeue_MPDU(Buffer)
%ED_DEQUEUE_MPDU Remove the oldest event-driven MPDU in O(1) time.

    if Buffer.ED_MPDU_Count <= 0
        error('ED:EmptyMPDUQueue', 'Cannot dequeue an empty MPDU queue.');
    end
    capacity = size(Buffer.ED_MPDU_Data, 1);
    Buffer.ED_MPDU_Head = mod(Buffer.ED_MPDU_Head, capacity) + 1;
    Buffer.ED_MPDU_Count = Buffer.ED_MPDU_Count - 1;
    Buffer.Length = Buffer.ED_MPDU_Count;
    if Buffer.ED_MPDU_Count == 0
        Buffer.ED_MPDU_Head = 1;
    end
end
