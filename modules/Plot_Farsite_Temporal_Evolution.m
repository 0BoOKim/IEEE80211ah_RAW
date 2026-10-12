function Plot_Farsite_Temporal_Evolution(Model, SimParams)
%PLOT_FARSITE_TEMPORAL_EVOLUTION Animate the native FARSITE fire-front raster.
%
% This is the simulator-integrated counterpart of
% farsite_output/plot_farsite_temproral_evolution.m. It visualizes the fire
% front progression and, by default, overlays the fire front reconstructed
% from FARSITE-activated sensors. This view is independent of WLAN packet
% delivery; AP-observed reconstruction is handled by Plot_Farsite_Front_Animation.

    if nargin < 1 || ~isstruct(Model) || ~isfield(Model, 'Arrival_Time_Min')
        warning('FARSITE temporal evolution skipped because the model is missing.');
        return;
    end
    if nargin < 2
        SimParams = struct();
    end

    A = Model.Arrival_Time_Min;
    if isempty(A) || all(~isfinite(A(:)))
        warning('FARSITE temporal evolution skipped because the arrival raster is empty.');
        return;
    end

    cfg = Get_Temporal_Config(SimParams);
    t_list = Build_Time_List(Model, cfg);
    if isempty(t_list)
        warning('FARSITE temporal evolution skipped because the time list is empty.');
        return;
    end

    if cfg.Max_Frames > 0 && numel(t_list) > cfg.Max_Frames
        t_list = unique(round(linspace(t_list(1), t_list(end), cfg.Max_Frames), 6));
    end

    [MetricSummary, sensor_pos, sensor_on_min] = Build_Temporal_Reconstruction_Metrics(Model, t_list, cfg);
    if cfg.Save_Metrics_CSV && ~isempty(MetricSummary)
        writetable(MetricSummary, cfg.Metrics_File);
        fprintf('FARSITE temporal reconstruction metrics saved to: %s\n', cfg.Metrics_File);
    end

    fig = figure('Color', 'w', ...
        'Name', 'FARSITE Fire Front Temporal Evolution', ...
        'NumberTitle', 'off', ...
        'Visible', cfg.Visible, ...
        'Units', cfg.Figure_Units, ...
        'Position', cfg.Figure_Position);
    if cfg.Show_Metrics_Panel
        tile = tiledlayout(fig, 2, 3, ...
            'TileSpacing', cfg.TileSpacing, ...
            'Padding', cfg.TilePadding);
        ax = nexttile(tile, 1, [2 2]);
        ax_metric_ratio = nexttile(tile, 3);
        ax_metric_distance = nexttile(tile, 6);
    else
        ax = axes(fig);
        ax_metric_ratio = [];
        ax_metric_distance = [];
    end

    if cfg.Save_Video
        video_writer = VideoWriter(cfg.Video_File, 'MPEG-4');
        video_writer.FrameRate = cfg.Video_FPS;
        open(video_writer);
    else
        video_writer = [];
    end

    for k = 1:numel(t_list)
        t_now = t_list(k);
        delete(findall(fig, 'Type', 'ColorBar'));
        cla(ax);
        hold(ax, 'on');

        if cfg.Show_Background_Arrival
            h_img = imagesc(ax, Model.Arrival_X(1,:), Model.Arrival_Y(:,1), A);
            set(h_img, 'AlphaData', isfinite(A) * cfg.Background_Alpha);
            axis(ax, 'xy');
            colormap(ax, cfg.Colormap);
            cb = colorbar(ax);
            cb.Label.String = 'FARSITE arrival time (min)';
        end

        if cfg.Show_Burned_Area
            burned = isfinite(A) & A <= t_now;
            h_burn = imagesc(ax, Model.Arrival_X(1,:), Model.Arrival_Y(:,1), burned);
            set(h_burn, 'AlphaData', double(burned) * cfg.Burned_Alpha);
            set(h_burn, 'CData', burned);
        end

        contour(ax, Model.Arrival_X, Model.Arrival_Y, A, [t_now t_now], ...
            'Color', cfg.Front_Line_Color, ...
            'LineWidth', cfg.Front_Line_Width);

        active_sensor = isfinite(sensor_on_min) & sensor_on_min <= t_now;
        if cfg.Show_Sensors
            Plot_Sensors(ax, sensor_pos, ~active_sensor, cfg.Inactive_Marker_Size, ...
                cfg.Inactive_Marker_Face, [0.3 0.3 0.3], 0.6);
            Plot_Sensors(ax, sensor_pos, active_sensor, cfg.Active_Marker_Size, ...
                cfg.Active_Marker_Face, cfg.Active_Marker_Edge, 1.1);
        end

        if cfg.Show_Reconstructed_Front
            Plot_Reconstructed_Front(ax, Model, sensor_pos, sensor_on_min, ...
                active_sensor, t_now, cfg);
        end

        axis(ax, 'equal');
        axis(ax, 'tight');
        grid(ax, 'on');
        xlabel(ax, 'X (m)');
        ylabel(ax, 'Y (m)');
        n_burned = sum(isfinite(A(:)) & A(:) <= t_now);
        title(ax, sprintf('FARSITE fire front at %.1f min | Burned raster cells: %d', ...
            t_now, n_burned), 'FontWeight', 'bold');
        Add_Map_Legend(ax, cfg);
        hold(ax, 'off');

        if cfg.Show_Metrics_Panel
            Plot_Metrics_Panel(ax_metric_ratio, ax_metric_distance, MetricSummary, k, cfg);
        end
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
        fprintf('FARSITE temporal evolution video saved to: %s\n', cfg.Video_File);
    end
    if cfg.Save_GIF
        fprintf('FARSITE temporal evolution GIF saved to: %s\n', cfg.GIF_File);
    end
end

function cfg = Get_Temporal_Config(SimParams)
    cfg = struct();
    cfg.T_Start_Min = Get_Field_Or_Default(SimParams, 'Farsite_Temporal_Animation_TStart_Min', 0);
    cfg.T_Step_Min = Get_Field_Or_Default(SimParams, 'Farsite_Temporal_Animation_TStep_Min', ...
        Get_Field_Or_Default(SimParams, 'Farsite_Animation_TStep_Min', 60));
    cfg.T_End_Mode = lower(Get_Field_Or_Default(SimParams, 'Farsite_Temporal_Animation_TEnd_Mode', 'raster'));
    cfg.T_End_Min = Get_Field_Or_Default(SimParams, 'Farsite_Temporal_Animation_TEnd_Min', []);
    cfg.Max_Frames = Get_Field_Or_Default(SimParams, 'Farsite_Temporal_Animation_Max_Frames', ...
        Get_Field_Or_Default(SimParams, 'Farsite_Animation_Max_Frames', 80));
    cfg.Pause_Sec = Get_Field_Or_Default(SimParams, 'Farsite_Temporal_Animation_Pause_Sec', ...
        Get_Field_Or_Default(SimParams, 'Farsite_Animation_Pause_Sec', 0.10));
    cfg.Visible = Get_Field_Or_Default(SimParams, 'Farsite_Temporal_Animation_Visible', ...
        Get_Field_Or_Default(SimParams, 'Farsite_Animation_Visible', 'on'));
    cfg.Figure_Units = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Figure_Units', 'pixels');
    cfg.Figure_Position = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Figure_Position', Get_Default_Figure_Position());
    cfg.TileSpacing = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_TileSpacing', 'compact');
    cfg.TilePadding = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_TilePadding', 'compact');

    cfg.Show_Background_Arrival = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Show_Background', 1);
    cfg.Background_Alpha = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Background_Alpha', 0.75);
    cfg.Colormap = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Colormap', 'jet');
    cfg.Show_Burned_Area = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Show_Burned_Area', 0);
    cfg.Burned_Alpha = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Burned_Alpha', 0.22);
    cfg.Front_Line_Color = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Front_Line_Color', 'k');
    cfg.Front_Line_Width = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Front_Line_Width', 2.0);

    cfg.Show_Reconstructed_Front = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Show_Reconstructed_Front', 1);
    cfg.Reconstruction_Method = lower(Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Reconstruction_Method', ...
        Get_Field_Or_Default(SimParams, 'Farsite_Reconstruction_Front_Method', 'active-boundary')));
    cfg.Reconstruction_Min_Sensors = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Reconstruction_Min_Sensors', ...
        Get_Field_Or_Default(SimParams, 'Farsite_Reconstruction_Min_Sensors', 5));
    cfg.Reconstruction_Boundary_Shrink = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Reconstruction_Boundary_Shrink', ...
        Get_Field_Or_Default(SimParams, 'Farsite_Reconstruction_Boundary_Shrink', 0.75));
    cfg.Reconstruction_Line_Color = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Reconstruction_Line_Color', [0 0.45 1]);
    cfg.Reconstruction_Line_Width = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Reconstruction_Line_Width', 2.4);
    cfg.Reconstruction_Line_Style = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Reconstruction_Line_Style', '--');

    cfg.Show_Sensors = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Show_Sensors', 1);
    cfg.Active_Marker_Face = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Active_Sensor_Color', [1 0.12 0.08]);
    cfg.Active_Marker_Edge = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Active_Sensor_Edge_Color', [0.15 0.15 0.15]);
    cfg.Inactive_Marker_Face = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Inactive_Sensor_Color', [1 1 1]);
    cfg.Active_Marker_Size = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Active_Sensor_Size', 26);
    cfg.Inactive_Marker_Size = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Inactive_Sensor_Size', 12);

    cfg.Show_Metrics_Panel = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Show_Metrics_Panel', 1);
    cfg.Map_Legend_Location = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Map_Legend_Location', 'southoutside');
    cfg.Ratio_Legend_Location = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Ratio_Legend_Location', 'southoutside');
    cfg.Distance_Legend_Location = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Distance_Legend_Location', 'southoutside');
    cfg.Save_Metrics_CSV = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Save_Metrics_CSV', 1);
    cfg.Metrics_File = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Metrics_File', ...
        'farsite_temporal_reconstruction_metrics.csv');

    cfg.Save_Video = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Save_Video', 0);
    cfg.Video_File = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Video_File', 'farsite_temporal_evolution.mp4');
    cfg.Video_FPS = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Video_FPS', 5);
    cfg.Save_GIF = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_Save_GIF', 0);
    cfg.GIF_File = Get_Field_Or_Default(SimParams, ...
        'Farsite_Temporal_Animation_GIF_File', 'farsite_temporal_evolution.gif');
end

function [MetricSummary, sensor_pos, sensor_on_min] = Build_Temporal_Reconstruction_Metrics(Model, t_list, cfg)
    MetricSummary = table();
    if ~isfield(Model, 'Sensor_Pos') || ~isfield(Model, 'T_On_Min')
        sensor_pos = zeros(0, 2);
        sensor_on_min = zeros(0, 1);
        return;
    end

    sensor_pos = Model.Sensor_Pos;
    sensor_on_min = Model.T_On_Min(:);
    if isempty(sensor_pos) || numel(sensor_on_min) ~= size(sensor_pos, 1)
        return;
    end

    metric_cfg = struct();
    metric_cfg.Method = cfg.Reconstruction_Method;
    metric_cfg.Min_Sensors = cfg.Reconstruction_Min_Sensors;
    metric_cfg.Boundary_Shrink = cfg.Reconstruction_Boundary_Shrink;
    metric_cfg.Observed_On_Min = sensor_on_min;

    for k = 1:numel(t_list)
        t_now = t_list(k);
        active_sensor = isfinite(sensor_on_min) & sensor_on_min <= t_now;
        metric = Evaluate_Farsite_Reconstruction_Metrics(Model, sensor_pos, ...
            active_sensor, t_now, metric_cfg);
        row = struct2table(metric);
        row.N_Farsite_Active_Sensors = sum(active_sensor);
        row.Farsite_Active_Sensor_Ratio = Safe_Div(sum(active_sensor), numel(active_sensor));
        row.Frame_Index = k;
        MetricSummary = [MetricSummary; row]; %#ok<AGROW>
    end
end

function Plot_Reconstructed_Front(ax, Model, sensor_pos, sensor_on_min, active_sensor, t_now, cfg)
    if sum(active_sensor) < cfg.Reconstruction_Min_Sensors
        return;
    end

    active_pos = sensor_pos(active_sensor, :);
    if size(unique(active_pos, 'rows'), 1) < cfg.Reconstruction_Min_Sensors
        return;
    end

    try
        switch cfg.Reconstruction_Method
            case 'active-boundary'
                active_pos = unique(active_pos, 'rows');
                boundary_idx = boundary(active_pos(:,1), active_pos(:,2), ...
                    cfg.Reconstruction_Boundary_Shrink);
                plot(ax, active_pos(boundary_idx,1), active_pos(boundary_idx,2), ...
                    'Color', cfg.Reconstruction_Line_Color, ...
                    'LineWidth', cfg.Reconstruction_Line_Width, ...
                    'LineStyle', cfg.Reconstruction_Line_Style);

            case 'arrival-interp'
                active_t = sensor_on_min(active_sensor);
                keep = isfinite(active_t);
                active_pos = active_pos(keep, :);
                active_t = active_t(keep);
                if size(active_pos, 1) < cfg.Reconstruction_Min_Sensors
                    return;
                end
                F = scatteredInterpolant(active_pos(:,1), active_pos(:,2), active_t(:), ...
                    'natural', 'nearest');
                T_hat = F(Model.Arrival_X, Model.Arrival_Y);
                contour(ax, Model.Arrival_X, Model.Arrival_Y, T_hat, [t_now t_now], ...
                    'Color', cfg.Reconstruction_Line_Color, ...
                    'LineWidth', cfg.Reconstruction_Line_Width, ...
                    'LineStyle', cfg.Reconstruction_Line_Style);

            otherwise
                error('Unsupported reconstruction method: %s', cfg.Reconstruction_Method);
        end
    catch
        % Degenerate sensor geometry can prevent boundary/interpolation.
    end
end

function Plot_Sensors(ax, sensor_pos, mask, marker_size, marker_face, marker_edge, line_width)
    if isempty(sensor_pos) || ~any(mask)
        return;
    end

    scatter(ax, sensor_pos(mask,1), sensor_pos(mask,2), marker_size, ...
        'MarkerFaceColor', marker_face, ...
        'MarkerEdgeColor', marker_edge, ...
        'LineWidth', line_width);
end

function Plot_Metrics_Panel(ax_ratio, ax_distance, MetricSummary, frame_idx, cfg)
    if isempty(MetricSummary)
        return;
    end

    idx = 1:min(frame_idx, height(MetricSummary));
    t = MetricSummary.Eval_Time_Min(idx);

    cla(ax_ratio);
    hold(ax_ratio, 'on');
    plot(ax_ratio, t, MetricSummary.Burned_Area_IoU(idx), ...
        'Color', [0 0.45 1], 'LineWidth', 1.5, 'Marker', 'o');
    plot(ax_ratio, t, MetricSummary.False_Burned_Ratio(idx), ...
        'Color', [0.85 0.15 0.12], 'LineWidth', 1.2, 'LineStyle', '--');
    plot(ax_ratio, t, MetricSummary.Missed_Burned_Ratio(idx), ...
        'Color', [0.1 0.1 0.1], 'LineWidth', 1.2, 'LineStyle', ':');
    plot(ax_ratio, t, MetricSummary.Farsite_Active_Sensor_Ratio(idx), ...
        'Color', [0.15 0.55 0.2], 'LineWidth', 1.1, 'LineStyle', '-.');
    grid(ax_ratio, 'on');
    ylim(ax_ratio, [0 1.05]);
    Set_XLim_Safe(ax_ratio, MetricSummary.Eval_Time_Min);
    xlabel(ax_ratio, 'FARSITE time (min)');
    ylabel(ax_ratio, 'Ratio');
    title(ax_ratio, sprintf('Reconstruction ratios | active sensors: %d', ...
        MetricSummary.N_Farsite_Active_Sensors(idx(end))));
    legend(ax_ratio, {'IoU', 'False burned', 'Missed burned', 'Active sensor ratio'}, ...
        'Location', cfg.Ratio_Legend_Location);
    hold(ax_ratio, 'off');

    cla(ax_distance);
    hold(ax_distance, 'on');
    plot(ax_distance, t, MetricSummary.Mean_Front_Distance_m(idx), ...
        'Color', cfg.Reconstruction_Line_Color, 'LineWidth', 1.5, 'Marker', 's');
    plot(ax_distance, t, MetricSummary.Hausdorff_Front_Distance_m(idx), ...
        'Color', [0.85 0.33 0.1], 'LineWidth', 1.2, 'LineStyle', '--');
    grid(ax_distance, 'on');
    Set_XLim_Safe(ax_distance, MetricSummary.Eval_Time_Min);
    xlabel(ax_distance, 'FARSITE time (min)');
    ylabel(ax_distance, 'Distance error (m)');
    title(ax_distance, 'Front distance error');
    legend(ax_distance, {'Mean', 'Hausdorff'}, 'Location', cfg.Distance_Legend_Location);
    hold(ax_distance, 'off');
end

function Add_Map_Legend(ax, cfg)
    h_true = plot(ax, nan, nan, cfg.Front_Line_Color, ...
        'LineWidth', cfg.Front_Line_Width);
    h_recon = plot(ax, nan, nan, ...
        'Color', cfg.Reconstruction_Line_Color, ...
        'LineWidth', cfg.Reconstruction_Line_Width, ...
        'LineStyle', cfg.Reconstruction_Line_Style);
    if cfg.Show_Sensors
        h_inactive = scatter(ax, nan, nan, cfg.Inactive_Marker_Size, ...
            'MarkerFaceColor', cfg.Inactive_Marker_Face, ...
            'MarkerEdgeColor', [0.3 0.3 0.3]);
        h_active = scatter(ax, nan, nan, cfg.Active_Marker_Size, ...
            'MarkerFaceColor', cfg.Active_Marker_Face, ...
            'MarkerEdgeColor', cfg.Active_Marker_Edge);
        legend(ax, [h_true h_recon h_inactive h_active], ...
            {'True FARSITE front', 'Sensor-reconstructed front', ...
            'Inactive sensor', 'FARSITE-active sensor'}, ...
            'Location', cfg.Map_Legend_Location);
    else
        legend(ax, [h_true h_recon], ...
            {'True FARSITE front', 'Sensor-reconstructed front'}, ...
            'Location', cfg.Map_Legend_Location);
    end
end

function y = Safe_Div(num, den)
    if den == 0
        y = NaN;
    else
        y = num / den;
    end
end

function Set_XLim_Safe(ax, x)
    x = x(isfinite(x));
    if isempty(x)
        return;
    end

    xmin = min(x);
    xmax = max(x);
    if xmin == xmax
        pad = max(1, abs(xmin) * 0.05);
        xlim(ax, [xmin - pad xmax + pad]);
    else
        xlim(ax, [xmin xmax]);
    end
end

function t_list = Build_Time_List(Model, cfg)
    finite_arrival = Model.Arrival_Time_Min(isfinite(Model.Arrival_Time_Min));
    finite_sensor = [];
    if isfield(Model, 'T_On_Min')
        finite_sensor = Model.T_On_Min(isfinite(Model.T_On_Min));
    end

    switch cfg.T_End_Mode
        case 'manual'
            t_end = cfg.T_End_Min;
        case 'triggered'
            if isempty(finite_sensor)
                t_end = max(finite_arrival);
            else
                t_end = max(finite_sensor);
            end
        case {'raster', 'auto'}
            t_end = max(finite_arrival);
        otherwise
            error('Unsupported Farsite_Temporal_Animation_TEnd_Mode: %s', cfg.T_End_Mode);
    end

    if isempty(t_end) || ~isfinite(t_end)
        t_list = [];
        return;
    end
    if cfg.T_Step_Min <= 0
        error('Farsite_Temporal_Animation_TStep_Min must be positive.');
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

function pos = Get_Default_Figure_Position()
    screen = get(0, 'ScreenSize');
    target_w = 1800;
    target_h = 1000;

    max_w = max(900, screen(3) - 100);
    max_h = max(650, screen(4) - 160);
    w = min(target_w, max_w);
    h = min(target_h, max_h);
    x = max(20, screen(1) + (screen(3) - w) / 2);
    y = max(40, screen(2) + (screen(4) - h) / 2);
    pos = [x y w h];
end
