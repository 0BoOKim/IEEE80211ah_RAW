function [MAP_LoS, MAP_RSS] = Build_NetworkInfoMaps(AP_Pos, STA_Pos, STA_Type, H_ANT_AP, H_ANT_STA_BatteryLimit, H_ANT_STA_BatteryUnLimit, ...
                                                    TX_Power_AP, TX_Power_STA_BatteryLimit, TX_Power_STA_BatteryUnLimit)
% 이 함수는 다음과 같은 두 개의 맵을 생성한다.
% (1) MAP_LoS: 송수신 안테나 간의 LoS값 
% (2) MAP_RSS: 송신측(row)에서 전송된 신호가 수신측(col)에서 감쇄된 크기
% (note) row: 송신측, col:수신측

    N_STA = length(STA_Pos);
    N_AP = 1;
    L_MAP = N_STA + N_AP;
    
    MAP_LoS = zeros(L_MAP, L_MAP);
    MAP_RSS = zeros(L_MAP, L_MAP);
    
    STA_Pos = [AP_Pos; STA_Pos];
    % STA_Type = [-1; STA_Type];  % (note) -1 means non-STA device (i.e., AP)
    
    % (note) i is the index for row, and j is the index for column.
    for i = 1:L_MAP
        for j = 1:L_MAP
                      
            if STA_Type(i) == -1 && STA_Type(j) == 0 % is 'i' AP(TX)? and battery-unlimit STA(RX)?
                MAP_LoS(i,j) = Get_LoS(AP_Pos(i,:), STA_Pos(j,:), H_ANT_AP, H_ANT_STA_BatteryUnLimit);
                MAP_RSS(i,j) = Get_RSS(1, TX_Power_AP, MAP_LoS(i,j), H_ANT_AP, H_ANT_STA_BatteryUnLimit);
                
            elseif STA_Type(i) == 0 && STA_Type(j) == -1 % is 'j' AP(RX)? and battery-unlimit STA(TX)?
            
                MAP_LoS(i,j) = Get_LoS(STA_Pos(i,:), AP_Pos(j,:), H_ANT_STA_BatteryUnLimit, H_ANT_AP); 
                MAP_RSS(i,j) = Get_RSS(2, TX_Power_STA_BatteryUnLimit, MAP_LoS(i,j), H_ANT_STA_BatteryUnLimit, H_ANT_AP);
                
            elseif STA_Type(i) == -1 && STA_Type(j) == 1 % is 'i' AP(TX)? and battery-limit STA(RX)?
                MAP_LoS(i,j) = Get_LoS(AP_Pos(i,:), STA_Pos(j,:), H_ANT_AP, H_ANT_STA_BatteryLimit);
                MAP_RSS(i,j) = Get_RSS(1, TX_Power_AP, MAP_LoS(i,j), H_ANT_AP, H_ANT_STA_BatteryLimit);
                
            elseif STA_Type(i) == 1 && STA_Type(j) == -1 % is 'j' AP(RX)? and battery-limit STA(TX)?
            
                MAP_LoS(i,j) = Get_LoS(STA_Pos(i,:), AP_Pos(j,:), H_ANT_STA_BatteryLimit, H_ANT_AP); 
                MAP_RSS(i,j) = Get_RSS(2, TX_Power_STA_BatteryLimit, MAP_LoS(i,j), H_ANT_STA_BatteryLimit, H_ANT_AP);
                
            elseif STA_Type(i) == 0 && STA_Type(j) == 0  % TX: battery-Unlimit STA, RX: battery-UnLimit STA
            
                MAP_LoS(i,j) = Get_LoS(STA_Pos(i,:), STA_Pos(j,:),  H_ANT_STA_BatteryUnLimit, H_ANT_STA_BatteryUnLimit); 
                MAP_RSS(i,j) = Get_RSS(3, TX_Power_STA_BatteryUnLimit, MAP_LoS(i,j), H_ANT_STA_BatteryUnLimit, H_ANT_STA_BatteryUnLimit);
                
            elseif STA_Type(i) == 0 && STA_Type(j) == 1  % TX: battery-Unlimit STA, RX: battery-limit STA
            
                MAP_LoS(i,j) = Get_LoS(STA_Pos(i,:), STA_Pos(j,:),  H_ANT_STA_BatteryUnLimit, H_ANT_STA_BatteryLimit); 
                MAP_RSS(i,j) = Get_RSS(3, TX_Power_STA_BatteryUnLimit, MAP_LoS(i,j), H_ANT_STA_BatteryUnLimit, H_ANT_STA_BatteryLimit);
                
            elseif STA_Type(i) == 1 && STA_Type(j) == 0  % TX: battery-limit STA, RX: battery-Unlimit STA
            
                MAP_LoS(i,j) = Get_LoS(STA_Pos(i,:), STA_Pos(j,:),  H_ANT_STA_BatteryLimit, H_ANT_STA_BatteryUnLimit); 
                MAP_RSS(i,j) = Get_RSS(3, TX_Power_STA_BatteryLimit, MAP_LoS(i,j), H_ANT_STA_BatteryLimit, H_ANT_STA_BatteryUnLimit);
                
            elseif STA_Type(i) == 1 && STA_Type(j) == 1  % TX: battery-limit STA, RX: battery-limit STA
            
                MAP_LoS(i,j) = Get_LoS(STA_Pos(i,:), STA_Pos(j,:),  H_ANT_STA_BatteryLimit, H_ANT_STA_BatteryLimit);
                MAP_RSS(i,j) = Get_RSS(3, TX_Power_STA_BatteryLimit, MAP_LoS(i,j), H_ANT_STA_BatteryLimit, H_ANT_STA_BatteryLimit);
            
            else
                %error('unexpected cases!');
            end
        end
    end


end

