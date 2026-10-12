function [MAP_LoS, MAP_RSS] = Build_NetworkInfoMaps(AP_Pos, STA_Pos, STA_Type, H_ANT_AP, H_ANT_STA_BatteryLimit, H_ANT_STA_BatteryUnLimit, ...
                                                    TX_Power_AP, TX_Power_STA_BatteryLimit, TX_Power_STA_BatteryUnLimit, AP_STA_Pathloss_Mode)
    if nargin < 10 || isempty(AP_STA_Pathloss_Mode)
        AP_STA_Pathloss_Mode = 1;
    end
    N_AP = size(AP_Pos, 1);
    N_STA = size(STA_Pos, 1);
    N_Node = N_AP + N_STA;

    Node_Pos = [AP_Pos; STA_Pos];
    Node_Type = zeros(1, N_Node);
    Node_Type(1:N_AP) = -1;
    Node_Type(N_AP+1:end) = STA_Type(N_AP+1:N_AP+N_STA);

    MAP_LoS = zeros(N_Node, N_Node);
    MAP_RSS = zeros(N_Node, N_Node);

    for tx = 1:N_Node
        for rx = 1:N_Node
            if tx == rx
                continue;
            end

            [h_tx, p_tx] = Get_Node_Tx_Config(Node_Type(tx), H_ANT_AP, H_ANT_STA_BatteryLimit, H_ANT_STA_BatteryUnLimit, ...
                TX_Power_AP, TX_Power_STA_BatteryLimit, TX_Power_STA_BatteryUnLimit);
            h_rx = Get_Node_Ant_Height(Node_Type(rx), H_ANT_AP, H_ANT_STA_BatteryLimit, H_ANT_STA_BatteryUnLimit);

            MAP_LoS(tx,rx) = Get_LoS(Node_Pos(tx,:), Node_Pos(rx,:), h_tx, h_rx);
            pathloss_mode = Get_Pathloss_Mode(Node_Type(tx), Node_Type(rx), AP_STA_Pathloss_Mode);
            MAP_RSS(tx,rx) = Get_RSS(pathloss_mode, p_tx, MAP_LoS(tx,rx), h_tx, h_rx);
        end
    end
end

function h = Get_Node_Ant_Height(node_type, H_ANT_AP, H_ANT_STA_BatteryLimit, H_ANT_STA_BatteryUnLimit)
    if node_type == -1
        h = H_ANT_AP;
    elseif node_type == 0
        h = H_ANT_STA_BatteryUnLimit;
    else
        h = H_ANT_STA_BatteryLimit;
    end
end

function [h, p] = Get_Node_Tx_Config(node_type, H_ANT_AP, H_ANT_STA_BatteryLimit, H_ANT_STA_BatteryUnLimit, ...
                                     TX_Power_AP, TX_Power_STA_BatteryLimit, TX_Power_STA_BatteryUnLimit)
    h = Get_Node_Ant_Height(node_type, H_ANT_AP, H_ANT_STA_BatteryLimit, H_ANT_STA_BatteryUnLimit);
    if node_type == -1
        p = TX_Power_AP;
    elseif node_type == 0
        p = TX_Power_STA_BatteryUnLimit;
    else
        p = TX_Power_STA_BatteryLimit;
    end
end

function mode = Get_Pathloss_Mode(tx_type, rx_type, AP_STA_Pathloss_Mode)
    if (tx_type == -1 && rx_type ~= -1) || ...
       (tx_type ~= -1 && rx_type == -1)
        mode = AP_STA_Pathloss_Mode;
    else
        mode = 3; % STA <-> STA or AP <-> AP interference
    end
end
