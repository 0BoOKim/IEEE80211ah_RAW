function Results = ED_Run_TXLOG_Sequential_Experiment(Exp)
%ED_RUN_TXLOG_SEQUENTIAL_EXPERIMENT Run independent bounded-memory sequences.

    Validate_Experiment(Exp);
    Exp.BaseParams = Build_Base_Params();
    scenario_sets = Build_Scenario_Sets(Exp);

    quiet = isfield(Exp, 'Quiet') && Exp.Quiet;
    if ~quiet
        fprintf('=== Event-Driven Sequential Disaster TX_LOG Comparison ===\n');
        fprintf(['Disasters=%d, alarm STAs=%d, BSS=%d, history=%d slots, ' ...
            'fire compression=%.2fx\n'], ...
            Exp.DisasterCount, Exp.TotalAlarmSTA, Exp.N_BSS, ...
            Exp.ChannelHistorySlots, Exp.FireTimeCompression);
        fprintf(['Fixed ROS=%.2f m/s, Changed ROS=[%s] m/s, ' ...
            'alarm interval=%.1f s\n'], ...
            Exp.FireSpreadNominalROS_mps, ...
            strtrim(sprintf('%.2f ', Exp.ChangedROSSequence_mps)), ...
            Exp.AlarmIntervalSec);
    end

    fixed_network = [];
    if Exp.UsePrecomputedNetworkInfo
        fixed_network = Build_Fixed_Network( ...
            Exp, scenario_sets(1).Specs(1));
    end

    tasks = Build_Tasks(scenario_sets, Exp);
    summary_cells = cell(numel(tasks), 1);
    trace_cells = cell(numel(tasks), 1);
    txlog_cells = cell(numel(tasks), 1);

    parallel_ready = Prepare_Parallel(Exp);
    if parallel_ready
        parfor task_idx = 1:numel(tasks)
            [summary_cells{task_idx}, trace_cells{task_idx}, ...
                txlog_cells{task_idx}] = Run_Task( ...
                Exp, tasks{task_idx}, fixed_network);
        end
    else
        for task_idx = 1:numel(tasks)
            [summary_cells{task_idx}, trace_cells{task_idx}, ...
                txlog_cells{task_idx}] = Run_Task( ...
                Exp, tasks{task_idx}, fixed_network);
        end
    end

    Summary = vertcat(summary_cells{:});
    TimeSeries = Vertcat_Nonempty(trace_cells);
    TXLOGStats = Vertcat_Nonempty(txlog_cells);
    Aggregate = Build_Aggregate(Summary);

    write_files = ~isfield(Exp, 'WriteResultFiles') || ...
        Exp.WriteResultFiles;
    if write_files
        writetable(Summary, [Exp.SavePrefix '_Summary.csv']);
        writetable(Aggregate, [Exp.SavePrefix '_Aggregate.csv']);
        if ~isempty(TimeSeries)
            writetable(TimeSeries, [Exp.SavePrefix '_TimeSeries.csv']);
        end
        if ~isempty(TXLOGStats)
            writetable(TXLOGStats, [Exp.SavePrefix '_TXLOGStats.csv']);
        end
    end

    Results = struct();
    Results.Summary = Summary;
    Results.Aggregate = Aggregate;
    Results.TimeSeries = TimeSeries;
    Results.TXLOGStats = TXLOGStats;
    Results.Experiment = Exp;

    if ~quiet
        if write_files
            fprintf('Saved event-driven results with prefix: %s\n', ...
                Exp.SavePrefix);
        else
            fprintf('Completed event-driven experiment without CSV output.\n');
        end
    end
end

function Validate_Experiment(Exp)
    positive_fields = {'DisasterCount', 'TotalAlarmSTA', ...
        'ReferenceAlarmSTA', 'N_BSS', 'NRAW', ...
        'SlotDurationCount', 'ChannelHistorySlots', ...
        'FireSpreadReferenceDistance_m', ...
        'FireSpreadNominalROS_mps', 'FireTimeCompression', ...
        'SequenceAlpha', 'SequenceBeta', ...
        'SequenceActiveTarget', 'AlarmIntervalSec'};
    for k = 1:numel(positive_fields)
        name = positive_fields{k};
        if ~isfield(Exp, name) || isempty(Exp.(name)) || ...
                ~isscalar(Exp.(name)) || ~isfinite(Exp.(name)) || ...
                Exp.(name) <= 0
            error('ED:InvalidExperiment', ...
                'Exp.%s must be a finite positive scalar.', name);
        end
    end
    if ~isfield(Exp, 'NBackgroundSTA') || ...
            ~isscalar(Exp.NBackgroundSTA) || ...
            ~isfinite(Exp.NBackgroundSTA) || ...
            Exp.NBackgroundSTA < 0 || ...
            Exp.NBackgroundSTA ~= round(Exp.NBackgroundSTA)
        error('ED:InvalidExperiment', ...
            'Exp.NBackgroundSTA must be a nonnegative integer.');
    end
    if ~isfield(Exp, 'ChangedROSSequence_mps') || ...
            isempty(Exp.ChangedROSSequence_mps) || ...
            ~isnumeric(Exp.ChangedROSSequence_mps) || ...
            any(~isfinite(Exp.ChangedROSSequence_mps(:))) || ...
            any(Exp.ChangedROSSequence_mps(:) <= 0)
        error('ED:InvalidExperiment', ...
            ['Exp.ChangedROSSequence_mps must contain finite, ' ...
             'positive ROS values.']);
    end
    if Exp.SequenceActiveTarget > ...
            max(Exp.TotalAlarmSTA, Exp.ReferenceAlarmSTA)
        error('ED:InvalidExperiment', ...
            ['Exp.SequenceActiveTarget cannot exceed the larger of ' ...
             'TotalAlarmSTA and ReferenceAlarmSTA.']);
    end
    if ~isempty(Exp.SurgeWindowSec)
        if ~isscalar(Exp.SurgeWindowSec) || ...
                ~isfinite(Exp.SurgeWindowSec) || ...
                Exp.SurgeWindowSec <= 0
            error('ED:InvalidExperiment', ...
                ['Exp.SurgeWindowSec must be empty or a finite ' ...
                 'positive scalar.']);
        end
        suppress_warning = ...
            isfield(Exp, 'SuppressSurgeWindowWarning') && ...
            Exp.SuppressSurgeWindowWarning;
        if ~suppress_warning
            warning('ED:ROSSequenceMaskedBySurgeWindow', ...
                ['Exp.SurgeWindowSec overrides the ROS-derived activation ' ...
                 'window. Leave it empty for ChangedROS to alter the ' ...
                 'network traffic-arrival rate.']);
        end
    end
end

function Base = Build_Base_Params()
    Base = Get_Config();
    remove = {'Farsite_Model', 'Farsite_Output_Dir', ...
        'Farsite_Arrival_Format', 'Farsite_Arrival_Asc_File', ...
        'BSS_AP_Pos', 'Precomputed_NetworkInfo', ...
        'TX_LOG', 'Norm_TX_LOG', 'Tab_Traffic_Model'};
    for k = 1:numel(remove)
        if isfield(Base, remove{k})
            Base = rmfield(Base, remove{k});
        end
    end
end

function Sets = Build_Scenario_Sets(Exp)
    fixed_label = sprintf('Fixed_ROS_%.2f_mps', ...
        Exp.FireSpreadNominalROS_mps);
    fixed = repmat(Make_Spec(fixed_label, ...
        Exp.SequenceAlpha, Exp.SequenceBeta, ...
        Exp.SequenceActiveTarget, Exp.GeoPreset, ...
        Exp.FireSpreadNominalROS_mps), 1, Exp.DisasterCount);

    ros = Exp.ChangedROSSequence_mps(:).';
    changed = repmat(Make_Spec('', ...
        Exp.SequenceAlpha, Exp.SequenceBeta, ...
        Exp.SequenceActiveTarget, Exp.GeoPreset, ros(1)), ...
        1, Exp.DisasterCount);
    for k = 1:Exp.DisasterCount
        source = mod(k - 1, numel(ros)) + 1;
        label = sprintf('Changed_ROS_%.2f_mps', ros(source));
        changed(k) = Make_Spec(label, ...
            Exp.SequenceAlpha, Exp.SequenceBeta, ...
            Exp.SequenceActiveTarget, Exp.GeoPreset, ros(source));
    end

    Sets(1).Name = "FixedROS";
    Sets(1).Specs = fixed;
    Sets(2).Name = "ChangedROS";
    Sets(2).Specs = changed;

    if isfield(Exp, 'ScenarioSetSelection') && ...
            ~isempty(Exp.ScenarioSetSelection)
        requested = string(Exp.ScenarioSetSelection);
        keep = false(size(Sets));
        for k = 1:numel(Sets)
            keep(k) = any(string(Sets(k).Name) == requested);
        end
        if ~any(keep)
            error('ED:InvalidScenarioSelection', ...
                'ScenarioSetSelection did not match FixedROS or ChangedROS.');
        end
        Sets = Sets(keep);
    end
end

function spec = Make_Spec(label, alpha, beta_param, target, ...
    geo_preset, ros_mps)
    spec.Label = string(label);
    spec.Alpha = alpha;
    spec.Beta = beta_param;
    spec.ActiveTarget = target;
    spec.GeoPreset = string(geo_preset);
    spec.ROS_mps = ros_mps;
end

function tasks = Build_Tasks(scenario_sets, Exp)
    methods = {'Standard_RAW', 'TXLOG_Proposed'};
    if isfield(Exp, 'MethodSelection') && ...
            ~isempty(Exp.MethodSelection)
        requested = string(Exp.MethodSelection);
        keep = ismember(string(methods), requested);
        if ~any(keep)
            error('ED:InvalidMethodSelection', ...
                ['MethodSelection did not match Standard_RAW or ' ...
                 'TXLOG_Proposed.']);
        end
        methods = methods(keep);
    end
    tasks = cell(numel(scenario_sets) * numel(methods), 1);
    task_idx = 0;
    for set_idx = 1:numel(scenario_sets)
        for method_idx = 1:numel(methods)
            task_idx = task_idx + 1;
            tasks{task_idx} = struct( ...
                'Sequence_ID', task_idx, ...
                'Scenario_Set', scenario_sets(set_idx), ...
                'Method', methods{method_idx});
        end
    end
end

function network = Build_Fixed_Network(Exp, spec)
    params = Build_Params( ...
        Exp, spec, 1, 'Standard_RAW', 4, [], [], false);
    [state, ~] = ED_Init_Network(params);
    network.MAP_LoS = state.MAP_LoS;
    network.MAP_RSS = state.MAP_RSS;
    network.Cached_Interferers = state.Cached_Interferers;
    network.Cached_CarrierSenseNodes = ...
        state.Cached_CarrierSenseNodes;
end

function ready = Prepare_Parallel(Exp)
    ready = false;
    if ~Exp.UseParallelSequences || ...
       ~license('test', 'Distrib_Computing_Toolbox')
        return;
    end
    try
        pool = gcp('nocreate');
        if isempty(pool)
            if isempty(Exp.NumWorkers)
                pool = parpool;
            else
                pool = parpool(Exp.NumWorkers);
            end
        end
        ready = true;
        fprintf('Parallel sequence execution: %d workers.\n', ...
            pool.NumWorkers);
    catch ME
        warning('ED:ParallelUnavailable', ...
            'Parallel pool unavailable; using serial execution: %s', ...
            ME.message);
    end
end

function [Summary, TimeSeries, TXLOGStats] = Run_Task( ...
    Exp, task, fixed_network)

    summary_rows = cell(Exp.DisasterCount, 1);
    trace_rows = cell(Exp.DisasterCount, 1);
    txlog_rows = cell(Exp.DisasterCount, 1);
    previous_txlog = [];

    for disaster_idx = 1:Exp.DisasterCount
        spec = task.Scenario_Set.Specs(disaster_idx);
        [raw_mode, uses_txlog, bootstrap] = Select_Mode( ...
            task.Method, disaster_idx);
        collect_txlog = strcmp(task.Method, 'TXLOG_Proposed');
        case_id = (task.Sequence_ID - 1) * ...
            Exp.DisasterCount + disaster_idx;

        if Exp.ShowProgress
            fprintf(['[ED %s | %s | D%02d] target=%d, ' ...
                'a=%.2f, b=%.2f, ROS=%.2f m/s\n'], ...
                task.Scenario_Set.Name, task.Method, disaster_idx, ...
                spec.ActiveTarget, spec.Alpha, spec.Beta, spec.ROS_mps);
        end

        params = Build_Params(Exp, spec, disaster_idx, ...
            task.Method, raw_mode, previous_txlog, ...
            fixed_network, collect_txlog);
        timer = tic;
        [state, trace] = ED_Run_Disaster(params);
        elapsed = toc(timer);

        trace = Decorate_Trace(trace, state, params, Exp, ...
            task.Scenario_Set.Name, spec, task.Method, ...
            disaster_idx, case_id, uses_txlog, bootstrap);
        trace_rows{disaster_idx} = trace;
        summary_rows{disaster_idx} = Build_Summary( ...
            state, params, task.Scenario_Set.Name, spec, ...
            task.Method, disaster_idx, case_id, ...
            uses_txlog, bootstrap, elapsed, trace);

        if collect_txlog
            [previous_txlog, stats] = Build_TXLOG( ...
                state, task.Scenario_Set.Name, spec, task.Method, ...
                disaster_idx, case_id, uses_txlog);
            txlog_rows{disaster_idx} = struct2table(stats);
            if Exp.SaveTXLOGFiles
                Unnamed_Tab = previous_txlog; %#ok<NASGU>
                TXLOG_Metadata = stats; %#ok<NASGU>
                filename = sprintf('%s_%s_D%02d_TXLOG.mat', ...
                    Exp.SavePrefix, char(task.Scenario_Set.Name), ...
                    disaster_idx);
                save(filename, 'Unnamed_Tab', 'TXLOG_Metadata');
            end
        end
    end

    Summary = vertcat(summary_rows{:});
    TimeSeries = Vertcat_Nonempty(trace_rows);
    TXLOGStats = Vertcat_Nonempty(txlog_rows);
end

function [raw_mode, uses_txlog, bootstrap] = ...
    Select_Mode(method, disaster_idx)
    if strcmp(method, 'Standard_RAW')
        raw_mode = 4;
        uses_txlog = false;
        bootstrap = false;
    else
        bootstrap = disaster_idx == 1;
        uses_txlog = ~bootstrap;
        if bootstrap
            raw_mode = 4;
        else
            raw_mode = 3;
        end
    end
end

function P = Build_Params(Exp, spec, disaster_idx, method, ...
    raw_mode, previous_txlog, fixed_network, collect_txlog)
    P = ED_Build_Disaster_Params(Exp, spec, disaster_idx, method, ...
        raw_mode, previous_txlog, fixed_network, collect_txlog);
end

function Trace = Decorate_Trace(Trace, state, P, Exp, ...
    scenario_name, spec, method, disaster_idx, case_id, ...
    uses_txlog, bootstrap)

    if isempty(Trace)
        return;
    end
    n = height(Trace);
    Trace.Case_ID = repmat(case_id, n, 1);
    Trace.Scenario_Set = repmat(string(scenario_name), n, 1);
    Trace.Method = repmat(string(method), n, 1);
    Trace.Disaster_Idx = repmat(disaster_idx, n, 1);
    Trace.Uses_TX_LOG = repmat(uses_txlog, n, 1);
    Trace.Bootstrap_Disaster = repmat(bootstrap, n, 1);
    Trace.Disaster_Label = repmat(spec.Label, n, 1);
    Trace.Alpha = repmat(spec.Alpha, n, 1);
    Trace.Beta = repmat(spec.Beta, n, 1);
    Trace.Nominal_ROS_mps = repmat(spec.ROS_mps, n, 1);
    Trace.Physical_Fire_Window_s = repmat( ...
        P.Fire_Physical_Window_s, n, 1);
    Trace.Network_Fire_Window_s = repmat( ...
        P.Fire_Network_Window_s, n, 1);
    Trace.Total_Alarm_STA = repmat(Exp.TotalAlarmSTA, n, 1);
    Trace.Target_Active_Alarm_STA = repmat( ...
        Count_Physical_Target(state, ...
        P.Reference_Target_Active_Alarm_STA), n, 1);
    Trace.Physical_Fire_Elapsed_s = min( ...
        P.Fire_Physical_Window_s, ...
        max(0, Trace.TimeSec - P.Opt_Start * P.T_slot) * ...
        P.Fire_Time_Compression);

    dt = [max(1, Trace.TimeSlot(1)); ...
        max(1, diff(Trace.TimeSlot))];
    fields = {'N_Enqueued', 'N_Access', 'N_Success_ACKed', ...
        'N_Data_Collision', 'N_ACK_Timeout', 'N_Loss', ...
        'Success_Bytes'};
    for k = 1:numel(fields)
        values = Trace.(fields{k});
        Trace.(['Interval_' fields{k}]) = ...
            [values(1); diff(values)];
    end
    Trace.Interval_Throughput_Mbps = ...
        Trace.Interval_Success_Bytes * 8 ./ ...
        (dt * P.T_slot) / 1e6;
    Trace.Interval_PDR_ACKed_Over_Enqueued = Safe_Divide( ...
        Trace.Interval_N_Success_ACKed, Trace.Interval_N_Enqueued);
    Trace.Interval_Loss_Ratio_Over_Enqueued = Safe_Divide( ...
        Trace.Interval_N_Loss, Trace.Interval_N_Enqueued);
    Trace.Interval_Success_Ratio_ACKed_Over_Access = Safe_Divide( ...
        Trace.Interval_N_Success_ACKed, Trace.Interval_N_Access);
    Trace.Interval_Collision_Ratio_Data = Safe_Divide( ...
        Trace.Interval_N_Data_Collision, Trace.Interval_N_Access);
end

function Summary = Build_Summary(state, P, scenario_name, ...
    spec, method, disaster_idx, case_id, uses_txlog, ...
    bootstrap, elapsed, Trace)

    sta = P.idx_STA;
    enqueued = sum(state.n_enq(sta));
    access = sum(state.n_access(sta));
    success = sum(state.n_success2(sta));
    collision = sum(state.n_collision(sta));
    timeout = sum(state.n_collision2(sta));
    loss = sum(state.n_loss(sta));
    delays = Collect_Delays(state, sta);

    row.Case_ID = case_id;
    row.Scenario_Set = string(scenario_name);
    row.Method = string(method);
    row.Disaster_Idx = disaster_idx;
    row.Uses_TX_LOG = uses_txlog;
    row.Bootstrap_Disaster = bootstrap;
    row.RAW_Mode_Used = P.RAW_Mode;
    row.RAW_Offset_Mode = string(P.RAW_Offset_Mode);
    row.RAW_Offset_Beacons = sum( ...
        [state.BSS.RAW_Offset_Beacon_Count]);
    row.RAW_Offset_Changes = sum( ...
        [state.BSS.RAW_Offset_Change_Count]);
    row.RAW_Offset_Repeats = sum( ...
        [state.BSS.RAW_Offset_Repeat_Count]);
    row.Disaster_Label = spec.Label;
    row.Alpha = spec.Alpha;
    row.Beta = spec.Beta;
    row.Nominal_ROS_mps = spec.ROS_mps;
    row.Target_Active_Alarm_STA = Count_Physical_Target( ...
        state, P.Reference_Target_Active_Alarm_STA);
    row.Final_Active_Alarm_STA = sum(arrayfun( ...
        @(id) state.Node.TX_Buffer(id).Triggered == 1, ...
        P.idx_STA_Type1));
    row.N_Enqueued = enqueued;
    row.N_Access = access;
    row.N_Success_ACKed = success;
    row.N_Data_Collision = collision;
    row.N_ACK_Timeout = timeout;
    row.N_Loss = loss;
    row.Final_Buffered_Frames = sum(arrayfun( ...
        @(id) state.Node.TX_Buffer(id).Length, sta));
    row.PDR_ACKed_Over_Enqueued = Scalar_Divide(success, enqueued);
    row.Loss_Ratio_Over_Enqueued = Scalar_Divide(loss, enqueued);
    row.Success_Ratio_ACKed_Over_Access = ...
        Scalar_Divide(success, access);
    row.Collision_Ratio_Data = Scalar_Divide(collision, access);
    row.ACK_Timeout_Ratio = Scalar_Divide(timeout, access);
    row.Throughput_Mbps = sum(state.L_success(sta)) * 8 / ...
        (P.N_slot * P.T_slot) / 1e6;
    row.Delay_Mean_s = mean(delays, 'omitnan') * P.T_slot;
    row.Delay_P95_s = Percentile(delays, 95) * P.T_slot;
    row.SimTimeSec = P.N_slot * P.T_slot;
    row.Physical_Fire_Window_s = P.Fire_Physical_Window_s;
    row.Network_Fire_Window_s = P.Fire_Network_Window_s;
    row.Fire_Time_Compression = P.Fire_Time_Compression;
    row.Alarm_Interval_s = P.Alarm_Report_Interval_s;
    row.Alarm_Payload_Bytes = P.Alarm_Payload_Bytes;
    row.Elapsed_s = elapsed;
    row.Processed_Event_Slots = state.ED_Stats.ProcessedSlots;
    row.Skipped_Idle_Slots = state.ED_Stats.SkippedSlots;
    row.Processed_Slot_Ratio = Scalar_Divide( ...
        state.ED_Stats.ProcessedSlots, P.N_slot);
    row.Max_Jump_Slots = state.ED_Stats.MaxJumpSlots;
    row.Channel_History_Bytes = state.ED_Stats.ChannelHistoryBytes;
    row.Legacy_tx_state_Bytes_Avoided = ...
        state.ED_Stats.LegacyTxStateBytesAvoided;
    row.Beta_Activation_Event_Rows = ...
        size(P.ED_Beta_Activation_Events, 1);
    row.Dense_Beta_Samples_Avoided = ...
        P.Period + 1 - size(P.ED_Beta_Activation_Events, 1);

    if isempty(Trace)
        row.First_Loss_Sec = NaN;
        row.Active_STA_At_First_Loss = NaN;
    else
        first_loss = find(Trace.N_Loss > 0, 1, 'first');
        if isempty(first_loss)
            row.First_Loss_Sec = NaN;
            row.Active_STA_At_First_Loss = NaN;
        else
            row.First_Loss_Sec = Trace.TimeSec(first_loss);
            row.Active_STA_At_First_Loss = ...
                Trace.ActiveAlarmSTA(first_loss);
        end
    end
    Summary = struct2table(row);
end

function [TXLOG, stats] = Build_TXLOG(state, scenario_name, ...
    spec, method, disaster_idx, case_id, uses_txlog)

    if isfield(state, 'TX_LOG_Aggregate_Bins')
        aggregate = state.TX_LOG_Aggregate_Bins;
        complete = aggregate(:, 4) > 0;
        aggregate = aggregate(complete, :);
        if isempty(aggregate)
            TXLOG = [0 0 1 1 0 1 1 0 1 0 1];
        else
            aggregate = sortrows(aggregate, [1 2]);
            bins = aggregate(:, 1:2);
            count = aggregate(:, 4);
            fail = aggregate(:, 5);
            success = aggregate(:, 6);
            TXLOG = [bins, count, count, fail, success, ...
                count ./ count, fail ./ count, success ./ count, ...
                fail ./ count, success ./ count];
        end
        access_rows = sum(state.TX_LOG_Aggregate_Bins(:, 3));
        completed_rows = sum(state.TX_LOG_Aggregate_Bins(:, 4));
    elseif isfield(state, 'TX_LOG_Access_Log')
        access_log = state.TX_LOG_Access_Log;
        complete = access_log(:, 11) == 1;
        access_log = access_log(complete, :);
        if isempty(access_log)
            TXLOG = [0 0 1 1 0 1 1 0 1 0 1];
        else
            ch_bin = ceil(access_log(:, 4) / 0.1) * 0.1;
            ack_bin = ceil(access_log(:, 5) / 5) * 5;
            [bins, ~, group] = unique([ch_bin, ack_bin], 'rows');
            count = accumarray(group, 1);
            fail = accumarray(group, access_log(:, 7));
            success = accumarray(group, access_log(:, 8));
            TXLOG = [bins, count, count, fail, success, ...
                count ./ count, fail ./ count, success ./ count, ...
                fail ./ count, success ./ count];
        end
        access_rows = size(state.TX_LOG_Access_Log, 1);
        completed_rows = size(access_log, 1);
    else
        TXLOG = [0 0 1 1 0 1 1 0 1 0 1];
        access_rows = 0;
        completed_rows = 0;
    end
    TXLOG(:, 10:11) = min(1, max(0, TXLOG(:, 10:11)));

    stats.Case_ID = case_id;
    stats.Scenario_Set = string(scenario_name);
    stats.Method = string(method);
    stats.Disaster_Idx = disaster_idx;
    stats.Uses_TX_LOG = uses_txlog;
    stats.Disaster_Label = spec.Label;
    stats.Alpha = spec.Alpha;
    stats.Beta = spec.Beta;
    stats.Nominal_ROS_mps = spec.ROS_mps;
    stats.AccessLog_Rows = access_rows;
    stats.Completed_AccessLog_Rows = completed_rows;
    stats.TXLOG_Rows = size(TXLOG, 1);
    stats.TXLOG_Min_TX_Prob = min(TXLOG(:, 11));
    stats.TXLOG_Mean_TX_Prob = mean(TXLOG(:, 11));
    stats.TXLOG_Max_TX_Prob = max(TXLOG(:, 11));
    stats.TXLOG_Total_Access = sum(TXLOG(:, 4));
    stats.TXLOG_Total_Fail = sum(TXLOG(:, 5));
    stats.TXLOG_Total_Success = sum(TXLOG(:, 6));
end

function Aggregate = Build_Aggregate(Summary)
    scenarios = unique(Summary.Scenario_Set, 'stable');
    methods = unique(Summary.Method, 'stable');
    rows = cell(numel(scenarios) * numel(methods), 1);
    row_idx = 0;
    for s = 1:numel(scenarios)
        for m = 1:numel(methods)
            mask = Summary.Scenario_Set == scenarios(s) & ...
                Summary.Method == methods(m);
            if methods(m) == "TXLOG_Proposed"
                mask = mask & ~Summary.Bootstrap_Disaster;
            end
            row_idx = row_idx + 1;
            row.Scenario_Set = scenarios(s);
            row.Method = methods(m);
            row.N = sum(mask);
            ros_values = Summary.Nominal_ROS_mps(mask);
            row.Mean_Nominal_ROS_mps = mean( ...
                ros_values, 'omitnan');
            row.Min_Nominal_ROS_mps = Finite_Min(ros_values);
            row.Max_Nominal_ROS_mps = Finite_Max(ros_values);
            row.Mean_Throughput_Mbps = mean( ...
                Summary.Throughput_Mbps(mask), 'omitnan');
            row.Mean_PDR = mean( ...
                Summary.PDR_ACKed_Over_Enqueued(mask), 'omitnan');
            row.Mean_Loss_Ratio = mean( ...
                Summary.Loss_Ratio_Over_Enqueued(mask), 'omitnan');
            row.Mean_Collision_Ratio = mean( ...
                Summary.Collision_Ratio_Data(mask), 'omitnan');
            row.Mean_Delay_s = mean( ...
                Summary.Delay_Mean_s(mask), 'omitnan');
            row.Mean_Processed_Slot_Ratio = mean( ...
                Summary.Processed_Slot_Ratio(mask), 'omitnan');
            row.Mean_Elapsed_s = mean( ...
                Summary.Elapsed_s(mask), 'omitnan');
            rows{row_idx} = row;
        end
    end
    Aggregate = struct2table([rows{:}]);
end

function result = Vertcat_Nonempty(cells)
    keep = cellfun(@(x) istable(x) && ~isempty(x), cells);
    if any(keep)
        result = vertcat(cells{keep});
    else
        result = table();
    end
end

function n = Count_Physical_Target(state, reference_target)
    n = sum(state.Alarm_Reference_Rank <= reference_target);
end

function delays = Collect_Delays(state, node_ids)
    delays = [];
    for node_id = node_ids
        if ~isempty(state.Delay(node_id).delay)
            delays = [delays; ...
                state.Delay(node_id).delay(:, 3)]; %#ok<AGROW>
        end
    end
end

function value = Percentile(values, pct)
    values = sort(values(isfinite(values)));
    if isempty(values)
        value = NaN;
        return;
    end
    idx = 1 + (numel(values) - 1) * pct / 100;
    low = floor(idx);
    high = ceil(idx);
    if low == high
        value = values(low);
    else
        value = values(low) + ...
            (idx - low) * (values(high) - values(low));
    end
end

function value = Finite_Min(values)
    values = values(isfinite(values));
    if isempty(values)
        value = NaN;
    else
        value = min(values);
    end
end

function value = Finite_Max(values)
    values = values(isfinite(values));
    if isempty(values)
        value = NaN;
    else
        value = max(values);
    end
end

function ratio = Safe_Divide(numerator, denominator)
    ratio = nan(size(numerator));
    valid = denominator ~= 0;
    ratio(valid) = numerator(valid) ./ denominator(valid);
end

function ratio = Scalar_Divide(numerator, denominator)
    if denominator == 0
        ratio = NaN;
    else
        ratio = numerator / denominator;
    end
end
