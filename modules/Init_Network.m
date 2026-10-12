function SimState = Init_Network(SimParams)

    rng(SimParams.PNRG_Seed1);

    N_AP = SimParams.N_AP;
    N_Node = SimParams.N_Node;
    N_bkSTA = SimParams.N_bkSTA;

    % Initialize Nodes
    Node.Pos = zeros(N_Node, 2);
    Node.Type = zeros(1, N_Node);
    Node.ACK_Timer = zeros(N_Node, 2);
    Node.BSS_ID = zeros(1, N_Node);
    Node.Serving_AP = zeros(1, N_Node);

    pathloss_mode = Get_Field_Or_Default(SimParams, 'AP_STA_Pathloss_Mode', 1);
    rx_sensitivity = Get_Field_Or_Default(SimParams, 'RX_Sensitivity', SimParams.CSTh);
    deployment_radius_factor = Get_Field_Or_Default( ...
        SimParams, 'STA_Deployment_Radius_Factor', 1.0);
    min_sta_separation = Get_Field_Or_Default( ...
        SimParams, 'STA_Min_Separation_m', 0.0);

    TX_Radius_AP = Get_MaxDist(pathloss_mode, ...
        SimParams.Ant_Height_AP, SimParams.Ant_Height_STA, ...
        SimParams.TX_Power_AP, rx_sensitivity);
    TX_Radius_STA = Get_MaxDist(pathloss_mode, ...
        SimParams.Ant_Height_STA, SimParams.Ant_Height_AP, ...
        SimParams.TX_Power_STA_Battery_Limit, rx_sensitivity);
    STA_Deployment_Radius = min(TX_Radius_AP, TX_Radius_STA) * ...
        deployment_radius_factor;

    % AP Setup
    AP_Pos = Build_BSS_Grid_AP_Pos(SimParams.N_AP, TX_Radius_AP, SimParams);
    for i = 1:N_AP
        Node.Pos(i,:) = AP_Pos(i,:);
        Node.Type(i) = -1;
        Node.ACK_Timer(i,:) = [-1 -1];
        Node.BSS_ID(i) = i;
        Node.Serving_AP(i) = i;
    end

    idx_bk = N_AP+1:N_AP+N_bkSTA;
    idx_alarm = N_AP+N_bkSTA+1:N_Node;
    Node.Type(idx_bk) = 0;
    Node.Type(idx_alarm) = 1;

    uses_mode3_reference = SimParams.Traffic_Surge_Mode == 3 && ...
        isfield(SimParams, 'Mode3_Reference_Alarm_STA_Count') && ...
        ~isempty(SimParams.Mode3_Reference_Alarm_STA_Count);
    uses_farsite_positions = SimParams.Traffic_Surge_Mode == 4 && ...
        isfield(SimParams, 'Farsite_Model') && ...
        isfield(SimParams.Farsite_Model, 'Sensor_Pos');
    if uses_farsite_positions
        if size(SimParams.Farsite_Model.Sensor_Pos, 1) ~= numel(idx_alarm)
            error('Farsite sensor-position count must equal N_alarmSTA.');
        end
        Node.Pos(idx_alarm,:) = SimParams.Farsite_Model.Sensor_Pos;
        Node.Pos(idx_bk,:) = Build_STA_Deployment( ...
            AP_Pos, idx_bk, [], STA_Deployment_Radius, ...
            min_sta_separation, Node.Pos(idx_alarm,:));
    elseif uses_mode3_reference
        n_reference_alarm = max( ...
            SimParams.N_alarmSTA, ...
            round(SimParams.Mode3_Reference_Alarm_STA_Count));
        reference_alarm_pos = Build_STA_Deployment( ...
            AP_Pos, [], 1:n_reference_alarm, STA_Deployment_Radius, ...
            min_sta_separation, zeros(0, 2));

        physical_reference_id = 1:SimParams.N_alarmSTA;
        Node.Pos(idx_alarm,:) = reference_alarm_pos(physical_reference_id,:);
        Node.Pos(idx_bk,:) = Build_STA_Deployment( ...
            AP_Pos, idx_bk, [], STA_Deployment_Radius, ...
            min_sta_separation, reference_alarm_pos);

        SimState.Fire_Reference_Alarm_Pos = reference_alarm_pos;
        SimState.Physical_Alarm_Reference_ID = physical_reference_id;
        SimState.Fire_Reference_Alarm_Count = n_reference_alarm;
        SimState.Fire_Virtual_Alarm_Count = ...
            n_reference_alarm - SimParams.N_alarmSTA;
        SimState.Fire_Reference_Min_Separation_m = ...
            Get_Min_Pairwise_Separation(reference_alarm_pos);
        SimState.Fire_Reference_Activation_Order = 1:n_reference_alarm;
        SimState.Fire_Reference_Activation_Rank = 1:n_reference_alarm;
        SimState.Alarm_Reference_Rank = physical_reference_id;
    else
        Node.Pos([idx_bk idx_alarm],:) = Build_STA_Deployment( ...
            AP_Pos, idx_bk, idx_alarm, STA_Deployment_Radius, ...
            min_sta_separation, zeros(0, 2));
    end

    for i = N_AP+1:N_Node
        Node.Serving_AP(i) = Get_Serving_AP(Node.Pos(i,:), AP_Pos, SimParams);
        Node.BSS_ID(i) = Node.Serving_AP(i);
        Node.ACK_Timer(i,:) = [-1 -1];
    end

    SimState.AP_Pos = AP_Pos;
    SimState.Coverage_Radius_AP_m = TX_Radius_AP;
    SimState.Coverage_Radius_STA_m = TX_Radius_STA;
    SimState.STA_Deployment_Radius_m = STA_Deployment_Radius;
    SimState.STA_Min_Separation_Config_m = min_sta_separation;
    SimState.STA_Min_Separation_Actual_m = ...
        Get_Min_Pairwise_Separation(Node.Pos(N_AP+1:N_Node,:));
    if SimParams.Traffic_Surge_Mode == 4 && isfield(SimParams, 'Farsite_Model')
        SimState.Farsite = SimParams.Farsite_Model;
    end

    SimState.Alarm_Activation_Order = SimParams.idx_STA_Type1;
    SimState.Geo_Mode3_Preset = struct();
    if SimParams.Traffic_Surge_Mode == 3 && ...
       isfield(SimParams, 'On_GeoAware_Activation_Mode3') && ...
       SimParams.On_GeoAware_Activation_Mode3 == 1
        GeoCfg = [];
        if uses_mode3_reference
            reference_node_pos = [AP_Pos; SimState.Fire_Reference_Alarm_Pos];
            reference_alarm_idx = N_AP + (1:SimState.Fire_Reference_Alarm_Count);
            if isfield(SimParams, 'On_Use_GeoPreset_Mode3') && ...
               SimParams.On_Use_GeoPreset_Mode3 == 1
                GeoCfg = Build_GeoPreset_Mode3( ...
                    reference_node_pos, 1:N_AP, reference_alarm_idx, ...
                    SimParams.Geo_Scenario_Preset_Mode3);
                SimState.Geo_Mode3_Preset = GeoCfg;
            end

            reference_order_node_idx = Build_GeoAware_Activation_Order( ...
                reference_node_pos, reference_alarm_idx, SimParams, GeoCfg);
            reference_order = reference_order_node_idx - N_AP;
            reference_rank = nan(1, SimState.Fire_Reference_Alarm_Count);
            reference_rank(reference_order) = 1:numel(reference_order);
            physical_rank = reference_rank( ...
                SimState.Physical_Alarm_Reference_ID);
            [~, physical_order_local] = sort(physical_rank, 'ascend');

            SimState.Fire_Reference_Activation_Order = reference_order;
            SimState.Fire_Reference_Activation_Rank = reference_rank;
            SimState.Alarm_Reference_Rank = physical_rank;
            SimState.Alarm_Activation_Order = ...
                SimParams.idx_STA_Type1(physical_order_local);
        else
            if isfield(SimParams, 'On_Use_GeoPreset_Mode3') && SimParams.On_Use_GeoPreset_Mode3 == 1
                GeoCfg = Build_GeoPreset_Mode3(Node.Pos, SimParams.idx_AP, SimParams.idx_STA_Type1, SimParams.Geo_Scenario_Preset_Mode3);
                SimState.Geo_Mode3_Preset = GeoCfg;
            end
            SimState.Alarm_Activation_Order = Build_GeoAware_Activation_Order(Node.Pos, SimParams.idx_STA_Type1, SimParams, GeoCfg);
        end
    end

    % Initialize Buffer and Traffic State
    SimState.Next_Frame_Length_bk = zeros(1, N_Node);
    SimState.Next_Frame_Interval_bk = zeros(1, N_Node);
    SimState.Next_Frame_Length_al = zeros(1, N_Node);
    SimState.Next_Frame_Interval_al = zeros(1, N_Node);
    SimState.Farsite_Remaining_Burst_Count = zeros(1, N_Node);
    SimState.Mode3_Remaining_Burst_Count = zeros(1, N_Node);

    for i = 1:N_Node
        Node.TX_Buffer(i).Length = 0;
        Node.TX_Buffer(i).ACK_Length = 0;
        Node.TX_Buffer(i).ACK = [ ];
        Node.TX_Buffer(i).MPDU= [ ];
        Node.TX_Buffer(i).Triggered = 0;
        Node.TX_Buffer(i).Trigger_Time = inf;

        if Node.Type(i) == 0  % BK STA
            SimState.Next_Frame_Length_bk(i) = ceil( (SimParams.Range_Frame_Length_bk(2)-SimParams.Range_Frame_Length_bk(1))*rand + SimParams.Range_Frame_Length_bk(1) );
            SimState.Next_Frame_Interval_bk(i) = ceil( (SimParams.Range_Frame_Interval_bk(2)-SimParams.Range_Frame_Interval_bk(1))*rand + SimParams.Range_Frame_Interval_bk(1) );

        elseif Node.Type(i) == 1  % Alarm STA
            if SimParams.Traffic_Surge_Mode == 1
                if SimParams.Traffic_Gen_Mode == 0
                    SimState.Next_Frame_Length_al(i) = ceil( (SimParams.Range_Frame_Length_al(2)-SimParams.Range_Frame_Length_al(1))*rand + SimParams.Range_Frame_Length_al(1) );
                    SimState.Next_Frame_Interval_al(i) = ceil( (SimParams.Range_Frame_Interval_al(2)-SimParams.Range_Frame_Interval_al(1))*rand + SimParams.Range_Frame_Interval_al(1) );
                end
            elseif SimParams.Traffic_Surge_Mode == 2 || ...
                   SimParams.Traffic_Surge_Mode == 3 || ...
                   SimParams.Traffic_Surge_Mode == 4
                if SimParams.Traffic_Surge_Mode == 3 || SimParams.Traffic_Surge_Mode == 4
                    SimState.Next_Frame_Length_al(i) = ceil( (SimParams.Range_Frame_Length_al(2)-SimParams.Range_Frame_Length_al(1))*rand + SimParams.Range_Frame_Length_al(1) );
                    SimState.Next_Frame_Interval_al(i) = ceil( (SimParams.Range_Frame_Interval_al(2)-SimParams.Range_Frame_Interval_al(1))*rand + SimParams.Range_Frame_Interval_al(1) );
                end
            end
        end
        SimState.Delay(i).delay = [];
    end

    if SimParams.Traffic_Surge_Mode == 1 && SimParams.Traffic_Gen_Mode == 1
         SimState.Next_Frame_Length_al = ceil( (SimParams.Range_Frame_Length_al(2)-SimParams.Range_Frame_Length_al(1))*rand + SimParams.Range_Frame_Length_al(1) );
         SimState.Next_Frame_Interval_al = ceil( (SimParams.Range_Frame_Interval_al(2)-SimParams.Range_Frame_Interval_al(1))*rand + SimParams.Range_Frame_Interval_al(1) );
    end

    for bss_id = 1:SimParams.N_BSS
        SimState.BSS(bss_id).AP_ID = bss_id;
        SimState.BSS(bss_id).STA_IDs = find(Node.Serving_AP == bss_id & Node.Type ~= -1);
        SimState.BSS(bss_id).BK_STA_IDs = find(Node.Serving_AP == bss_id & Node.Type == 0);
        SimState.BSS(bss_id).Alarm_STA_IDs = find(Node.Serving_AP == bss_id & Node.Type == 1);
    end

    % Network Maps
    idx_AP = SimParams.idx_AP;
    idx_STA = SimParams.idx_STA;
    if isfield(SimParams, 'Precomputed_NetworkInfo') && ...
       isfield(SimParams.Precomputed_NetworkInfo, 'MAP_LoS') && ...
       isfield(SimParams.Precomputed_NetworkInfo, 'MAP_RSS') && ...
       size(SimParams.Precomputed_NetworkInfo.MAP_RSS, 1) == N_Node
        SimState.MAP_LoS = SimParams.Precomputed_NetworkInfo.MAP_LoS;
        SimState.MAP_RSS = SimParams.Precomputed_NetworkInfo.MAP_RSS;
        if isfield(SimParams.Precomputed_NetworkInfo, 'Cached_Interferers')
            SimState.Cached_Interferers = SimParams.Precomputed_NetworkInfo.Cached_Interferers;
        else
            interference_threshold = Get_Field_Or_Default( ...
                SimParams, 'Interference_RSS_Threshold', SimParams.CSTh);
            SimState.Cached_Interferers = Build_Cached_Interferers( ...
                SimState.MAP_RSS, interference_threshold, N_Node);
        end
        if isfield(SimParams.Precomputed_NetworkInfo, 'Cached_CarrierSenseNodes')
            SimState.Cached_CarrierSenseNodes = ...
                SimParams.Precomputed_NetworkInfo.Cached_CarrierSenseNodes;
        else
            SimState.Cached_CarrierSenseNodes = Build_Cached_Interferers( ...
                SimState.MAP_RSS, SimParams.CSTh, N_Node);
        end
    else
        [SimState.MAP_LoS, SimState.MAP_RSS] = Build_NetworkInfoMaps(Node.Pos(idx_AP,:), Node.Pos(idx_STA,:), Node.Type, ...
            SimParams.Ant_Height_AP, SimParams.Ant_Height_STA, SimParams.Ant_Height_STA, ...
            SimParams.TX_Power_AP, SimParams.TX_Power_STA_Battery_Limit, ...
            SimParams.TX_Power_STA_Battery_NonLimit, pathloss_mode);
        interference_threshold = Get_Field_Or_Default( ...
            SimParams, 'Interference_RSS_Threshold', SimParams.CSTh);
        SimState.Cached_Interferers = Build_Cached_Interferers( ...
            SimState.MAP_RSS, interference_threshold, N_Node);
        SimState.Cached_CarrierSenseNodes = Build_Cached_Interferers( ...
            SimState.MAP_RSS, SimParams.CSTh, N_Node);
    end

    % Initial Backoff & AIFS
    rng(SimParams.PNRG_Seed2);

    Node.CW = SimParams.CW_min;
    Node.bc = ceil(rand(1,N_Node).*Node.CW);
    Node.Init_aifs = SimParams.AIFSN;
    Node.aifs = Node.Init_aifs;
    Node.N_retry = zeros(1, N_Node);
    Node.Retry_Limit = SimParams.Retry_Limit;
    Node.CW_max = SimParams.CW_max;
    Node.CW_min = SimParams.CW_min;

    SimState.Node = Node;

    % Channel State
    SimState.tx_state = zeros(SimParams.N_slot, N_Node, 'uint8'); % dominant memory block
    SimState.tx_status = zeros(N_Node, 5) -1;
    SimState.n_txnode = zeros(1, N_Node);

    % Statistics
    SimState.n_access = zeros(1,N_Node);
    SimState.n_collision = zeros(1,N_Node);
    SimState.n_collision2 = zeros(1,N_Node);
    SimState.n_success = zeros(1,N_Node);
    SimState.n_success2 = zeros(1,N_Node);
    SimState.L_success = zeros(1,N_Node);
    SimState.n_loss = zeros(1,N_Node);
    SimState.n_enq = zeros(1,N_Node);

    % Multi-BSS interference diagnostics
    SimState.BSS_Interference.RAW_Active_Slots = zeros(1, SimParams.N_AP);
    SimState.BSS_Interference.RAW_Overlap_Slots = zeros(SimParams.N_AP, SimParams.N_AP);
    SimState.BSS_Interference.TX_Active_Slots = zeros(1, SimParams.N_AP);
    SimState.BSS_Interference.TX_Overlap_Slots = zeros(SimParams.N_AP, SimParams.N_AP);
    SimState.BSS_Interference.Collision_Matrix = zeros(SimParams.N_AP, SimParams.N_AP);
    SimState.BSS_Interference.Link_Type_Count = zeros(1, 4);
    SimState.BSS_Interference.Link_Type_Names = {'STA_to_AP', 'AP_to_STA', 'AP_to_AP', 'STA_to_STA'};

    % RAW State
    if SimParams.On_RAW
        SimState.BSS_Beacon_Offset = Get_BSS_Beacon_Offsets(SimParams);
        SimState.Next_BTT = ones(1, SimParams.N_AP) + SimState.BSS_Beacon_Offset;
        SimState.Tab_RAW = cell(1, SimParams.N_AP);
        SimState.List_Assigned_STA = cell(1, SimParams.N_AP);
        % RAW assignment is static; this mask carries per-cycle admission.
        SimState.RAW_TX_Allowed = true(1, N_Node);
        SimState.List_Remained_Slot = cell(1, SimParams.N_AP);
        SimState.STATE_Prev_Remained_Slot = zeros(1, SimParams.N_AP);
        for bss_id = 1:SimParams.N_AP
            SimState.BSS(bss_id).Beacon_Offset = SimState.BSS_Beacon_Offset(bss_id);
            SimState.BSS(bss_id).N_RAW = SimParams.BSS_N_RAW(bss_id);
            SimState.BSS(bss_id).Slot_Duration_Count = SimParams.BSS_Opt_Slot_Duration_Count(bss_id);
            SimState.BSS(bss_id).T_RAW_Slot_in_Slot = SimParams.BSS_T_RAW_Slot_in_Slot(bss_id);
            SimState.BSS(bss_id).Beacon_Interval = SimParams.BSS_Beacon_Interval(bss_id);
            SimState.Tab_RAW{bss_id} = zeros(SimParams.BSS_N_RAW(bss_id), 3);
            SimState.List_Assigned_STA{bss_id} = [];
            SimState.List_Remained_Slot{bss_id} = [];
            SimState.BSS(bss_id).Current_N_offset = NaN;
            SimState.BSS(bss_id).Beacon_FCS_Lower16 = NaN;
            SimState.BSS(bss_id).RAW_Offset_Beacon_Count = 0;
            SimState.BSS(bss_id).RAW_Offset_Change_Count = 0;
            SimState.BSS(bss_id).RAW_Offset_Repeat_Count = 0;
            SimState.BSS(bss_id).RAW_Offset_PRNG_State = ...
                Initialize_RAW_Offset_PRNG_State(SimParams, bss_id);
        end
    end

    % Logs & Metrics
    if SimParams.Mode_Net_Congestion_Measure
        for i = 1:N_Node
            SimState.Net_Congestion_Measure(i).CH_Util = [0 0];
            SimState.Net_Congestion_Measure(i).N_ACK = [0 0];
            SimState.Net_Congestion_Measure(i).N_Acc = [0 0];
            SimState.Net_Congestion_Measure(i).N_Fail = [0 0];
            SimState.Net_Congestion_Measure(i).N_Suc = [0 0];
            SimState.Net_Congestion_Measure(i).N_MPDU = [0 0];
            SimState.Net_Congestion_Measure(i).L_QTime = [0 0];
        end
        SimState.Init_Net_Congestion_Measure_Time = 0;
        SimState.Next_Net_Congestion_Measure_Time = SimParams.Net_Congestion_Measure_Interval;
    end

    if SimParams.On_Measure_Traffic_Temporal_Evolution
       SimState.Next_Measure_Time = SimParams.Opt_Measure_Interval;
       SimState.Traffic_Temporal_Evolution = [0 0 0 0 0 0 0 0 0];
    end

    % Adaptive Mode
    if SimParams.RAW_Mode == 3
        SimState.Prev_TxConfig = -1*ones(N_Node, 2);
        SimState.Cnt_NoLog = zeros(N_Node,1);

        if SimParams.On_Log_TxWeight
            SimState.Log_TxWeight = zeros(1, 3*length(SimParams.Target_Node_Log_TxWeight));
            SimState.Ptr_EachNodeLog = ones(1,length(SimParams.Target_Node_Log_TxWeight));
            SimState.Next_Measure_Interval_Log_TxWeight = SimParams.Measure_Interval_Log_TxWeight;
        end
    end

    % Traffic Surge State
    SimState.Last_Time = 1;
    SimState.Measure_Cummulated_N_Triggerd_STAs = [0 0];
    SimState.L_Measure_Cummulated_N_Triggerd_STAs = 1;
    SimState.Prev_Traffic_Event = 0;
    SimState.AP_Alarm_Success_Log = zeros(0, 6);
    SimState.AP_Last_Alarm_Success_Slot = inf(1, N_Node);
    if isfield(SimParams, 'On_Save_TX_Log') && SimParams.On_Save_TX_Log
        % Columns: node, bss, access_start_slot, ch_util, n_ack, mpdu_gid,
        % ack_timeout, acked_success, retry_loss, data_collision, completed.
        SimState.TX_LOG_Access_Log = zeros(0, 11);
        SimState.TX_LOG_Pending_Access_Idx = zeros(1, N_Node);
    end

    % Global ID
    SimState.GID = 0;

    % Simulation Start Time
    SimState.Time = 1;
    if SimParams.On_RAW
        SimState.Time = 2;
    end

end

function state = Initialize_RAW_Offset_PRNG_State(SimParams, bss_id)
    raw_seed = [];
    if isfield(SimParams, 'RAW_Offset_Seed')
        raw_seed = SimParams.RAW_Offset_Seed;
    end
    if isempty(raw_seed)
        raw_seed = SimParams.PNRG_Seed2 + 17041;
    end
    if ~isscalar(raw_seed) || ~isfinite(raw_seed) || raw_seed ~= round(raw_seed)
        error('RAW_Offset_Seed must be empty or a finite integer scalar.');
    end

    modulus = double(intmax('uint32'));
    seed_value = mod(double(raw_seed) + 104729 * double(bss_id), modulus);
    if seed_value == 0
        seed_value = 1;
    end
    state = uint32(seed_value);
end

function Cached_Interferers = Build_Cached_Interferers(MAP_RSS, CSTh, N_Node)
    Cached_Interferers = cell(1, N_Node);
    for tx_idx = 1:N_Node
        Cached_Interferers{tx_idx} = find( ...
            MAP_RSS(tx_idx,:) >= CSTh & ...
            MAP_RSS(tx_idx,:) ~= Inf & ...
            MAP_RSS(tx_idx,:) ~= 0);
    end
end

function positions = Build_STA_Deployment( ...
    AP_Pos, idx_bk, idx_alarm, radius, min_separation, existing_positions)

    n_bk = numel(idx_bk);
    n_alarm = numel(idx_alarm);
    n_total = n_bk + n_alarm;
    n_bss = size(AP_Pos, 1);
    positions = zeros(n_total, 2);
    home_bss = zeros(n_total, 1);

    for k = 1:n_bk
        home_bss(k) = Get_Home_BSS_ID(k, n_bss);
    end
    for k = 1:n_alarm
        home_bss(n_bk + k) = Get_Home_BSS_ID(k, n_bss);
    end

    placed_positions = existing_positions;
    for bss_id = 1:n_bss
        row_idx = find(home_bss == bss_id);
        bss_positions = Generate_Disc_Positions( ...
            AP_Pos(bss_id,:), radius, numel(row_idx), ...
            min_separation, placed_positions);
        positions(row_idx,:) = bss_positions;
        placed_positions = [placed_positions; bss_positions]; %#ok<AGROW>
    end
end

function positions = Generate_Disc_Positions( ...
    center, radius, count, min_separation, existing_positions)

    positions = zeros(count, 2);
    if count == 0
        return;
    end
    if radius <= 0
        error('STA deployment radius must be positive.');
    end

    if min_separation <= 0
        angle = 2*pi*rand(count, 1);
        radial = radius*sqrt(rand(count, 1));
        positions = center + [radial.*cos(angle), radial.*sin(angle)];
        return;
    end

    row_spacing = min_separation * sqrt(3) / 2;
    y_values = -radius:row_spacing:radius;
    candidates = zeros(0, 2);
    for row = 1:numel(y_values)
        x_offset = mod(row-1, 2) * min_separation / 2;
        x_values = (-radius:min_separation:radius) + x_offset;
        row_points = [x_values(:), repmat(y_values(row), numel(x_values), 1)];
        candidates = [candidates; row_points]; %#ok<AGROW>
    end
    candidates = candidates(sum(candidates.^2, 2) <= radius^2 + eps, :);

    rotation_angle = 2*pi*rand;
    rotation = [cos(rotation_angle), -sin(rotation_angle); ...
                sin(rotation_angle),  cos(rotation_angle)];
    candidates = candidates * rotation.' + center;
    candidates = candidates(randperm(size(candidates, 1)), :);

    selected = zeros(0, 2);
    for k = 1:size(candidates, 1)
        candidate = candidates(k,:);
        if ~isempty(existing_positions)
            dist_existing = sqrt(sum((existing_positions - candidate).^2, 2));
            if any(dist_existing < min_separation - 1e-9)
                continue;
            end
        end
        selected = [selected; candidate]; %#ok<AGROW>
        if size(selected, 1) == count
            positions = selected;
            return;
        end
    end

    error(['Unable to place %d STAs within radius %.1f m while keeping ' ...
        'minimum separation %.1f m. Increase coverage or reduce density.'], ...
        count, radius, min_separation);
end

function min_distance = Get_Min_Pairwise_Separation(positions)
    if size(positions, 1) < 2
        min_distance = NaN;
        return;
    end

    min_distance = inf;
    for k = 1:size(positions, 1)-1
        distance = sqrt(sum((positions(k+1:end,:) - positions(k,:)).^2, 2));
        min_distance = min(min_distance, min(distance));
    end
end

function value = Get_Field_Or_Default(S, field_name, default_value)
    if isfield(S, field_name) && ~isempty(S.(field_name))
        value = S.(field_name);
    else
        value = default_value;
    end
end


