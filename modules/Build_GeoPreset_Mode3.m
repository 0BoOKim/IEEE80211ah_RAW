function GeoPreset = Build_GeoPreset_Mode3(Node_Pos, idx_AP, idx_STA_Type1, ScenarioName)
    % Scenario presets for geo-aware activation ordering (Traffic_Surge_Mode == 3).
    % Fields:
    %   Name, Seed_Coords(Kx2), Dominant_Direction(1x2), Anisotropy_A, Anisotropy_B, Jitter_Sigma

    AP_Pos = Node_Pos(idx_AP(1), :);
    Alarm_Pos = Node_Pos(idx_STA_Type1, :);
    if isempty(Alarm_Pos)
        R = 1.0;
    else
        R = max(sqrt(sum((Alarm_Pos - AP_Pos).^2, 2)));
        if R <= 0
            R = 1.0;
        end
    end

    make_seed = @(rx, ry) AP_Pos + [rx ry] .* R;
    key = lower(strtrim(ScenarioName));

    GeoPreset.Name = key;
    GeoPreset.Jitter_Sigma = 1e-6;

    switch key
        case {'center-isotropic', 'center_isotropic'}
            % Center ignition with an isotropic circular front.
            GeoPreset.Name = 'center-isotropic';
            GeoPreset.Seed_Coords = AP_Pos;
            GeoPreset.Dominant_Direction = [1.0 0.0];
            GeoPreset.Anisotropy_A = 1.0;
            GeoPreset.Anisotropy_B = 1.0;

        case {'center-directional', 'center_directional'}
            % Center ignition with a wind-driven front toward the northeast.
            GeoPreset.Name = 'center-directional';
            GeoPreset.Seed_Coords = AP_Pos;
            GeoPreset.Dominant_Direction = [1.0 1.0];
            GeoPreset.Anisotropy_A = 3.0;
            GeoPreset.Anisotropy_B = 1.0;

        case {'edge-isotropic', 'edge_isotropic'}
            % Edge ignition with an isotropic front entering the BSS area.
            GeoPreset.Name = 'edge-isotropic';
            GeoPreset.Seed_Coords = make_seed(-0.75, 0.00);
            GeoPreset.Dominant_Direction = [1.0 0.0];
            GeoPreset.Anisotropy_A = 1.0;
            GeoPreset.Anisotropy_B = 1.0;

        case {'edge-directional', 'edge_directional'}
            % Edge ignition with a strongly directional inward front.
            GeoPreset.Name = 'edge-directional';
            GeoPreset.Seed_Coords = make_seed(-0.75, 0.00);
            GeoPreset.Dominant_Direction = [1.0 0.0];
            GeoPreset.Anisotropy_A = 3.0;
            GeoPreset.Anisotropy_B = 1.0;

        case 'wildfire'
            % Wind-biased front spread from an off-center ignition point.
            GeoPreset.Seed_Coords = make_seed(-0.70, -0.20);
            GeoPreset.Dominant_Direction = [1.0 0.4];
            GeoPreset.Anisotropy_A = 2.2;
            GeoPreset.Anisotropy_B = 1.0;

        case 'flood'
            % 1D corridor propagation from upstream to downstream.
            GeoPreset.Seed_Coords = make_seed(-0.95, 0.00);
            GeoPreset.Dominant_Direction = [1.0 0.0];
            GeoPreset.Anisotropy_A = 3.0;
            GeoPreset.Anisotropy_B = 1.0;

        case 'plume'
            % Advection-diffusion plume with strong downwind preference.
            GeoPreset.Seed_Coords = make_seed(-0.85, 0.15);
            GeoPreset.Dominant_Direction = [1.0 0.2];
            GeoPreset.Anisotropy_A = 2.6;
            GeoPreset.Anisotropy_B = 1.0;

        case 'debris'
            % Abrupt downslope-type activation from upper area.
            GeoPreset.Seed_Coords = make_seed(0.15, 0.95);
            GeoPreset.Dominant_Direction = [0.2 -1.0];
            GeoPreset.Anisotropy_A = 2.0;
            GeoPreset.Anisotropy_B = 1.0;

        case {'multi-source', 'multisource', 'multi_source'}
            % Two independent seeds (NaTech/domino-like mixture).
            GeoPreset.Name = 'multi-source';
            GeoPreset.Seed_Coords = [make_seed(-0.80, -0.55); make_seed(0.75, 0.50)];
            GeoPreset.Dominant_Direction = [1.0 0.0];
            GeoPreset.Anisotropy_A = 1.8;
            GeoPreset.Anisotropy_B = 1.0;

        otherwise
            error('Unknown Geo scenario preset: %s', ScenarioName);
    end
end
