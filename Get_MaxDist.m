function [MaxDist MaxLoS] = Get_MaxDist(Mode_Pathloss, H_TX_ANT, H_RX_ANT,TX_Power, CSTh)
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

    List_Dist = 0:0.01:500; 
    List_LoS  = sqrt((H_TX_ANT-H_RX_ANT)^2 + List_Dist.^2);

    if Mode_Pathloss == 1

        PL_mcr = 8 + 36.7*log10(List_LoS);
        Prx_mcr = TX_Power + Gtx - Ltx - PL_mcr + Grx - Lrx;
        Idx_MaxLoS = find(Prx_mcr < CSTh, 1, 'first'); 
        
    elseif Mode_Pathloss == 2

        PL_pc = 23.3 + 36.7*log10(List_LoS);
        Prx_pc = TX_Power + Gtx - Ltx - PL_pc + Grx - Lrx; 
        Idx_MaxLoS = find(Prx_pc < CSTh, 1, 'first');
        
    elseif Mode_Pathloss == 3
        
        PL_od =  -6.17 + 58.6*log10(List_LoS);  
        Prx_od = TX_Power + Gtx - Ltx - PL_od + Grx - Lrx;
        Idx_MaxLoS = find(Prx_od < CSTh, 1, 'first');
    end        

    MaxDist = List_Dist(Idx_MaxLoS);
    MaxLoS = List_LoS(Idx_MaxLoS);

end

