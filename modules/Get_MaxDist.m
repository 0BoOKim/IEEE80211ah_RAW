function [MaxDist, MaxLoS] = Get_MaxDist(Mode_Pathloss, H_TX_ANT, H_RX_ANT, TX_Power, RSS_Threshold)
% Get_Max_Dist() 함수는 AH-STA 및 AH-AP의 최대 전송 거리를 구하는 함수이다.
% 입력: pathloss model 유형, 송/수신 안테나 높이, 전송 전력, 안테나 게인, 기준 CSTh
% 처리: pathloss model 유형 및 다른 입력 파라미터에 따라 CSTh을 만족하는 거리 값 계산
% 출력: CSTh을 만족하는 거리 값 및 LoS  

% Mode_Pathloss
% 1: Pathloss Model I)  Macro deployment (AP -> STA)
% 2: Pathloss Model II)  Pico deployment (STA -> AP)
% 3: Pathloss Model III)  Outdoor Device to Device Pathloss model (STA <-> STA)

    Gtx = 0;   % TX antenna gain (dBi)
    Grx = 0;   % RX antenna gain (Prototype: 0 dBi, ideal: 3 dBi)
    Ltx = 0;   % system loss at TX (dBi)
    Lrx = 0;   % system loss at RX (dBi) 

    if Mode_Pathloss == 1
        pathloss_offset = 8;
        pathloss_slope = 36.7;
    elseif Mode_Pathloss == 2
        pathloss_offset = 23.3;
        pathloss_slope = 36.7;
    elseif Mode_Pathloss == 3
        pathloss_offset = -6.17;
        pathloss_slope = 58.6;
    else
        error('Unsupported path-loss mode: %d', Mode_Pathloss);
    end        

    max_pathloss = TX_Power + Gtx - Ltx + Grx - Lrx - RSS_Threshold;
    MaxLoS = 10.^((max_pathloss - pathloss_offset) / pathloss_slope);
    height_delta = abs(H_TX_ANT - H_RX_ANT);
    MaxDist = sqrt(max(0, MaxLoS.^2 - height_delta.^2));

end

