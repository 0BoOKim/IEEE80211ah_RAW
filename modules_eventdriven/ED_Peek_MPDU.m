function MPDU = ED_Peek_MPDU(Buffer)
%ED_PEEK_MPDU Return the oldest MPDU without removing it.

    if Buffer.ED_MPDU_Count <= 0
        error('ED:EmptyMPDUQueue', 'Cannot read an empty MPDU queue.');
    end
    MPDU = Buffer.ED_MPDU_Data(Buffer.ED_MPDU_Head, :);
end
