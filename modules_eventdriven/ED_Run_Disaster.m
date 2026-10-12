function [SimState, Trace] = ED_Run_Disaster(SimParams)
%ED_RUN_DISASTER Run one Mode-3 disaster with event-slot skipping.

    [SimState, SimParams] = ED_Init_Network(SimParams);
    report_interval = Get_Field_Or_Default( ...
        SimParams, 'ReportIntervalSlots', inf);
    collect_trace = isfinite(report_interval) && report_interval > 0;
    record_debug = isfield(SimParams, 'ED_Record_Debug_State') && ...
        SimParams.ED_Record_Debug_State;
    if record_debug
        SimState.ED_Debug = struct();
    end
    next_report = SimState.Time;
    rows = cell(0, 1);
    progress_interval = Get_Field_Or_Default( ...
        SimParams, 'ED_Progress_Interval_Slots', inf);
    next_progress = SimState.Time + progress_interval;
    checkpoint_interval = Get_Field_Or_Default( ...
        SimParams, 'ED_Checkpoint_Interval_Slots', inf);
    next_checkpoint = SimState.Time + checkpoint_interval;
    checkpoint_file = Get_Field_Or_Default( ...
        SimParams, 'ED_Checkpoint_File', '');
    fingerprint = Get_Field_Or_Default( ...
        SimParams, 'ED_Checkpoint_Fingerprint', []);

    resume_checkpoint = Get_Field_Or_Default( ...
        SimParams, 'ED_Resume_From_Checkpoint', false);
    if resume_checkpoint && ~isempty(checkpoint_file) && ...
       exist(checkpoint_file, 'file') == 2
        [resumed, SimState, rows, next_report, next_progress, ...
            next_checkpoint] = Load_Checkpoint( ...
            checkpoint_file, fingerprint, SimState, rows, ...
            next_report, next_progress, next_checkpoint);
        if resumed
            SimState = ED_Upgrade_TXOP_State(SimState, SimParams);
        end
        if resumed && Get_Field_Or_Default( ...
                SimParams, 'ED_Show_Progress', false)
            fprintf('[%s] resumed at %.1f%% (sim %.1f s).\n', ...
                Get_Field_Or_Default(SimParams, ...
                    'ED_Progress_Label', 'event-driven run'), ...
                100 * SimState.Time / SimParams.N_slot, ...
                SimState.Time * SimParams.T_slot);
        end
    end

    while SimState.Time <= SimParams.N_slot
        SimState = ED_Manage_RAW(SimState, SimParams);
        SimState = ED_MAC_Access(SimState, SimParams);
        SimState = ED_Handle_Tx_Events(SimState, SimParams);
        SimState = ED_Generate_Traffic(SimState, SimParams);
        SimState.ED_Stats.ProcessedSlots = ...
            SimState.ED_Stats.ProcessedSlots + 1;
        if record_debug
            SimState = Append_Debug_State(SimState, SimParams);
        end

        if collect_trace && ...
           (SimState.Time >= next_report || ...
            SimState.Time == SimParams.N_slot)
            rows{end + 1, 1} = Make_Trace_Row( ...
                SimState, SimParams); %#ok<AGROW>
            while next_report <= SimState.Time
                next_report = next_report + report_interval;
            end
        end

        if SimState.Time >= SimParams.N_slot
            break;
        end

        next_slot = ED_Find_Next_Event( ...
            SimState, SimParams, next_report);
        skipped = next_slot - SimState.Time - 1;
        SimState = ED_Advance_Countdowns( ...
            SimState, SimParams, skipped);
        if skipped > 0
            SimState.ED_Stats.SkippedSlots = ...
                SimState.ED_Stats.SkippedSlots + skipped;
            SimState.ED_Stats.JumpCount = ...
                SimState.ED_Stats.JumpCount + 1;
            SimState.ED_Stats.MaxJumpSlots = max( ...
                SimState.ED_Stats.MaxJumpSlots, skipped);
        end
        SimState.Time = next_slot;

        if SimState.Time >= next_progress
            Print_Progress(SimState, SimParams);
            while next_progress <= SimState.Time
                next_progress = next_progress + progress_interval;
            end
        end
        if ~isempty(checkpoint_file) && ...
           SimState.Time >= next_checkpoint
            while next_checkpoint <= SimState.Time
                next_checkpoint = next_checkpoint + checkpoint_interval;
            end
            Save_Checkpoint(checkpoint_file, fingerprint, ...
                SimState, rows, next_report, next_progress, ...
                next_checkpoint);
        end
    end

    SimState = ED_Materialize_Delays(SimState);
    if ~isempty(checkpoint_file) && exist(checkpoint_file, 'file') == 2
        delete(checkpoint_file);
    end
    if isempty(rows)
        Trace = table();
    else
        Trace = struct2table([rows{:}]);
    end
end

function SimState = Append_Debug_State(SimState, SimParams)
    if ~isfield(SimState.ED_Debug, 'Time')
        row = 1;
    else
        row = numel(SimState.ED_Debug.Time) + 1;
    end
    SimState.ED_Debug.Time(row, 1) = SimState.Time;
    SimState.ED_Debug.bc(row, :) = SimState.Node.bc;
    SimState.ED_Debug.aifs(row, :) = SimState.Node.aifs;
    SimState.ED_Debug.n_access(row, :) = SimState.n_access;
    SimState.ED_Debug.n_success2(row, :) = SimState.n_success2;
    SimState.ED_Debug.n_txnode(row, :) = SimState.n_txnode;
    SimState.ED_Debug.tx_status(row, :) = SimState.tx_status(:).';
    SimState.ED_Debug.ACK_Timer(row, :) = ...
        SimState.Node.ACK_Timer(:).';
    SimState.ED_Debug.BufferLength(row, :) = arrayfun( ...
        @(id) SimState.Node.TX_Buffer(id).Length, ...
        1:SimParams.N_Node);
    SimState.ED_Debug.NextAlarm(row, :) = ...
        SimState.Next_Frame_Interval_al;
    SimState.ED_Debug.NextBackground(row, :) = ...
        SimState.Next_Frame_Interval_bk;
    SimState.ED_Debug.GID(row, 1) = SimState.GID;
    [assigned, ~] = ED_Get_Active_RAW_Assignment( ...
        SimState, SimParams);
    assigned_mask = false(1, SimParams.N_Node);
    assigned_mask(assigned) = true;
    SimState.ED_Debug.AssignedMask(row, :) = assigned_mask;
    SimState.ED_Debug.Next_BTT(row, :) = SimState.Next_BTT;
end

function row = Make_Trace_Row(SimState, SimParams)
    sta = SimParams.idx_STA;
    alarm = SimParams.idx_STA_Type1;
    camera = Get_Camera_IDs(SimParams);
    row.TimeSlot = SimState.Time;
    row.TimeSec = SimState.Time * SimParams.T_slot;
    row.ReferenceActiveAlarmSTA = ...
        SimState.ED_Reference_Active_Count;
    row.ActiveAlarmSTA = SimState.ED_Active_Alarm_Count;
    row.N_Enqueued = sum(SimState.n_enq(sta));
    row.N_Access = sum(SimState.n_access(sta));
    row.N_Success_ACKed = sum(SimState.n_success2(sta));
    row.N_Data_Collision = sum(SimState.n_collision(sta));
    row.N_ACK_Timeout = sum(SimState.n_collision2(sta));
    row.N_Loss = sum(SimState.n_loss(sta));
    row.Success_Bytes = sum(SimState.L_success(sta));
    row.Buffered_Frames = sum(arrayfun( ...
        @(id) SimState.Node.TX_Buffer(id).Length, sta));
    row.Alarm_N_Enqueued = sum(SimState.n_enq(alarm));
    row.Alarm_N_Access = sum(SimState.n_access(alarm));
    row.Alarm_N_Success_ACKed = sum(SimState.n_success2(alarm));
    row.Alarm_N_Loss = sum(SimState.n_loss(alarm));
    row.Alarm_Success_Bytes = sum(SimState.L_success(alarm));
    row.Alarm_Buffered_Frames = sum(arrayfun( ...
        @(id) SimState.Node.TX_Buffer(id).Length, alarm));
    row.Alarm_Oldest_Buffered_Age_s = Oldest_Buffered_Age_s( ...
        SimState, SimParams, alarm);
    row.ActiveCameraSTA = Count_Active_Cameras(SimState);
    row.Camera_N_Enqueued = sum(SimState.n_enq(camera));
    row.Camera_N_Access = sum(SimState.n_access(camera));
    row.Camera_N_Success_ACKed = sum(SimState.n_success2(camera));
    row.Camera_N_Data_Collision = sum(SimState.n_collision(camera));
    row.Camera_N_ACK_Timeout = sum(SimState.n_collision2(camera));
    row.Camera_N_Loss = sum(SimState.n_loss(camera));
    row.Camera_Success_Bytes = sum(SimState.L_success(camera));
    row.Camera_Buffered_Frames = sum(arrayfun( ...
        @(id) SimState.Node.TX_Buffer(id).Length, camera));
    row.Camera_Oldest_Buffered_Age_s = Oldest_Buffered_Age_s( ...
        SimState, SimParams, camera);
    row.Camera_TXOP_Acquisitions = sum( ...
        SimState.ED_TXOP.Acquisitions(camera));
    row.Camera_TXOP_Continuation_Attempts = sum( ...
        SimState.ED_TXOP.ContinuationAttempts(camera));
    row.Camera_TXOP_Reservation_Foreign_Data_Starts = sum( ...
        SimState.ED_TXOP.ReservationForeignDataStarts(camera));
    row.Camera_TXOP_Reservation_Hidden_Data_Starts = sum( ...
        SimState.ED_TXOP.ReservationHiddenDataStarts(camera));
    row.Processed_Event_Slots = SimState.ED_Stats.ProcessedSlots;
    row.Skipped_Idle_Slots = SimState.ED_Stats.SkippedSlots;
end

function age_s = Oldest_Buffered_Age_s(SimState, SimParams, node_ids)
    oldest_generated_slot = inf;
    for node_id = node_ids
        if SimState.Node.TX_Buffer(node_id).Length <= 0
            continue;
        end
        mpdu = ED_Peek_MPDU(SimState.Node.TX_Buffer(node_id));
        oldest_generated_slot = min(oldest_generated_slot, mpdu(3));
    end
    if isfinite(oldest_generated_slot)
        age_s = max(0, SimState.Time - oldest_generated_slot) * ...
            SimParams.T_slot;
    else
        age_s = NaN;
    end
end

function ids = Get_Camera_IDs(SimParams)
    if isfield(SimParams, 'idx_Camera_STA')
        ids = SimParams.idx_Camera_STA;
    else
        ids = zeros(1, 0);
    end
end

function count = Count_Active_Cameras(SimState)
    if ~isfield(SimState, 'ED_Camera') || ...
       ~SimState.ED_Camera.Enabled
        count = 0;
        return;
    end
    count = sum(SimState.ED_Camera.Active_Until_Slot >= ...
        SimState.Time);
end

function value = Get_Field_Or_Default(S, field_name, default_value)
    if isfield(S, field_name) && ~isempty(S.(field_name))
        value = S.(field_name);
    else
        value = default_value;
    end
end

function Print_Progress(SimState, SimParams)
    if ~Get_Field_Or_Default(SimParams, 'ED_Show_Progress', false)
        return;
    end
    label = Get_Field_Or_Default( ...
        SimParams, 'ED_Progress_Label', 'event-driven run');
    lengths = [SimState.Node.TX_Buffer.Length];
    fprintf(['[%s] %5.1f%%, sim %.1f/%.1f s, processed=%d, ' ...
        'skipped=%d, buffered=%d\n'], label, ...
        100 * SimState.Time / SimParams.N_slot, ...
        SimState.Time * SimParams.T_slot, ...
        SimParams.N_slot * SimParams.T_slot, ...
        SimState.ED_Stats.ProcessedSlots, ...
        SimState.ED_Stats.SkippedSlots, sum(lengths));
end

function Save_Checkpoint(file_name, fingerprint, SimState, rows, ...
    next_report, next_progress, next_checkpoint)

    Checkpoint = struct();
    Checkpoint.SchemaVersion = 2;
    Checkpoint.Fingerprint = fingerprint;
    Checkpoint.SimState = SimState;
    Checkpoint.Rows = rows;
    Checkpoint.NextReport = next_report;
    Checkpoint.NextProgress = next_progress;
    Checkpoint.NextCheckpoint = next_checkpoint;
    Checkpoint.RNGState = rng;

    folder = fileparts(file_name);
    if ~isempty(folder) && exist(folder, 'dir') ~= 7
        mkdir(folder);
    end
    temp_file = sprintf('%s.tmp-%d.mat', ...
        file_name, feature('getpid'));
    save(temp_file, 'Checkpoint', '-v7.3');
    [ok, message] = movefile(temp_file, file_name, 'f');
    if ~ok
        if exist(temp_file, 'file') == 2
            delete(temp_file);
        end
        error('ED:CheckpointMoveFailed', ...
            'Could not finalize checkpoint %s: %s', file_name, message);
    end
end

function [resumed, SimState, rows, next_report, next_progress, ...
    next_checkpoint] = Load_Checkpoint(file_name, fingerprint, ...
    SimState, rows, next_report, next_progress, next_checkpoint)

    resumed = false;
    try
        loaded = load(file_name, 'Checkpoint');
        if ~isfield(loaded, 'Checkpoint') || ...
           ~isstruct(loaded.Checkpoint) || ...
           ~isfield(loaded.Checkpoint, 'SchemaVersion') || ...
           loaded.Checkpoint.SchemaVersion ~= 2 || ...
           ~isfield(loaded.Checkpoint, 'Fingerprint') || ...
           ~isequaln(loaded.Checkpoint.Fingerprint, fingerprint)
            return;
        end
        required = {'SimState', 'Rows', 'NextReport', ...
            'NextProgress', 'NextCheckpoint', 'RNGState'};
        if ~all(isfield(loaded.Checkpoint, required))
            return;
        end
        SimState = loaded.Checkpoint.SimState;
        rows = loaded.Checkpoint.Rows;
        next_report = loaded.Checkpoint.NextReport;
        next_progress = loaded.Checkpoint.NextProgress;
        next_checkpoint = loaded.Checkpoint.NextCheckpoint;
        rng(loaded.Checkpoint.RNGState);
        resumed = true;
    catch ME
        warning('ED:CheckpointLoadFailed', ...
            'Ignoring checkpoint %s: %s', file_name, ME.message);
    end
end
