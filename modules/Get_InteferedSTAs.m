function [Idx_IntfSTA, Idx_IntfAP] = Get_InteferedSTAs(MAP_RSS, Idx_TX_STA, CSTh, N_AP)

    % MAP_RSS(tx, rx) is the received signal strength at rx from tx.
    % Therefore, a transmitter's affected receivers are in its row.
    Idx_IntfSTA = find( MAP_RSS(Idx_TX_STA,:) >= CSTh ...
                        & MAP_RSS(Idx_TX_STA,:) ~= Inf ...
                        & MAP_RSS(Idx_TX_STA,:) ~= 0).';
    Idx_IntfAP = Idx_IntfSTA(Idx_IntfSTA <= N_AP); 
%     if ~isemty(Idx_IntfAP)
%         Idx_IntfSTA(Idx_IntfSTA== Idx_IntfAP) = [];  
%     end
%     Idx_IntfSTA = Idx_IntfSTA - N_AP;
end

