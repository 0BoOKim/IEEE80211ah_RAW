function Summary = ED_Summarize_Camera_Overload( ...
    SimState, SimParams, Trace, Cfg, case_row, elapsed_s)
%ED_SUMMARIZE_CAMERA_OVERLOAD Build class-specific QoS overload metrics.

    alarm = SimParams.idx_STA_Type1;
    camera = SimParams.idx_Camera_STA;
    all_sta = SimParams.idx_STA;
    sim_time_s = SimParams.N_slot * SimParams.T_slot;

    alarm_delay_slots = Collect_Delay_Rows(SimState, alarm);
    camera_delay_slots = Collect_Delay_Rows(SimState, camera);
    alarm_delay_s = Get_Delay_Seconds(alarm_delay_slots, SimParams.T_slot);
    camera_delay_s = Get_Delay_Seconds(camera_delay_slots, SimParams.T_slot);

    alarm_enqueued = sum(SimState.n_enq(alarm));
    camera_enqueued = sum(SimState.n_enq(camera));
    all_enqueued = sum(SimState.n_enq(all_sta));
    alarm_success = sum(SimState.n_success2(alarm));
    camera_success = sum(SimState.n_success2(camera));
    all_success = sum(SimState.n_success2(all_sta));
    alarm_buffered = Buffer_Length(SimState, alarm);
    camera_buffered = Buffer_Length(SimState, camera);

    [initial_met, initial_total] = Count_Initial_Alarm_Deadlines( ...
        SimState, SimParams, Cfg.AlarmInitialDeadlineSec);
    alarm_deadline_success = sum( ...
        alarm_delay_s <= Cfg.AlarmPacketDeadlineSec);
    camera_deadline_success = sum( ...
        camera_delay_s <= Cfg.CameraPacketDeadlineSec);

    alarm_pdr = Divide(alarm_success, alarm_enqueued);
    camera_pdr = Divide(camera_success, camera_enqueued);
    network_pdr = Divide(all_success, all_enqueued);
    alarm_initial_deadline_pdr = Divide(initial_met, initial_total);
    alarm_deadline_pdr = Divide( ...
        alarm_deadline_success, alarm_enqueued);
    camera_deadline_pdr = Divide( ...
        camera_deadline_success, camera_enqueued);

    camera_node_pdr = Per_Node_Ratio( ...
        SimState.n_success2, SimState.n_enq, camera);
    camera_node_deadline_pdr = Per_Node_Deadline_PDR( ...
        SimState, camera, Cfg.CameraPacketDeadlineSec, ...
        SimParams.T_slot);
    camera_node_goodput_mbps = ...
        SimState.L_success(camera).' * 8 / sim_time_s / 1e6;

    alarm_data_airtime_s = Sum_Airtime( ...
        SimState, 'DATA_Attempt_Slots', alarm, SimParams.T_slot);
    camera_data_airtime_s = Sum_Airtime( ...
        SimState, 'DATA_Attempt_Slots', camera, SimParams.T_slot);
    alarm_ack_airtime_s = Sum_Airtime( ...
        SimState, 'ACK_Attempt_Slots_By_Destination', ...
        alarm, SimParams.T_slot);
    camera_ack_airtime_s = Sum_Airtime( ...
        SimState, 'ACK_Attempt_Slots_By_Destination', ...
        camera, SimParams.T_slot);
    alarm_attempt_airtime_s = ...
        alarm_data_airtime_s + alarm_ack_airtime_s;
    camera_attempt_airtime_s = ...
        camera_data_airtime_s + camera_ack_airtime_s;

    camera_active_time_s = Camera_Active_Time(SimState, SimParams);
    if camera_active_time_s > 0
        camera_offered_active_mbps = camera_enqueued * ...
            Cfg.CameraFrameBytes * 8 / camera_active_time_s / 1e6;
    else
        camera_offered_active_mbps = NaN;
    end

    peak_offered_mbps = Max_Column(Trace, ...
        'Interval_Total_Offered_Mbps');
    phy_rate_mbps = min(SimParams.R_data(all_sta)) / 1e6;
    raw_cycle_s = SimParams.BSS_RAW_Cycle_Interval(1) * ...
        SimParams.T_slot;
    one_mpdu_cycle_mbps = Cfg.CameraFrameBytes * 8 / ...
        raw_cycle_s / 1e6;

    has_camera = ~isempty(camera);
    camera_overload = has_camera && ( ...
        camera_pdr < Cfg.MinCameraPDR || ...
        camera_deadline_pdr < Cfg.MinCameraDeadlinePDR || ...
        camera_buffered > Cfg.MaxFinalBufferedFrames);
    alarm_overload = alarm_initial_deadline_pdr < ...
        Cfg.MinAlarmInitialDeadlinePDR || ...
        alarm_deadline_pdr < Cfg.MinAlarmDeadlinePDR || ...
        alarm_buffered > Cfg.MaxFinalBufferedFrames;
    observed_overload = camera_overload || alarm_overload;

    row.Case_ID = case_row.Case_ID;
    row.Case_Label = string(case_row.Case_Label);
    row.Method = string(SimParams.MethodName);
    row.TimeSeries_Enabled = Get_Field_Or_Default( ...
        Cfg, 'CollectTimeSeries', false);
    row.TimeSeries_Interval_s = Get_Field_Or_Default( ...
        Cfg, 'ReportIntervalSec', NaN);
    row.Delay_TimeSeries_Success_Only = true;
    row.EDCA_Enabled = Get_Field_Or_Default( ...
        SimParams, 'EDCA_Enabled', false);
    row.Alarm_Access_Category = string(Get_Field_Or_Default( ...
        SimParams, 'EDCA_Alarm_Access_Category', 'DCF'));
    row.Camera_Access_Category = string(Get_Field_Or_Default( ...
        SimParams, 'EDCA_Camera_Access_Category', 'DCF'));
    row.Alarm_EDCA_AIFSN = Get_Field_Or_Default( ...
        SimParams, 'EDCA_Alarm_AIFSN', NaN);
    row.Camera_EDCA_AIFSN = Get_Field_Or_Default( ...
        SimParams, 'EDCA_Camera_AIFSN', NaN);
    row.Alarm_AIFS_Slots = Get_Field_Or_Default( ...
        SimParams, 'EDCA_Alarm_AIFS_Slots', NaN);
    row.Camera_AIFS_Slots = Get_Field_Or_Default( ...
        SimParams, 'EDCA_Camera_AIFS_Slots', NaN);
    row.Alarm_EDCA_CWmin = Get_Field_Or_Default( ...
        SimParams, 'EDCA_Alarm_CWmin', NaN);
    row.Alarm_EDCA_CWmax = Get_Field_Or_Default( ...
        SimParams, 'EDCA_Alarm_CWmax', NaN);
    row.Camera_EDCA_CWmin = Get_Field_Or_Default( ...
        SimParams, 'EDCA_Camera_CWmin', NaN);
    row.Camera_EDCA_CWmax = Get_Field_Or_Default( ...
        SimParams, 'EDCA_Camera_CWmax', NaN);
    row.EDCA_TXOP_Enabled = Get_Field_Or_Default( ...
        SimParams, 'EDCA_TXOP_Enabled', false);
    row.Camera_TXOP_Mode = string(Get_Field_Or_Default( ...
        SimParams, 'EDCA_TXOP_Mode', 'disabled'));
    row.Camera_TXOP_Boundary_Mode = string(Get_Field_Or_Default( ...
        SimParams, 'EDCA_TXOP_Boundary_Mode', 'disabled'));
    row.Camera_TXOP_Cross_Slot_Allowed = Get_Field_Or_Default( ...
        SimParams, 'EDCA_TXOP_Cross_Slot_Allowed', false);
    row.Camera_TXOP_Dynamic_Period_End = Get_Field_Or_Default( ...
        SimParams, 'EDCA_TXOP_Dynamic_Period_End', false);
    row.Camera_TXOP_Duration_Multiplier = Get_Field_Or_Default( ...
        SimParams, 'EDCA_TXOP_Duration_Multiplier', 0);
    base_txop_limit_us = Get_Field_Or_Default( ...
        SimParams, 'EDCA_TXOP_Base_Limit_us_By_BSS', 0);
    row.Camera_TXOP_Base_Limit_ms = base_txop_limit_us(1) / 1e3;
    txop_limit_us = Get_Field_Or_Default( ...
        SimParams, 'EDCA_TXOP_Limit_us_By_BSS', 0);
    row.Camera_TXOP_Limit_ms = txop_limit_us(1) / 1e3;
    txop_limit_slots = Get_Field_Or_Default( ...
        SimParams, 'EDCA_TXOP_Limit_Slots_By_BSS', 0);
    row.Camera_TXOP_Quantized_Limit_ms = ...
        txop_limit_slots(1) * SimParams.T_slot * 1e3;
    row.Camera_TXOP_SDC_Fraction = Get_Field_Or_Default( ...
        SimParams, 'EDCA_TXOP_SDC_Fraction', 0);
    row.Camera_TXOP_Guard_Slots = Get_Field_Or_Default( ...
        SimParams, 'EDCA_TXOP_Guard_Slots', 0);
    row.Camera_TXOP_Max_MPDUs_Mode = string(Get_Field_Or_Default( ...
        SimParams, 'EDCA_TXOP_Max_MPDUs_Mode', 'disabled'));
    row.Camera_TXOP_NAV_Enabled = Get_Field_Or_Default( ...
        SimParams, 'EDCA_TXOP_NAV_Enabled', false);
    row.Camera_TXOP_Reservation_Mode = string(Get_Field_Or_Default( ...
        SimParams, 'EDCA_TXOP_Reservation_Mode', 'unknown'));
    txop_max_mpdus = Get_Field_Or_Default( ...
        SimParams, 'EDCA_TXOP_Max_MPDUs', ones(1, SimParams.N_Node));
    if isempty(camera)
        row.Camera_TXOP_Max_MPDUs = NaN;
    else
        row.Camera_TXOP_Max_MPDUs = txop_max_mpdus(camera(1));
    end
    row.RAW_Mode = SimParams.RAW_Mode;
    row.N_RAW = SimParams.N_RAW;
    row.Slot_Duration_Count = ...
        SimParams.BSS_Opt_Slot_Duration_Count(1);
    row.RAW_Slot_Duration_ms = SimParams.BSS_T_RAW_Slot(1) * 1e3;
    row.RAW_Slot_Quantized_Duration_ms = ...
        SimParams.BSS_T_RAW_Slot_in_Slot(1) * SimParams.T_slot * 1e3;
    row.RAW_Cycle_Duration_ms = ...
        SimParams.BSS_RAW_Cycle_Interval(1) * SimParams.T_slot * 1e3;
    row.STA_RAW_Duty_Ratio = 1 / SimParams.N_RAW;
    row.RAW_Offset_Mode = string(SimParams.RAW_Offset_Mode);
    row.RAW_Offset_Beacons = sum( ...
        [SimState.BSS.RAW_Offset_Beacon_Count]);
    row.RAW_Offset_Changes = sum( ...
        [SimState.BSS.RAW_Offset_Change_Count]);
    row.RAW_Offset_Repeats = sum( ...
        [SimState.BSS.RAW_Offset_Repeat_Count]);
    row.Background_STA = Cfg.NBackgroundSTA;
    row.Camera_STA = numel(camera);
    camera_peer_counts = zeros(numel(camera), 1);
    for camera_idx = 1:numel(camera)
        camera_peer_counts(camera_idx) = numel(intersect( ...
            SimState.Cached_CarrierSenseNodes{camera(camera_idx)}, ...
            setdiff(camera, camera(camera_idx))));
    end
    if isempty(camera_peer_counts)
        row.Camera_CarrierSense_Min_Peers = NaN;
        row.Camera_CarrierSense_Mean_Peers = NaN;
        row.Camera_CarrierSense_Fully_Connected = false;
    else
        row.Camera_CarrierSense_Min_Peers = min(camera_peer_counts);
        row.Camera_CarrierSense_Mean_Peers = mean(camera_peer_counts);
        row.Camera_CarrierSense_Fully_Connected = ...
            all(camera_peer_counts == max(0, numel(camera) - 1));
    end
    row.Installed_Alarm_STA = numel(alarm);
    row.Target_Active_Alarm_STA = SimParams.Reference_Target_Active_Alarm_STA;
    row.Final_Active_Alarm_STA = sum(arrayfun(@(id) ...
        SimState.Node.TX_Buffer(id).Triggered == 1, alarm));
    row.Alpha = Cfg.Alpha;
    row.Beta = Cfg.Beta;
    row.ROS_mps = case_row.ROS_mps;
    row.Fire_Network_Window_s = SimParams.Fire_Network_Window_s;
    row.Camera_Bitrate_Per_Active_Camera_Mbps = ...
        Cfg.CameraBitrate_bps / 1e6;
    row.Camera_Active_Time_Sum_s = camera_active_time_s;
    row.Max_Concurrent_Cameras = Get_Max_Concurrent(SimState);
    row.Final_Alarm_Periodic_Offered_Mbps = ...
        row.Final_Active_Alarm_STA * mean(Cfg.AlarmPayloadBytes) * 8 / ...
        Cfg.AlarmIntervalSec / 1e6;
    row.Peak_Camera_Application_Offered_Mbps = ...
        row.Max_Concurrent_Cameras * Cfg.CameraBitrate_bps / 1e6;
    row.Estimated_Peak_Application_Offered_Mbps = ...
        row.Final_Alarm_Periodic_Offered_Mbps + ...
        row.Peak_Camera_Application_Offered_Mbps;
    row.Peak_Interval_Offered_Load_Mbps = peak_offered_mbps;
    row.PHY_Rate_Mbps = phy_rate_mbps;
    row.Peak_Offered_Exceeds_PHY = peak_offered_mbps > phy_rate_mbps;
    row.One_MPDU_Per_RAW_Cycle_Mbps = one_mpdu_cycle_mbps;
    row.Camera_Rate_Exceeds_One_MPDU_Per_RAW_Cycle = has_camera && ...
        Cfg.CameraBitrate_bps / 1e6 > one_mpdu_cycle_mbps;
    row.Network_Enqueued = all_enqueued;
    row.Network_ACKed = all_success;
    row.Network_PDR = network_pdr;
    row.Network_Throughput_Mbps = sum( ...
        SimState.L_success(all_sta)) * 8 / sim_time_s / 1e6;
    row.Alarm_Enqueued = alarm_enqueued;
    row.Alarm_ACKed = alarm_success;
    row.Alarm_Access_Attempts = sum(SimState.n_access(alarm));
    row.Alarm_DATA_Collisions = sum(SimState.n_collision(alarm));
    row.Alarm_ACK_Timeouts = sum(SimState.n_collision2(alarm));
    row.Alarm_Access_Success_Ratio = Divide( ...
        alarm_success, row.Alarm_Access_Attempts);
    row.Alarm_Lost = sum(SimState.n_loss(alarm));
    row.Alarm_Final_Buffered = alarm_buffered;
    row.Alarm_PDR = alarm_pdr;
    row.Alarm_Initial_Deadline_PDR = alarm_initial_deadline_pdr;
    row.Alarm_All_Packet_Deadline_PDR = alarm_deadline_pdr;
    row.Alarm_Delay_Mean_s = Mean_Or_NaN(alarm_delay_s);
    row.Alarm_Delay_P95_s = Percentile(alarm_delay_s, 95);
    row.Alarm_Delay_Min_s = Min_Or_NaN(alarm_delay_s);
    row.Alarm_Delay_Max_s = Max_Or_NaN(alarm_delay_s);
    row.Alarm_Delay_Sample_Count = numel(alarm_delay_s);
    row.Camera_Enqueued = camera_enqueued;
    row.Camera_ACKed = camera_success;
    row.Camera_Access_Attempts = sum(SimState.n_access(camera));
    row.Camera_DATA_Collisions = sum(SimState.n_collision(camera));
    row.Camera_ACK_Timeouts = sum(SimState.n_collision2(camera));
    row.Camera_Access_Success_Ratio = Divide( ...
        camera_success, row.Camera_Access_Attempts);
    row.Camera_TXOP_Acquisitions = sum( ...
        SimState.ED_TXOP.Acquisitions(camera));
    row.Camera_TXOP_Continuation_Attempts = sum( ...
        SimState.ED_TXOP.ContinuationAttempts(camera));
    row.Camera_TXOP_ACKed_MPDUs = sum( ...
        SimState.ED_TXOP.AcknowledgedMPDUs(camera));
    row.Camera_TXOP_ACKed_MPDUs_Per_Acquisition = Divide( ...
        row.Camera_TXOP_ACKed_MPDUs, row.Camera_TXOP_Acquisitions);
    row.Camera_TXOP_Completed = sum( ...
        SimState.ED_TXOP.Completed(camera));
    row.Camera_TXOP_Aborted = sum( ...
        SimState.ED_TXOP.Aborted(camera));
    row.Camera_TXOP_Limit_Stops = sum( ...
        SimState.ED_TXOP.LimitStops(camera));
    row.Camera_TXOP_Cross_Slot_Exchanges = sum( ...
        SimState.ED_TXOP.CrossSlotExchanges(camera));
    row.Camera_TXOP_Cross_Slot_Exchange_Overrun_s = sum( ...
        SimState.ED_TXOP.CrossSlotExchangeOverrunSlots(camera)) * ...
        SimParams.T_slot;
    row.Camera_TXOP_Period_Boundary_Violations = sum( ...
        SimState.ED_TXOP.PeriodBoundaryViolations(camera));
    row.Camera_TXOP_Period_Boundary_Overrun_s = sum( ...
        SimState.ED_TXOP.PeriodBoundaryOverrunSlots(camera)) * ...
        SimParams.T_slot;
    row.Camera_TXOP_Reservation_Foreign_Starts = sum( ...
        SimState.ED_TXOP.ReservationForeignStarts(camera));
    row.Camera_TXOP_Reservation_Foreign_Data_Starts = sum( ...
        SimState.ED_TXOP.ReservationForeignDataStarts(camera));
    row.Camera_TXOP_Reservation_Foreign_ACK_Starts = sum( ...
        SimState.ED_TXOP.ReservationForeignACKStarts(camera));
    row.Camera_TXOP_Reservation_Sensed_Data_Starts = sum( ...
        SimState.ED_TXOP.ReservationSensedDataStarts(camera));
    row.Camera_TXOP_Reservation_Hidden_Data_Starts = sum( ...
        SimState.ED_TXOP.ReservationHiddenDataStarts(camera));
    row.Camera_TXOP_Reservation_Collided_Data_Starts = sum( ...
        SimState.ED_TXOP.ReservationCollidedDataStarts(camera));
    row.Camera_Lost = sum(SimState.n_loss(camera));
    row.Camera_Final_Buffered = camera_buffered;
    row.Camera_PDR = camera_pdr;
    row.Camera_Deadline_PDR = camera_deadline_pdr;
    row.Camera_Per_Node_PDR_Min = Min_Or_NaN(camera_node_pdr);
    row.Camera_Per_Node_PDR_Max = Max_Or_NaN(camera_node_pdr);
    row.Camera_Per_Node_PDR_Jain = Jain_Index(camera_node_pdr);
    row.Camera_Per_Node_Deadline_PDR_Min = ...
        Min_Or_NaN(camera_node_deadline_pdr);
    row.Camera_Per_Node_Deadline_PDR_Max = ...
        Max_Or_NaN(camera_node_deadline_pdr);
    row.Camera_Per_Node_Deadline_PDR_Jain = ...
        Jain_Index(camera_node_deadline_pdr);
    row.Camera_Delay_Mean_s = Mean_Or_NaN(camera_delay_s);
    row.Camera_Delay_P95_s = Percentile(camera_delay_s, 95);
    row.Camera_Delay_Min_s = Min_Or_NaN(camera_delay_s);
    row.Camera_Delay_Max_s = Max_Or_NaN(camera_delay_s);
    row.Camera_Delay_Sample_Count = numel(camera_delay_s);
    row.Camera_Offered_While_Active_Mbps = ...
        camera_offered_active_mbps;
    row.Camera_Goodput_Mbps = sum(SimState.L_success(camera)) * ...
        8 / sim_time_s / 1e6;
    row.Camera_Per_Node_Goodput_Min_Mbps = ...
        Min_Or_NaN(camera_node_goodput_mbps);
    row.Camera_Per_Node_Goodput_Max_Mbps = ...
        Max_Or_NaN(camera_node_goodput_mbps);
    row.Camera_Per_Node_Goodput_Jain = ...
        Jain_Index(camera_node_goodput_mbps);
    row.Alarm_DATA_Attempt_Airtime_s = alarm_data_airtime_s;
    row.Camera_DATA_Attempt_Airtime_s = camera_data_airtime_s;
    row.Alarm_ACK_Attempt_Airtime_s = alarm_ack_airtime_s;
    row.Camera_ACK_Attempt_Airtime_s = camera_ack_airtime_s;
    row.Alarm_MAC_Attempt_Airtime_s = alarm_attempt_airtime_s;
    row.Camera_MAC_Attempt_Airtime_s = camera_attempt_airtime_s;
    row.Camera_MAC_Attempt_Airtime_Share = Divide( ...
        camera_attempt_airtime_s, ...
        camera_attempt_airtime_s + alarm_attempt_airtime_s);
    row.Camera_Overload = camera_overload;
    row.Alarm_Overload = alarm_overload;
    row.Observed_Network_Overload = observed_overload;
    row.Overload_Cause = Build_Overload_Cause( ...
        camera_overload, alarm_overload, ...
        row.Peak_Offered_Exceeds_PHY, ...
        row.Camera_Rate_Exceeds_One_MPDU_Per_RAW_Cycle);
    row.SimTime_s = sim_time_s;
    row.Elapsed_s = elapsed_s;
    row.Processed_Event_Slots = SimState.ED_Stats.ProcessedSlots;
    row.Skipped_Idle_Slots = SimState.ED_Stats.SkippedSlots;
    Summary = struct2table(row);
end

function rows = Collect_Delay_Rows(state, ids)
    rows = zeros(0, 3);
    for node_id = ids
        if ~isempty(state.Delay(node_id).delay)
            rows = [rows; state.Delay(node_id).delay]; %#ok<AGROW>
        end
    end
end

function values = Get_Delay_Seconds(rows, slot_duration)
    if isempty(rows)
        values = zeros(0, 1);
    else
        values = rows(:, 3) * slot_duration;
    end
end

function [met, total] = Count_Initial_Alarm_Deadlines( ...
    state, params, deadline_s)
    met = 0;
    total = 0;
    deadline_slots = deadline_s / params.T_slot;
    for node_id = params.idx_STA_Type1
        trigger_slot = state.Node.TX_Buffer(node_id).Trigger_Time;
        if ~isfinite(trigger_slot)
            continue;
        end
        total = total + 1;
        delay_rows = state.Delay(node_id).delay;
        hit = ~isempty(delay_rows) && any( ...
            delay_rows(:, 1) == trigger_slot & ...
            delay_rows(:, 3) <= deadline_slots);
        met = met + double(hit);
    end
end

function total = Buffer_Length(state, ids)
    total = sum(arrayfun(@(id) ...
        state.Node.TX_Buffer(id).Length, ids));
end

function active_time_s = Camera_Active_Time(state, params)
    active_time_s = 0;
    if ~isfield(state, 'ED_Camera')
        return;
    end
    for k = 1:numel(state.ED_Camera.Active_Intervals)
        intervals = state.ED_Camera.Active_Intervals{k};
        if isempty(intervals)
            continue;
        end
        intervals(:, 2) = min(intervals(:, 2), params.N_slot);
        slots = max(0, intervals(:, 2) - intervals(:, 1) + 1);
        active_time_s = active_time_s + sum(slots) * params.T_slot;
    end
end

function value = Get_Max_Concurrent(state)
    if isfield(state, 'ED_Camera')
        value = state.ED_Camera.Max_Concurrent;
    else
        value = 0;
    end
end

function value = Get_Field_Or_Default(S, name, default_value)
    if isfield(S, name) && ~isempty(S.(name))
        value = S.(name);
    else
        value = default_value;
    end
end

function value = Max_Column(T, name)
    if isempty(T) || ~ismember(name, T.Properties.VariableNames)
        value = NaN;
    else
        values = T.(name);
        values = values(isfinite(values));
        if isempty(values)
            value = NaN;
        else
            value = max(values);
        end
    end
end

function value = Divide(numerator, denominator)
    if denominator <= 0
        value = NaN;
    else
        value = numerator / denominator;
    end
end

function value = Mean_Or_NaN(values)
    if isempty(values)
        value = NaN;
    else
        value = mean(values, 'omitnan');
    end
end

function value = Min_Or_NaN(values)
    values = values(isfinite(values));
    if isempty(values)
        value = NaN;
    else
        value = min(values);
    end
end

function value = Max_Or_NaN(values)
    values = values(isfinite(values));
    if isempty(values)
        value = NaN;
    else
        value = max(values);
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

function values = Per_Node_Ratio(numerator, denominator, ids)
    values = nan(numel(ids), 1);
    if isempty(ids)
        return;
    end
    den = denominator(ids).';
    num = numerator(ids).';
    valid = den > 0;
    values(valid) = num(valid) ./ den(valid);
end

function values = Per_Node_Deadline_PDR( ...
    state, ids, deadline_s, slot_duration)
    values = nan(numel(ids), 1);
    deadline_slots = deadline_s / slot_duration;
    for idx = 1:numel(ids)
        node_id = ids(idx);
        enqueued = state.n_enq(node_id);
        if enqueued <= 0
            continue;
        end
        delays = state.Delay(node_id).delay;
        if isempty(delays)
            met = 0;
        else
            met = sum(delays(:, 3) <= deadline_slots);
        end
        values(idx) = met / enqueued;
    end
end

function value = Jain_Index(values)
    values = values(isfinite(values) & values >= 0);
    if isempty(values) || sum(values .^ 2) <= 0
        value = NaN;
    else
        value = sum(values) ^ 2 / (numel(values) * sum(values .^ 2));
    end
end

function value = Sum_Airtime(state, field_name, ids, slot_duration)
    if isempty(ids) || ~isfield(state, 'ED_Airtime') || ...
            ~isfield(state.ED_Airtime, field_name)
        value = 0;
    else
        value = sum(state.ED_Airtime.(field_name)(ids)) * slot_duration;
    end
end

function cause = Build_Overload_Cause( ...
    camera_overload, alarm_overload, phy_overload, raw_rate_overload)
    labels = strings(0, 1);
    if camera_overload
        labels(end + 1) = "camera_qos"; %#ok<AGROW>
    end
    if alarm_overload
        labels(end + 1) = "alarm_qos"; %#ok<AGROW>
    end
    if phy_overload
        labels(end + 1) = "offered_over_phy"; %#ok<AGROW>
    end
    if raw_rate_overload
        labels(end + 1) = "camera_rate_over_raw_duty"; %#ok<AGROW>
    end
    if isempty(labels)
        cause = "none";
    else
        cause = strjoin(labels, "+");
    end
end
