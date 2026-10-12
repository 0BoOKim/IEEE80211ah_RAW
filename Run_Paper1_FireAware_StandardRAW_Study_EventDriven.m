function Results = Run_Paper1_FireAware_StandardRAW_Study_EventDriven(Override)
%RUN_PAPER1_FIREAWARE_STANDARDRAW_STUDY_EVENTDRIVEN Run Paper 1 E2-E4.
%
% E2: Standard-RAW capacity sweep over camera count, N_RAW, and SDC.
% E3: Temporal fire-regime sweep over ROS and Beta activation shape.
% E4: Spatial fire-regime sweep over ignition location and anisotropy.
%
% The default design uses ten paired replicates. Conditions shared by E2,
% E3, and E4 are simulated once and referenced by each experiment. Use the
% DesignOnly option to inspect the complete design without running it:
%
%   O.Study.DesignOnly = true;
%   R = Run_Paper1_FireAware_StandardRAW_Study_EventDriven(O);
%
% A small subset can be selected without editing this file, for example:
%
%   O.Study.Experiments = "E3";
%   O.Study.Replicates = 3;
%   Run_Paper1_FireAware_StandardRAW_Study_EventDriven(O);

    if nargin < 1 || isempty(Override)
        Override = struct();
    end
    if ~isstruct(Override)
        error('ED:InvalidPaper1Override', ...
            'Override must be a structure.');
    end

    project_dir = fileparts(mfilename('fullpath'));
    addpath(fullfile(project_dir, 'modules'));
    addpath(fullfile(project_dir, 'modules_eventdriven'));

    Study = Default_Study_Config();
    Cfg = Default_Simulation_Config();
    [Study, Cfg] = Apply_Override(Study, Cfg, Override);
    Study.Experiments = Normalize_Experiments(Study.Experiments);
    Validate_Study(Study, Cfg);

    [Design, ExecutionDesign] = Build_Design(Study);
    master_prefix = Resolve_Path(project_dir, Study.SavePrefix);
    output_folder = fileparts(master_prefix);
    if ~isempty(output_folder) && exist(output_folder, 'dir') ~= 7
        mkdir(output_folder);
    end
    writetable(Design, [master_prefix '_Design.csv']);
    writetable(ExecutionDesign, ...
        [master_prefix '_ExecutionDesign.csv']);

    fprintf('=== Paper 1 Fire-Aware Standard-RAW Study: E2-E4 ===\n');
    fprintf(['Analysis rows=%d, unique executions=%d, replicates=%d, ' ...
        'experiments=%s.\n'], height(Design), height(ExecutionDesign), ...
        Study.Replicates, strjoin(cellstr(Study.Experiments), ', '));
    fprintf(['Alarm STAs=%d, background STAs=%d, camera rate=%.0f ' ...
        'kbps/camera, alarm interval=%.1f s.\n'], Cfg.TotalAlarmSTA, ...
        Cfg.NBackgroundSTA, Cfg.CameraBitrate_bps / 1e3, ...
        Cfg.AlarmIntervalSec);
    fprintf(['Shared conditions saved %d executions through design ' ...
        'deduplication.\n'], height(Design) - height(ExecutionDesign));

    if Study.DesignOnly
        Results = Empty_Results(Study, Cfg, Design, ExecutionDesign);
        fprintf('Design-only mode: no simulation was run.\n');
        return;
    end

    checkpoint_dir = [master_prefix '_Checkpoints'];
    if exist(checkpoint_dir, 'dir') ~= 7
        mkdir(checkpoint_dir);
    end

    group_keys = unique(ExecutionDesign.Group_Key, 'stable');
    summary_cells = cell(numel(group_keys), 1);
    trace_cells = cell(numel(group_keys), 1);
    deployment_cells = cell(numel(group_keys), 1);
    for group_idx = 1:numel(group_keys)
        rows = ExecutionDesign( ...
            ExecutionDesign.Group_Key == group_keys(group_idx), :);
        run_cfg = Build_Group_Config( ...
            Cfg, rows, checkpoint_dir);
        fprintf('\n--- Configuration group %d/%d: %s (%d cases) ---\n', ...
            group_idx, numel(group_keys), ...
            char(group_keys(group_idx)), height(rows));
        group_result = ED_Run_Camera_Overload_Experiment(run_cfg);
        group_summary = Decorate_Execution_Table( ...
            group_result.Summary, rows);
        group_trace = Decorate_Execution_Table( ...
            group_result.TimeSeries, rows);
        group_deployment = Decorate_Execution_Table( ...
            group_result.Deployment, rows);
        group_summary = Add_Derived_Metrics( ...
            group_summary, group_trace, group_deployment, Cfg);
        summary_cells{group_idx} = group_summary;
        trace_cells{group_idx} = group_trace;
        deployment_cells{group_idx} = group_deployment;
    end

    ExecutionSummary = ED_Vertcat_Compatible_Tables( ...
        summary_cells, 'Paper 1 execution summaries');
    ExecutionTimeSeries = ED_Vertcat_Compatible_Tables( ...
        trace_cells, 'Paper 1 execution time series');
    ExecutionDeployment = ED_Vertcat_Compatible_Tables( ...
        deployment_cells, 'Paper 1 execution deployments');
    ExecutionSummary = sortrows(ExecutionSummary, 'Execution_ID');
    if ~isempty(ExecutionTimeSeries)
        ExecutionTimeSeries = sortrows( ...
            ExecutionTimeSeries, {'Execution_ID', 'TimeSec'});
    end
    if ~isempty(ExecutionDeployment)
        ExecutionDeployment = sortrows( ...
            ExecutionDeployment, ...
            {'Execution_ID', 'Camera_Local_ID'});
    end

    Summary = Expand_Summary(ExecutionSummary, Design);
    TimeSeries = Expand_Repeated_Table(ExecutionTimeSeries, Design);
    Deployment = Expand_Repeated_Table(ExecutionDeployment, Design);
    Aggregate = Aggregate_Replicates(Summary);

    writetable(ExecutionSummary, ...
        [master_prefix '_ExecutionSummary.csv']);
    if ~isempty(ExecutionTimeSeries)
        writetable(ExecutionTimeSeries, ...
            [master_prefix '_ExecutionTimeSeries.csv']);
    end
    if ~isempty(ExecutionDeployment)
        writetable(ExecutionDeployment, ...
            [master_prefix '_ExecutionDeployment.csv']);
    end
    writetable(Summary, [master_prefix '_Summary.csv']);
    if ~isempty(TimeSeries)
        writetable(TimeSeries, [master_prefix '_TimeSeries.csv']);
    end
    if ~isempty(Deployment)
        writetable(Deployment, [master_prefix '_Deployment.csv']);
    end
    writetable(Aggregate, [master_prefix '_Aggregate.csv']);

    Results = struct();
    Results.Study = Study;
    Results.Config = Cfg;
    Results.Design = Design;
    Results.ExecutionDesign = ExecutionDesign;
    Results.ExecutionSummary = ExecutionSummary;
    Results.ExecutionTimeSeries = ExecutionTimeSeries;
    Results.ExecutionDeployment = ExecutionDeployment;
    Results.Summary = Summary;
    Results.TimeSeries = TimeSeries;
    Results.Deployment = Deployment;
    Results.Aggregate = Aggregate;
    save([master_prefix '_Workspace.mat'], 'Results', '-v7.3');

    fprintf('\nSaved Paper 1 E2-E4 results with prefix: %s\n', ...
        master_prefix);
end

function Study = Default_Study_Config()
    Study = struct();
    Study.SavePrefix = ...
        'Result_Paper1_FireAware_StandardRAW_EventDriven';
    Study.Experiments = ["E2" "E3" "E4"];
    Study.Replicates = 10;
    Study.RandomSeedBase = 1010000;
    Study.SeedStride = 1000;
    Study.LayoutSeedBase = 1731;
    Study.LayoutSeedStride = 37;
    Study.DesignOnly = false;

    % E2: load and RAW-parameter capacity surface.
    Study.E2CameraCounts = [0 2 4];
    Study.E2NRAW = [1 2 4 8];
    Study.E2SDC = [127 255 511 1023 2047];
    Study.E2ROS_mps = 0.5;

    % E3: the final sensor count is fixed; only activation timing changes.
    Study.E3NCamera = 4;
    Study.E3NRAW = 1;
    Study.E3SDC = 255;
    Study.E3ROS_mps = [0.25 0.5 1.0];
    Study.E3BetaRegimes = table( ...
        ["DiffuseEarly"; "Nominal"; "ConcentratedEarly"; ...
         "Symmetric"; "Late"], ...
        [3.0; 7.5; 15.0; 12.5; 17.5], ...
        [7.0; 17.5; 35.0; 12.5; 7.5], ...
        'VariableNames', {'Regime', 'Alpha', 'Beta'});

    % E4: the global Beta curve is fixed; spatial assignment changes.
    Study.E4NCamera = 4;
    Study.E4NRAW = 1;
    Study.E4SDC = 255;
    Study.E4ROS_mps = 0.5;
    Study.E4GeoPresets = [ ...
        "center-isotropic"; "center-directional"; ...
        "edge-isotropic"; "edge-directional"];

    Study.NominalAlpha = 7.5;
    Study.NominalBeta = 17.5;
    Study.BaselineGeoPreset = "center-isotropic";
end

function Cfg = Default_Simulation_Config()
    Cfg = ED_Default_Camera_Overload_Config();
    Cfg.TotalAlarmSTA = 400;
    Cfg.ReferenceAlarmSTA = 400;
    Cfg.TargetActiveAlarmSTA = 400;
    Cfg.NBackgroundSTA = 0;
    Cfg.N_BSS = 1;
    Cfg.FireSpreadReferenceDistance_m = 900;
    Cfg.FireTimeCompression = 1;
    Cfg.PreSurgeSec = 5;
    Cfg.PostSurgeSec = 15;
    Cfg.AlarmIntervalSec = 10;
    Cfg.AlarmPayloadBytes = [64 64];
    Cfg.AlarmBurstCount = 3;
    Cfg.AlarmBurstIntervalSec = 1;
    Cfg.CameraBitrate_bps = 128000;
    Cfg.CameraFrameBytes = 500;
    Cfg.CameraFrameIntervalSec = ...
        Cfg.CameraFrameBytes * 8 / Cfg.CameraBitrate_bps;
    Cfg.CameraStreamDurationSec = 10;
    Cfg.EnableEDCA = false;
    Cfg.EnableTXOP = false;
    Cfg.RAWOffsetMode = 'beacon-fcs16';
    Cfg.ReportIntervalSec = 10;
    Cfg.CollectTimeSeries = true;
    Cfg.CollectRAWRemainedLog = false;
    Cfg.UseParallelCases = true;
    Cfg.NumWorkers = 4;
    Cfg.EnableCaseCheckpoints = true;
    Cfg.ResumeCompletedCases = true;
    Cfg.ResumeIncompleteCases = true;
    Cfg.CheckpointIntervalSec = 300;
    Cfg.ProgressIntervalSec = 60;
    Cfg.WriteResultFiles = false;
end

function [Study, Cfg] = Apply_Override(Study, Cfg, Override)
    allowed = {'Study', 'Config'};
    names = fieldnames(Override);
    if any(~ismember(names, allowed))
        error('ED:UnknownPaper1Override', ...
            'Only Study and Config override structures are supported.');
    end
    if isfield(Override, 'Study')
        Study = Copy_Fields(Study, Override.Study);
    end
    if isfield(Override, 'Config')
        Cfg = Copy_Fields(Cfg, Override.Config);
    end
end

function destination = Copy_Fields(destination, source)
    if ~isstruct(source)
        error('ED:InvalidPaper1Override', ...
            'Study and Config overrides must be structures.');
    end
    names = fieldnames(source);
    for idx = 1:numel(names)
        destination.(names{idx}) = source.(names{idx});
    end
end

function experiments = Normalize_Experiments(experiments)
    experiments = upper(string(experiments(:).'));
    experiments = unique(experiments, 'stable');
end

function Validate_Study(Study, Cfg)
    if isempty(Study.Experiments) || ...
            any(~ismember(Study.Experiments, ["E2" "E3" "E4"]))
        error('ED:InvalidPaper1Experiment', ...
            'Study.Experiments must contain E2, E3, and/or E4.');
    end
    Validate_Positive_Integer(Study.Replicates, 'Replicates');
    Validate_Positive_Integer(Study.RandomSeedBase, 'RandomSeedBase');
    Validate_Positive_Integer(Study.SeedStride, 'SeedStride');
    Validate_Positive_Integer(Study.LayoutSeedBase, 'LayoutSeedBase');
    Validate_Positive_Integer(Study.LayoutSeedStride, ...
        'LayoutSeedStride');
    Validate_Integer_Vector(Study.E2CameraCounts, 0, inf, ...
        'E2CameraCounts');
    Validate_Integer_Vector(Study.E2NRAW, 1, 8, 'E2NRAW');
    Validate_Integer_Vector(Study.E2SDC, 0, 2047, 'E2SDC');
    Validate_Positive_Vector(Study.E3ROS_mps, 'E3ROS_mps');
    Validate_Integer_Vector(Study.E3NCamera, 0, inf, 'E3NCamera');
    Validate_Integer_Vector(Study.E3NRAW, 1, 8, 'E3NRAW');
    Validate_Integer_Vector(Study.E3SDC, 0, 2047, 'E3SDC');
    Validate_Integer_Vector(Study.E4NCamera, 0, inf, 'E4NCamera');
    Validate_Integer_Vector(Study.E4NRAW, 1, 8, 'E4NRAW');
    Validate_Integer_Vector(Study.E4SDC, 0, 2047, 'E4SDC');
    Validate_Positive_Vector(Study.E2ROS_mps, 'E2ROS_mps');
    Validate_Positive_Vector(Study.E4ROS_mps, 'E4ROS_mps');
    scalar_fields = {'E2ROS_mps', 'E3NCamera', 'E3NRAW', 'E3SDC', ...
        'E4NCamera', 'E4NRAW', 'E4SDC', 'E4ROS_mps', ...
        'NominalAlpha', 'NominalBeta'};
    for field_idx = 1:numel(scalar_fields)
        if ~isscalar(Study.(scalar_fields{field_idx}))
            error('ED:InvalidPaper1Scalar', ...
                'Study.%s must be scalar.', scalar_fields{field_idx});
        end
    end
    if ~istable(Study.E3BetaRegimes) || ...
            ~all(ismember({'Regime', 'Alpha', 'Beta'}, ...
            Study.E3BetaRegimes.Properties.VariableNames)) || ...
            isempty(Study.E3BetaRegimes) || ...
            any(Study.E3BetaRegimes.Alpha <= 0) || ...
            any(Study.E3BetaRegimes.Beta <= 0)
        error('ED:InvalidPaper1BetaRegimes', ...
            ['E3BetaRegimes must be a nonempty table containing ' ...
             'positive Regime, Alpha, and Beta values.']);
    end
    if isempty(Study.E4GeoPresets)
        error('ED:InvalidPaper1GeoRegimes', ...
            'E4GeoPresets must not be empty.');
    end
    if Cfg.NBackgroundSTA ~= 0 || Cfg.N_BSS ~= 1 || ...
            Cfg.EnableEDCA || Cfg.EnableTXOP
        error('ED:InvalidPaper1Baseline', ...
            ['Paper 1 E2-E4 require zero background STAs, one BSS, ' ...
             'equal DCF contention, and TXOP disabled.']);
    end
    if Cfg.TotalAlarmSTA <= 0 || ...
            Cfg.ReferenceAlarmSTA < Cfg.TotalAlarmSTA || ...
            Cfg.TargetActiveAlarmSTA > Cfg.TotalAlarmSTA
        error('ED:InvalidPaper1AlarmPopulation', ...
            'The alarm/reference population settings are inconsistent.');
    end
    if Cfg.FireTimeCompression ~= 1
        error('ED:InvalidPaper1FireCompression', ...
            'Paper 1 E2-E4 use uncompressed physical fire time.');
    end
    if ~Cfg.CollectTimeSeries
        error('ED:Paper1TimeSeriesRequired', ...
            'CollectTimeSeries must be enabled for E2-E4 diagnostics.');
    end
end

function Validate_Positive_Integer(value, name)
    if ~isscalar(value) || ~isfinite(value) || ...
            value < 1 || value ~= round(value)
        error('ED:InvalidPaper1Scalar', ...
            '%s must be a positive integer.', name);
    end
end

function Validate_Integer_Vector(values, lower, upper, name)
    if isempty(values) || any(~isfinite(values)) || ...
            any(values < lower) || any(values > upper) || ...
            any(values ~= round(values))
        error('ED:InvalidPaper1Vector', ...
            '%s must contain integers in [%g, %g].', name, lower, upper);
    end
end

function Validate_Positive_Vector(values, name)
    if isempty(values) || any(~isfinite(values)) || any(values <= 0)
        error('ED:InvalidPaper1Vector', ...
            '%s must contain positive finite values.', name);
    end
end

function [Design, ExecutionDesign] = Build_Design(Study)
    rows = repmat(Empty_Design_Row(), 0, 1);
    analysis_id = 0;
    for replicate = 1:Study.Replicates
        pair_seed = Study.RandomSeedBase + ...
            (replicate - 1) * Study.SeedStride;
        layout_seed = Study.LayoutSeedBase + ...
            (replicate - 1) * Study.LayoutSeedStride;

        if ismember("E2", Study.Experiments)
            for camera = Study.E2CameraCounts(:).'
                for n_raw = Study.E2NRAW(:).'
                    for sdc = Study.E2SDC(:).'
                        analysis_id = analysis_id + 1;
                        condition_id = string(sprintf( ...
                            'E2_C%d_RAW%d_SDC%d', camera, n_raw, sdc));
                        label = string(sprintf( ...
                            'E2 cameras=%d, N_RAW=%d, SDC=%d', ...
                            camera, n_raw, sdc));
                        rows(end + 1, 1) = Make_Design_Row( ...
                            analysis_id, "E2", condition_id, label, ...
                            replicate, pair_seed, layout_seed, camera, ...
                            Study.E2ROS_mps, n_raw, sdc, ...
                            Study.NominalAlpha, Study.NominalBeta, ...
                            "Nominal", "CenterIsotropic", ...
                            Study.BaselineGeoPreset); %#ok<AGROW>
                    end
                end
            end
        end

        if ismember("E3", Study.Experiments)
            for regime_idx = 1:height(Study.E3BetaRegimes)
                beta_row = Study.E3BetaRegimes(regime_idx, :);
                regime = string(beta_row.Regime);
                for ros = Study.E3ROS_mps(:).'
                    analysis_id = analysis_id + 1;
                    condition_id = string(sprintf( ...
                        'E3_%s_ROS%s', Safe_Tag(regime), ...
                        Number_Tag(ros)));
                    label = string(sprintf( ...
                        'E3 %s, ROS=%.3g m/s', regime, ros));
                    rows(end + 1, 1) = Make_Design_Row( ...
                        analysis_id, "E3", condition_id, label, ...
                        replicate, pair_seed, layout_seed, ...
                        Study.E3NCamera, ros, Study.E3NRAW, ...
                        Study.E3SDC, beta_row.Alpha, beta_row.Beta, ...
                        regime, "CenterIsotropic", ...
                        Study.BaselineGeoPreset); %#ok<AGROW>
                end
            end
        end

        if ismember("E4", Study.Experiments)
            geo_presets = string(Study.E4GeoPresets(:));
            for geo_idx = 1:numel(geo_presets)
                geo_preset = geo_presets(geo_idx);
                analysis_id = analysis_id + 1;
                geo_regime = Geo_Regime_Label(geo_preset);
                condition_id = string(sprintf( ...
                    'E4_%s', Safe_Tag(geo_preset)));
                label = string(sprintf('E4 %s', geo_regime));
                rows(end + 1, 1) = Make_Design_Row( ...
                    analysis_id, "E4", condition_id, label, ...
                    replicate, pair_seed, layout_seed, ...
                    Study.E4NCamera, Study.E4ROS_mps, ...
                    Study.E4NRAW, Study.E4SDC, ...
                    Study.NominalAlpha, Study.NominalBeta, ...
                    "Nominal", geo_regime, geo_preset); %#ok<AGROW>
            end
        end
    end

    Design = struct2table(rows);
    [unique_keys, first_index] = unique( ...
        Design.Execution_Key, 'stable');
    [~, execution_index] = ismember(Design.Execution_Key, unique_keys);
    Design.Execution_ID = execution_index;
    ExecutionDesign = Design(first_index, :);
    ExecutionDesign.Execution_ID = (1:height(ExecutionDesign)).';
end

function row = Empty_Design_Row()
    row = struct( ...
        'Analysis_Case_ID', 0, 'Experiment', "", ...
        'Condition_ID', "", 'Condition_Label', "", ...
        'Replicate', 0, 'Pair_Seed', 0, 'Layout_Seed', 0, ...
        'NCamera', 0, 'ROS_mps', 0, 'N_RAW', 0, ...
        'Slot_Duration_Count', 0, 'Alpha', 0, 'Beta', 0, ...
        'Beta_Regime', "", 'Geo_Regime', "", ...
        'Geo_Preset', "", 'Execution_Key', "", ...
        'Group_Key', "", 'Execution_Label', "");
end

function row = Make_Design_Row(analysis_id, experiment, condition_id, ...
    condition_label, replicate, pair_seed, layout_seed, camera, ros, ...
    n_raw, sdc, alpha, beta_value, beta_regime, geo_regime, geo_preset)

    row = Empty_Design_Row();
    row.Analysis_Case_ID = analysis_id;
    row.Experiment = experiment;
    row.Condition_ID = condition_id;
    row.Condition_Label = condition_label;
    row.Replicate = replicate;
    row.Pair_Seed = pair_seed;
    row.Layout_Seed = layout_seed;
    row.NCamera = camera;
    row.ROS_mps = ros;
    row.N_RAW = n_raw;
    row.Slot_Duration_Count = sdc;
    row.Alpha = alpha;
    row.Beta = beta_value;
    row.Beta_Regime = beta_regime;
    row.Geo_Regime = geo_regime;
    row.Geo_Preset = geo_preset;
    row.Execution_Key = string(sprintf( ...
        'R%d_PS%d_LS%d_C%d_ROS%s_RAW%d_SDC%d_A%s_B%s_G%s', ...
        replicate, pair_seed, layout_seed, camera, Number_Tag(ros), ...
        n_raw, sdc, Number_Tag(alpha), Number_Tag(beta_value), ...
        Safe_Tag(geo_preset)));
    row.Group_Key = string(sprintf('R%02d_A%s_B%s_G%s', ...
        replicate, Number_Tag(alpha), Number_Tag(beta_value), ...
        Safe_Tag(geo_preset)));
    row.Execution_Label = string(sprintf( ...
        'R%02d_C%d_ROS%s_RAW%d_SDC%d_A%s_B%s_%s', ...
        replicate, camera, Number_Tag(ros), n_raw, sdc, ...
        Number_Tag(alpha), Number_Tag(beta_value), ...
        Safe_Tag(geo_preset)));
end

function label = Geo_Regime_Label(preset)
    token = lower(string(preset));
    switch token
        case "center-isotropic"
            label = "CenterIsotropic";
        case "center-directional"
            label = "CenterDirectional";
        case "edge-isotropic"
            label = "EdgeIsotropic";
        case "edge-directional"
            label = "EdgeDirectional";
        otherwise
            label = string(preset);
    end
end

function run_cfg = Build_Group_Config(Cfg, rows, checkpoint_dir)
    run_cfg = Cfg;
    run_cfg.Alpha = rows.Alpha(1);
    run_cfg.Beta = rows.Beta(1);
    run_cfg.GeoPreset = char(rows.Geo_Preset(1));
    run_cfg.LayoutSeed = rows.Layout_Seed(1);
    run_cfg.RandomSeedBase = rows.Pair_Seed(1);
    run_cfg.CameraFrameIntervalSec = ...
        run_cfg.CameraFrameBytes * 8 / run_cfg.CameraBitrate_bps;
    run_cfg.SavePrefix = fullfile( ...
        checkpoint_dir, Safe_Tag(rows.Group_Key(1)));
    n = height(rows);
    run_cfg.Cases = table((1:n).', rows.Execution_Label, ...
        rows.NCamera, rows.ROS_mps, rows.N_RAW, ...
        rows.Slot_Duration_Count, ...
        'VariableNames', {'Case_ID', 'Case_Label', 'NCamera', ...
        'ROS_mps', 'N_RAW', 'Slot_Duration_Count'});
    max_raw_slot_slots = max(ceil((500 + ...
        120 * rows.Slot_Duration_Count) / 52));
    run_cfg.ChannelHistorySlots = max( ...
        run_cfg.ChannelHistorySlots, max_raw_slot_slots + 128);
end

function T = Decorate_Execution_Table(T, design_rows)
    if isempty(T)
        return;
    end
    local_case_id = T.Case_ID;
    if any(local_case_id < 1 | ...
            local_case_id > height(design_rows) | ...
            local_case_id ~= round(local_case_id))
        error('ED:InvalidPaper1CaseID', ...
            'A group result contains an invalid local case ID.');
    end
    T.Local_Case_ID = local_case_id;
    T.Case_ID = design_rows.Execution_ID(local_case_id);
    T.Execution_ID = design_rows.Execution_ID(local_case_id);
    T.Execution_Key = design_rows.Execution_Key(local_case_id);
    T.Execution_Label = design_rows.Execution_Label(local_case_id);
    T.Primary_Experiment = design_rows.Experiment(local_case_id);
    T.Replicate = design_rows.Replicate(local_case_id);
    T.Pair_Seed = design_rows.Pair_Seed(local_case_id);
    T.Layout_Seed = design_rows.Layout_Seed(local_case_id);
    T.Beta_Regime = design_rows.Beta_Regime(local_case_id);
    T.Geo_Regime = design_rows.Geo_Regime(local_case_id);
    T.Geo_Preset = design_rows.Geo_Preset(local_case_id);
end

function Summary = Add_Derived_Metrics( ...
    Summary, Trace, Deployment, Cfg)

    n_summary = height(Summary);
    peak_reference_rate = nan(n_summary, 1);
    peak_physical_rate = nan(n_summary, 1);
    overload_duration = nan(n_summary, 1);
    overlap_two = nan(n_summary, 1);
    overlap_all = nan(n_summary, 1);
    t10 = nan(n_summary, 1);
    t50 = nan(n_summary, 1);
    t90 = nan(n_summary, 1);
    alarm_max_age = nan(n_summary, 1);
    camera_max_age = nan(n_summary, 1);
    trigger_cv = nan(n_summary, 1);
    trigger_max_share = nan(n_summary, 1);

    for row_idx = 1:n_summary
        execution_id = Summary.Execution_ID(row_idx);
        trace_rows = Trace(Trace.Execution_ID == execution_id, :);
        if ~isempty(trace_rows)
            trace_rows = sortrows(trace_rows, 'TimeSec');
            time_s = trace_rows.TimeSec;
            dt = [time_s(1); diff(time_s)];
            valid_dt = dt > 0;
            peak_reference_rate(row_idx) = Peak_Increment_Rate( ...
                trace_rows.ReferenceActiveAlarmSTA, dt, valid_dt);
            peak_physical_rate(row_idx) = Peak_Increment_Rate( ...
                trace_rows.ActiveAlarmSTA, dt, valid_dt);
            overload_duration(row_idx) = sum(dt(valid_dt & ...
                trace_rows.Interval_Offered_Exceeds_PHY));
            overlap_two(row_idx) = sum(dt(valid_dt & ...
                trace_rows.ActiveCameraSTA >= 2));
            if Summary.Camera_STA(row_idx) > 0
                overlap_all(row_idx) = sum(dt(valid_dt & ...
                    trace_rows.ActiveCameraSTA >= ...
                    Summary.Camera_STA(row_idx)));
            else
                overlap_all(row_idx) = 0;
            end
            target = Summary.Target_Active_Alarm_STA(row_idx);
            t10(row_idx) = Threshold_Fire_Time( ...
                time_s, trace_rows.ReferenceActiveAlarmSTA, ...
                0.10 * target, Cfg.PreSurgeSec);
            t50(row_idx) = Threshold_Fire_Time( ...
                time_s, trace_rows.ReferenceActiveAlarmSTA, ...
                0.50 * target, Cfg.PreSurgeSec);
            t90(row_idx) = Threshold_Fire_Time( ...
                time_s, trace_rows.ReferenceActiveAlarmSTA, ...
                0.90 * target, Cfg.PreSurgeSec);
            alarm_max_age(row_idx) = Max_Finite( ...
                trace_rows.Alarm_Oldest_Buffered_Age_s);
            camera_max_age(row_idx) = Max_Finite( ...
                trace_rows.Camera_Oldest_Buffered_Age_s);
        end

        if isempty(Deployment)
            deployment_rows = table();
        else
            deployment_rows = Deployment( ...
                Deployment.Execution_ID == execution_id, :);
        end
        if ~isempty(deployment_rows)
            triggers = deployment_rows.Sensor_Trigger_Count;
            total_triggers = sum(triggers);
            if mean(triggers) > 0
                trigger_cv(row_idx) = std(triggers, 0) / mean(triggers);
            end
            if total_triggers > 0
                trigger_max_share(row_idx) = ...
                    max(triggers) / total_triggers;
            end
        end
    end

    Summary.Peak_Reference_Activation_Rate_STA_per_s = ...
        peak_reference_rate;
    Summary.Peak_Physical_Activation_Rate_STA_per_s = ...
        peak_physical_rate;
    Summary.PHY_Overload_Duration_s = overload_duration;
    Summary.Camera_Overlap_2Plus_s = overlap_two;
    Summary.Camera_Overlap_All_s = overlap_all;
    Summary.Reference_T10_FireElapsed_s = t10;
    Summary.Reference_T50_FireElapsed_s = t50;
    Summary.Reference_T90_FireElapsed_s = t90;
    Summary.Alarm_Max_Oldest_Buffered_Age_s = alarm_max_age;
    Summary.Camera_Max_Oldest_Buffered_Age_s = camera_max_age;
    Summary.Camera_Trigger_Count_CV = trigger_cv;
    Summary.Camera_Trigger_Max_Share = trigger_max_share;
end

function rate = Peak_Increment_Rate(values, dt, valid_dt)
    increments = [values(1); diff(values)];
    increments = max(0, increments);
    rates = increments(valid_dt) ./ dt(valid_dt);
    if isempty(rates)
        rate = NaN;
    else
        rate = max(rates);
    end
end

function time_value = Threshold_Fire_Time( ...
    time_s, active_count, threshold, pre_surge_s)
    index = find(active_count >= threshold, 1, 'first');
    if isempty(index)
        time_value = NaN;
    else
        time_value = max(0, time_s(index) - pre_surge_s);
    end
end

function value = Max_Finite(values)
    values = values(isfinite(values));
    if isempty(values)
        value = NaN;
    else
        value = max(values);
    end
end

function Summary = Expand_Summary(ExecutionSummary, Design)
    [found, location] = ismember( ...
        Design.Execution_ID, ExecutionSummary.Execution_ID);
    if any(~found)
        error('ED:MissingPaper1ExecutionResult', ...
            'One or more design executions have no summary result.');
    end
    Summary = ExecutionSummary(location, :);
    Summary = Apply_Membership_Columns(Summary, Design);
end

function Expanded = Expand_Repeated_Table(T, Design)
    if isempty(T)
        Expanded = table();
        return;
    end
    cells = cell(height(Design), 1);
    for row_idx = 1:height(Design)
        block = T(T.Execution_ID == Design.Execution_ID(row_idx), :);
        if ~isempty(block)
            membership = Design(repmat(row_idx, height(block), 1), :);
            block = Apply_Membership_Columns(block, membership);
        end
        cells{row_idx} = block;
    end
    Expanded = Vertcat_Nonempty(cells);
end

function T = Apply_Membership_Columns(T, membership)
    T.Case_ID = membership.Analysis_Case_ID;
    T.Analysis_Case_ID = membership.Analysis_Case_ID;
    T.Experiment = membership.Experiment;
    T.Condition_ID = membership.Condition_ID;
    T.Condition_Label = membership.Condition_Label;
    T.Replicate = membership.Replicate;
    T.Pair_Seed = membership.Pair_Seed;
    T.Layout_Seed = membership.Layout_Seed;
    T.Beta_Regime = membership.Beta_Regime;
    T.Geo_Regime = membership.Geo_Regime;
    T.Geo_Preset = membership.Geo_Preset;
end

function Aggregate = Aggregate_Replicates(Summary)
    metric_names = [ ...
        "Peak_Reference_Activation_Rate_STA_per_s", ...
        "Peak_Physical_Activation_Rate_STA_per_s", ...
        "Max_Concurrent_Cameras", ...
        "Camera_Active_Time_Sum_s", ...
        "Peak_Interval_Offered_Load_Mbps", ...
        "PHY_Overload_Duration_s", ...
        "Camera_Overlap_2Plus_s", ...
        "Camera_Overlap_All_s", ...
        "Camera_Trigger_Count_CV", ...
        "Camera_Trigger_Max_Share", ...
        "Alarm_PDR", "Alarm_All_Packet_Deadline_PDR", ...
        "Alarm_Delay_P95_s", "Alarm_Delay_Max_s", ...
        "Alarm_Max_Oldest_Buffered_Age_s", ...
        "Camera_PDR", "Camera_Deadline_PDR", ...
        "Camera_Delay_P95_s", "Camera_Delay_Max_s", ...
        "Camera_Max_Oldest_Buffered_Age_s", ...
        "Network_Throughput_Mbps", "Observed_Network_Overload", ...
        "Elapsed_s", "Processed_Event_Slots"];

    condition_ids = unique(Summary.Condition_ID, 'stable');
    row_cells = cell(numel(condition_ids), 1);
    for condition_idx = 1:numel(condition_ids)
        condition_rows = Summary( ...
            Summary.Condition_ID == condition_ids(condition_idx), :);
        first = condition_rows(1, :);
        row = struct();
        row.Experiment = first.Experiment;
        row.Condition_ID = first.Condition_ID;
        row.Condition_Label = first.Condition_Label;
        row.NCamera = first.Camera_STA;
        row.ROS_mps = first.ROS_mps;
        row.N_RAW = first.N_RAW;
        row.Slot_Duration_Count = first.Slot_Duration_Count;
        row.Alpha = first.Alpha;
        row.Beta = first.Beta;
        row.Beta_Regime = first.Beta_Regime;
        row.Geo_Regime = first.Geo_Regime;
        row.Geo_Preset = first.Geo_Preset;
        row.Replicate_Count = height(condition_rows);
        for metric_idx = 1:numel(metric_names)
            metric = metric_names(metric_idx);
            values = double(condition_rows.(char(metric)));
            values = values(isfinite(values));
            n = numel(values);
            if n == 0
                mean_value = NaN;
                std_value = NaN;
                ci95 = NaN;
            elseif n == 1
                mean_value = values;
                std_value = NaN;
                ci95 = NaN;
            else
                mean_value = mean(values);
                std_value = std(values, 0);
                ci95 = Student_T_Critical_95(n - 1) * ...
                    std_value / sqrt(n);
            end
            row.(char(metric + "_N")) = n;
            row.(char(metric + "_Mean")) = mean_value;
            row.(char(metric + "_Std")) = std_value;
            row.(char(metric + "_CI95")) = ci95;
        end
        row_cells{condition_idx} = row;
    end
    Aggregate = struct2table(vertcat(row_cells{:}));
end

function critical = Student_T_Critical_95(df)
    lookup = [12.706 4.303 3.182 2.776 2.571 2.447 2.365 ...
        2.306 2.262 2.228 2.201 2.179 2.160 2.145 2.131 ...
        2.120 2.110 2.101 2.093 2.086 2.080 2.074 2.069 ...
        2.064 2.060 2.056 2.052 2.048 2.045 2.042];
    if df <= numel(lookup)
        critical = lookup(df);
    elseif df <= 40
        critical = 2.021;
    elseif df <= 60
        critical = 2.000;
    elseif df <= 120
        critical = 1.980;
    else
        critical = 1.960;
    end
end

function Results = Empty_Results(Study, Cfg, Design, ExecutionDesign)
    Results = struct();
    Results.Study = Study;
    Results.Config = Cfg;
    Results.Design = Design;
    Results.ExecutionDesign = ExecutionDesign;
    Results.ExecutionSummary = table();
    Results.ExecutionTimeSeries = table();
    Results.ExecutionDeployment = table();
    Results.Summary = table();
    Results.TimeSeries = table();
    Results.Deployment = table();
    Results.Aggregate = table();
end

function result = Vertcat_Nonempty(cells)
    keep = cellfun(@(x) istable(x) && ~isempty(x), cells);
    if any(keep)
        result = vertcat(cells{keep});
    else
        result = table();
    end
end

function tag = Safe_Tag(value)
    tag = regexprep(char(value), '[^A-Za-z0-9_-]', '_');
end

function tag = Number_Tag(value)
    tag = regexprep(sprintf('%.12g', value), '[^A-Za-z0-9]', 'p');
end

function path_value = Resolve_Path(project_dir, path_value)
    path_value = char(path_value);
    is_windows_absolute = ~isempty(regexp( ...
        path_value, '^[A-Za-z]:[\\/]', 'once'));
    is_unc = startsWith(path_value, '\\');
    if ~is_windows_absolute && ~is_unc
        path_value = fullfile(project_dir, path_value);
    end
end
