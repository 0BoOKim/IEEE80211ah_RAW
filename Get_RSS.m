function [RSS] = Get_RSS(Mode_Pathloss, TX_Power, LoS, H_ANT_AP, H_ANT_STA)
% 이 함수는 전송 신호 전력과 LoS를 입력 받아 신호 감쇄 모델의 유형에 따라 
% 수신측에서 감쇄된 신호의 크기 RSS(Received Signal Strength)를 반환함.

    Gtx = 0;   % TX antenna gain (dBi)
    Grx = 0;   % RX antenna gain (Prototype: 0 dBi, ideal: 3 dBi)
    Ltx = 0;   % system loss at TX (dBi)
    Lrx = 0;   % system loss at RX (dBi) 

    if Mode_Pathloss == 1       % Pathloss Model I)  Macro deployment (AP -> STA)

        PL_mcr = 8 + 36.7*log10(LoS);
        RSS = TX_Power + Gtx - Ltx - PL_mcr + Grx - Lrx;
       
        
    elseif Mode_Pathloss == 2   % Pathloss Model II)  Pico deployment (STA -> AP)

        PL_pc = 23.3 + 36.7*log10(LoS);
        RSS = TX_Power + Gtx - Ltx - PL_pc + Grx - Lrx; 
        
        
    elseif Mode_Pathloss == 3   % Pathloss Model III)  Outdoor Device to Device Pathloss model (STA <-> STA)
        
        PL_od =  -6.17 + 58.6*log10(LoS);  
        RSS = TX_Power + Gtx - Ltx - PL_od + Grx - Lrx;
        
    else
        error('Unexpected pathloss mode!');
    end      


end

