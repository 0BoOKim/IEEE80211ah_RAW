function [TX_Buffer_AP GID] = Enque_ACK(TX_Buffer_AP, GID, GID_Src, Src_ID, L_ack, GenTime)
% AP의 전송 버퍼에 ACK를 인큐잉함.
% GID: Global ID of ACK
% GID_Src: Global ID of Received MPDU from Source node.
% Src_ID: AID of Source Node
% L_ack: Length of Ack Frame in Bytes
% GenTime: ACK Generated Time in Slot

    GID = GID + 1;
    TX_Buffer_AP.ACK_Length = TX_Buffer_AP.ACK_Length + 1;
    TX_Buffer_AP.ACK = [ TX_Buffer_AP.ACK; GID GID_Src Src_ID L_ack GenTime];

end

