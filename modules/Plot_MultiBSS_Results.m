function Plot_MultiBSS_Results(SimState, SimParams, Stats)
%PLOT_MULTIBSS_RESULTS Visualize multi-BSS topology, surge, and metrics.

    if ~isfield(Stats, 'Per_BSS') || SimParams.N_AP <= 1
        return;
    end

    colors = lines(SimParams.N_AP);
    bss_ids = 1:SimParams.N_AP;

    Plot_Topology(SimState, SimParams, colors);
    Plot_BSS_Traffic_Surge(SimState, SimParams, colors);
    Plot_BSS_Performance(Stats, bss_ids);
end

function Plot_Topology(SimState, SimParams, colors)
    figure('Name', 'Multi-BSS Topology and STA Association', ...
        'NumberTitle', 'off', 'Color', 'w', ...
        'Units', 'pixels', 'Position', Get_Large_Figure_Position(1800, 1000));
    hold on;

    for bss_id = 1:SimParams.N_AP
        sta_ids = SimState.BSS(bss_id).STA_IDs;
        alarm_ids = SimState.BSS(bss_id).Alarm_STA_IDs;
        bk_ids = SimState.BSS(bss_id).BK_STA_IDs;
        active_alarm_ids = Get_Triggered_Alarm_IDs(SimState, alarm_ids);
        light_color = 0.65 * [1 1 1] + 0.35 * colors(bss_id,:);

        if ~isempty(bk_ids)
            scatter(SimState.Node.Pos(bk_ids,1), SimState.Node.Pos(bk_ids,2), ...
                22, light_color, 'o', 'filled', ...
                'DisplayName', sprintf('BSS %d BK STA', bss_id));
        end

        inactive_alarm_ids = setdiff(alarm_ids, active_alarm_ids);
        if ~isempty(inactive_alarm_ids)
            scatter(SimState.Node.Pos(inactive_alarm_ids,1), SimState.Node.Pos(inactive_alarm_ids,2), ...
                24, colors(bss_id,:), '^', ...
                'DisplayName', sprintf('BSS %d inactive alarm', bss_id));
        end

        if ~isempty(active_alarm_ids)
            scatter(SimState.Node.Pos(active_alarm_ids,1), SimState.Node.Pos(active_alarm_ids,2), ...
                42, colors(bss_id,:), '^', 'filled', ...
                'MarkerEdgeColor', 'k', 'LineWidth', 0.7, ...
                'DisplayName', sprintf('BSS %d active alarm', bss_id));
        end

        ap_id = SimState.BSS(bss_id).AP_ID;
        plot(SimState.Node.Pos(ap_id,1), SimState.Node.Pos(ap_id,2), ...
            'p', 'Color', 'k', 'MarkerFaceColor', colors(bss_id,:), ...
            'MarkerSize', 14, 'LineWidth', 1.4, ...
            'DisplayName', sprintf('AP %d', bss_id));
        text(SimState.Node.Pos(ap_id,1), SimState.Node.Pos(ap_id,2), ...
            sprintf('  AP%d', bss_id), 'FontWeight', 'bold');

        if ~isempty(sta_ids)
            for idx = sta_ids(:).'
                plot([SimState.Node.Pos(ap_id,1), SimState.Node.Pos(idx,1)], ...
                     [SimState.Node.Pos(ap_id,2), SimState.Node.Pos(idx,2)], ...
                     '-', 'Color', light_color, 'HandleVisibility', 'off');
            end
        end
    end

    axis equal;
    grid on;
    xlabel('x (m)');
    ylabel('y (m)');
    title('AP Grid and STA Association');
    legend('Location', 'bestoutside');
    hold off;
end

function Plot_BSS_Traffic_Surge(SimState, SimParams, colors)
    figure('Name', 'Per-BSS Alarm Activation and Traffic Surge', ...
        'NumberTitle', 'off', 'Color', 'w', ...
        'Units', 'pixels', 'Position', Get_Large_Figure_Position(1600, 850));

    subplot(1,2,1);
    hold on;
    for bss_id = 1:SimParams.N_AP
        alarm_ids = SimState.BSS(bss_id).Alarm_STA_IDs;
        trigger_times = Get_Trigger_Times(SimState, alarm_ids);
        trigger_times = sort(trigger_times(isfinite(trigger_times)));
        if isempty(trigger_times)
            plot(nan, nan, 'Color', colors(bss_id,:), 'DisplayName', sprintf('BSS %d', bss_id));
        else
            stairs(trigger_times, 1:length(trigger_times), 'Color', colors(bss_id,:), ...
                'LineWidth', 1.4, 'DisplayName', sprintf('BSS %d', bss_id));
        end
    end

    if isfield(SimParams, 'Opt_Start') && isfield(SimParams, 'Opt_End')
        xline(SimParams.Opt_Start, 'k--', 'Start', 'HandleVisibility', 'off');
        xline(SimParams.Opt_End, 'k:', 'End', 'HandleVisibility', 'off');
    end

    grid on;
    xlabel('Time (slot)');
    ylabel('Cumulative active alarm STAs');
    title('Alarm Activation by BSS');
    legend('Location', 'best');
    hold off;

    subplot(1,2,2);
    active_alarm = zeros(1, SimParams.N_AP);
    enqueued_alarm = zeros(1, SimParams.N_AP);
    for bss_id = 1:SimParams.N_AP
        alarm_ids = SimState.BSS(bss_id).Alarm_STA_IDs;
        active_alarm(bss_id) = length(Get_Triggered_Alarm_IDs(SimState, alarm_ids));
        enqueued_alarm(bss_id) = sum(SimState.n_enq(alarm_ids));
    end

    yyaxis left;
    bar(1:SimParams.N_AP, active_alarm, 0.45);
    ylabel('Active alarm STA count');
    yyaxis right;
    plot(1:SimParams.N_AP, enqueued_alarm, 'ko-', 'LineWidth', 1.3);
    ylabel('Alarm MPDUs enqueued');
    grid on;
    xlabel('BSS ID');
    title('Final Surge Load by BSS');
end

function Plot_BSS_Performance(Stats, bss_ids)
    T = Stats.Per_BSS;

    figure('Name', 'Per-BSS Performance Comparison', ...
        'NumberTitle', 'off', 'Color', 'w', ...
        'Units', 'pixels', 'Position', Get_Large_Figure_Position(1600, 950));

    subplot(2,2,1);
    bar(bss_ids, T.Throughput_Mbps);
    grid on;
    xlabel('BSS ID');
    ylabel('Throughput (Mb/s)');
    title('Per-BSS Throughput');

    subplot(2,2,2);
    ratio_data = [T.Success_Ratio_ACKed, T.Collision_Ratio_Data, T.Loss_Ratio];
    bar(bss_ids, ratio_data);
    grid on;
    xlabel('BSS ID');
    ylabel('Ratio');
    title('Success / Collision / Loss');
    legend({'Success', 'Collision', 'Loss'}, 'Location', 'best');

    subplot(2,2,3);
    bar(bss_ids, T.Avg_Delay_s);
    grid on;
    xlabel('BSS ID');
    ylabel('Average delay (s)');
    title('Per-BSS Delay');

    subplot(2,2,4);
    overlap_data = [T.RAW_Overlap_Slots_With_Other_BSS, T.TX_Overlap_Slots_With_Other_BSS];
    bar(bss_ids, overlap_data);
    grid on;
    xlabel('BSS ID');
    ylabel('Slot count');
    title('Overlap with Other BSSs');
    legend({'RAW overlap', 'TX overlap'}, 'Location', 'best');
end

function trigger_times = Get_Trigger_Times(SimState, alarm_ids)
    trigger_times = inf(length(alarm_ids), 1);
    for k = 1:length(alarm_ids)
        idx = alarm_ids(k);
        if isfield(SimState.Node.TX_Buffer(idx), 'Trigger_Time')
            trigger_times(k) = SimState.Node.TX_Buffer(idx).Trigger_Time;
        end
    end
end

function active_alarm_ids = Get_Triggered_Alarm_IDs(SimState, alarm_ids)
    active_alarm_ids = [];
    for idx = alarm_ids(:).'
        if isfield(SimState.Node.TX_Buffer(idx), 'Triggered') && SimState.Node.TX_Buffer(idx).Triggered == 1
            active_alarm_ids(end+1) = idx; %#ok<AGROW>
        end
    end
end
