function SimState = ED_Apply_Camera_Deployment(SimState, SimParams)
%ED_APPLY_CAMERA_DEPLOYMENT Place fixed cameras and rebuild radio maps.
%
% Cameras reuse Type-0 STA indices for compatibility with the legacy MAC,
% but their traffic is generated only by ED_Generate_Camera_Traffic.

    cfg = SimParams.ED_Camera;
    camera_ids = Get_Field_Or_Default( ...
        SimParams, 'idx_Camera_STA', zeros(1, 0));
    camera_ids = camera_ids(:).';
    enabled = Get_Field_Or_Default(cfg, 'Enabled', false) && ...
        ~isempty(camera_ids);

    state = struct();
    state.Enabled = enabled;
    state.Node_IDs = camera_ids;
    state.Sector_Index = 1:numel(camera_ids);
    state.Sector_Width_Deg = Safe_Divide(360, numel(camera_ids));
    state.Sector_Boundary_Deg = Get_Field_Or_Default( ...
        cfg, 'SectorBoundaryDeg', 0);
    state.Sector_Center_Deg = zeros(1, numel(camera_ids));
    state.Active_Until_Slot = zeros(1, numel(camera_ids));
    state.Next_Frame_Slot = inf(1, numel(camera_ids));
    state.Active_Intervals = cell(numel(camera_ids), 1);
    state.Activation_Count = zeros(1, numel(camera_ids));
    state.Extension_Count = zeros(1, numel(camera_ids));
    state.Sensor_Trigger_Count = zeros(1, numel(camera_ids));
    state.Generated_Frames = zeros(1, numel(camera_ids));
    state.Generated_Bytes = zeros(1, numel(camera_ids));
    state.Max_Concurrent = 0;
    state.Placement_Radius_m = 0;

    if ~enabled
        SimState.ED_Camera = state;
        return;
    end

    if SimParams.N_AP ~= 1
        error('ED:CameraSingleBSSOnly', ...
            'The camera overload module currently requires N_AP=1.');
    end
    if any(~ismember(camera_ids, SimParams.idx_STA_Type0))
        error('ED:InvalidCameraIDs', ...
            'Camera STA IDs must be reserved Type-0 STA indices.');
    end

    n_camera = numel(camera_ids);
    sector_width = 360 / n_camera;
    centers = mod(state.Sector_Boundary_Deg + ...
        ((1:n_camera) - 0.5) * sector_width, 360);
    radius_factor = Get_Field_Or_Default( ...
        cfg, 'PlacementRadiusFactor', 0.5);
    validateattributes(radius_factor, {'numeric'}, ...
        {'scalar', 'real', 'positive', '<=', 1});
    radius = SimState.STA_Deployment_Radius_m * radius_factor;
    ap_pos = SimState.Node.Pos(SimParams.idx_AP(1), :);
    camera_pos = ap_pos + radius * ...
        [cosd(centers(:)), sind(centers(:))];

    SimState.Node.Pos(camera_ids, :) = camera_pos;
    SimState.Node.Serving_AP(camera_ids) = SimParams.idx_AP(1);
    SimState.Node.BSS_ID(camera_ids) = 1;
    SimState.STA_Min_Separation_Actual_m = Min_Pairwise_Separation( ...
        SimState.Node.Pos(SimParams.idx_STA, :));
    SimState.BSS(1).STA_IDs = find( ...
        SimState.Node.Serving_AP == 1 & SimState.Node.Type ~= -1);
    SimState.BSS(1).BK_STA_IDs = find( ...
        SimState.Node.Serving_AP == 1 & SimState.Node.Type == 0);
    SimState.BSS(1).Alarm_STA_IDs = find( ...
        SimState.Node.Serving_AP == 1 & SimState.Node.Type == 1);

    pathloss_mode = Get_Field_Or_Default( ...
        SimParams, 'AP_STA_Pathloss_Mode', 1);
    [SimState.MAP_LoS, SimState.MAP_RSS] = Build_NetworkInfoMaps( ...
        SimState.Node.Pos(SimParams.idx_AP, :), ...
        SimState.Node.Pos(SimParams.idx_STA, :), ...
        SimState.Node.Type, ...
        SimParams.Ant_Height_AP, SimParams.Ant_Height_STA, ...
        SimParams.Ant_Height_STA, SimParams.TX_Power_AP, ...
        SimParams.TX_Power_STA_Battery_Limit, ...
        SimParams.TX_Power_STA_Battery_NonLimit, pathloss_mode);
    interference_threshold = Get_Field_Or_Default( ...
        SimParams, 'Interference_RSS_Threshold', SimParams.CSTh);
    SimState.Cached_Interferers = Build_Cached_Nodes( ...
        SimState.MAP_RSS, interference_threshold, SimParams.N_Node);
    SimState.Cached_CarrierSenseNodes = Build_Cached_Nodes( ...
        SimState.MAP_RSS, SimParams.CSTh, SimParams.N_Node);

    state.Sector_Center_Deg = centers;
    state.Sector_Width_Deg = sector_width;
    state.Placement_Radius_m = radius;
    state.Position_m = camera_pos;
    state.RSS_To_AP_dBm = arrayfun(@(id) ...
        SimState.MAP_RSS(id, SimParams.idx_AP(1)), camera_ids);
    SimState.ED_Camera = state;
end

function cached = Build_Cached_Nodes(map_rss, threshold, n_node)
    cached = cell(1, n_node);
    for tx_id = 1:n_node
        cached{tx_id} = find( ...
            map_rss(tx_id, :) >= threshold & ...
            map_rss(tx_id, :) ~= Inf & ...
            map_rss(tx_id, :) ~= 0);
    end
end

function min_distance = Min_Pairwise_Separation(positions)
    if size(positions, 1) < 2
        min_distance = inf;
        return;
    end
    min_distance = inf;
    for row = 1:size(positions, 1) - 1
        delta = positions(row + 1:end, :) - positions(row, :);
        min_distance = min(min_distance, min(sqrt(sum(delta.^2, 2))));
    end
end

function value = Safe_Divide(numerator, denominator)
    if denominator == 0
        value = 0;
    else
        value = numerator / denominator;
    end
end

function value = Get_Field_Or_Default(S, field_name, default_value)
    if isfield(S, field_name) && ~isempty(S.(field_name))
        value = S.(field_name);
    else
        value = default_value;
    end
end
