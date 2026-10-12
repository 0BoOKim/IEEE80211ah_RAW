function SimParams = Build_Farsite_Activation_Model(SimParams)
%BUILD_FARSITE_ACTIVATION_MODEL Build fire-front based alarm STA activation.
%
% The FARSITE output provides a fire arrival-time raster. Sensor locations are
% generated from a configurable meter spacing, instead of using the example
% sensor CSV bundled with the FARSITE visualization script.

    [X, Y, A, meta] = Load_Farsite_Arrival_Raster(SimParams);

    spacing_m = Get_Field_Or_Default(SimParams, 'Farsite_Sensor_Spacing_m', 300);
    margin_m = Get_Field_Or_Default(SimParams, 'Farsite_Sensor_Margin_m', 100);
    if spacing_m <= 0
        error('Farsite_Sensor_Spacing_m must be positive.');
    end

    xmin = min(X(:));
    xmax = max(X(:));
    ymin = min(Y(:));
    ymax = max(Y(:));

    xs = (xmin + margin_m):spacing_m:(xmax - margin_m);
    ys = (ymin + margin_m):spacing_m:(ymax - margin_m);
    if isempty(xs) || isempty(ys)
        error('FARSITE sensor spacing/margin produced no sensor points.');
    end

    [SX, SY] = meshgrid(xs, ys);
    sensor_pos = [SX(:), SY(:)];

    t_front_min = interp2(X, Y, A, sensor_pos(:,1), sensor_pos(:,2), 'nearest');
    t_front_min = t_front_min(:);
    t_front_min(~isfinite(t_front_min)) = inf;

    use_only_reachable = Get_Field_Or_Default(SimParams, 'Farsite_Use_Only_Reachable_Sensors', 1);
    if use_only_reachable
        keep = isfinite(t_front_min);
        sensor_pos = sensor_pos(keep, :);
        t_front_min = t_front_min(keep);
    end

    max_alarm_sta = Get_Field_Or_Default(SimParams, 'Farsite_Max_Alarm_STA', inf);
    if isfinite(max_alarm_sta) && numel(t_front_min) > max_alarm_sta
        select_mode = lower(Get_Field_Or_Default(SimParams, 'Farsite_Sensor_Select_Mode', 'earliest'));
        switch select_mode
            case 'earliest'
                [~, order] = sort(t_front_min, 'ascend', 'MissingPlacement', 'last');
                selected = order(1:max_alarm_sta);
            case 'random'
                rng(Get_Field_Or_Default(SimParams, 'Farsite_Sensor_Select_Seed', SimParams.PNRG_Seed1 + 404));
                selected = randperm(numel(t_front_min), max_alarm_sta);
            otherwise
                error('Unsupported Farsite_Sensor_Select_Mode: %s', select_mode);
        end
        sensor_pos = sensor_pos(selected, :);
        t_front_min = t_front_min(selected);
    end

    if isempty(sensor_pos)
        error('FARSITE activation model has no alarm sensors after filtering.');
    end

    time_compression = Get_Field_Or_Default(SimParams, 'Farsite_Time_Compression', 1.0);
    if time_compression <= 0
        error('Farsite_Time_Compression must be positive.');
    end

    trigger_slot = inf(size(t_front_min));
    finite_t = isfinite(t_front_min);
    trigger_slot(finite_t) = SimParams.Opt_Start + ...
        ceil((t_front_min(finite_t) * 60) ./ (SimParams.T_slot * time_compression));

    Model = struct();
    Model.Sensor_ID = (1:size(sensor_pos, 1)).';
    Model.Sensor_Pos = sensor_pos;
    Model.Sensor_X = sensor_pos(:,1);
    Model.Sensor_Y = sensor_pos(:,2);
    Model.T_Front_Min = t_front_min;
    Model.T_On_Min = t_front_min;
    Model.Trigger_Time_Slot = trigger_slot;
    Model.Time_Compression = time_compression;
    Model.Sensor_Spacing_m = spacing_m;
    Model.Sensor_Margin_m = margin_m;
    Model.Use_Only_Reachable_Sensors = use_only_reachable;
    Model.Arrival_X = X;
    Model.Arrival_Y = Y;
    Model.Arrival_Time_Min = A;
    Model.Arrival_Meta = meta;
    if isfield(meta, 'Source_File')
        Model.Arrival_Source_File = meta.Source_File;
    else
        Model.Arrival_Source_File = '';
    end
    Model.Map_Bounds = [xmin xmax ymin ymax];

    SimParams.Farsite_Model = Model;
    if isfield(SimParams, 'Tab_Traffic_Model')
        SimParams = rmfield(SimParams, 'Tab_Traffic_Model');
    end
    SimParams.N_alarmSTA = size(sensor_pos, 1);

    SimParams = Fill_Default_Farsite_Traffic_Profile(SimParams);
    SimParams.Prob_Frame_Generation_al = Get_Field_Or_Default(SimParams, 'Prob_Frame_Generation_al', 1.0);

    finite_trigger = trigger_slot(isfinite(trigger_slot));
    if isempty(finite_trigger)
        SimParams.Opt_End = SimParams.N_slot;
    else
        SimParams.Opt_End = max(SimParams.N_slot, max(finite_trigger));
    end

    if Get_Field_Or_Default(SimParams, 'Farsite_Set_AP_Pos', 1)
        SimParams.BSS_AP_Pos = Build_Farsite_AP_Grid_Pos(SimParams.N_AP, sensor_pos);
    end

    SimParams = Refresh_Node_Dependent_Config(SimParams);
end

function SimParams = Fill_Default_Farsite_Traffic_Profile(SimParams)
    packet_len = Get_Field_Or_Default(SimParams, ...
        'Farsite_Alarm_Packet_Length_Bytes', [100 100]);
    SimParams.Farsite_Alarm_Packet_Length_Bytes = packet_len;

    SimParams.Farsite_Alarm_Burst_Count = Get_Field_Or_Default(SimParams, ...
        'Farsite_Alarm_Burst_Count', 3);
    burst_interval_sec = Get_Field_Or_Default(SimParams, ...
        'Farsite_Alarm_Burst_Interval_Sec', 1);
    SimParams.Farsite_Alarm_Burst_Interval_Sec = burst_interval_sec;
    SimParams.Farsite_Alarm_Burst_Interval_Slots = Get_Field_Or_Default(SimParams, ...
        'Farsite_Alarm_Burst_Interval_Slots', ...
        max(1, round(burst_interval_sec / SimParams.T_slot)) * [1 1]);

    keepalive_sec = Get_Field_Or_Default(SimParams, ...
        'Farsite_Alarm_KeepAlive_Interval_Sec', 30);
    jitter_ratio = Get_Field_Or_Default(SimParams, ...
        'Farsite_Alarm_KeepAlive_Jitter_Ratio', 0.10);
    SimParams.Farsite_Alarm_KeepAlive_Interval_Sec = keepalive_sec;
    SimParams.Farsite_Alarm_KeepAlive_Jitter_Ratio = jitter_ratio;

    keepalive_center_slots = max(1, round(keepalive_sec / SimParams.T_slot));
    keepalive_jitter_slots = round(keepalive_center_slots * jitter_ratio);
    keepalive_range = [ ...
        max(1, keepalive_center_slots - keepalive_jitter_slots), ...
        keepalive_center_slots + keepalive_jitter_slots];

    SimParams.Range_Frame_Length_al = Get_Field_Or_Default(SimParams, ...
        'Range_Frame_Length_al', packet_len);
    SimParams.Range_Frame_Interval_al = Get_Field_Or_Default(SimParams, ...
        'Range_Frame_Interval_al', keepalive_range);
    SimParams.Farsite_Reconstruction_Expected_Interval_Slots = Get_Field_Or_Default(SimParams, ...
        'Farsite_Reconstruction_Expected_Interval_Slots', keepalive_center_slots);
    SimParams.Farsite_Reconstruction_Deactivate_Missed_Count = Get_Field_Or_Default(SimParams, ...
        'Farsite_Reconstruction_Deactivate_Missed_Count', 3);
    SimParams.Farsite_Reconstruction_Deactivate_Time_Min = Get_Field_Or_Default(SimParams, ...
        'Farsite_Reconstruction_Deactivate_Time_Min', 2);
end

function AP_Pos = Build_Farsite_AP_Grid_Pos(N_AP, sensor_pos)
    n_col = ceil(sqrt(N_AP));
    n_row = ceil(N_AP / n_col);

    xmin = min(sensor_pos(:,1));
    xmax = max(sensor_pos(:,1));
    ymin = min(sensor_pos(:,2));
    ymax = max(sensor_pos(:,2));

    if n_col == 1
        xs = (xmin + xmax) / 2;
    else
        xs = linspace(xmin, xmax, n_col);
    end

    if n_row == 1
        ys = (ymin + ymax) / 2;
    else
        ys = linspace(ymin, ymax, n_row);
    end

    AP_Pos = zeros(N_AP, 2);
    idx = 0;
    for r = 1:n_row
        for c = 1:n_col
            idx = idx + 1;
            if idx > N_AP
                return;
            end
            AP_Pos(idx,:) = [xs(c), ys(r)];
        end
    end
end

function val = Get_Field_Or_Default(S, field_name, default_val)
    if isfield(S, field_name) && ~isempty(S.(field_name))
        val = S.(field_name);
    else
        val = default_val;
    end
end
