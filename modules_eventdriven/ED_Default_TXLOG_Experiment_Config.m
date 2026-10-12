function Exp = ED_Default_TXLOG_Experiment_Config()
%ED_DEFAULT_TXLOG_EXPERIMENT_CONFIG Defaults for the independent ED engine.
%
% The sequential experiment runs four independent sequences:
%   FixedROS/Standard_RAW, FixedROS/TXLOG_Proposed,
%   ChangedROS/Standard_RAW, and ChangedROS/TXLOG_Proposed.
% Within a TXLOG_Proposed sequence, each disaster uses the TX_LOG learned
% from the immediately preceding disaster.

    % ----- Output files -----
    % File stem for Summary, Aggregate, TimeSeries, TXLOGStats CSV files
    % and per-disaster TX_LOG MAT files.
    Exp.SavePrefix = 'Result_TXLOG_SequentialDisasters_EventDriven';

    % Number of consecutive disasters in each scenario/method sequence.
    Exp.DisasterCount = 10;

    % ----- Network population and random seeds -----
    % Number of deployed alarm STAs that can generate and transmit packets.
    Exp.TotalAlarmSTA = 400;

    % Alarm-STA count in the densest reference deployment used to model a
    % common fire-propagation field. Reference STAs above TotalAlarmSTA are
    % virtual: they affect activation timing/rank but never generate traffic.
    Exp.ReferenceAlarmSTA = 400;

    % Number of always-present STAs generating ordinary background traffic.
    Exp.NBackgroundSTA = 0;

    % Number of BSSs. The simulator creates one AP per BSS.
    Exp.N_BSS = 1;

    % Seed for the fixed node layout and geo-aware activation ordering.
    Exp.LayoutSeed = 1731;

    % Base seed for MAC/traffic randomness. Disaster d uses Base + d, so
    % matching Standard_RAW and TXLOG_Proposed disasters are paired by seed.
    Exp.RandomSeedBase = 880000;

    % ----- RAW and event-engine timing -----
    % Number of RAW slots/groups in each BSS RAW cycle.
    Exp.NRAW = 8;

    % A Beacon-specific 16-bit pseudo-random value substitutes for the lower
    % two FCS octets; mod(value, NRAW) becomes that Beacon's RAW offset.
    % The independent stream keeps paired Standard/TXLOG offset sequences
    % identical even though TXLOG admission consumes additional randomness.
    Exp.RAWOffsetMode = 'beacon-fcs16'; % beacon-fcs16|fixed
    Exp.RAWOffsetSeed = []; % [] derives the stream from each disaster seed

    % IEEE 802.11ah RAW Slot Duration Count. The modeled RAW-slot duration
    % is 500 us + SlotDurationCount * 120 us (31.1 ms when the value is 255).
    Exp.SlotDurationCount = 255;

    % Multi-BSS beacon/RAW offset policy: 'sync' starts all BSSs together;
    % 'uniform' distributes their starts across one RAW cycle. This setting
    % has no practical timing-offset effect when N_BSS is 1.
    Exp.TimingMode = 'sync';

    % Number of recent MAC slots retained by the circular channel-history
    % buffer. It must cover the congestion window, RAW slot, and ACK timer.
    % Memory grows approximately in proportion to this value and node count.
    Exp.ChannelHistorySlots = 4096;

    % ----- Fire timeline and packet generation -----
    % Simulated quiet time before the first fire-activation event [s].
    Exp.PreSurgeSec = 5;

    % Network-time duration of the activation window [s]. Leave empty to
    % derive it as ReferenceDistance / nominal ROS / time compression.
    % A numeric value directly overrides that derived network-time window.
    Exp.SurgeWindowSec = [];

    % Extra simulation time after the activation window [s]. Activated
    % sensors continue their periodic reporting during this interval.
    Exp.PostSurgeSec = 15;

    % Representative physical distance traversed by the modeled fire front
    % over the complete activation window [m].
    Exp.FireSpreadReferenceDistance_m = 900;

    % Nominal physical rate of spread (ROS) used to derive fire time [m/s].
    % This is also the ROS used by every disaster in the FixedROS set.
    Exp.FireSpreadNominalROS_mps = 0.5;

    % Common Beta activation shape and final reference-grid activation
    % target. These stay fixed so that ROS is the only regime variable.
    Exp.SequenceAlpha = 7.5;
    Exp.SequenceBeta = 17.5;
    Exp.SequenceActiveTarget = 260;

    % Per-disaster ROS values for ChangedROS. If DisasterCount is longer
    % than this vector, the sequence repeats cyclically.
    Exp.ChangedROSSequence_mps = [ ...
        0.5 0.5 1.0 1.0 0.25 0.25 1.0 1.0 0.5 0.5];

    % Physical-fire-time to network-time ratio when SurgeWindowSec is empty.
    % Use 1 for no compression; 60 maps 60 s of fire time to 1 s of MAC time.
    Exp.FireTimeCompression = 1;

    % Period between regular reports from each activated alarm STA [s].
    Exp.AlarmIntervalSec = 10; %[30]

    % Alarm MAC payload-size range [minimum maximum] in bytes. Equal values
    % select a fixed payload length.
    Exp.AlarmPayloadBytes = [64 64];

    % Total number of packets in the initial burst, including the packet
    % generated immediately when an alarm STA is activated.
    Exp.AlarmBurstCount = 3;

    % Interval between packets in an activated STA's initial burst [s].
    Exp.AlarmBurstIntervalSec = 1;

    % Packet-generation interval of each background STA [s].
    Exp.BackgroundIntervalSec = 1;

    % Sampling interval for rows in the TimeSeries result CSV [s].
    Exp.ReportIntervalSec = 1;

    % Geo-aware activation-order preset. Supported values are 'wildfire',
    % 'flood', 'plume', 'debris', and 'multi-source'.
    Exp.GeoPreset = 'wildfire';

    % ----- Collection and execution -----
    % Collect interval-level network metrics. False still produces Summary
    % and Aggregate files but suppresses the TimeSeries CSV.
    Exp.CollectTimeSeries = true;

    % Save the TX_LOG learned after every proposed-method disaster as MAT.
    Exp.SaveTXLOGFiles = true;

    % Aggregate TX_LOG sufficient statistics online instead of retaining
    % one matrix row per MAC access. This produces the same learned TX_LOG
    % while avoiding repeated large-array growth in long/high-load runs.
    Exp.UseOnlineTXLOGAggregation = true;

    % Print per-disaster progress messages in the MATLAB command window.
    Exp.ShowProgress = true;

    % Parallelize the four independent scenario/method sequences. Disasters
    % within one sequence remain serial because TX_LOG depends on the prior one.
    Exp.UseParallelSequences = true;

    % Worker count used only when a new pool is created. Empty selects the
    % MATLAB local-profile default; an already open pool is reused as-is.
    Exp.NumWorkers = [];

    % Precompute and reuse path-loss/interference maps for all sequences.
    % This reduces runtime and keeps their physical network realization fixed.
    Exp.UsePrecomputedNetworkInfo = true;

    % Optional execution filters. Empty values run both FixedROS/ChangedROS
    % scenario sets and both Standard_RAW/TXLOG_Proposed methods.
    Exp.ScenarioSetSelection = {};
    Exp.MethodSelection = {};

    % Write the normal CSV outputs. Parameter-search callers can disable
    % this and consume the returned tables directly.
    Exp.WriteResultFiles = true;

    % Suppress experiment-level command-window messages. Per-disaster
    % messages are controlled separately by ShowProgress.
    Exp.Quiet = false;

    % Suppress the warning raised when SurgeWindowSec intentionally replaces
    % the ROS-derived window, as in a short MAC-capacity screening run.
    Exp.SuppressSurgeWindowWarning = false;
end
