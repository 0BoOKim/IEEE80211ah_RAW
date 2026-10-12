function [LoS Dist] = Get_LoS(TX_Pos, RX_Pos, H_TX_ANT, H_RX_ANT)
% 이 함수는 송수신기의 위치와 안테나의 높이에 따라 LoS(안테나 간의 직선 거리)와 송수신기 간의 직선 거리를 계산함.
% 자세한 설명 위치

Dist = sqrt( (TX_Pos(1)-RX_Pos(1))^2 + (TX_Pos(2)-RX_Pos(2))^2 );
LoS = sqrt( (H_TX_ANT-H_RX_ANT)^2 + Dist^2 );

end

