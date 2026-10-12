function Plot_Farsite_Multiscale_Results(WindowSummary, MetricSummary, APSuccessLog, RuntimeSummary, Model, SimState, SimParams, Exp)
%PLOT_FARSITE_MULTISCALE_RESULTS Plot multi-scale FARSITE/WLAN results.

    if isempty(WindowSummary)
        warning('Multi-scale plotting skipped because WindowSummary is empty.');
        return;
    end

    save_figures = Get_Field_Or_Default(Exp, 'SaveFigures', 0);
    fig_dir = Get_Field_Or_Default(Exp, 'FigureDir', 'figures');
    if save_figures && ~exist(fig_dir, 'dir')
        mkdir(fig_dir);
    end

    Plot_Fire_Observation_Timeline(WindowSummary, MetricSummary, save_figures, fig_dir);
    Plot_WLAN_Window_Performance(WindowSummary, APSuccessLog, save_figures, fig_dir);
    Plot_Reconstruction_Accuracy(MetricSummary, save_figures, fig_dir);
    Plot_Runtime_Reduction(RuntimeSummary, save_figures, fig_dir);
    Plot_Farsite_AP_Observation_Map(Model, SimState, SimParams, APSuccessLog, save_figures, fig_dir);
end

function Plot_Fire_Observation_Timeline(WindowSummary, MetricSummary, save_figures, fig_dir)
    fig = figure('Name', 'Multi-Scale Fire Observation Timeline', ...
        'NumberTitle', 'off', 'Color', 'w', ...
        'Units', 'pixels', 'Position', Get_Large_Figure_Position(1600, 950));

    subplot(2,2,1);
    hold on;
    plot(WindowSummary.Eval_Time_Min, WindowSummary.N_True_Active, 'k-', 'LineWidth', 1.7);
    plot(WindowSummary.Eval_Time_Min, WindowSummary.N_AP_Observed_Active, 'ro-', 'LineWidth', 1.4);
    bar(WindowSummary.Eval_Time_Min, WindowSummary.N_Newly_Active, 0.35, ...
        'FaceAlpha', 0.25, 'EdgeColor', 'none');
    grid on;
    xlabel('FARSITE time (min)');
    ylabel('Sensor count');
    title('True vs AP-observed Active Sensors');
    legend({'True active', 'AP-observed active', 'Newly active'}, 'Location', 'best');
    hold off;

    subplot(2,2,2);
    if ismember('AP_Observed_Active_Ratio', MetricSummary.Properties.VariableNames)
        plot(MetricSummary.Eval_Time_Min, MetricSummary.AP_Observed_Active_Ratio, 'b-o', 'LineWidth', 1.4);
    else
        plot(nan, nan);
    end
    grid on;
    ylim([0 1.05]);
    xlabel('FARSITE time (min)');
    ylabel('Ratio');
    title('AP Observation Ratio');

    subplot(2,2,3);
    if ismember('Observation_Latency_Mean_Min', MetricSummary.Properties.VariableNames)
        plot(MetricSummary.Eval_Time_Min, MetricSummary.Observation_Latency_Mean_Min, 'm-o', 'LineWidth', 1.4);
        hold on;
        plot(MetricSummary.Eval_Time_Min, MetricSummary.Observation_Latency_Max_Min, 'm--', 'LineWidth', 1.1);
        legend({'Mean', 'Max'}, 'Location', 'best');
        hold off;
    else
        plot(nan, nan);
    end
    grid on;
    xlabel('FARSITE time (min)');
    ylabel('Latency (min)');
    title('Observation Latency');

    subplot(2,2,4);
    stairs(WindowSummary.Eval_Time_Min, WindowSummary.N_Enqueued, 'Color', [0.1 0.55 0.1], 'LineWidth', 1.4);
    hold on;
    stairs(WindowSummary.Eval_Time_Min, WindowSummary.N_Success_ACKed, 'k-', 'LineWidth', 1.4);
    grid on;
    xlabel('FARSITE time (min)');
    ylabel('Packet count / window');
    title('Alarm Load and ACKed Success');
    legend({'Enqueued', 'ACKed success'}, 'Location', 'best');
    hold off;

    Save_Figure_If_Requested(fig, save_figures, fig_dir, 'Multiscale_Fire_Observation_Timeline');
end

function Plot_WLAN_Window_Performance(WindowSummary, APSuccessLog, save_figures, fig_dir)
    fig = figure('Name', 'Multi-Scale WLAN Window Performance', ...
        'NumberTitle', 'off', 'Color', 'w', ...
        'Units', 'pixels', 'Position', Get_Large_Figure_Position(1600, 950));

    subplot(2,2,1);
    plot(WindowSummary.Eval_Time_Min, WindowSummary.Throughput_Mbps, 'k-o', 'LineWidth', 1.4);
    grid on;
    xlabel('FARSITE time (min)');
    ylabel('Throughput (Mb/s)');
    title('Window Throughput');

    subplot(2,2,2);
    ratio_vars = {'Success_Ratio_ACKed','Collision_Ratio_Data','ACK_Timeout_Ratio','Loss_Ratio'};
    ratio_data = nan(height(WindowSummary), numel(ratio_vars));
    for k = 1:numel(ratio_vars)
        if ismember(ratio_vars{k}, WindowSummary.Properties.VariableNames)
            ratio_data(:,k) = WindowSummary.(ratio_vars{k});
        end
    end
    plot(WindowSummary.Eval_Time_Min, ratio_data, 'LineWidth', 1.25);
    grid on;
    xlabel('FARSITE time (min)');
    ylabel('Ratio');
    title('MAC Reliability Ratios');
    legend({'Success', 'Data collision', 'ACK timeout', 'Loss'}, 'Location', 'best');

    subplot(2,2,3);
    bar(WindowSummary.Eval_Time_Min, [WindowSummary.N_Access, WindowSummary.N_Data_Collision, WindowSummary.N_ACK_Timeout]);
    grid on;
    xlabel('FARSITE time (min)');
    ylabel('Count / window');
    title('Access and Failure Events');
    legend({'Access', 'Data collision', 'ACK timeout'}, 'Location', 'best');

    subplot(2,2,4);
    if ~isempty(APSuccessLog) && ismember('Delivery_Delay_s', APSuccessLog.Properties.VariableNames)
        histogram(APSuccessLog.Delivery_Delay_s, 20);
    else
        histogram(nan);
    end
    grid on;
    xlabel('Packet delivery delay (s)');
    ylabel('Frequency');
    title('AP Success Delivery Delay');

    Save_Figure_If_Requested(fig, save_figures, fig_dir, 'Multiscale_WLAN_Window_Performance');
end

function Plot_Reconstruction_Accuracy(MetricSummary, save_figures, fig_dir)
    if isempty(MetricSummary)
        return;
    end

    fig = figure('Name', 'Multi-Scale Front Reconstruction Accuracy', ...
        'NumberTitle', 'off', 'Color', 'w', ...
        'Units', 'pixels', 'Position', Get_Large_Figure_Position(1600, 950));

    subplot(2,2,1);
    Plot_If_Var(MetricSummary, 'Eval_Time_Min', 'Burned_Area_IoU', 'b-o');
    grid on;
    ylim([0 1.05]);
    xlabel('FARSITE time (min)');
    ylabel('IoU');
    title('Burned-Area IoU');

    subplot(2,2,2);
    hold on;
    Plot_If_Var(MetricSummary, 'Eval_Time_Min', 'False_Burned_Ratio', 'r-o');
    Plot_If_Var(MetricSummary, 'Eval_Time_Min', 'Missed_Burned_Ratio', 'k--o');
    grid on;
    ylim([0 1.05]);
    xlabel('FARSITE time (min)');
    ylabel('Ratio');
    title('False / Missed Burned Area');
    legend({'False burned', 'Missed burned'}, 'Location', 'best');
    hold off;

    subplot(2,2,3);
    hold on;
    Plot_If_Var(MetricSummary, 'Eval_Time_Min', 'Mean_Front_Distance_m', 'Color', [0 0.45 1], 'Marker', 'o');
    Plot_If_Var(MetricSummary, 'Eval_Time_Min', 'Hausdorff_Front_Distance_m', 'Color', [0.85 0.33 0.1], 'Marker', 's', 'LineStyle', '--');
    grid on;
    xlabel('FARSITE time (min)');
    ylabel('Distance (m)');
    title('Front Distance Error');
    legend({'Mean', 'Hausdorff'}, 'Location', 'best');
    hold off;

    subplot(2,2,4);
    if ismember('Reconstruction_Available', MetricSummary.Properties.VariableNames)
        stairs(MetricSummary.Eval_Time_Min, double(MetricSummary.Reconstruction_Available), 'k-', 'LineWidth', 1.4);
    else
        stairs(nan, nan);
    end
    grid on;
    ylim([-0.05 1.05]);
    xlabel('FARSITE time (min)');
    ylabel('Available');
    title('Reconstruction Availability');

    Save_Figure_If_Requested(fig, save_figures, fig_dir, 'Multiscale_Reconstruction_Accuracy');
end

function Plot_Runtime_Reduction(RuntimeSummary, save_figures, fig_dir)
    if isempty(RuntimeSummary)
        return;
    end

    fig = figure('Name', 'Multi-Scale Runtime Reduction', ...
        'NumberTitle', 'off', 'Color', 'w', ...
        'Units', 'pixels', 'Position', Get_Large_Figure_Position(1500, 850));

    subplot(1,2,1);
    bar(categorical({'Packet-level simulated','Equivalent full timeline'}), ...
        [RuntimeSummary.Packet_Level_Slots_Simulated, RuntimeSummary.Equivalent_Full_Timeline_Slots]);
    set(gca, 'YScale', 'log');
    grid on;
    ylabel('Slots (log scale)');
    title('Simulated Slot Count');

    subplot(1,2,2);
    reduction_pct = RuntimeSummary.Estimated_Slot_Reduction * 100;
    bar(reduction_pct, 'FaceColor', [0.1 0.55 0.1]);
    ylim([0 100]);
    grid on;
    ylabel('Reduction (%)');
    title(sprintf('Estimated Slot Reduction: %.3f%%', reduction_pct));
    set(gca, 'XTickLabel', {'Multi-scale'});

    Save_Figure_If_Requested(fig, save_figures, fig_dir, 'Multiscale_Runtime_Reduction');
end

function Plot_Farsite_AP_Observation_Map(Model, SimState, SimParams, APSuccessLog, save_figures, fig_dir)
    fig = figure('Name', 'FARSITE AP Observation Map', ...
        'NumberTitle', 'off', 'Color', 'w', ...
        'Units', 'pixels', 'Position', Get_Large_Figure_Position(1800, 1000));
    ax = axes(fig);
    hold(ax, 'on');

    h_img = imagesc(ax, Model.Arrival_X(1,:), Model.Arrival_Y(:,1), Model.Arrival_Time_Min);
    set(h_img, 'AlphaData', isfinite(Model.Arrival_Time_Min) * 0.72);
    axis(ax, 'xy');
    colormap(ax, jet);
    cb = colorbar(ax);
    cb.Label.String = 'FARSITE arrival time (min)';

    idx_alarm = SimParams.idx_STA_Type1;
    pos_alarm = SimState.Node.Pos(idx_alarm, :);
    first_success = inf(numel(idx_alarm), 1);
    if ~isempty(APSuccessLog) && ismember('Sensor_ID', APSuccessLog.Properties.VariableNames)
        for k = 1:height(APSuccessLog)
            sid = APSuccessLog.Sensor_ID(k);
            if sid >= 1 && sid <= numel(first_success)
                first_success(sid) = min(first_success(sid), APSuccessLog.Rx_Fire_Time_Min(k));
            end
        end
    end

    no_success = ~isfinite(first_success);
    if any(no_success)
        scatter(ax, pos_alarm(no_success,1), pos_alarm(no_success,2), 16, [0.82 0.82 0.82], ...
            'filled', 'MarkerEdgeColor', [0.45 0.45 0.45], 'DisplayName', 'No AP success');
    end
    if any(~no_success)
        scatter(ax, pos_alarm(~no_success,1), pos_alarm(~no_success,2), 28, first_success(~no_success), ...
            'filled', 'MarkerEdgeColor', 'k', 'DisplayName', 'First AP success time');
    end

    pos_ap = SimState.Node.Pos(SimParams.idx_AP, :);
    plot(ax, pos_ap(:,1), pos_ap(:,2), 'kp', 'MarkerFaceColor', 'y', ...
        'MarkerSize', 13, 'LineWidth', 1.4, 'DisplayName', 'AP');

    axis(ax, 'equal');
    axis(ax, 'tight');
    grid(ax, 'on');
    xlabel(ax, 'X (m)');
    ylabel(ax, 'Y (m)');
    title(ax, 'FARSITE Arrival Map and AP-observed Sensors');
    legend(ax, 'Location', 'bestoutside');
    hold(ax, 'off');

    Save_Figure_If_Requested(fig, save_figures, fig_dir, 'Multiscale_AP_Observation_Map');
end

function Plot_If_Var(T, x_var, y_var, varargin)
    if ismember(x_var, T.Properties.VariableNames) && ismember(y_var, T.Properties.VariableNames)
        plot(T.(x_var), T.(y_var), varargin{:}, 'LineWidth', 1.3);
    else
        plot(nan, nan, varargin{:}, 'LineWidth', 1.3);
    end
end

function Save_Figure_If_Requested(fig, save_figures, fig_dir, basename)
    if ~save_figures
        return;
    end
    saveas(fig, fullfile(fig_dir, [basename '.png']));
    savefig(fig, fullfile(fig_dir, [basename '.fig']));
end

function val = Get_Field_Or_Default(S, field_name, default_val)
    if isstruct(S) && isfield(S, field_name) && ~isempty(S.(field_name))
        val = S.(field_name);
    else
        val = default_val;
    end
end
