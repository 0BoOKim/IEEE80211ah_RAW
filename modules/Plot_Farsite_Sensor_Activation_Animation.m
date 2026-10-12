function Plot_Farsite_Sensor_Activation_Animation(Model, SimState, SimParams)
%PLOT_FARSITE_SENSOR_ACTIVATION_ANIMATION Animate FARSITE front and sensors.
%
% This reproduces the core behavior of
% farsite_output/animate_farsite_front_and_sensors.m inside the simulator:
% sensors become active when the FARSITE arrival-time raster reaches their
% locations. This is intentionally separate from AP-observed activation,
% which is handled by Plot_Farsite_Front_Animation.

    if nargin < 1 || ~isstruct(Model) || ~isfield(Model, 'Arrival_Time_Min') || ...
       ~isfield(Model, 'Sensor_Pos') || ~isfield(Model, 'T_On_Min')
        warning('FARSITE sensor activation animation skipped because the model is incomplete.');
        return;
    end
    if nargin < 2
        SimState = [];
    end
    if nargin < 3
        SimParams = struct();
    end

    cfg = Get_Sensor_Animation_Config(SimParams);
    t_list = Build_Time_List(Model, cfg);
    if isempty(t_list)
        warning('FARSITE sensor activation animation skipped because the time list is empty.');
        return;
    end
    if cfg.Max_Frames > 0 && numel(t_list) > cfg.Max_Frames
        t_list = unique(round(linspace(t_list(1), t_list(end), cfg.Max_Frames), 6));
    end

    [sensor_pos, sensor_id, serving_ap, ap_pos] = Resolve_Sensor_And_AP_Pos(Model, SimState, SimParams);
    n_sensors = size(sensor_pos, 1);
    if n_sensors == 0
        warning('FARSITE sensor activation animation skipped because no sensors are available.');
        return;
    end

    t_on = Model.T_On_Min(:);
    if numel(t_on) ~= n_sensors
        error('Model.T_On_Min length must match the number of FARSITE sensors.');
    end

    if cfg.Save_Onset_Table
        T = table(sensor_id(:), sensor_pos(:,1), sensor_pos(:,2), t_on(:), ...
            'VariableNames', {'sensor_id','x','y','t_on_min'});
        writetable(T, cfg.Onset_Table_File);
        fprintf('FARSITE sensor onset table saved to: %s\n', cfg.Onset_Table_File);
    end

    fig = figure('Color', 'w', ...
        'Name', 'FARSITE Fire Front + FARSITE Sensor Activation', ...
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

    bss_colors = lines(max([1; serving_ap(:)]));
    for k = 1:numel(t_list)
        t_now = t_list(k);
        delete(findall(fig, 'Type', 'ColorBar'));
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

        is_active = isfinite(t_on) & t_on <= t_now;
        Plot_Sensors(ax, sensor_pos, serving_ap, ~is_active, cfg.Inactive_Marker_Size, ...
            cfg.Inactive_Marker_Face, bss_colors, false);
        Plot_Sensors(ax, sensor_pos, serving_ap, is_active, cfg.Active_Marker_Size, ...
            cfg.Active_Marker_Face, bss_colors, true);

        if cfg.Show_AP && ~isempty(ap_pos)
            plot(ax, ap_pos(:,1), ap_pos(:,2), 'kp', ...
                'MarkerFaceColor', cfg.AP_Marker_Face, ...
                'MarkerSize', cfg.AP_Marker_Size, ...
                'LineWidth', 1.4, ...
                'DisplayName', 'AP');
        end

        if cfg.Show_Sensor_Labels
            for n = 1:n_sensors
                text(ax, sensor_pos(n,1)+10, sensor_pos(n,2)+10, string(sensor_id(n)), ...
                    'FontSize', 7, 'Color', 'k');
            end
        end

        axis(ax, 'equal');
        axis(ax, 'tight');
        grid(ax, 'on');
        xlabel(ax, 'X (m)');
        ylabel(ax, 'Y (m)');
        title(ax, sprintf('FARSITE front and sensor activation at %.1f min | Active: %d / %d', ...
            t_now, sum(is_active), n_sensors), 'FontWeight', 'bold');
        Add_Legend(ax, cfg);
        hold(ax, 'off');
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
        fprintf('FARSITE sensor activation video saved to: %s\n', cfg.Video_File);
    end
    if cfg.Save_GIF
        fprintf('FARSITE sensor activation GIF saved to: %s\n', cfg.GIF_File);
    end
end

function cfg = Get_Sensor_Animation_Config(SimParams)
    cfg = struct();
    cfg.T_Start_Min = Get_Field_Or_Default(SimParams, 'Farsite_Sensor_Animation_TStart_Min', 0);
    cfg.T_Step_Min = Get_Field_Or_Default(SimParams, 'Farsite_Sensor_Animation_TStep_Min', ...
        Get_Field_Or_Default(SimParams, 'Farsite_Animation_TStep_Min', 60));
    cfg.T_End_Mode = lower(Get_Field_Or_Default(SimParams, 'Farsite_Sensor_Animation_TEnd_Mode', 'triggered'));
    cfg.T_End_Min = Get_Field_Or_Default(SimParams, 'Farsite_Sensor_Animation_TEnd_Min', []);
    cfg.Max_Frames = Get_Field_Or_Default(SimParams, 'Farsite_Sensor_Animation_Max_Frames', ...
        Get_Field_Or_Default(SimParams, 'Farsite_Animation_Max_Frames', 80));
    cfg.Pause_Sec = Get_Field_Or_Default(SimParams, 'Farsite_Sensor_Animation_Pause_Sec', ...
        Get_Field_Or_Default(SimParams, 'Farsite_Animation_Pause_Sec', 0.10));
    cfg.Visible = Get_Field_Or_Default(SimParams, 'Farsite_Sensor_Animation_Visible', ...
        Get_Field_Or_Default(SimParams, 'Farsite_Animation_Visible', 'on'));
    cfg.Figure_Units = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_Figure_Units', 'pixels');
    cfg.Figure_Position = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_Figure_Position', Get_Large_Figure_Position(1800, 1000));

    cfg.Show_Background_Arrival = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_Show_Background', 1);
    cfg.Background_Alpha = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_Background_Alpha', 0.75);
    cfg.Colormap = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_Colormap', 'jet');
    cfg.Front_Line_Color = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_Front_Line_Color', 'k');
    cfg.Front_Line_Width = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_Front_Line_Width', 2.0);

    cfg.Active_Marker_Face = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_Active_Color', [1 0 0]);
    cfg.Inactive_Marker_Face = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_Inactive_Color', [1 1 1]);
    cfg.Active_Marker_Size = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_Active_Marker_Size', 42);
    cfg.Inactive_Marker_Size = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_Inactive_Marker_Size', 28);
    cfg.Show_Sensor_Labels = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_Show_Sensor_Labels', 0);
    cfg.Show_AP = Get_Field_Or_Default(SimParams, 'Farsite_Sensor_Animation_Show_AP', 1);
    cfg.AP_Marker_Face = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_AP_Marker_Face', 'y');
    cfg.AP_Marker_Size = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_AP_Marker_Size', 13);

    cfg.Save_Video = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_Save_Video', 0);
    cfg.Video_File = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_Video_File', 'farsite_sensor_activation.mp4');
    cfg.Video_FPS = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_Video_FPS', 5);
    cfg.Save_GIF = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_Save_GIF', 0);
    cfg.GIF_File = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_GIF_File', 'farsite_sensor_activation.gif');
    cfg.Save_Onset_Table = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_Save_Onset_Table', 0);
    cfg.Onset_Table_File = Get_Field_Or_Default(SimParams, ...
        'Farsite_Sensor_Animation_Onset_Table_File', 'farsite_sensor_onset_times.csv');
end

function [sensor_pos, sensor_id, serving_ap, ap_pos] = Resolve_Sensor_And_AP_Pos(Model, SimState, SimParams)
    sensor_pos = Model.Sensor_Pos;
    sensor_id = Model.Sensor_ID;
    if isempty(sensor_id)
        sensor_id = (1:size(sensor_pos, 1)).';
    end
    serving_ap = ones(size(sensor_pos, 1), 1);
    ap_pos = zeros(0, 2);

    if isstruct(SimState) && isfield(SimState, 'Node') && isstruct(SimParams) && ...
       isfield(SimParams, 'idx_STA_Type1')
        idx_alarm = SimParams.idx_STA_Type1;
        if numel(idx_alarm) == size(sensor_pos, 1)
            sensor_pos = SimState.Node.Pos(idx_alarm, :);
            serving_ap = SimState.Node.Serving_AP(idx_alarm).';
        end
        if isfield(SimParams, 'idx_AP') && ~isempty(SimParams.idx_AP)
            ap_pos = SimState.Node.Pos(SimParams.idx_AP, :);
        end
    end
end

function t_list = Build_Time_List(Model, cfg)
    finite_arrival = Model.Arrival_Time_Min(isfinite(Model.Arrival_Time_Min));
    finite_on = Model.T_On_Min(isfinite(Model.T_On_Min));

    switch cfg.T_End_Mode
        case 'manual'
            t_end = cfg.T_End_Min;
        case {'raster', 'auto'}
            t_end = max(finite_arrival);
        case 'triggered'
            if isempty(finite_on)
                t_end = max(finite_arrival);
            else
                t_end = max(finite_on);
            end
        otherwise
            error('Unsupported Farsite_Sensor_Animation_TEnd_Mode: %s', cfg.T_End_Mode);
    end

    if isempty(t_end) || ~isfinite(t_end)
        t_list = [];
        return;
    end
    if cfg.T_Step_Min <= 0
        error('Farsite_Sensor_Animation_TStep_Min must be positive.');
    end

    t_start = cfg.T_Start_Min;
    if isempty(t_start) || ~isfinite(t_start)
        t_start = min(finite_arrival);
    end
    t_list = t_start:cfg.T_Step_Min:t_end;
    if isempty(t_list) || t_list(end) < t_end
        t_list = [t_list t_end];
    end
end

function Plot_Sensors(ax, sensor_pos, serving_ap, mask, marker_size, marker_face, bss_colors, is_active)
    if ~any(mask)
        return;
    end

    bss_list = unique(serving_ap(mask));
    for b = 1:numel(bss_list)
        bss_id = bss_list(b);
        idx = mask & serving_ap == bss_id;
        if ~any(idx)
            continue;
        end

        if is_active
            edge_color = bss_colors(max(1, bss_id), :);
            line_width = 1.4;
        else
            edge_color = [0.25 0.25 0.25];
            line_width = 0.7;
        end

        scatter(ax, sensor_pos(idx,1), sensor_pos(idx,2), marker_size, ...
            'MarkerFaceColor', marker_face, ...
            'MarkerEdgeColor', edge_color, ...
            'LineWidth', line_width);
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
    if cfg.Show_AP
        h_ap = plot(ax, nan, nan, 'kp', 'MarkerFaceColor', cfg.AP_Marker_Face, ...
            'MarkerSize', cfg.AP_Marker_Size);
        legend(ax, [h_inactive h_active h_front h_ap], ...
            {'Inactive sensors', 'FARSITE-active sensors', 'FARSITE front', 'AP'}, ...
            'Location', 'bestoutside');
    else
        legend(ax, [h_inactive h_active h_front], ...
            {'Inactive sensors', 'FARSITE-active sensors', 'FARSITE front'}, ...
            'Location', 'bestoutside');
    end
end

function Write_GIF_Frame(fig, gif_file, frame_idx, pause_sec)
    frame = getframe(fig);
    [im, map] = rgb2ind(frame2im(frame), 256);
    if frame_idx == 1
        imwrite(im, map, gif_file, 'gif', 'LoopCount', inf, 'DelayTime', pause_sec);
    else
        imwrite(im, map, gif_file, 'gif', 'WriteMode', 'append', 'DelayTime', pause_sec);
    end
end

function val = Get_Field_Or_Default(S, field_name, default_val)
    if isstruct(S) && isfield(S, field_name) && ~isempty(S.(field_name))
        val = S.(field_name);
    else
        val = default_val;
    end
end
