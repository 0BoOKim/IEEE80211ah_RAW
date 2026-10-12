function P = ED_Build_Disaster_Params(Exp, spec, disaster_idx, method, ...
    raw_mode, previous_txlog, fixed_network, collect_txlog)
%ED_BUILD_DISASTER_PARAMS Build one event-driven disaster configuration.
%
% This public helper is shared by the sequential experiment and paper-figure
% generation so both use the same topology, activation, and traffic settings.

    if ~isfield(Exp, 'BaseParams') || isempty(Exp.BaseParams)
        Exp.BaseParams = Build_Base_Params();
    end

    P = Exp.BaseParams;
    P.PNRG_Seed1 = Exp.LayoutSeed;
    P.PNRG_Seed2 = Exp.RandomSeedBase + disaster_idx;
    P.Traffic_Surge_Mode = 3;
    P.RAW_Mode = raw_mode;
    P.N_BSS = Exp.N_BSS;
    P.N_AP = Exp.N_BSS;
    P.N_alarmSTA = Exp.TotalAlarmSTA;
    P.N_bkSTA = Exp.NBackgroundSTA;
    P.Mode3_Reference_Alarm_STA_Count = max( ...
        Exp.TotalAlarmSTA, round(Exp.ReferenceAlarmSTA));

    P.On_RAW = 1;
    P.On_CSB = 0;
    P.On_BSR = 0;
    P.On_Save_TX_Log = collect_txlog;
    P.ED_Use_Online_TXLOG_Aggregation = ...
        ~isfield(Exp, 'UseOnlineTXLOGAggregation') || ...
        Exp.UseOnlineTXLOGAggregation;
    P.Mode_Net_Congestion_Measure = 1;
    P.On_Measure_Traffic_Temporal_Evolution = 0;
    P.On_Plot_Alarm_Activation_Validation = 0;
    P.On_Plot_MultiBSS_Results = 0;
    P.Collision_Check_Mode = 'auto';

    P.Opt_N_RAW = Exp.NRAW;
    P.Opt_Slot_Duration_Count = Exp.SlotDurationCount;
    P.N_RAW = Exp.NRAW;
    P.N_offset = 0;
    if isfield(Exp, 'RAWOffsetMode') && ~isempty(Exp.RAWOffsetMode)
        P.RAW_Offset_Mode = Exp.RAWOffsetMode;
    end
    if isfield(Exp, 'RAWOffsetSeed')
        P.RAW_Offset_Seed = Exp.RAWOffsetSeed;
    end
    P.BSS_RAW_Config_Mode = 'uniform';
    P.BSS_Opt_N_RAW = Exp.NRAW * ones(1, Exp.N_BSS);
    P.BSS_Opt_Slot_Duration_Count = ...
        Exp.SlotDurationCount * ones(1, Exp.N_BSS);
    P.BSS_Beacon_Offset_Mode = Exp.TimingMode;
    P = Refresh_Node_Dependent_Config(P);

    physical_window = Exp.FireSpreadReferenceDistance_m / spec.ROS_mps;
    if isempty(Exp.SurgeWindowSec)
        network_window = physical_window / Exp.FireTimeCompression;
        compression = Exp.FireTimeCompression;
    else
        network_window = Exp.SurgeWindowSec;
        compression = physical_window / network_window;
    end

    pre_slots = max(1, round(Exp.PreSurgeSec / P.T_slot));
    period_slots = max(1, round(network_window / P.T_slot));
    post_slots = max(1, round(Exp.PostSurgeSec / P.T_slot));
    P.Opt_Start = pre_slots;
    P.Period = period_slots;
    P.Opt_End = pre_slots + period_slots;
    P.N_slot = P.Opt_End + post_slots;

    target = min(P.Mode3_Reference_Alarm_STA_Count, ...
        max(0, round(spec.ActiveTarget)));
    P.ED_Beta_Activation_Events = ED_Build_Beta_Activation_Events( ...
        spec.Alpha, spec.Beta, P.Opt_Start, P.Period, target);
    P.Reference_Target_Active_Alarm_STA = target;

    alarm_interval = max(1, ...
        round(Exp.AlarmIntervalSec / P.T_slot));
    burst_interval = max(1, ...
        round(Exp.AlarmBurstIntervalSec / P.T_slot));
    background_interval = max(1, ...
        round(Exp.BackgroundIntervalSec / P.T_slot));
    P.Range_Frame_Length_al = Exp.AlarmPayloadBytes;
    P.Range_Frame_Interval_al = alarm_interval * [1 1];
    P.Prob_Frame_Generation_al = 1;
    P.Mode3_Periodic_Alarm_After_Activation = 1;
    P.Mode3_Alarm_Burst_Count = max(1, round(Exp.AlarmBurstCount));
    P.Mode3_Alarm_Burst_Interval_Slots = burst_interval * [1 1];
    P.Range_Frame_Length_bk = [100 100];
    P.Range_Frame_Interval_bk = background_interval * [1 1];
    P.Prob_Frame_Generation_bk = 1;

    P.On_GeoAware_Activation_Mode3 = 1;
    P.On_Use_GeoPreset_Mode3 = 1;
    P.Geo_Scenario_Preset_Mode3 = char(spec.GeoPreset);
    P.Geo_Seed_Coords = [];
    P.Geo_Dominant_Direction = [1 0];
    P.Geo_Anisotropy_A = 1;
    P.Geo_Anisotropy_B = 1;
    P.Geo_Jitter_Sigma = 1e-6;
    P.Geo_Order_Seed = Exp.LayoutSeed + 991;

    if Exp.CollectTimeSeries
        P.ReportIntervalSlots = max(1, ...
            round(Exp.ReportIntervalSec / P.T_slot));
    else
        P.ReportIntervalSlots = inf;
    end
    P.ED_Channel_History_Slots = Exp.ChannelHistorySlots;
    P.MethodName = method;
    P.Fire_Physical_Window_s = physical_window;
    P.Fire_Time_Compression = compression;
    P.Fire_Network_Window_s = network_window;
    P.Fire_Nominal_ROS_mps = spec.ROS_mps;
    P.Fire_Spread_Reference_Distance_m = ...
        Exp.FireSpreadReferenceDistance_m;
    P.Alarm_Report_Interval_s = Exp.AlarmIntervalSec;
    P.Alarm_Payload_Bytes = mean(Exp.AlarmPayloadBytes);

    if ~isempty(fixed_network)
        P.Precomputed_NetworkInfo = fixed_network;
    end
    if raw_mode == 3
        if isempty(previous_txlog)
            error('ED:MissingPreviousTXLOG', ...
                'RAW mode 3 requires the previous disaster TX_LOG.');
        end
        P = Configure_TXLOG(P, previous_txlog);
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

function P = Configure_TXLOG(P, TXLOG)
    P.Enable_TxWeight = 1;
    P.Init_TxWeight = 1;
    P.Max_TxWeight = 1;
    P.Min_TxWeight = 1;
    P.Dec_TxWeight = 0;
    P.Inc_TxWeight = 0;
    P.On_Log_TxWeight = 0;
    P.TX_LOG = TXLOG;
    P.Bin_CH_Usage = 0.1;
    P.Bin_N_ACK = 5;
    max_ch = max([1; TXLOG(:, 1)]);
    max_ack = max([1; TXLOG(:, 2)]);
    P.Norm_TX_LOG = [TXLOG(:, 1) / max_ch, ...
        TXLOG(:, 2) / max_ack];
end
