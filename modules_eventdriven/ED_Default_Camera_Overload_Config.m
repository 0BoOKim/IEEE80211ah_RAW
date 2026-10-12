function Cfg = ED_Default_Camera_Overload_Config()
%ED_DEFAULT_CAMERA_OVERLOAD_CONFIG Camera-assisted wildfire load study.
%
% This experiment uses Standard RAW only. It is intended to determine when
% fixed camera traffic overloads the network; it does not run or evaluate
% the TX_LOG-based proposed method.

    % ----- Output and execution -----
    Cfg.SavePrefix = 'Result_Camera_Wildfire_Overload_EventDriven';
    Cfg.WriteResultFiles = true;
    Cfg.CollectTimeSeries = true;
    Cfg.ShowProgress = true;
    % Cases are independent and are parallelized at the outer case level.
    % Two process workers limit aggregate memory pressure during overloaded
    % cases. Increase this only after checking per-worker memory use.
    Cfg.UseParallelCases = true;
    Cfg.NumWorkers = 2;
    % A completed case is reused only when its scientific configuration
    % matches. In-progress engine state is saved periodically and includes
    % the random-number-generator state for deterministic continuation.
    Cfg.EnableCaseCheckpoints = true;
    Cfg.ResumeCompletedCases = true;
    Cfg.ResumeIncompleteCases = true;
    Cfg.CheckpointIntervalSec = 300;
    Cfg.ProgressIntervalSec = 60;

    % ----- Network and fire-sensor population -----
    Cfg.TotalAlarmSTA = 400;
    Cfg.ReferenceAlarmSTA = 400;
    Cfg.TargetActiveAlarmSTA = 400;%260;
    Cfg.NBackgroundSTA = 0;
    Cfg.N_BSS = 1;
    Cfg.LayoutSeed = 1731;
    Cfg.RandomSeedBase = 930000;
    Cfg.GeoPreset = 'wildfire';

    % One shared RAW group is the primary aggregate-capacity test. This
    % avoids limiting each camera to one opportunity per eight-slot cycle.
    % Set NRAW=8 to reproduce the study's conventional grouped RAW layout;
    % the output reports the resulting per-camera RAW duty diagnostic.
    Cfg.NRAW = 1;
    Cfg.SlotDurationCount = 255;
    Cfg.RAWOffsetMode = 'beacon-fcs16';
    Cfg.RAWOffsetSeed = [];
    Cfg.ChannelHistorySlots = 4096;
    % Detailed remaining-slot history is not used by this overload study.
    % Disabling it prevents an ever-growing per-RAW diagnostic array.
    Cfg.CollectRAWRemainedLog = false;
    Cfg.InitialQueueCapacity = 64;
    Cfg.InitialDelayCapacity = 64;

    % ----- Optional EDCA contention differentiation -----
    % RAW eligibility is unchanged. When enabled, eligible camera STAs use
    % AC_VI while alarm STAs use AC_BE.
    Cfg.EnableEDCA = false;
    Cfg.AlarmAccessCategory = 'AC_BE';
    Cfg.CameraAccessCategory = 'AC_VI';
    Cfg.EDCAProfiles = ED_Default_EDCA_Profiles();

    % ----- Optional AC_VI TXOP bursting -----
    % Keep disabled in the common configuration until a TXOP experiment is
    % selected explicitly. When enabled, the camera TXOP is calculated from
    % the case-specific SDC RAW-slot duration:
    %   floor32us(fraction * (500 us + SDC*120 us - guard)).
    % A TXOP is also truncated at the current RAW boundary. MaxMPDUs gives
    % an independent fairness cap. Set it to Inf or 'raw-slot-max' to send
    % as many complete MPDUs as fit before the configured RAW/TXOP boundary.
    Cfg.EnableTXOP = false;
    Cfg.CameraTXOPSDCFraction = 1.0;
    Cfg.CameraTXOPGuardSlots = 1;
    Cfg.CameraTXOPMaxMPDUs = 2;
    % strict truncates at the current RAW boundary. bounded-cross keeps the
    % one-slot TXOP budget across it. aggressive-cross multiplies that
    % budget before crossing. full-period-aggressive continues to the final
    % RAW boundary of the current Beacon and freezes same-BSS contenders
    % after the first successful DATA/ACK exchange.
    Cfg.CameraTXOPBoundaryMode = 'strict';
    Cfg.CameraTXOPAggressiveMultiplier = 2;

    % ----- Fire activation and sensor traffic -----
    Cfg.PreSurgeSec = 5;
    Cfg.PostSurgeSec = 15;
    Cfg.FireSpreadReferenceDistance_m = 900;
    Cfg.FireTimeCompression = 1;
    Cfg.Alpha = 7.5;
    Cfg.Beta = 17.5;
    Cfg.AlarmIntervalSec = 10;
    Cfg.AlarmPayloadBytes = [64 64];
    Cfg.AlarmBurstCount = 3;
    Cfg.AlarmBurstIntervalSec = 1;
    Cfg.ReportIntervalSec = 1;

    % ----- Fixed camera placement and activation -----
    % Cameras are equally spaced by angular sector around the AP and are
    % placed halfway from the AP to the sensor-deployment boundary.
    Cfg.CameraPlacementRadiusFactor = 0.5;
    Cfg.CameraSectorBoundaryDeg = 0;

    % A new fire-sensor activation starts its sector camera. Streaming ends
    % 10 s after the latest activation in that sector.
    Cfg.CameraStreamDurationSec = 10;

    % The camera source is a 128-kbit/s application stream fragmented into
    % 500-byte MAC payloads so each frame fits the configured 31.1-ms RAW
    % slot at the simulator's 300-kbit/s PHY rate.
    Cfg.CameraBitrate_bps = 128000;
    Cfg.CameraFrameBytes = 500;
    Cfg.CameraFrameIntervalSec = ...
        Cfg.CameraFrameBytes * 8 / Cfg.CameraBitrate_bps;

    % ----- QoS-based overload criteria -----
    Cfg.CameraPacketDeadlineSec = 0.2;
    Cfg.AlarmInitialDeadlineSec = 5;
    Cfg.AlarmPacketDeadlineSec = Cfg.AlarmIntervalSec;
    Cfg.MinCameraPDR = 0.95;
    Cfg.MinCameraDeadlinePDR = 0.95;
    Cfg.MinAlarmInitialDeadlinePDR = 0.99;
    Cfg.MinAlarmDeadlinePDR = 0.95;
    Cfg.MaxFinalBufferedFrames = 0;

    % Camera count and ROS are varied while the installed fire-sensor set,
    % Beta shape, final active-sensor target, placement, and payloads remain
    % fixed. SensorOnly is the no-camera reference case.
    Cfg.Cases = table( ...
        (1:6).', ...
        ["SensorOnly_Nominal"; "Camera1_Nominal"; ...
         "Camera2_Nominal"; "Camera4_Slow"; ...
         "Camera4_Nominal"; "Camera4_Fast"], ...
        [0; 1; 2; 4; 4; 4], ...
        [0.5; 0.5; 0.5; 0.25; 0.5; 1.0], ...
        'VariableNames', {'Case_ID', 'Case_Label', ...
        'NCamera', 'ROS_mps'});
end
