function [TX_Buffer GID] = Enque_MPDU(TX_Buffer, GID, L_MPDU, GenTime)
    GID = GID + 1;
    TX_Buffer.Length = TX_Buffer.Length + 1;
    TX_Buffer.MPDU = [ TX_Buffer.MPDU; GID L_MPDU GenTime];
end

