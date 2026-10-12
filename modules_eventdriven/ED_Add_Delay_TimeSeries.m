function Trace = ED_Add_Delay_TimeSeries(SimState, SimParams, Trace)
%ED_ADD_DELAY_TIMESERIES Add class-specific delay distributions to Trace.
%
% Completion bins describe the delay observed by the AP during each report
% interval. Generation-cohort bins group eventually successful packets by
% when they were generated. Both distributions contain successful packets
% only; interval loss and queue-age columns are logged separately.

    if isempty(Trace)
        return;
    end

    bin_ends = Trace.TimeSlot(:);
    bin_starts = [0; bin_ends(1:end - 1) + 1];
    Trace.Interval_Start_s = bin_starts * SimParams.T_slot;
    Trace.Interval_End_s = bin_ends * SimParams.T_slot;
    Trace.Delay_Statistics_Success_Only = true(height(Trace), 1);

    alarm_rows = Collect_Delay_Rows( ...
        SimState, SimParams.idx_STA_Type1);
    camera_rows = Collect_Delay_Rows( ...
        SimState, Get_Camera_IDs(SimParams));

    Trace = Add_Class_Statistics( ...
        Trace, alarm_rows, bin_ends, SimParams.T_slot, 'Alarm');
    Trace = Add_Class_Statistics( ...
        Trace, camera_rows, bin_ends, SimParams.T_slot, 'Camera');
end

function Trace = Add_Class_Statistics( ...
    Trace, rows, bin_ends, slot_duration, class_name)

    completion = Bin_Delays(rows, 2, bin_ends, slot_duration);
    generation = Bin_Delays(rows, 1, bin_ends, slot_duration);
    Trace = Assign_Statistics(Trace, completion, ...
        ['Interval_' class_name '_Completion_Delay']);
    Trace = Assign_Statistics(Trace, generation, ...
        ['Interval_' class_name '_Generation_Cohort_Delay']);
end

function Trace = Assign_Statistics(Trace, stats, prefix)
    Trace.([prefix '_Count']) = stats.Count;
    Trace.([prefix '_Mean_s']) = stats.Mean;
    Trace.([prefix '_P95_s']) = stats.P95;
    Trace.([prefix '_Min_s']) = stats.Min;
    Trace.([prefix '_Max_s']) = stats.Max;
end

function stats = Bin_Delays(rows, event_column, bin_ends, slot_duration)
    n_bins = numel(bin_ends);
    stats = struct( ...
        'Count', zeros(n_bins, 1), ...
        'Mean', nan(n_bins, 1), ...
        'P95', nan(n_bins, 1), ...
        'Min', nan(n_bins, 1), ...
        'Max', nan(n_bins, 1));
    if isempty(rows)
        return;
    end

    valid = all(isfinite(rows), 2) & rows(:, event_column) >= 0 & ...
        rows(:, 3) >= 0;
    rows = rows(valid, :);
    if isempty(rows)
        return;
    end
    rows = sortrows(rows, event_column);
    events = rows(:, event_column);
    cursor = 1;
    n_rows = size(rows, 1);
    for bin_idx = 1:n_bins
        last = cursor - 1;
        while last < n_rows && events(last + 1) <= bin_ends(bin_idx)
            last = last + 1;
        end
        if last < cursor
            continue;
        end
        delays = rows(cursor:last, 3) * slot_duration;
        stats.Count(bin_idx) = numel(delays);
        stats.Mean(bin_idx) = mean(delays);
        stats.P95(bin_idx) = Percentile(delays, 95);
        stats.Min(bin_idx) = min(delays);
        stats.Max(bin_idx) = max(delays);
        cursor = last + 1;
    end
end

function rows = Collect_Delay_Rows(SimState, node_ids)
    counts = zeros(numel(node_ids), 1);
    for idx = 1:numel(node_ids)
        counts(idx) = SimState.Delay(node_ids(idx)).ED_Count;
    end
    rows = zeros(sum(counts), 3);
    cursor = 1;
    for idx = 1:numel(node_ids)
        count = counts(idx);
        if count <= 0
            continue;
        end
        node_id = node_ids(idx);
        last = cursor + count - 1;
        rows(cursor:last, :) = ...
            SimState.Delay(node_id).ED_Data(1:count, :);
        cursor = last + 1;
    end
end

function ids = Get_Camera_IDs(SimParams)
    if isfield(SimParams, 'idx_Camera_STA')
        ids = SimParams.idx_Camera_STA;
    else
        ids = zeros(1, 0);
    end
end

function value = Percentile(values, pct)
    values = sort(values(isfinite(values)));
    if isempty(values)
        value = NaN;
        return;
    end
    index = 1 + (numel(values) - 1) * pct / 100;
    low = floor(index);
    high = ceil(index);
    if low == high
        value = values(low);
    else
        value = values(low) + (index - low) * ...
            (values(high) - values(low));
    end
end
