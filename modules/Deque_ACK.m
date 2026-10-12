function [TX_Buffer] = Deque_ACK(TX_Buffer)
%UNTITLED4 이 함수의 요약 설명 위치
%   자세한 설명 위치
    TX_Buffer.ACK(1, :) = [];
    TX_Buffer.ACK_Length  = TX_Buffer.ACK_Length - 1;
end

