function [R_Suc] = Calc_SucRatio(Node_ID, NetCongestionMeasure)
    L = size(NetCongestionMeasure(Node_ID).N_Acc, 1);
    % 초기 상태를 고려하여, 행을 기준으로 길이를 얻도록 변경할 것
    % --> length 대시 size() 사용
    
    N_Acc = NetCongestionMeasure(Node_ID).N_Acc(L,2);
    N_Suc = NetCongestionMeasure(Node_ID).N_Suc(L,2);
    R_Suc = N_Suc/N_Acc;
    
    % 최초에는 NetCongestionMeasure가 없으므로 예외처리 필요-->ㅡMain에서 처리함 
    
end

