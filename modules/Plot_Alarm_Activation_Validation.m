function Plot_Alarm_Activation_Validation(SimState, SimParams)
    if ~isfield(SimParams, 'idx_STA_Type1') || isempty(SimParams.idx_STA_Type1)
        return;
    end

    idx_alarm = SimParams.idx_STA_Type1;
    N_alarm = length(idx_alarm);

    Trigger_Time = inf(N_alarm, 1);
    for n = 1:N_alarm
        idx = idx_alarm(n);
        if isfield(SimState.Node.TX_Buffer(idx), 'Trigger_Time')
            Trigger_Time(n) = SimState.Node.TX_Buffer(idx).Trigger_Time;
        end
    end

    is_triggered = isfinite(Trigger_Time);
    Trigger_Sorted = sort(Trigger_Time(is_triggered), 'ascend');
    Actual_Count = (1:length(Trigger_Sorted)).';

    figure('Name', 'Alarm Activation Validation', ...
        'NumberTitle', 'off', 'Color', 'w', ...
        'Units', 'pixels', 'Position', Get_Large_Figure_Position(1700, 850));

    % 1) Temporal validation: expected cumulative activation vs actual.
    subplot(1,2,1);
    hold on;
    h = [];
    labels = {};
    if isfield(SimParams, 'Tab_Traffic_Model')
        t_expected = SimParams.Tab_Traffic_Model(1,:);
        a_expected = floor(SimParams.Tab_Traffic_Model(2,:));
        t_max = min(SimParams.N_slot, SimParams.Opt_End);
        valid_idx = (t_expected >= SimParams.Opt_Start) & (t_expected <= t_max);
        h(end+1) = plot(t_expected(valid_idx), a_expected(valid_idx), 'k-', 'LineWidth', 1.5);
        labels{end+1} = 'Expected (Beta)';
    end
    if isfield(SimParams, 'Farsite_Model') && isfield(SimParams.Farsite_Model, 'Trigger_Time_Slot')
        farsite_slots = SimParams.Farsite_Model.Trigger_Time_Slot(:);
        farsite_slots = sort(farsite_slots(isfinite(farsite_slots)), 'ascend');
        if ~isempty(farsite_slots)
            h(end+1) = stairs(farsite_slots, (1:numel(farsite_slots)).', 'k-', 'LineWidth', 1.5);
            labels{end+1} = 'Expected (FARSITE front)';
        end
    end
    if ~isempty(Trigger_Sorted)
        h(end+1) = stairs(Trigger_Sorted, Actual_Count, 'r-', 'LineWidth', 1.2);
        labels{end+1} = 'Actual (Trigger time)';
    end
    if isfield(SimState, 'Measure_Cummulated_N_Triggerd_STAs') && size(SimState.Measure_Cummulated_N_Triggerd_STAs,1) > 1
        h(end+1) = plot(SimState.Measure_Cummulated_N_Triggerd_STAs(:,1), SimState.Measure_Cummulated_N_Triggerd_STAs(:,2), 'b.');
        labels{end+1} = 'Event log';
    end
    grid on;
    xlabel('Time (slot)');
    ylabel('Cumulative activated alarm STAs');
    title('Temporal Activation Validation');
    if ~isempty(h)
        legend(h, labels, 'Location', 'best');
    end
    hold off;

    % 2) Spatial validation: node position colored by trigger time.
    subplot(1,2,2);
    hold on;
    Pos_Alarm = SimState.Node.Pos(idx_alarm, :);
    if isfield(SimParams, 'Farsite_Model') && ...
       isfield(SimParams.Farsite_Model, 'Arrival_Time_Min')
        contour(SimParams.Farsite_Model.Arrival_X, ...
            SimParams.Farsite_Model.Arrival_Y, ...
            SimParams.Farsite_Model.Arrival_Time_Min, ...
            12, 'LineColor', [0.72 0.72 0.72]);
    end
    if any(is_triggered)
        scatter(Pos_Alarm(is_triggered,1), Pos_Alarm(is_triggered,2), 20, Trigger_Time(is_triggered), 'filled');
        cb = colorbar;
        cb.Label.String = 'Trigger time (slot)';
    end
    if any(~is_triggered)
        scatter(Pos_Alarm(~is_triggered,1), Pos_Alarm(~is_triggered,2), 14, [0.75 0.75 0.75], 'filled');
    end

    if isfield(SimParams, 'idx_AP') && ~isempty(SimParams.idx_AP)
        Pos_AP = SimState.Node.Pos(SimParams.idx_AP, :);
        plot(Pos_AP(:,1), Pos_AP(:,2), 'kp', 'MarkerSize', 12, 'LineWidth', 1.5);
    end

    Seed_Pos = [];
    if isfield(SimState, 'Geo_Mode3_Preset') && isstruct(SimState.Geo_Mode3_Preset) && ...
       isfield(SimState.Geo_Mode3_Preset, 'Seed_Coords') && ~isempty(SimState.Geo_Mode3_Preset.Seed_Coords)
        Seed_Pos = SimState.Geo_Mode3_Preset.Seed_Coords;
    elseif isfield(SimParams, 'Geo_Seed_Coords') && ~isempty(SimParams.Geo_Seed_Coords)
        Seed_Pos = SimParams.Geo_Seed_Coords;
    end
    if ~isempty(Seed_Pos)
        plot(Seed_Pos(:,1), Seed_Pos(:,2), 'rx', 'MarkerSize', 10, 'LineWidth', 1.8);
    end

    axis equal;
    grid on;
    xlabel('x (m)');
    ylabel('y (m)');
    title(sprintf('Spatial Activation Map (Triggered: %d/%d)', sum(is_triggered), N_alarm));
    hold off;
end
