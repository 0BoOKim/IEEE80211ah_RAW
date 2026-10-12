function Plot_Farsite_Front_Animation(SimState, SimParams)
%PLOT_FARSITE_FRONT_ANIMATION Animate FARSITE front and simulated STA activation.
%
% This is the simulator-integrated counterpart of
% farsite_output/animate_farsite_front_and_sensors.m.  It uses
% SimParams.Farsite_Model for the fire-front raster/sensor layout.  By
% default, sensor activity and reconstructed front overlays use only alarm
% DATA packets successfully delivered to APs.

    if SimParams.Traffic_Surge_Mode ~= 4 || ...
       ~isfield(SimParams, 'Farsite_Model') || ...
       ~isfield(SimParams.Farsite_Model, 'Arrival_Time_Min')
        return;
    end

    Model = SimParams.Farsite_Model;
    idx_alarm = SimParams.idx_STA_Type1;
    n_alarm = numel(idx_alarm);

    if n_alarm == 0
        return;
    end

    cfg = Get_Animation_Config(SimParams);
    [observed_on_min, trigger_slot, success_log] = Get_Observed_Onset_Minutes(SimState, SimParams, idx_alarm, cfg);
    t_list = Build_Time_List(Model, observed_on_min, cfg);
    if isempty(t_list)
        warning('FARSITE animation skipped because the time list is empty.');
        return;
    end

    if cfg.Max_Frames > 0 && numel(t_list) > cfg.Max_Frames
        t_list = unique(round(linspace(t_list(1), t_list(end), cfg.Max_Frames), 6));
    end

    fig = figure('Color', 'w', ...
        'Name', 'FARSITE Fire Front + Simulated Alarm Activation', ...
        'NumberTitle', 'off', ...
        'Visible', cfg.Visible, ...
        'Units', cfg.Figure_Units, ...
        'Position', cfg.Figure_Position);
    ax = axes(fig);

    if cfg.Save_Video
        video_writer = VideoWriter(cfg.Video_File, 'MPEG-4');
        video_writer.FrameRate = cfg.Video_FPS;
        open(video_writer);
    else
        video_writer = [];
    end

    if cfg.Save_Onset_Table
        Save_Onset_Table(Model, observed_on_min, trigger_slot, cfg.Onset_Table_File);
    end

    bss_colors = lines(SimParams.N_AP);
    sensor_pos = SimState.Node.Pos(idx_alarm, :);
    serving_ap = SimState.Node.Serving_AP(idx_alarm);
    for k = 1:numel(t_list)
        t_now = t_list(k);
        slot_now = Convert_Min_To_Slot(t_now, SimParams);
        cla(ax);
        hold(ax, 'on');

        if cfg.Show_Background_Arrival
            h_img = imagesc(ax, Model.Arrival_X(1,:), Model.Arrival_Y(:,1), Model.Arrival_Time_Min);
            set(h_img, 'AlphaData', isfinite(Model.Arrival_Time_Min) * cfg.Background_Alpha);
            axis(ax, 'xy');
            colormap(ax, cfg.Colormap);
            cb = colorbar(ax);
            cb.Label.String = 'FARSITE arrival time (min)';
        end

        contour(ax, Model.Arrival_X, Model.Arrival_Y, Model.Arrival_Time_Min, ...
            [t_now t_now], 'Color', cfg.Front_Line_Color, ...
            'LineWidth', cfg.Front_Line_Width);

        is_active = Get_Reconstruction_Active_State(slot_now, success_log, idx_alarm, SimParams, cfg);
        is_inactive = ~is_active;

        if cfg.Reconstruction_Enable
            Plot_Reconstructed_Front(ax, sensor_pos, observed_on_min, is_active, ...
                Model.Arrival_X, Model.Arrival_Y, t_now, cfg);
        end

        Plot_Sensors_By_BSS(ax, sensor_pos, serving_ap, is_inactive, ...
            cfg.Inactive_Marker_Size, cfg.Inactive_Marker_Face, bss_colors, false);
        Plot_Sensors_By_BSS(ax, sensor_pos, serving_ap, is_active, ...
            cfg.Active_Marker_Size, cfg.Active_Marker_Face, bss_colors, true);
        Plot_APs(ax, SimState, SimParams, bss_colors);

        if cfg.Show_Sensor_Labels
            for n = 1:n_alarm
                text(ax, sensor_pos(n,1)+10, sensor_pos(n,2)+10, string(n), ...
                    'FontSize', 7, 'Color', 'k');
            end
        end

        axis(ax, 'equal');
        axis(ax, 'tight');
        grid(ax, 'on');
        xlabel(ax, 'X (m)');
        ylabel(ax, 'Y (m)');
        title(ax, sprintf('FARSITE front at %.1f min | AP-observed active alarm STAs: %d / %d', ...
            t_now, sum(is_active), n_alarm), 'FontWeight', 'bold');
        Add_Legend(ax, cfg);
        drawnow;

        if cfg.Save_Video
            writeVideo(video_writer, getframe(fig));
        end
        if cfg.Save_GIF
            Write_GIF_Frame(fig, cfg.GIF_File, k, cfg.Pause_Sec);
        end
        if cfg.Pause_Sec > 0 && strcmpi(cfg.Visible, 'on')
            pause(cfg.Pause_Sec);
        end
    end

    if cfg.Save_Video
        close(video_writer);
        fprintf('FARSITE animation video saved to: %s\n', cfg.Video_File);
    end
    if cfg.Save_GIF
        fprintf('FARSITE animation GIF saved to: %s\n', cfg.GIF_File);
    end
end

function cfg = Get_Animation_Config(SimParams)
    cfg = struct();
    cfg.T_Start_Min = Get_Field_Or_Default(SimParams, 'Farsite_Animation_TStart_Min', 0);
    cfg.T_Step_Min = Get_Field_Or_Default(SimParams, 'Farsite_Animation_TStep_Min', 60);
    cfg.T_End_Mode = lower(Get_Field_Or_Default(SimParams, 'Farsite_Animation_TEnd_Mode', 'triggered'));
    cfg.T_End_Min = Get_Field_Or_Default(SimParams, 'Farsite_Animation_TEnd_Min', []);
    cfg.Max_Frames = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Max_Frames', 80);
    cfg.Pause_Sec = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Pause_Sec', 0.10);
    cfg.Visible = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Visible', 'on');
    cfg.Figure_Units = Get_Field_Or_Default(SimParams, ...
        'Farsite_Animation_Figure_Units', 'pixels');
    cfg.Figure_Position = Get_Field_Or_Default(SimParams, ...
        'Farsite_Animation_Figure_Position', Get_Large_Figure_Position(1800, 1000));

    cfg.Show_Background_Arrival = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Show_Background', 1);
    cfg.Background_Alpha = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Background_Alpha', 0.75);
    cfg.Colormap = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Colormap', 'jet');
    cfg.Front_Line_Color = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Front_Line_Color', 'k');
    cfg.Front_Line_Width = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Front_Line_Width', 2.0);

    cfg.Active_Marker_Face = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Active_Color', [1 0 0]);
    cfg.Inactive_Marker_Face = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Inactive_Color', [1 1 1]);
    cfg.Active_Marker_Size = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Active_Marker_Size', 42);
    cfg.Inactive_Marker_Size = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Inactive_Marker_Size', 28);
    cfg.Show_Sensor_Labels = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Show_Sensor_Labels', 0);

    cfg.Save_Video = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Save_Video', 0);
    cfg.Video_File = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Video_File', 'farsite_front_sim_activation.mp4');
    cfg.Video_FPS = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Video_FPS', 5);
    cfg.Save_GIF = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Save_GIF', 0);
    cfg.GIF_File = Get_Field_Or_Default(SimParams, 'Farsite_Animation_GIF_File', 'farsite_front_sim_activation.gif');
    cfg.Save_Onset_Table = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Save_Onset_Table', 0);
    cfg.Onset_Table_File = Get_Field_Or_Default(SimParams, 'Farsite_Animation_Onset_Table_File', 'farsite_simulated_sensor_onset_times.csv');

    cfg.Reconstruction_Enable = Get_Field_Or_Default(SimParams, 'Farsite_Reconstruction_Enable', 1);
    cfg.Reconstruction_Source = lower(Get_Field_Or_Default(SimParams, 'Farsite_Reconstruction_Source', 'ap-success'));
    cfg.Reconstruction_Front_Method = lower(Get_Field_Or_Default(SimParams, 'Farsite_Reconstruction_Front_Method', 'active-boundary'));
    cfg.Reconstruction_Min_Sensors = Get_Field_Or_Default(SimParams, 'Farsite_Reconstruction_Min_Sensors', 5);
    cfg.Reconstruction_Boundary_Shrink = Get_Field_Or_Default(SimParams, 'Farsite_Reconstruction_Boundary_Shrink', 0.75);
    cfg.Reconstruction_Line_Color = Get_Field_Or_Default(SimParams, 'Farsite_Reconstruction_Line_Color', [0 0.45 1]);
    cfg.Reconstruction_Line_Width = Get_Field_Or_Default(SimParams, 'Farsite_Reconstruction_Line_Width', 2.0);
    cfg.Reconstruction_Line_Style = Get_Field_Or_Default(SimParams, 'Farsite_Reconstruction_Line_Style', '--');
    cfg.Reconstruction_Deactivate_Missed_Count = Get_Field_Or_Default(SimParams, 'Farsite_Reconstruction_Deactivate_Missed_Count', 3);
    cfg.Reconstruction_Expected_Interval_Slots = Get_Field_Or_Default(SimParams, 'Farsite_Reconstruction_Expected_Interval_Slots', []);
    cfg.Reconstruction_Deactivate_Time_Min = Get_Field_Or_Default(SimParams, 'Farsite_Reconstruction_Deactivate_Time_Min', 60);
end

function t_list = Build_Time_List(Model, actual_on_min, cfg)
    finite_arrival = Model.Arrival_Time_Min(isfinite(Model.Arrival_Time_Min));
    finite_actual = actual_on_min(isfinite(actual_on_min));

    switch cfg.T_End_Mode
        case 'manual'
            t_end = cfg.T_End_Min;
        case 'raster'
            t_end = max(finite_arrival);
        case 'triggered'
            if isempty(finite_actual)
                t_end = min(finite_arrival);
            else
                t_end = max(finite_actual);
            end
        otherwise
            error('Unsupported Farsite_Animation_TEnd_Mode: %s', cfg.T_End_Mode);
    end

    if isempty(t_end) || ~isfinite(t_end)
        t_list = [];
        return;
    end

    if cfg.T_Step_Min <= 0
        error('Farsite_Animation_TStep_Min must be positive.');
    end

    t_list = cfg.T_Start_Min:cfg.T_Step_Min:t_end;
    if isempty(t_list) || t_list(end) < t_end
        t_list = [t_list t_end];
    end
end

function [observed_on_min, trigger_slot, success_log] = Get_Observed_Onset_Minutes(SimState, SimParams, idx_alarm, cfg)
    n_alarm = numel(idx_alarm);
    trigger_slot = inf(n_alarm, 1);
    for n = 1:n_alarm
        idx = idx_alarm(n);
        if isfield(SimState.Node.TX_Buffer(idx), 'Trigger_Time')
            trigger_slot(n) = SimState.Node.TX_Buffer(idx).Trigger_Time;
        end
    end

    success_log = zeros(0, 6);
    if isfield(SimState, 'AP_Alarm_Success_Log') && ~isempty(SimState.AP_Alarm_Success_Log)
        success_log = SimState.AP_Alarm_Success_Log;
    end

    observed_slot = inf(n_alarm, 1);
    switch cfg.Reconstruction_Source
        case 'ap-success'
            for n = 1:n_alarm
                idx = idx_alarm(n);
                rows = success_log(:,2) == idx;
                if any(rows)
                    observed_slot(n) = min(success_log(rows,1));
                end
            end
        case 'trigger'
            observed_slot = trigger_slot;
        otherwise
            error('Unsupported Farsite_Reconstruction_Source: %s', cfg.Reconstruction_Source);
    end

    observed_on_min = inf(n_alarm, 1);
    finite_observed = isfinite(observed_slot);
    time_compression = SimParams.Farsite_Model.Time_Compression;
    observed_on_min(finite_observed) = ...
        max(0, (observed_slot(finite_observed) - SimParams.Opt_Start) .* ...
        SimParams.T_slot .* time_compression ./ 60);
end

function is_active = Get_Reconstruction_Active_State(slot_now, success_log, idx_alarm, SimParams, cfg)
    n_alarm = numel(idx_alarm);
    is_active = false(n_alarm, 1);

    if strcmpi(cfg.Reconstruction_Source, 'trigger')
        for n = 1:n_alarm
            idx = idx_alarm(n);
            trigger_slot = SimParams.Farsite_Model.Trigger_Time_Slot(n);
            is_active(n) = isfinite(trigger_slot) && trigger_slot <= slot_now;
        end
        return;
    end

    if isempty(success_log)
        return;
    end

    expected_interval_slots = cfg.Reconstruction_Expected_Interval_Slots;
    if isempty(expected_interval_slots)
        expected_interval_slots = mean(SimParams.Range_Frame_Interval_al);
    end
    missed_limit_slots = inf;
    if isfinite(cfg.Reconstruction_Deactivate_Missed_Count)
        missed_limit_slots = cfg.Reconstruction_Deactivate_Missed_Count * expected_interval_slots;
    end

    time_limit_slots = inf;
    if isfinite(cfg.Reconstruction_Deactivate_Time_Min)
        time_limit_slots = cfg.Reconstruction_Deactivate_Time_Min * 60 / ...
            (SimParams.T_slot * SimParams.Farsite_Model.Time_Compression);
    end

    for n = 1:n_alarm
        idx = idx_alarm(n);
        rows = success_log(:,2) == idx & success_log(:,1) <= slot_now;
        if ~any(rows)
            continue;
        end
        last_success_slot = max(success_log(rows,1));
        elapsed_slots = slot_now - last_success_slot;
        is_active(n) = elapsed_slots <= missed_limit_slots && ...
            elapsed_slots <= time_limit_slots;
    end
end

function Plot_Reconstructed_Front(ax, sensor_pos, observed_on_min, is_active, X, Y, t_now, cfg)
    if sum(is_active) < cfg.Reconstruction_Min_Sensors
        return;
    end

    switch cfg.Reconstruction_Front_Method
        case 'active-boundary'
            Plot_Active_Boundary(ax, sensor_pos(is_active,:), cfg);
        case 'arrival-interp'
            Plot_Arrival_Interp_Reconstruction(ax, sensor_pos(is_active,:), ...
                observed_on_min(is_active), X, Y, t_now, cfg);
        otherwise
            error('Unsupported Farsite_Reconstruction_Front_Method: %s', cfg.Reconstruction_Front_Method);
    end
end

function Plot_Active_Boundary(ax, active_pos, cfg)
    if size(unique(active_pos, 'rows'), 1) < cfg.Reconstruction_Min_Sensors
        return;
    end

    try
        k = boundary(active_pos(:,1), active_pos(:,2), cfg.Reconstruction_Boundary_Shrink);
        plot(ax, active_pos(k,1), active_pos(k,2), ...
            'Color', cfg.Reconstruction_Line_Color, ...
            'LineWidth', cfg.Reconstruction_Line_Width, ...
            'LineStyle', cfg.Reconstruction_Line_Style);
    catch
        % Boundary can fail for nearly collinear or degenerate active sets.
    end
end

function Plot_Arrival_Interp_Reconstruction(ax, active_pos, active_on_min, X, Y, t_now, cfg)
    valid = isfinite(active_on_min);
    active_pos = active_pos(valid, :);
    active_on_min = active_on_min(valid);
    if size(unique(active_pos, 'rows'), 1) < cfg.Reconstruction_Min_Sensors
        return;
    end

    try
        F = scatteredInterpolant(active_pos(:,1), active_pos(:,2), active_on_min(:), ...
            'natural', 'nearest');
        T_hat = F(X, Y);
        contour(ax, X, Y, T_hat, [t_now t_now], ...
            'Color', cfg.Reconstruction_Line_Color, ...
            'LineWidth', cfg.Reconstruction_Line_Width, ...
            'LineStyle', cfg.Reconstruction_Line_Style);
    catch
        % Interpolation can fail if the active sensors are geometrically degenerate.
    end
end

function Plot_Sensors_By_BSS(ax, sensor_pos, serving_ap, is_member, marker_size, marker_face, bss_colors, is_active)
    for bss_id = 1:size(bss_colors, 1)
        idx = is_member(:) & serving_ap(:) == bss_id;
        if ~any(idx)
            continue;
        end

        if is_active
            scatter(ax, sensor_pos(idx,1), sensor_pos(idx,2), marker_size, ...
                'MarkerFaceColor', marker_face, ...
                'MarkerEdgeColor', bss_colors(bss_id,:), ...
                'LineWidth', 1.1);
        else
            scatter(ax, sensor_pos(idx,1), sensor_pos(idx,2), marker_size, ...
                'MarkerFaceColor', marker_face, ...
                'MarkerEdgeColor', bss_colors(bss_id,:), ...
                'LineWidth', 0.8);
        end
    end
end

function Plot_APs(ax, SimState, SimParams, bss_colors)
    for bss_id = 1:SimParams.N_AP
        ap_id = SimState.BSS(bss_id).AP_ID;
        plot(ax, SimState.Node.Pos(ap_id,1), SimState.Node.Pos(ap_id,2), ...
            'p', 'Color', 'k', 'MarkerFaceColor', bss_colors(bss_id,:), ...
            'MarkerSize', 14, 'LineWidth', 1.4);
        text(ax, SimState.Node.Pos(ap_id,1), SimState.Node.Pos(ap_id,2), ...
            sprintf('  AP%d', bss_id), 'FontWeight', 'bold', 'Color', 'k');
    end
end

function Add_Legend(ax, cfg)
    h_inactive = scatter(ax, nan, nan, cfg.Inactive_Marker_Size, ...
        'MarkerFaceColor', cfg.Inactive_Marker_Face, ...
        'MarkerEdgeColor', 'k');
    h_active = scatter(ax, nan, nan, cfg.Active_Marker_Size, ...
        'MarkerFaceColor', cfg.Active_Marker_Face, ...
        'MarkerEdgeColor', 'k');
    h_front = plot(ax, nan, nan, cfg.Front_Line_Color, 'LineWidth', cfg.Front_Line_Width);
    h_recon = plot(ax, nan, nan, ...
        'Color', cfg.Reconstruction_Line_Color, ...
        'LineWidth', cfg.Reconstruction_Line_Width, ...
        'LineStyle', cfg.Reconstruction_Line_Style);
    h_ap = plot(ax, nan, nan, 'kp', 'MarkerFaceColor', [0.8 0.8 0.8], ...
        'MarkerSize', 14, 'LineWidth', 1.4);

    if cfg.Reconstruction_Enable
        handles = [h_inactive h_active h_front h_recon h_ap];
        labels = {'Inactive alarm STA', 'AP-observed active alarm STA', ...
            'True FARSITE front', 'Sensor-reconstructed front', 'AP'};
    else
        handles = [h_inactive h_active h_front h_ap];
        labels = {'Inactive alarm STA', 'AP-observed active alarm STA', ...
            'True FARSITE front', 'AP'};
    end

    legend(ax, handles, labels, ...
        'Location', 'bestoutside');
end

function slot_now = Convert_Min_To_Slot(t_now_min, SimParams)
    slot_now = SimParams.Opt_Start + ...
        round(t_now_min * 60 / (SimParams.T_slot * SimParams.Farsite_Model.Time_Compression));
end

function Write_GIF_Frame(fig, gif_file, frame_idx, delay_time)
    frame = getframe(fig);
    [im, map] = rgb2ind(frame2im(frame), 256);
    if frame_idx == 1
        imwrite(im, map, gif_file, 'gif', 'LoopCount', inf, 'DelayTime', delay_time);
    else
        imwrite(im, map, gif_file, 'gif', 'WriteMode', 'append', 'DelayTime', delay_time);
    end
end

function Save_Onset_Table(Model, actual_on_min, trigger_slot, out_file)
    T = table(Model.Sensor_ID(:), Model.Sensor_X(:), Model.Sensor_Y(:), ...
        Model.T_Front_Min(:), Model.T_On_Min(:), trigger_slot(:), actual_on_min(:), ...
        'VariableNames', {'sensor_id','x','y','t_front_min','t_expected_on_min', ...
        'actual_trigger_slot','actual_on_min'});
    writetable(T, out_file);
    fprintf('FARSITE simulated onset table saved to: %s\n', out_file);
end

function val = Get_Field_Or_Default(S, field_name, default_val)
    if isfield(S, field_name) && ~isempty(S.(field_name))
        val = S.(field_name);
    else
        val = default_val;
    end
end
