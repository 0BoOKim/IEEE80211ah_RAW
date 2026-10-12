function [Buffer, GID] = ED_Reset_MPDU_GID(Buffer, GID)
%ED_RESET_MPDU_GID Give the head MPDU a new identifier before retry.

    if Buffer.ED_MPDU_Count <= 0
        error('ED:EmptyMPDUQueue', 'Cannot reset GID on an empty MPDU queue.');
    end
    GID = GID + 1;
    Buffer.ED_MPDU_Data(Buffer.ED_MPDU_Head, 1) = GID;
end
