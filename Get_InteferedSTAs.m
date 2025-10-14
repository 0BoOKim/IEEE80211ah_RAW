function [Idx_IntfSTA, Idx_IntfAP] = Get_InteferedSTAs(MAP_RSS, Idx_TX_STA, CSTh, N_AP)

    Idx_IntfSTA = find( MAP_RSS(:,Idx_TX_STA) >= CSTh ...
                        & MAP_RSS(:,Idx_TX_STA) ~= Inf ...
                        & MAP_RSS(:,Idx_TX_STA) ~= 0);
    Idx_IntfAP = Idx_IntfSTA(Idx_IntfSTA <= N_AP); 
%     if ~isemty(Idx_IntfAP)
%         Idx_IntfSTA(Idx_IntfSTA== Idx_IntfAP) = [];  
%     end
%     Idx_IntfSTA = Idx_IntfSTA - N_AP;
end

