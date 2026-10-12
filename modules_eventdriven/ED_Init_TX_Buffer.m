function Buffer = ED_Init_TX_Buffer(Buffer, initial_capacity)
%ED_INIT_TX_BUFFER Initialize event-driven circular MPDU and ACK queues.

    if nargin < 2 || isempty(initial_capacity)
        initial_capacity = 64;
    end
    initial_capacity = max(1, round(initial_capacity));

    Buffer.ED_MPDU_Data = zeros(initial_capacity, 3);
    Buffer.ED_MPDU_Head = 1;
    Buffer.ED_MPDU_Count = 0;
    Buffer.ED_ACK_Data = zeros(max(8, ceil(initial_capacity / 4)), 5);
    Buffer.ED_ACK_Head = 1;
    Buffer.ED_ACK_Count = 0;
    Buffer.Length = 0;
    Buffer.ACK_Length = 0;
    Buffer.MPDU = zeros(0, 3);
    Buffer.ACK = zeros(0, 5);
end
