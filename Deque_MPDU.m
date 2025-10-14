function [TX_Buffer] = Deque_MPDU(TX_Buffer)
%UNTITLED3 이 함수의 요약 설명 위치
%   자세한 설명 위치
    TX_Buffer.MPDU(1, :) = [];
    TX_Buffer.Length  = TX_Buffer.Length - 1;

end

