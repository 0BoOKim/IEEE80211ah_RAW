function Results = ED_Run_Camera_Overload_Experiment(Cfg)
%ED_RUN_CAMERA_OVERLOAD_EXPERIMENT Run Standard-RAW camera load cases.

    Validate_Config(Cfg);
    n_case = height(Cfg.Cases);
    summary_cells = cell(n_case, 1);
    trace_cells = cell(n_case, 1);
    deployment_cells = cell(n_case, 1);

    if Is_EDCA_Enabled(Cfg)
        access_label = sprintf('EDCA %s camera / %s alarm', ...
            Cfg.CameraAccessCategory, Cfg.AlarmAccessCategory);
    else
        access_label = 'equal contention';
    end
    fprintf('=== Camera-Assisted Wildfire Overload Study (Standard RAW) ===\n');
    fprintf(['Alarm STAs=%d, background STAs=%d, camera stream=' ...
        '%.3f Mbps, cases=%d\n'], Cfg.TotalAlarmSTA, ...
        Cfg.NBackgroundSTA, Cfg.CameraBitrate_bps / 1e6, n_case);
    fprintf('Channel access: %s.\n', access_label);
    fprintf('TX_LOG/proposed-method evaluation is disabled in this study.\n');

    [parallel_ready, parallel_workers] = Prepare_Parallel(Cfg);
    if parallel_ready
        parfor (case_idx = 1:n_case, parallel_workers)
            [summary_cells{case_idx}, trace_cells{case_idx}, ...
                deployment_cells{case_idx}] = Run_One_Case( ...
                Cfg, Cfg.Cases(case_idx, :));
        end
    else
        for case_idx = 1:n_case
            [summary_cells{case_idx}, trace_cells{case_idx}, ...
                deployment_cells{case_idx}] = Run_One_Case( ...
                Cfg, Cfg.Cases(case_idx, :));
        end
    end

    Summary = ED_Vertcat_Compatible_Tables( ...
        summary_cells, 'camera-overload summaries');
    TimeSeries = ED_Vertcat_Compatible_Tables( ...
        trace_cells, 'camera-overload time series');
    Deployment = ED_Vertcat_Compatible_Tables( ...
        deployment_cells, 'camera-overload deployments');

    if Cfg.WriteResultFiles
        writetable(Summary, [Cfg.SavePrefix '_Summary.csv']);
        if ~isempty(TimeSeries)
            writetable(TimeSeries, [Cfg.SavePrefix '_TimeSeries.csv']);
        end
        if ~isempty(Deployment)
            writetable(Deployment, [Cfg.SavePrefix '_Deployment.csv']);
        end
        fprintf('Saved results with prefix: %s\n', Cfg.SavePrefix);
    end

    Results = struct();
    Results.Summary = Summary;
    Results.TimeSeries = TimeSeries;
    Results.Deployment = Deployment;
    Results.Config = Cfg;
    Results.ParallelWorkersUsed = parallel_workers;
end

function [Summary, Trace, Deployment] = Run_One_Case(Cfg, case_row)
    fingerprint = Build_Case_Fingerprint(Cfg, case_row);
    completed_file = Case_Checkpoint_File( ...
        Cfg.SavePrefix, case_row.Case_ID, 'Completed');
    if Cfg.EnableCaseCheckpoints && Cfg.ResumeCompletedCases && ...
       exist(completed_file, 'file') == 2
        loaded = load(completed_file, 'SavedCase');
        if isfield(loaded, 'SavedCase') && ...
           isstruct(loaded.SavedCase) && ...
           all(isfield(loaded.SavedCase, { ...
               'SchemaVersion', 'Fingerprint', 'Summary', ...
               'Trace', 'Deployment'})) && ...
           loaded.SavedCase.SchemaVersion == 2 && ...
           isequaln(loaded.SavedCase.Fingerprint, fingerprint) && ...
           Is_Compatible_Completed_Result(loaded.SavedCase, Cfg)
            Summary = loaded.SavedCase.Summary;
            Trace = loaded.SavedCase.Trace;
            Deployment = loaded.SavedCase.Deployment;
            if Cfg.ShowProgress
                fprintf('[Case %02d | %s] resumed completed result.\n', ...
                    case_row.Case_ID, char(case_row.Case_Label));
            end
            return;
        end
    end

    if Cfg.ShowProgress
        [case_n_raw, case_sdc] = Resolve_Case_RAW_Params(Cfg, case_row);
        fprintf(['[Case %02d | %s] cameras=%d, ROS=%.2f m/s, ' ...
            'N_RAW=%d, SDC=%d\n'], ...
            case_row.Case_ID, char(case_row.Case_Label), ...
            case_row.NCamera, case_row.ROS_mps, case_n_raw, case_sdc);
    end

    Exp = Build_Experiment_Config(Cfg, case_row);
    spec = struct();
    spec.Label = char(case_row.Case_Label);
    spec.Alpha = Cfg.Alpha;
    spec.Beta = Cfg.Beta;
    spec.ActiveTarget = Cfg.TargetActiveAlarmSTA;
    spec.GeoPreset = Cfg.GeoPreset;
    spec.ROS_mps = case_row.ROS_mps;
    P = ED_Build_Disaster_Params( ...
        Exp, spec, 1, 'Standard_RAW', 4, [], [], false);
    P = Configure_Cameras(P, Cfg, case_row.NCamera);
    P = Configure_Channel_Access(P, Cfg);
    P = Configure_Long_Run_Execution( ...
        P, Cfg, case_row, fingerprint);

    timer = tic;
    [SimState, Trace] = ED_Run_Disaster(P);
    elapsed_s = toc(timer);
    Trace = ED_Add_Delay_TimeSeries(SimState, P, Trace);
    Trace = Decorate_Trace(Trace, P, Cfg, case_row);
    Summary = ED_Summarize_Camera_Overload( ...
        SimState, P, Trace, Cfg, case_row, elapsed_s);
    Deployment = Build_Deployment_Table( ...
        SimState, P, Cfg, case_row);

    if Cfg.EnableCaseCheckpoints
        SavedCase = struct();
        SavedCase.SchemaVersion = 2;
        SavedCase.Fingerprint = fingerprint;
        SavedCase.Summary = Summary;
        SavedCase.Trace = Trace;
        SavedCase.Deployment = Deployment;
        Atomic_Save(completed_file, 'SavedCase', SavedCase);
    end
end

function compatible = Is_Compatible_Completed_Result(SavedCase, Cfg)
    required_summary = { ...
        'Case_ID', 'Case_Label', 'Camera_STA', ...
        'Target_Active_Alarm_STA', ...
        'Alarm_PDR', 'Alarm_Initial_Deadline_PDR', ...
        'Alarm_All_Packet_Deadline_PDR', ...
        'Camera_PDR', 'Camera_Deadline_PDR', ...
        'Observed_Network_Overload', 'Elapsed_s'};
    Summary = SavedCase.Summary;
    compatible = istable(Summary) && height(Summary) == 1 && ...
        all(ismember(required_summary, ...
            Summary.Properties.VariableNames));
    if ~compatible
        return;
    end

    Trace = SavedCase.Trace;
    if ~Get_Field_Or_Default(Cfg, 'CollectTimeSeries', false)
        trace_compatible = true;
    else
        required_trace = { ...
            'Alarm_Oldest_Buffered_Age_s', ...
            'Camera_Oldest_Buffered_Age_s', ...
            'Interval_Alarm_Completion_Delay_P95_s', ...
            'Interval_Camera_Completion_Delay_P95_s'};
        trace_compatible = istable(Trace) && ~isempty(Trace) && ...
            all(ismember(required_trace, ...
                Trace.Properties.VariableNames));
    end
    if ~trace_compatible
        compatible = false;
        return;
    end

    if Summary.Camera_STA(1) <= 0
        return;
    end

    Deployment = SavedCase.Deployment;
    required_deployment = { ...
        'Case_ID', 'Camera_Local_ID', 'Sensor_Trigger_Count'};
    compatible = istable(Deployment) && ~isempty(Deployment) && ...
        all(ismember(required_deployment, ...
            Deployment.Properties.VariableNames));
end

function Exp = Build_Experiment_Config(Cfg, case_row)
    Exp = ED_Default_TXLOG_Experiment_Config();
    Exp.SavePrefix = Cfg.SavePrefix;
    Exp.DisasterCount = 1;
    Exp.TotalAlarmSTA = Cfg.TotalAlarmSTA;
    Exp.ReferenceAlarmSTA = Cfg.ReferenceAlarmSTA;
    % Type-0 IDs are reserved for cameras. No background application
    % traffic is generated; the reported background-STA count remains zero.
    Exp.NBackgroundSTA = case_row.NCamera;
    Exp.N_BSS = Cfg.N_BSS;
    Exp.LayoutSeed = Cfg.LayoutSeed;
    Exp.RandomSeedBase = Cfg.RandomSeedBase - 1;
    [Exp.NRAW, Exp.SlotDurationCount] = ...
        Resolve_Case_RAW_Params(Cfg, case_row);
    Exp.RAWOffsetMode = Cfg.RAWOffsetMode;
    Exp.RAWOffsetSeed = Cfg.RAWOffsetSeed;
    Exp.TimingMode = 'sync';
    Exp.ChannelHistorySlots = Cfg.ChannelHistorySlots;
    Exp.PreSurgeSec = Cfg.PreSurgeSec;
    Exp.SurgeWindowSec = [];
    Exp.PostSurgeSec = Cfg.PostSurgeSec;
    Exp.FireSpreadReferenceDistance_m = ...
        Cfg.FireSpreadReferenceDistance_m;
    Exp.FireSpreadNominalROS_mps = case_row.ROS_mps;
    Exp.SequenceAlpha = Cfg.Alpha;
    Exp.SequenceBeta = Cfg.Beta;
    Exp.SequenceActiveTarget = Cfg.TargetActiveAlarmSTA;
    Exp.ChangedROSSequence_mps = case_row.ROS_mps;
    Exp.FireTimeCompression = Cfg.FireTimeCompression;
    Exp.AlarmIntervalSec = Cfg.AlarmIntervalSec;
    Exp.AlarmPayloadBytes = Cfg.AlarmPayloadBytes;
    Exp.AlarmBurstCount = Cfg.AlarmBurstCount;
    Exp.AlarmBurstIntervalSec = Cfg.AlarmBurstIntervalSec;
    Exp.BackgroundIntervalSec = 1;
    Exp.ReportIntervalSec = Cfg.ReportIntervalSec;
    Exp.GeoPreset = Cfg.GeoPreset;
    Exp.CollectTimeSeries = Cfg.CollectTimeSeries;
    Exp.SaveTXLOGFiles = false;
    Exp.UseOnlineTXLOGAggregation = false;
    Exp.ShowProgress = false;
    Exp.UseParallelSequences = false;
    Exp.UsePrecomputedNetworkInfo = false;
    Exp.WriteResultFiles = false;
    Exp.Quiet = true;
end

function P = Configure_Cameras(P, Cfg, n_camera)
    P.idx_Camera_STA = P.idx_STA_Type0;
    if numel(P.idx_Camera_STA) ~= n_camera
        error('ED:CameraCountMismatch', ...
            'Reserved Type-0 STA count does not match the camera count.');
    end
    P.N_Application_Background_STA = Cfg.NBackgroundSTA;
    P.Prob_Frame_Generation_bk = 0;
    P.On_Save_TX_Log = false;
    P.MethodName = 'Standard_RAW';
    P.ED_Camera = struct();
    P.ED_Camera.Enabled = n_camera > 0;
    P.ED_Camera.PlacementRadiusFactor = ...
        Cfg.CameraPlacementRadiusFactor;
    P.ED_Camera.SectorBoundaryDeg = Cfg.CameraSectorBoundaryDeg;
    P.ED_Camera.StreamDurationSec = Cfg.CameraStreamDurationSec;
    P.ED_Camera.Bitrate_bps = Cfg.CameraBitrate_bps;
    P.ED_Camera.FrameBytes = Cfg.CameraFrameBytes;
    P.ED_Camera.FrameIntervalSec = Cfg.CameraFrameIntervalSec;
    P.ED_Collect_RAW_Remained_Log = Cfg.CollectRAWRemainedLog;
    P.ED_Initial_Queue_Capacity = Cfg.InitialQueueCapacity;
    P.ED_Initial_Delay_Capacity = Cfg.InitialDelayCapacity;

    tx_slots = ceil((8 * Cfg.CameraFrameBytes / P.R_data(1)) / ...
        P.T_slot);
    if tx_slots >= P.BSS_T_RAW_Slot_in_Slot(1) - 1
        error('ED:CameraFrameDoesNotFitRAW', ...
            ['CameraFrameBytes=%d requires %d MAC slots and does not fit ' ...
             'the configured RAW slot (%d slots).'], ...
            Cfg.CameraFrameBytes, tx_slots, ...
            P.BSS_T_RAW_Slot_in_Slot(1));
    end
end

function P = Configure_Channel_Access(P, Cfg)
    P = ED_Apply_EDCA_Access_Categories( ...
        P, Is_EDCA_Enabled(Cfg), Cfg.EDCAProfiles, ...
        Cfg.AlarmAccessCategory, Cfg.CameraAccessCategory);
    P = ED_Configure_SDC_Dependent_TXOP( ...
        P, Is_TXOP_Enabled(Cfg), P.idx_Camera_STA, ...
        Get_Field_Or_Default(Cfg, 'CameraTXOPSDCFraction', 1), ...
        Get_Field_Or_Default(Cfg, 'CameraTXOPGuardSlots', 1), ...
        Get_Field_Or_Default(Cfg, 'CameraTXOPMaxMPDUs', inf), ...
        Get_Field_Or_Default(Cfg, 'CameraTXOPBoundaryMode', 'strict'), ...
        Get_Field_Or_Default(Cfg, ...
            'CameraTXOPAggressiveMultiplier', 2));
    if P.EDCA_Enabled
        if P.EDCA_TXOP_Enabled
            P.MethodName = sprintf('Standard_RAW_EDCA_TXOP_%s', ...
                P.EDCA_TXOP_Boundary_Mode);
        else
            P.MethodName = 'Standard_RAW_EDCA';
        end
    else
        P.MethodName = 'Standard_RAW';
    end
end

function P = Configure_Long_Run_Execution( ...
    P, Cfg, case_row, fingerprint)

    P.ED_Show_Progress = Cfg.ShowProgress;
    P.ED_Progress_Label = sprintf('Case %02d | %s', ...
        case_row.Case_ID, char(case_row.Case_Label));
    P.ED_Progress_Interval_Slots = max(1, round( ...
        Cfg.ProgressIntervalSec / P.T_slot));
    if Cfg.EnableCaseCheckpoints
        P.ED_Checkpoint_File = Case_Checkpoint_File( ...
            Cfg.SavePrefix, case_row.Case_ID, 'State');
        P.ED_Checkpoint_Fingerprint = fingerprint;
        P.ED_Resume_From_Checkpoint = Cfg.ResumeIncompleteCases;
        P.ED_Checkpoint_Interval_Slots = max(1, round( ...
            Cfg.CheckpointIntervalSec / P.T_slot));
    else
        P.ED_Checkpoint_File = '';
        P.ED_Resume_From_Checkpoint = false;
        P.ED_Checkpoint_Interval_Slots = inf;
    end
end

function Trace = Decorate_Trace(Trace, P, Cfg, case_row)
    if isempty(Trace)
        return;
    end
    n = height(Trace);
    Trace.Case_ID = repmat(case_row.Case_ID, n, 1);
    Trace.Case_Label = repmat(string(case_row.Case_Label), n, 1);
    Trace.Method = repmat(string(P.MethodName), n, 1);
    Trace.EDCA_Enabled = repmat(P.EDCA_Enabled, n, 1);
    Trace.Alarm_Access_Category = repmat( ...
        string(P.EDCA_Alarm_Access_Category), n, 1);
    Trace.Camera_Access_Category = repmat( ...
        string(P.EDCA_Camera_Access_Category), n, 1);
    Trace.Camera_TXOP_Boundary_Mode = repmat(string( ...
        Get_Field_Or_Default(P, ...
            'EDCA_TXOP_Boundary_Mode', 'disabled')), n, 1);
    Trace.Camera_TXOP_Duration_Multiplier = repmat( ...
        Get_Field_Or_Default(P, ...
            'EDCA_TXOP_Duration_Multiplier', 0), n, 1);
    Trace.Camera_STA = repmat(case_row.NCamera, n, 1);
    Trace.Background_STA = repmat(Cfg.NBackgroundSTA, n, 1);
    Trace.ROS_mps = repmat(case_row.ROS_mps, n, 1);
    Trace.N_RAW = repmat(P.N_RAW, n, 1);
    Trace.Slot_Duration_Count = repmat( ...
        P.BSS_Opt_Slot_Duration_Count(1), n, 1);
    Trace.RAW_Slot_Duration_ms = repmat( ...
        P.BSS_T_RAW_Slot(1) * 1e3, n, 1);
    Trace.RAW_Cycle_Duration_ms = repmat( ...
        P.BSS_RAW_Cycle_Interval(1) * P.T_slot * 1e3, n, 1);

    dt = [Trace.TimeSec(1); diff(Trace.TimeSec)];
    dt = max(dt, P.T_slot);
    alarm_enqueued = Positive_Delta(Trace.Alarm_N_Enqueued);
    camera_enqueued = Positive_Delta(Trace.Camera_N_Enqueued);
    alarm_success = Positive_Delta(Trace.Alarm_N_Success_ACKed);
    camera_success = Positive_Delta(Trace.Camera_N_Success_ACKed);
    alarm_loss = Positive_Delta(Trace.Alarm_N_Loss);
    camera_loss = Positive_Delta(Trace.Camera_N_Loss);
    alarm_success_bytes = Positive_Delta(Trace.Alarm_Success_Bytes);
    camera_success_bytes = Positive_Delta(Trace.Camera_Success_Bytes);
    total_success_bytes = Positive_Delta(Trace.Success_Bytes);
    total_enqueued = Positive_Delta(Trace.N_Enqueued);
    total_success = Positive_Delta(Trace.N_Success_ACKed);

    Trace.Interval_Alarm_Offered_Mbps = alarm_enqueued * ...
        mean(Cfg.AlarmPayloadBytes) * 8 ./ dt / 1e6;
    Trace.Interval_Camera_Offered_Mbps = camera_enqueued * ...
        Cfg.CameraFrameBytes * 8 ./ dt / 1e6;
    Trace.Interval_Total_Offered_Mbps = ...
        Trace.Interval_Alarm_Offered_Mbps + ...
        Trace.Interval_Camera_Offered_Mbps;
    Trace.Interval_Alarm_Goodput_Mbps = ...
        alarm_success_bytes * 8 ./ dt / 1e6;
    Trace.Interval_Camera_Goodput_Mbps = ...
        camera_success_bytes * 8 ./ dt / 1e6;
    Trace.Interval_Total_Goodput_Mbps = ...
        total_success_bytes * 8 ./ dt / 1e6;
    Trace.Interval_Network_PDR = Divide_Vector( ...
        total_success, total_enqueued);
    Trace.Interval_Alarm_Enqueued = alarm_enqueued;
    Trace.Interval_Alarm_ACKed = alarm_success;
    Trace.Interval_Alarm_Lost = alarm_loss;
    Trace.Interval_Camera_Enqueued = camera_enqueued;
    Trace.Interval_Camera_ACKed = camera_success;
    Trace.Interval_Camera_Lost = camera_loss;
    Trace.Interval_Alarm_ACKed_Per_Enqueued = Divide_Vector( ...
        alarm_success, alarm_enqueued);
    Trace.Interval_Camera_ACKed_Per_Enqueued = Divide_Vector( ...
        camera_success, camera_enqueued);
    % Loss ratio uses packets resolved in this interval as its denominator.
    % This remains meaningful while an earlier backlog is being drained.
    Trace.Interval_Alarm_Loss_Ratio = Divide_Vector( ...
        alarm_loss, alarm_success + alarm_loss);
    Trace.Interval_Camera_Loss_Ratio = Divide_Vector( ...
        camera_loss, camera_success + camera_loss);
    Trace.Interval_Offered_Exceeds_PHY = ...
        Trace.Interval_Total_Offered_Mbps > min(P.R_data(P.idx_STA)) / 1e6;
end

function Deployment = Build_Deployment_Table( ...
    SimState, P, Cfg, case_row)
    camera = P.idx_Camera_STA;
    if isempty(camera)
        Deployment = table();
        return;
    end
    n = numel(camera);
    Deployment = table();
    Deployment.Case_ID = repmat(case_row.Case_ID, n, 1);
    Deployment.Case_Label = repmat(string(case_row.Case_Label), n, 1);
    Deployment.N_RAW = repmat(P.N_RAW, n, 1);
    Deployment.Slot_Duration_Count = repmat( ...
        P.BSS_Opt_Slot_Duration_Count(1), n, 1);
    Deployment.Camera_Local_ID = (1:n).';
    Deployment.Node_ID = camera(:);
    Deployment.Sector_Center_Deg = ...
        SimState.ED_Camera.Sector_Center_Deg(:);
    Deployment.Sector_Width_Deg = repmat( ...
        SimState.ED_Camera.Sector_Width_Deg, n, 1);
    Deployment.X_m = SimState.Node.Pos(camera, 1);
    Deployment.Y_m = SimState.Node.Pos(camera, 2);
    Deployment.AP_Distance_m = repmat( ...
        SimState.ED_Camera.Placement_Radius_m, n, 1);
    Deployment.RSS_To_AP_dBm = ...
        SimState.ED_Camera.RSS_To_AP_dBm(:);
    Deployment.Sensor_Trigger_Count = ...
        SimState.ED_Camera.Sensor_Trigger_Count(:);
    Deployment.Stream_Activation_Count = ...
        SimState.ED_Camera.Activation_Count(:);
    Deployment.Stream_Extension_Count = ...
        SimState.ED_Camera.Extension_Count(:);
    Deployment.Generated_Frames = ...
        SimState.ED_Camera.Generated_Frames(:);
    Deployment.Camera_Bitrate_Mbps = repmat( ...
        Cfg.CameraBitrate_bps / 1e6, n, 1);
    Deployment.Enqueued_Frames = SimState.n_enq(camera).';
    Deployment.ACKed_Frames = SimState.n_success2(camera).';
    Deployment.Lost_Frames = SimState.n_loss(camera).';
    Deployment.Final_Buffered_Frames = arrayfun(@(id) ...
        SimState.Node.TX_Buffer(id).Length, camera).';
    Deployment.PDR = Divide_Vector( ...
        Deployment.ACKed_Frames, Deployment.Enqueued_Frames);
    Deployment.Deadline_PDR = nan(n, 1);
    Deployment.Delay_Mean_s = nan(n, 1);
    Deployment.Delay_P95_s = nan(n, 1);
    for camera_idx = 1:n
        delay_rows = SimState.Delay(camera(camera_idx)).delay;
        if isempty(delay_rows)
            delay_s = zeros(0, 1);
        else
            delay_s = delay_rows(:, 3) * P.T_slot;
        end
        if Deployment.Enqueued_Frames(camera_idx) > 0
            Deployment.Deadline_PDR(camera_idx) = sum( ...
                delay_s <= Cfg.CameraPacketDeadlineSec) / ...
                Deployment.Enqueued_Frames(camera_idx);
        end
        if ~isempty(delay_s)
            Deployment.Delay_Mean_s(camera_idx) = mean(delay_s);
            Deployment.Delay_P95_s(camera_idx) = ...
                Local_Percentile(delay_s, 95);
        end
    end
    sim_time_s = P.N_slot * P.T_slot;
    Deployment.Goodput_Mbps = ...
        SimState.L_success(camera).' * 8 / sim_time_s / 1e6;
    Deployment.TXOP_Acquisitions = ...
        SimState.ED_TXOP.Acquisitions(camera).';
    Deployment.TXOP_ACKed_MPDUs = ...
        SimState.ED_TXOP.AcknowledgedMPDUs(camera).';
    Deployment.TXOP_Cross_Slot_Exchanges = ...
        SimState.ED_TXOP.CrossSlotExchanges(camera).';
    Deployment.DATA_Attempt_Airtime_s = ...
        SimState.ED_Airtime.DATA_Attempt_Slots(camera).' * P.T_slot;
    Deployment.ACK_Attempt_Airtime_s = ...
        SimState.ED_Airtime.ACK_Attempt_Slots_By_Destination(camera).' * ...
        P.T_slot;
end

function value = Local_Percentile(values, pct)
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

function delta = Positive_Delta(values)
    delta = [values(1); diff(values)];
    delta = max(0, delta);
end

function ratio = Divide_Vector(numerator, denominator)
    ratio = nan(size(numerator));
    mask = denominator > 0;
    ratio(mask) = numerator(mask) ./ denominator(mask);
end

function fingerprint = Build_Case_Fingerprint(Cfg, case_row)
    execution_fields = { ...
        'SavePrefix', 'WriteResultFiles', 'ShowProgress', ...
        'UseParallelCases', 'NumWorkers', 'EnableCaseCheckpoints', ...
        'ResumeCompletedCases', 'ResumeIncompleteCases', ...
        'CheckpointIntervalSec', 'ProgressIntervalSec', 'Cases'};
    present = intersect(execution_fields, fieldnames(Cfg), 'stable');
    science_cfg = rmfield(Cfg, present);
    if ~Is_EDCA_Enabled(Cfg)
        inactive_edca = {'EnableEDCA', 'AlarmAccessCategory', ...
            'CameraAccessCategory', 'EDCAProfiles', 'EnableTXOP', ...
            'CameraTXOPSDCFraction', 'CameraTXOPGuardSlots', ...
            'CameraTXOPMaxMPDUs', 'CameraTXOPBoundaryMode', ...
            'CameraTXOPAggressiveMultiplier'};
        inactive_edca = intersect( ...
            inactive_edca, fieldnames(science_cfg), 'stable');
        science_cfg = rmfield(science_cfg, inactive_edca);
    end
    fingerprint = struct( ...
        'Config', science_cfg, 'Case', table2struct(case_row));
end

function file_name = Case_Checkpoint_File(prefix, case_id, kind)
    file_name = sprintf('%s_Case%02d_%s.mat', ...
        prefix, case_id, kind);
end

function Atomic_Save(file_name, variable_name, value)
    folder = fileparts(file_name);
    if ~isempty(folder) && exist(folder, 'dir') ~= 7
        mkdir(folder);
    end
    temp_file = sprintf('%s.tmp-%d.mat', ...
        file_name, feature('getpid'));
    payload = struct();
    payload.(variable_name) = value;
    save(temp_file, '-struct', 'payload', '-v7.3');
    [ok, message] = movefile(temp_file, file_name, 'f');
    if ~ok
        if exist(temp_file, 'file') == 2
            delete(temp_file);
        end
        error('ED:CheckpointMoveFailed', ...
            'Could not finalize checkpoint %s: %s', file_name, message);
    end
end

function [ready, worker_limit] = Prepare_Parallel(Cfg)
    ready = false;
    worker_limit = 0;
    if ~Cfg.UseParallelCases || ...
       ~license('test', 'Distrib_Computing_Toolbox')
        return;
    end
    try
        pool = gcp('nocreate');
        if isempty(pool)
            if isempty(Cfg.NumWorkers)
                pool = parpool;
            else
                pool = parpool(Cfg.NumWorkers);
            end
        end
        if isempty(Cfg.NumWorkers)
            worker_limit = pool.NumWorkers;
        else
            worker_limit = min(pool.NumWorkers, Cfg.NumWorkers);
        end
        ready = true;
        fprintf(['Parallel case execution: %d workers used ' ...
            '(%d workers in pool).\n'], worker_limit, pool.NumWorkers);
    catch ME
        warning('ED:CameraParallelUnavailable', ...
            'Parallel pool unavailable; using serial execution: %s', ...
            ME.message);
    end
end

function Validate_Config(Cfg)
    if Cfg.NBackgroundSTA ~= 0
        error('ED:CameraBackgroundMustBeZero', ...
            'This experiment requires NBackgroundSTA=0.');
    end
    if Cfg.N_BSS ~= 1
        error('ED:CameraSingleBSSOnly', ...
            'This camera placement experiment currently requires N_BSS=1.');
    end
    required_case_columns = {'Case_ID', 'Case_Label', 'NCamera', 'ROS_mps'};
    if ~istable(Cfg.Cases) || ...
       ~all(ismember(required_case_columns, Cfg.Cases.Properties.VariableNames))
        error('ED:InvalidCameraCases', ...
            'Cfg.Cases must contain Case_ID, Case_Label, NCamera, and ROS_mps.');
    end
    if any(Cfg.Cases.NCamera < 0 | ...
           Cfg.Cases.NCamera ~= round(Cfg.Cases.NCamera)) || ...
       any(Cfg.Cases.ROS_mps <= 0)
        error('ED:InvalidCameraCases', ...
            'Camera counts must be nonnegative integers and ROS must be positive.');
    end
    n_case = height(Cfg.Cases);
    n_raw = repmat(Cfg.NRAW, n_case, 1);
    sdc = repmat(Cfg.SlotDurationCount, n_case, 1);
    if ismember('N_RAW', Cfg.Cases.Properties.VariableNames)
        n_raw = Cfg.Cases.N_RAW;
    end
    if ismember('Slot_Duration_Count', ...
            Cfg.Cases.Properties.VariableNames)
        sdc = Cfg.Cases.Slot_Duration_Count;
    end
    if any(~isfinite(n_raw) | n_raw < 1 | n_raw > 8 | ...
            n_raw ~= round(n_raw))
        error('ED:InvalidCameraRAWCount', ...
            'Slot Format 1 requires integer N_RAW values from 1 through 8.');
    end
    if any(~isfinite(sdc) | sdc < 0 | sdc > 2047 | ...
            sdc ~= round(sdc))
        error('ED:InvalidCameraSDC', ...
            ['Slot Format 1 requires integer Slot Duration Count values ' ...
             'from 0 through 2047.']);
    end
    if Cfg.CameraFrameBytes <= 0 || Cfg.CameraBitrate_bps <= 0 || ...
       Cfg.CameraFrameIntervalSec <= 0 || Cfg.CameraStreamDurationSec <= 0
        error('ED:InvalidCameraTraffic', ...
            'Camera traffic fields must be finite positive values.');
    end
    if Cfg.CheckpointIntervalSec <= 0 || Cfg.ProgressIntervalSec <= 0 || ...
       Cfg.InitialQueueCapacity < 1 || Cfg.InitialDelayCapacity < 1
        error('ED:InvalidCameraExecutionConfig', ...
            ['Checkpoint/progress intervals and initial queue capacities ' ...
             'must be positive.']);
    end
    if Is_EDCA_Enabled(Cfg)
        required = {'AlarmAccessCategory', 'CameraAccessCategory', ...
            'EDCAProfiles'};
        if ~all(isfield(Cfg, required))
            error('ED:InvalidEDCAConfig', ...
                'Enabled EDCA configuration is missing required fields.');
        end
        alarm_ac = char(string(Cfg.AlarmAccessCategory));
        camera_ac = char(string(Cfg.CameraAccessCategory));
        if ~isstruct(Cfg.EDCAProfiles) || ...
           ~isfield(Cfg.EDCAProfiles, alarm_ac) || ...
           ~isfield(Cfg.EDCAProfiles, camera_ac)
            error('ED:InvalidEDCAConfig', ...
                'Configured alarm/camera access categories are undefined.');
        end
    end
    if Is_TXOP_Enabled(Cfg)
        if ~Is_EDCA_Enabled(Cfg)
            error('ED:TXOPRequiresEDCA', ...
                'EnableTXOP requires EnableEDCA=true.');
        end
        required = {'CameraTXOPSDCFraction', ...
            'CameraTXOPGuardSlots', 'CameraTXOPMaxMPDUs', ...
            'CameraTXOPBoundaryMode', ...
            'CameraTXOPAggressiveMultiplier'};
        if ~all(isfield(Cfg, required))
            error('ED:InvalidTXOPConfig', ...
                'Enabled TXOP configuration is missing required fields.');
        end
        if ~isscalar(Cfg.CameraTXOPSDCFraction) || ...
           ~isfinite(Cfg.CameraTXOPSDCFraction) || ...
           Cfg.CameraTXOPSDCFraction <= 0 || ...
           Cfg.CameraTXOPSDCFraction > 1 || ...
           ~isscalar(Cfg.CameraTXOPGuardSlots) || ...
           ~isfinite(Cfg.CameraTXOPGuardSlots) || ...
           Cfg.CameraTXOPGuardSlots < 0 || ...
           Cfg.CameraTXOPGuardSlots ~= ...
                round(Cfg.CameraTXOPGuardSlots) || ...
            ~Is_Valid_TXOP_Max_MPDUs(Cfg.CameraTXOPMaxMPDUs) || ...
            ~Is_Valid_TXOP_Boundary_Mode( ...
                Cfg.CameraTXOPBoundaryMode) || ...
            ~isnumeric(Cfg.CameraTXOPAggressiveMultiplier) || ...
            ~isscalar(Cfg.CameraTXOPAggressiveMultiplier) || ...
            ~isfinite(Cfg.CameraTXOPAggressiveMultiplier) || ...
            Cfg.CameraTXOPAggressiveMultiplier < 1 || ...
            Cfg.CameraTXOPAggressiveMultiplier ~= ...
                round(Cfg.CameraTXOPAggressiveMultiplier)
            error('ED:InvalidTXOPConfig', ...
                ['TXOP fraction must be in (0,1], guard must be a ' ...
                 'nonnegative integer, and MaxMPDUs must be a positive ' ...
                 'integer, Inf, or ''raw-slot-max''. Boundary mode must ' ...
                 'be strict, bounded-cross, aggressive-cross, or ' ...
                 'full-period-aggressive, and ' ...
                 'the aggressive multiplier must be a positive integer.']);
        end
    end
end

function enabled = Is_EDCA_Enabled(Cfg)
    enabled = isfield(Cfg, 'EnableEDCA') && ...
        ~isempty(Cfg.EnableEDCA) && logical(Cfg.EnableEDCA);
end

function enabled = Is_TXOP_Enabled(Cfg)
    enabled = isfield(Cfg, 'EnableTXOP') && ...
        ~isempty(Cfg.EnableTXOP) && logical(Cfg.EnableTXOP);
end

function valid = Is_Valid_TXOP_Max_MPDUs(value)
    if (ischar(value) && isrow(value)) || ...
       (isstring(value) && isscalar(value))
        token = regexprep(char(value), '[^A-Za-z0-9]', '');
        valid = strcmpi(token, 'rawslotmax');
        return;
    end
    valid = isnumeric(value) && isscalar(value) && value >= 1 && ...
        (isinf(value) || (isfinite(value) && value == round(value)));
end

function valid = Is_Valid_TXOP_Boundary_Mode(value)
    if ~((ischar(value) && isrow(value)) || ...
            (isstring(value) && isscalar(value)))
        valid = false;
        return;
    end
    token = regexprep(char(value), '[^A-Za-z0-9]', '');
    valid = any(strcmpi(token, { ...
        'strict', 'rawbounded', 'boundedraw', ...
        'boundedcross', 'boundedcrossslot', 'crossbounded', ...
        'aggressivecross', 'aggressivecrossslot', ...
        'crossaggressive', 'fullperiodaggressive', 'fullperiod', ...
        'periodaggressive', 'aggressivefullperiod'}));
end

function value = Get_Field_Or_Default(S, field_name, default_value)
    if isfield(S, field_name) && ~isempty(S.(field_name))
        value = S.(field_name);
    else
        value = default_value;
    end
end

function [n_raw, sdc] = Resolve_Case_RAW_Params(Cfg, case_row)
    n_raw = Cfg.NRAW;
    sdc = Cfg.SlotDurationCount;
    names = case_row.Properties.VariableNames;
    if ismember('N_RAW', names)
        n_raw = case_row.N_RAW;
    end
    if ismember('Slot_Duration_Count', names)
        sdc = case_row.Slot_Duration_Count;
    end
end
