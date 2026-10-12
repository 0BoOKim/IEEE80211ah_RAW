function AP_Pos = Build_BSS_Grid_AP_Pos(N_AP, TX_Radius_AP, SimParams)
    if isfield(SimParams, 'BSS_AP_Pos') && ~isempty(SimParams.BSS_AP_Pos)
        AP_Pos = SimParams.BSS_AP_Pos;
        if size(AP_Pos, 1) ~= N_AP || size(AP_Pos, 2) ~= 2
            error('BSS_AP_Pos must be N_AP-by-2.');
        end
        return;
    end

    if isfield(SimParams, 'BSS_AP_Grid_Dim') && ~isempty(SimParams.BSS_AP_Grid_Dim)
        n_row = SimParams.BSS_AP_Grid_Dim(1);
        n_col = SimParams.BSS_AP_Grid_Dim(2);
        if n_row * n_col < N_AP
            error('BSS_AP_Grid_Dim must have at least N_AP grid points.');
        end
    else
        n_col = ceil(sqrt(N_AP));
        n_row = ceil(N_AP / n_col);
    end

    if isfield(SimParams, 'BSS_AP_Spacing') && ~isempty(SimParams.BSS_AP_Spacing)
        spacing = SimParams.BSS_AP_Spacing;
    else
        spacing = TX_Radius_AP * SimParams.BSS_AP_Spacing_Factor;
    end

    AP_Pos = zeros(N_AP, 2);
    base_pos = [TX_Radius_AP, TX_Radius_AP];
    idx = 0;
    for r = 1:n_row
        for c = 1:n_col
            idx = idx + 1;
            if idx > N_AP
                return;
            end
            AP_Pos(idx,:) = base_pos + [(c-1)*spacing, (r-1)*spacing];
        end
    end
end
