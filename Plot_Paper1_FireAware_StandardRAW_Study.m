function Figures = Plot_Paper1_FireAware_StandardRAW_Study(Input, Override)
%PLOT_PAPER1_FIREAWARE_STANDARDRAW_STUDY Plot Paper 1 E2-E4 results.
%
% Default usage after the full experiment:
%
%   Plot_Paper1_FireAware_StandardRAW_Study
%
% A result prefix, workspace MAT file, or returned Results structure can
% also be supplied. Figures are shown and saved as PNG and FIG files.
%
%   Plot_Paper1_FireAware_StandardRAW_Study('My_Result_Prefix')
%   Plot_Paper1_FireAware_StandardRAW_Study(R)

    if nargin < 1
        Input = [];
    end
    if nargin < 2 || isempty(Override)
        Override = struct();
    end
    if ~isstruct(Override)
        error('ED:InvalidPaper1PlotOverride', ...
            'Override must be a structure.');
    end

    project_dir = fileparts(mfilename('fullpath'));
    default_prefix = fullfile(project_dir, ...
        'Result_Paper1_FireAware_StandardRAW_EventDriven');
    [Aggregate, TimeSeries, source_prefix] = Load_Results( ...
        Input, default_prefix);
    Aggregate = Normalize_String_Columns(Aggregate);
    TimeSeries = Normalize_String_Columns(TimeSeries);

    Cfg = Default_Plot_Config(source_prefix);
    Cfg = Copy_Fields(Cfg, Override);
    if exist(Cfg.OutputDirectory, 'dir') ~= 7
        mkdir(Cfg.OutputDirectory);
    end

    Figures = struct();
    if any(Aggregate.Experiment == "E2")
        Figures.E2Capacity = Plot_E2_Capacity(Aggregate, Cfg);
        Figures.E2CameraQoS = Plot_E2_Camera_QoS(Aggregate, Cfg);
    end
    if any(Aggregate.Experiment == "E3")
        Figures.E3Aggregate = Plot_E3_Aggregate(Aggregate, Cfg);
        if ~isempty(TimeSeries)
            Figures.E3TimeSeries = Plot_E3_TimeSeries( ...
                TimeSeries, Cfg);
        end
    end
    if any(Aggregate.Experiment == "E4")
        Figures.E4Aggregate = Plot_E4_Aggregate(Aggregate, Cfg);
        if ~isempty(TimeSeries)
            Figures.E4TimeSeries = Plot_E4_TimeSeries( ...
                TimeSeries, Cfg);
        end
    end

    fprintf('Saved Paper 1 E2-E4 figures to: %s\n', ...
        Cfg.OutputDirectory);
end

function Cfg = Default_Plot_Config(source_prefix)
    Cfg = struct();
    Cfg.OutputDirectory = [source_prefix '_Figures'];
    Cfg.Visible = 'on';
    Cfg.SavePNG = true;
    Cfg.SaveFIG = true;
    Cfg.CloseAfterSave = false;
    Cfg.ResolutionDPI = 220;
end

function destination = Copy_Fields(destination, source)
    names = fieldnames(source);
    for idx = 1:numel(names)
        destination.(names{idx}) = source.(names{idx});
    end
end

function [Aggregate, TimeSeries, prefix] = Load_Results(Input, default_prefix)
    TimeSeries = table();
    if isempty(Input)
        prefix = default_prefix;
        Aggregate = Read_Required_Table([prefix '_Aggregate.csv']);
        TimeSeries = Read_Optional_Table([prefix '_TimeSeries.csv']);
        return;
    end

    if isstruct(Input)
        if ~isfield(Input, 'Aggregate')
            error('ED:InvalidPaper1PlotInput', ...
                'The Results structure must contain Aggregate.');
        end
        Aggregate = Input.Aggregate;
        if isfield(Input, 'TimeSeries')
            TimeSeries = Input.TimeSeries;
        end
        prefix = default_prefix;
        return;
    end

    if istable(Input)
        Aggregate = Input;
        prefix = default_prefix;
        return;
    end

    if ~(ischar(Input) || (isstring(Input) && isscalar(Input)))
        error('ED:InvalidPaper1PlotInput', ...
            'Input must be a Results structure, table, MAT file, or prefix.');
    end
    value = char(Input);
    if endsWith(value, '.mat', 'IgnoreCase', true)
        loaded = load(value, 'Results');
        if ~isfield(loaded, 'Results') || ...
                ~isfield(loaded.Results, 'Aggregate')
            error('ED:InvalidPaper1Workspace', ...
                'The MAT file does not contain a compatible Results value.');
        end
        Aggregate = loaded.Results.Aggregate;
        if isfield(loaded.Results, 'TimeSeries')
            TimeSeries = loaded.Results.TimeSeries;
        end
        suffix = '_Workspace.mat';
        if endsWith(value, suffix, 'IgnoreCase', true)
            prefix = value(1:end-numel(suffix));
        else
            [folder, name] = fileparts(value);
            prefix = fullfile(folder, name);
        end
        return;
    end

    aggregate_suffix = '_Aggregate.csv';
    if endsWith(value, aggregate_suffix, 'IgnoreCase', true)
        prefix = value(1:end-numel(aggregate_suffix));
    else
        prefix = value;
    end
    Aggregate = Read_Required_Table([prefix '_Aggregate.csv']);
    TimeSeries = Read_Optional_Table([prefix '_TimeSeries.csv']);
end

function T = Read_Required_Table(file_name)
    if exist(file_name, 'file') ~= 2
        error('ED:MissingPaper1PlotData', ...
            'Required result file not found: %s', file_name);
    end
    T = readtable(file_name);
end

function T = Read_Optional_Table(file_name)
    if exist(file_name, 'file') == 2
        T = readtable(file_name);
    else
        T = table();
    end
end

function T = Normalize_String_Columns(T)
    if isempty(T)
        return;
    end
    candidates = {'Experiment', 'Condition_ID', 'Condition_Label', ...
        'Beta_Regime', 'Geo_Regime', 'Geo_Preset'};
    for idx = 1:numel(candidates)
        name = candidates{idx};
        if ismember(name, T.Properties.VariableNames)
            T.(name) = string(T.(name));
        end
    end
end

function fig = Plot_E2_Capacity(Aggregate, Cfg)
    T = Aggregate(Aggregate.Experiment == "E2", :);
    camera_counts = unique(T.NCamera, 'sorted');
    n_camera = numel(camera_counts);
    fig = New_Figure(Cfg, max(1100, 600 * n_camera), 760);
    layout = tiledlayout(fig, 2, n_camera, ...
        'TileSpacing', 'loose', 'Padding', 'compact');
    title(layout, 'E2: Standard RAW capacity surface');
    throughput_max = Max_Or_Default( ...
        T.Network_Throughput_Mbps_Mean, 1);

    for idx = 1:n_camera
        rows = T(T.NCamera == camera_counts(idx), :);
        ax = nexttile(layout, idx);
        Plot_Heatmap(ax, rows, ...
            'Alarm_All_Packet_Deadline_PDR_Mean', ...
            sprintf('Alarm deadline PDR, %d cameras', ...
            camera_counts(idx)), 'PDR', [0.94 1]);
        Hide_Repeated_Y_Axis(ax, idx);
        ax = nexttile(layout, n_camera + idx);
        Plot_Heatmap(ax, rows, 'Network_Throughput_Mbps_Mean', ...
            sprintf('Network throughput, %d cameras', ...
            camera_counts(idx)), 'Throughput (Mbps)', ...
            [0 throughput_max]);
        Hide_Repeated_Y_Axis(ax, idx);
    end
    Save_Figure(fig, Cfg, 'E2_capacity_surface');
end

function fig = Plot_E2_Camera_QoS(Aggregate, Cfg)
    T = Aggregate(Aggregate.Experiment == "E2" & ...
        Aggregate.NCamera > 0, :);
    camera_counts = unique(T.NCamera, 'sorted');
    n_camera = numel(camera_counts);
    fig = New_Figure(Cfg, max(1000, 600 * n_camera), 1040);
    layout = tiledlayout(fig, 3, n_camera, ...
        'TileSpacing', 'loose', 'Padding', 'compact');
    title(layout, 'E2: camera QoS under Standard RAW');
    delay_max = Max_Or_Default(T.Camera_Delay_P95_s_Mean, 1);
    deadline_max = Max_Or_Default(T.Camera_Deadline_PDR_Mean, 1);
    for idx = 1:n_camera
        rows = T(T.NCamera == camera_counts(idx), :);
        ax = nexttile(layout, idx);
        Plot_Heatmap(ax, rows, 'Camera_PDR_Mean', ...
            sprintf('Camera PDR, %d cameras', ...
            camera_counts(idx)), 'PDR', [0 1]);
        Hide_Repeated_Y_Axis(ax, idx);
        ax = nexttile(layout, n_camera + idx);
        Plot_Heatmap(ax, rows, 'Camera_Deadline_PDR_Mean', ...
            sprintf('Camera deadline PDR, %d cameras', ...
            camera_counts(idx)), 'PDR', [0 deadline_max]);
        Hide_Repeated_Y_Axis(ax, idx);
        ax = nexttile(layout, 2 * n_camera + idx);
        Plot_Heatmap(ax, rows, 'Camera_Delay_P95_s_Mean', ...
            sprintf('Camera P95 delay, %d cameras', ...
            camera_counts(idx)), 'Delay (s)', [0 delay_max]);
        Hide_Repeated_Y_Axis(ax, idx);
    end
    Save_Figure(fig, Cfg, 'E2_camera_qos_surface');
end

function fig = Plot_E3_Aggregate(Aggregate, Cfg)
    T = Aggregate(Aggregate.Experiment == "E3", :);
    fire_window_s = 900 ./ T.ROS_mps;
    T.Mean_Active_Cameras_Mean = ...
        T.Camera_Active_Time_Sum_s_Mean ./ fire_window_s;
    fig = New_Figure(Cfg, 1450, 840);
    layout = tiledlayout(fig, 2, 2, ...
        'TileSpacing', 'loose', 'Padding', 'compact');
    title(layout, 'E3: temporal fire-regime sensitivity');

    ax = nexttile(layout);
    Plot_Regime_Heatmap(ax, T, ...
        'Peak_Reference_Activation_Rate_STA_per_s_Mean', ...
        'Peak activation rate', 'STAs/s', []);
    ax = nexttile(layout);
    Plot_Regime_Heatmap(ax, T, 'Mean_Active_Cameras_Mean', ...
        'Mean active cameras during fire window', 'Cameras', [0 4]);
    Hide_Repeated_Y_Axis(ax, 2);
    ax = nexttile(layout);
    Plot_Regime_Heatmap(ax, T, 'Camera_PDR_Mean', ...
        'Camera PDR', 'PDR', [0 1]);
    ax = nexttile(layout);
    Plot_Regime_Heatmap(ax, T, 'Camera_Deadline_PDR_Mean', ...
        'Camera deadline PDR', 'PDR', [0 1]);
    Hide_Repeated_Y_Axis(ax, 2);
    Save_Figure(fig, Cfg, 'E3_temporal_regime_aggregate');
end

function fig = Plot_E3_TimeSeries(TimeSeries, Cfg)
    T = TimeSeries(TimeSeries.Experiment == "E3", :);
    replicate = min(T.Replicate);
    T = T(T.Replicate == replicate, :);
    fig = New_Figure(Cfg, 1250, 820);
    layout = tiledlayout(fig, 2, 2, ...
        'TileSpacing', 'compact', 'Padding', 'compact');
    title(layout, sprintf( ...
        'E3: representative temporal evolution (replicate %d)', ...
        replicate));

    nominal = T(T.Beta_Regime == "Nominal", :);
    ax = nexttile(layout);
    Plot_TimeSeries_Groups(ax, nominal, 'ROS_mps', ...
        'ReferenceActiveAlarmSTA', 'Reference active STAs', ...
        'Active STAs', 'ROS %.2g m/s');
    ax = nexttile(layout);
    Plot_TimeSeries_Groups(ax, nominal, 'ROS_mps', ...
        'Interval_Total_Offered_Mbps', 'Total offered load', ...
        'Offered load (Mbps)', 'ROS %.2g m/s');

    ros_values = unique(T.ROS_mps, 'sorted');
    reference_ros = ros_values(ceil(numel(ros_values) / 2));
    fixed_ros = T(T.ROS_mps == reference_ros, :);
    ax = nexttile(layout);
    Plot_TimeSeries_Groups(ax, fixed_ros, 'Beta_Regime', ...
        'ReferenceActiveAlarmSTA', ...
        sprintf('Beta regimes at ROS %.2g m/s', reference_ros), ...
        'Active STAs', '%s');
    ax = nexttile(layout);
    Plot_TimeSeries_Groups(ax, fixed_ros, 'Beta_Regime', ...
        'ActiveCameraSTA', ...
        sprintf('Camera concurrency at ROS %.2g m/s', reference_ros), ...
        'Active cameras', '%s');
    Save_Figure(fig, Cfg, 'E3_temporal_regime_timeseries');
end

function fig = Plot_E4_Aggregate(Aggregate, Cfg)
    T = Aggregate(Aggregate.Experiment == "E4", :);
    fig = New_Figure(Cfg, 1250, 780);
    layout = tiledlayout(fig, 2, 2, ...
        'TileSpacing', 'compact', 'Padding', 'compact');
    title(layout, 'E4: spatial fire-regime sensitivity');

    ax = nexttile(layout);
    Plot_Bar_With_CI(ax, T, 'Camera_Active_Time_Sum_s', ...
        'Cumulative camera-active time', 'Camera-seconds');
    ax = nexttile(layout);
    Plot_Bar_With_CI(ax, T, 'Camera_Overlap_All_s', ...
        'All-camera overlap duration', 'Duration with 4 cameras (s)');
    ax = nexttile(layout);
    Plot_Bar_With_CI(ax, T, 'Camera_PDR', ...
        'Camera PDR', 'PDR');
    ylim(ax, [0 1]);
    ax = nexttile(layout);
    Plot_Bar_With_CI(ax, T, 'Camera_Deadline_PDR', ...
        'Camera deadline PDR', 'PDR');
    deadline_upper = max(T.Camera_Deadline_PDR_Mean + ...
        T.Camera_Deadline_PDR_CI95);
    ylim(ax, [0 max(0.06, 1.1 * deadline_upper)]);
    Save_Figure(fig, Cfg, 'E4_spatial_regime_aggregate');
end

function fig = Plot_E4_TimeSeries(TimeSeries, Cfg)
    T = TimeSeries(TimeSeries.Experiment == "E4", :);
    replicate = min(T.Replicate);
    T = T(T.Replicate == replicate, :);
    fig = New_Figure(Cfg, 1250, 500);
    layout = tiledlayout(fig, 1, 2, ...
        'TileSpacing', 'compact', 'Padding', 'compact');
    title(layout, sprintf( ...
        'E4: representative spatial evolution (replicate %d)', ...
        replicate));
    ax = nexttile(layout);
    Plot_TimeSeries_Groups(ax, T, 'Geo_Regime', ...
        'ActiveCameraSTA', 'Active cameras by spatial regime', ...
        'Active cameras', '%s');
    ax = nexttile(layout);
    Plot_TimeSeries_Groups(ax, T, 'Geo_Regime', ...
        'Interval_Total_Offered_Mbps', ...
        'Offered load by spatial regime', ...
        'Offered load (Mbps)', '%s');
    Save_Figure(fig, Cfg, 'E4_spatial_regime_timeseries');
end

function Plot_Heatmap(ax, T, metric_name, plot_title, ...
    colorbar_label, limits)

    x_values = unique(T.N_RAW, 'sorted');
    y_values = unique(T.Slot_Duration_Count, 'sorted');
    matrix = Build_Grid(T, x_values, y_values, metric_name);
    imagesc(ax, 1:numel(x_values), 1:numel(y_values), matrix);
    set(ax, 'YDir', 'normal', 'XTick', 1:numel(x_values), ...
        'XTickLabel', string(x_values), ...
        'YTick', 1:numel(y_values), ...
        'YTickLabel', string(y_values));
    xlabel(ax, 'N_{RAW}');
    ylabel(ax, 'Slot Duration Count');
    title(ax, plot_title);
    grid(ax, 'off');
    colorbar_handle = colorbar(ax);
    colorbar_handle.Label.String = colorbar_label;
    Apply_Color_Limits(ax, matrix, limits);
    Add_Heatmap_Text(ax, matrix);
end

function Plot_Regime_Heatmap(ax, T, metric_name, plot_title, ...
    colorbar_label, limits)

    x_values = unique(T.ROS_mps, 'sorted');
    y_values = unique(T.Beta_Regime, 'stable');
    matrix = nan(numel(y_values), numel(x_values));
    for y_idx = 1:numel(y_values)
        for x_idx = 1:numel(x_values)
            match = T.Beta_Regime == y_values(y_idx) & ...
                T.ROS_mps == x_values(x_idx);
            if any(match)
                matrix(y_idx, x_idx) = T.(metric_name)(find(match, 1));
            end
        end
    end
    imagesc(ax, 1:numel(x_values), 1:numel(y_values), matrix);
    set(ax, 'YDir', 'normal', 'XTick', 1:numel(x_values), ...
        'XTickLabel', string(x_values), ...
        'YTick', 1:numel(y_values), ...
        'YTickLabel', y_values);
    xlabel(ax, 'Rate of spread (m/s)');
    ylabel(ax, 'Beta regime');
    title(ax, plot_title);
    colorbar_handle = colorbar(ax);
    colorbar_handle.Label.String = colorbar_label;
    Apply_Color_Limits(ax, matrix, limits);
    Add_Heatmap_Text(ax, matrix);
end

function matrix = Build_Grid(T, x_values, y_values, metric_name)
    matrix = nan(numel(y_values), numel(x_values));
    for y_idx = 1:numel(y_values)
        for x_idx = 1:numel(x_values)
            match = T.N_RAW == x_values(x_idx) & ...
                T.Slot_Duration_Count == y_values(y_idx);
            if any(match)
                matrix(y_idx, x_idx) = T.(metric_name)(find(match, 1));
            end
        end
    end
end

function Apply_Color_Limits(ax, values, limits)
    finite_values = values(isfinite(values));
    if isempty(finite_values)
        return;
    end
    if isempty(limits)
        lower = min(finite_values);
        upper = max(finite_values);
        if lower == upper
            upper = lower + max(1, abs(lower)) * 1e-6;
        end
        limits = [lower upper];
    elseif limits(1) == limits(2)
        limits(2) = limits(1) + 1;
    end
    caxis(ax, limits);
end

function Add_Heatmap_Text(ax, values)
    for row = 1:size(values, 1)
        for column = 1:size(values, 2)
            value = values(row, column);
            if isfinite(value)
                text(ax, column, row, Format_Value(value), ...
                    'HorizontalAlignment', 'center', ...
                    'FontSize', 8, 'Color', [0.08 0.08 0.08]);
            end
        end
    end
end

function text_value = Format_Value(value)
    if abs(value) >= 100
        text_value = sprintf('%.0f', value);
    elseif abs(value) >= 10
        text_value = sprintf('%.1f', value);
    elseif abs(value) >= 1
        text_value = sprintf('%.2f', value);
    else
        text_value = sprintf('%.3f', value);
    end
end

function Plot_Bar_With_CI(ax, T, metric_base, plot_title, y_label)
    mean_name = [metric_base '_Mean'];
    ci_name = [metric_base '_CI95'];
    values = T.(mean_name);
    ci = T.(ci_name);
    ci(~isfinite(ci)) = 0;
    x = 1:height(T);
    bar(ax, x, values, 0.68, 'FaceColor', [0.18 0.48 0.72]);
    hold(ax, 'on');
    errorbar(ax, x, values, ci, 'k.', 'LineWidth', 1.1, ...
        'CapSize', 8);
    hold(ax, 'off');
    set(ax, 'XTick', x, 'XTickLabel', T.Geo_Regime, ...
        'XTickLabelRotation', 20);
    ylabel(ax, y_label);
    title(ax, plot_title);
    grid(ax, 'on');
end

function Hide_Repeated_Y_Axis(ax, column_index)
    if column_index > 1
        ylabel(ax, '');
        set(ax, 'YTickLabel', []);
    end
end

function Plot_TimeSeries_Groups(ax, T, group_name, value_name, ...
    plot_title, y_label, legend_format)

    hold(ax, 'on');
    groups = unique(T.(group_name), 'stable');
    labels = strings(numel(groups), 1);
    for group_idx = 1:numel(groups)
        if isnumeric(groups)
            group_rows = T(T.(group_name) == groups(group_idx), :);
            labels(group_idx) = string(sprintf( ...
                legend_format, groups(group_idx)));
        else
            group_rows = T(string(T.(group_name)) == ...
                string(groups(group_idx)), :);
            labels(group_idx) = string(sprintf( ...
                legend_format, char(string(groups(group_idx)))));
        end
        group_rows = sortrows(group_rows, 'TimeSec');
        plot(ax, group_rows.TimeSec / 60, ...
            group_rows.(value_name), 'LineWidth', 1.25);
    end
    hold(ax, 'off');
    xlabel(ax, 'Simulation time (min)');
    ylabel(ax, y_label);
    title(ax, plot_title);
    grid(ax, 'on');
    legend(ax, labels, 'Location', 'best');
end

function value = Max_Or_Default(values, default_value)
    values = values(isfinite(values));
    if isempty(values)
        value = default_value;
    else
        value = max(values);
        if value <= 0
            value = default_value;
        end
    end
end

function fig = New_Figure(Cfg, width, height)
    fig = figure('Color', 'w', 'Visible', Cfg.Visible, ...
        'Position', [80 80 width height]);
    colormap(fig, parula(256));
end

function Save_Figure(fig, Cfg, base_name)
    drawnow;
    if Cfg.SaveFIG
        savefig(fig, fullfile(Cfg.OutputDirectory, ...
            [base_name '.fig']));
    end
    if Cfg.SavePNG
        print(fig, fullfile(Cfg.OutputDirectory, ...
            [base_name '.png']), '-dpng', ...
            sprintf('-r%d', Cfg.ResolutionDPI));
    end
    if Cfg.CloseAfterSave
        close(fig);
    end
end
