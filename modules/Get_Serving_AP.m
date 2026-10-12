function Serving_AP = Get_Serving_AP(STA_Pos, AP_Pos, SimParams)
    mode = 'nearest-ap';
    if isfield(SimParams, 'STA_Association_Mode') && ~isempty(SimParams.STA_Association_Mode)
        mode = lower(SimParams.STA_Association_Mode);
    end

    switch mode
        case 'nearest-ap'
            dist2 = sum((AP_Pos - STA_Pos).^2, 2);
            [~, Serving_AP] = min(dist2);

        otherwise
            error('Unsupported STA_Association_Mode: %s', SimParams.STA_Association_Mode);
    end
end
