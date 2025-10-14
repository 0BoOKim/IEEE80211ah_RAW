function [TX_Buffer GID] = Reset_GID(TX_Buffer, GID)
%UNTITLED7 이 함수의 요약 설명 위치
%   자세한 설명 위치
    GID = GID + 1;
    TX_Buffer.MPDU(1, 1) = GID;
    
end

