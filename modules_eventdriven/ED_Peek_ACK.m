function ACK = ED_Peek_ACK(Buffer)
%ED_PEEK_ACK Return the oldest ACK without removing it.

    if Buffer.ED_ACK_Count <= 0
        error('ED:EmptyACKQueue', 'Cannot read an empty ACK queue.');
    end
    ACK = Buffer.ED_ACK_Data(Buffer.ED_ACK_Head, :);
end
