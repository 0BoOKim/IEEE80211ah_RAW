function SimParams = Get_Config()
    % Global Configuration Parameters

    SimParams.PNRG_Seed1 = 1731;  % random seed for Node deployment
    SimParams.PNRG_Seed2 = 1731;  % random seed for other random processes
    SimParams.BEB_ENABLE = 1;

    %------------------------------------------
    % PARAMETERS & VARIABLES
    %------------------------------------------
    SimParams.N_slot = 100000;
    SimParams.N_alarmSTA = 50;
    SimParams.N_bkSTA = 10;
    SimParams.N_STA = SimParams.N_alarmSTA + SimParams.N_bkSTA;
    SimParams.N_BSS = 4;
    SimParams.N_AP = SimParams.N_BSS;
    SimParams.N_Node = SimParams.N_AP + SimParams.N_STA;

    % Multi-BSS topology options (grid AP placement)
    SimParams.BSS_AP_Grid_Dim = []; % [] means automatic near-square grid
    SimParams.BSS_AP_Spacing = []; % [] means TX radius * BSS_AP_Spacing_Factor
    SimParams.BSS_AP_Spacing_Factor = 1.5;
    SimParams.STA_Deployment_Mode = 'per-bss-disc';
    SimParams.STA_Association_Mode = 'nearest-ap';
    SimParams.STA_Deployment_Radius_Factor = 1.0;
    % Commercial early-wildfire sensors commonly use 80-100 m spacing in
    % high-risk areas. Keep 80 m as the default lower bound.
    SimParams.STA_Min_Separation_m = 80.0;

    % RAW Config
    SimParams.Opt_N_RAW = 8;
    SimParams.Opt_Slot_Duration_Count = 255;
    SimParams.RAW_Mode = 4;
    % Standard RAW derives a fresh offset for every Beacon as
    % mod(Beacon_FCS_lower16, N_RAW). The simulator substitutes a dedicated
    % 16-bit pseudo-random value for the lower two FCS octets. Use 'fixed'
    % only to reproduce the former constant-offset behavior.
    SimParams.RAW_Offset_Mode = 'beacon-fcs16'; % beacon-fcs16|fixed
    SimParams.RAW_Offset_Seed = []; % [] derives an independent seed from PNRG_Seed2
    SimParams.N_offset = 0; % fallback used only when RAW_Offset_Mode='fixed'
    % ?좏슚??MODE
    % 4: Legacy RAW based on IEEE 802.11ah (?쒖???RAW ?좊떦 諛⑹떇???꾨???諛섏쁺)
    % 3: Proposed RAW(?ㅽ듃?뚰겕 ?쇱옟 濡쒓렇(TX_LOG) 湲곕컲 ?뺣쪧濡?STA瑜??щ’??諛곗젙)
    % 0: Legacy RAW, ?섏?留?RAW ?좊떦 諛⑹떇??unifom random???섑빐 寃곗젙(利? ?쒖????꾧꺽??諛섏쁺?섏? ?딆쓬) 
    % 1 or 2 : ?ъ슜?섏? ?딆쓬
    
    SimParams.Traffic_Surge_Mode = 4; % 3=Beta/geo-aware, 4=FARSITE fire-front driven
    SimParams.Mode3_Periodic_Alarm_After_Activation = 1;
    SimParams.Mode3_Reference_Alarm_STA_Count = 400;
    SimParams.Mode3_Alarm_Burst_Count = 3;
    SimParams.On_Save_TX_Log = 0;
    SimParams.On_Log_Tx_Fail_Ratio = 0;
    SimParams.Interval_Log_Tx_Fail_Ratio = 1000;

    % Antenna Config
    SimParams.Ant_Height_AP = 30.0;
    SimParams.Ant_Height_STA = 1.5;

    % A 20 dBm S1G transmitter and -98 dBm robust-link threshold give
    % approximately 1 km coverage with the configured outdoor macro model.
    SimParams.TX_Power_AP = 20; % (dBm)
    SimParams.TX_Power_STA_Battery_Limit = SimParams.TX_Power_AP;
    SimParams.TX_Power_STA_Battery_NonLimit = SimParams.TX_Power_AP;
    SimParams.RX_Sensitivity = -98.0; % robust S1G link threshold (dBm)
    SimParams.CSTh = -82.0; % (dBm)
    SimParams.Interference_RSS_Threshold = SimParams.RX_Sensitivity;
    % Use one reciprocal outdoor path-loss model for both AP-to-STA and
    % STA-to-AP links. Mode 1 is the IEEE 802.11ah outdoor macro model.
    SimParams.AP_STA_Pathloss_Mode = 1;
    SimParams.Collision_Check_Mode = 'auto'; % auto|legacy|rx-centric

    SimParams.Mode_Net_Congestion_Measure = 1;
    SimParams.Net_Congestion_Measure_Interval = 1000;

    SimParams.Mode_Dynamic_Sim_Time = 0;
    SimParams.Crit_Remaied_Slot = 500000;
    SimParams.N_Extending_Slot = 500000;

    % Rates and MAC Params
    SimParams.R_data = 0.3*10^6*ones(1,SimParams.N_Node);
    SimParams.CW_min = 16*ones(1,SimParams.N_Node);
    SimParams.CW_max = 1024*ones(1,SimParams.N_Node);
    SimParams.Retry_Limit = 7*ones(1,SimParams.N_Node);

    SimParams.L_data = 100*ones(1,SimParams.N_Node);
    SimParams.L_data(1:SimParams.N_AP) = 0;

    SimParams.T_slot = 52*10^-6;
    SimParams.L_macH = 18;
    SimParams.T_phyH = 560*10^-6 + 32/SimParams.R_data(1);
    SimParams.T_sifs = 160*10^-6;
    SimParams.L_ack  = 14;
    SimParams.R_ack  = 0.3*10^6;
    SimParams.T_ack  = SimParams.T_phyH + SimParams.L_ack*8/SimParams.R_ack;
    SimParams.T_ack_Timeout = SimParams.T_sifs + SimParams.T_ack + 0;

    T_difs = SimParams.T_sifs + 2*SimParams.T_slot;
    SimParams.AIFSN = ceil(T_difs/SimParams.T_slot)*ones(1,SimParams.N_Node);
    SimParams.SIFSN = ceil(SimParams.T_sifs/SimParams.T_slot);
    SimParams.T_ackN = ceil(SimParams.T_ack/SimParams.T_slot);

    % Pre-calculate data transmission times (approximate or initial)
    % Note: Actual T_data depends on frame length which varies

    % Background Traffic Params
    if SimParams.N_bkSTA > 0
        SimParams.Range_Frame_Length_bk = [100 100];
        SimParams.Range_Frame_Interval_bk = [19240 19240];
        SimParams.Prob_Frame_Generation_bk = 1.0;
    end

    % Traffic Surge Params
    SimParams.Allowed_MAX_Next_Traffic_Event = 1000;

    if SimParams.Traffic_Surge_Mode == 1
        SimParams.Range_Frame_Length_al = [100 100];
        SimParams.Range_Frame_Interval_al = [100 100];
        SimParams.Prob_Frame_Generation_al = 1.0;
        SimParams.Traffic_Gen_Mode = 1;
        SimParams.Noise_Arrival_Time = [10 50];
        SimParams.Opt_Start = 0;
        SimParams.Opt_End = SimParams.N_slot;

    elseif SimParams.Traffic_Surge_Mode == 2
        var_alpha = 1.7013;
        var_beta = 8.1347;
        SimParams.Opt_Start = 10000;
        SimParams.Opt_End = 150000;
        SimParams.Period = SimParams.Opt_End - SimParams.Opt_Start + 1;

        SimParams.Tab_Traffic_Model = Build_Traffic_Surge_Model(var_alpha, var_beta, SimParams.Period, SimParams.N_alarmSTA, SimParams.Opt_Start);
        SimParams.Tab_Traffic_Model(1,:) = SimParams.Tab_Traffic_Model(1,:) + SimParams.Opt_Start;

        SimParams.Range_Frame_Length_al = [100 100];

    elseif SimParams.Traffic_Surge_Mode == 3
        var_alpha = 2.029;
        var_beta = 2.4513;
        SimParams.Opt_Start = 10;
        SimParams.Opt_End = 50000 + SimParams.Opt_Start;
        SimParams.Period = SimParams.Opt_End - SimParams.Opt_Start + 1;

        SimParams.Tab_Traffic_Model = Build_Traffic_Surge_Model( ...
            var_alpha, var_beta, SimParams.Period, ...
            SimParams.Mode3_Reference_Alarm_STA_Count, SimParams.Opt_Start);
        SimParams.Tab_Traffic_Model(1,:) = SimParams.Tab_Traffic_Model(1,:) + SimParams.Opt_Start;

        SimParams.Range_Frame_Length_al = [64 64];
        SimParams.Range_Frame_Interval_al = ...
            max(1, round(5.0 / SimParams.T_slot)) * [1 1];
        SimParams.Mode3_Alarm_Burst_Interval_Slots = ...
            max(1, round(1.0 / SimParams.T_slot)) * [1 1];
        SimParams.Prob_Frame_Generation_al = 1.0;
        SimParams.Mode3_Periodic_Alarm_After_Activation = 1;

        % Optional geo-aware activation ordering (Section 3.6)
        % On: choose newly activated STAs by anisotropic distance from disaster seeds
        % Off: keep legacy activation order (node index order)
        SimParams.On_GeoAware_Activation_Mode3 = 1;
        SimParams.On_Use_GeoPreset_Mode3 = 1;
        SimParams.Geo_Scenario_Preset_Mode3 = 'debris'; % wildfire|flood|plume|debris|multi-source
        SimParams.Geo_Seed_Coords = []; % [x y; ...], empty means AP position
        SimParams.Geo_Dominant_Direction = [1 0]; % unit vector u
        SimParams.Geo_Anisotropy_A = 1.0; % parallel spread scale (a)
        SimParams.Geo_Anisotropy_B = 1.0; % orthogonal spread scale (b)
        SimParams.Geo_Jitter_Sigma = 1e-6; % tie-breaking jitter
        SimParams.Geo_Order_Seed = SimParams.PNRG_Seed1 + 991;

    elseif SimParams.Traffic_Surge_Mode == 4
        % FARSITE fire-front activation.
        % Sensors are generated from map spacing, not from sensor_onset_times.csv.
        SimParams.Opt_Start = 10;
        SimParams.Farsite_Output_Dir = 'farsite_output';
        SimParams.Farsite_Arrival_Format = 'asc';
        SimParams.Farsite_Arrival_Asc_File = 'farsite_arrival_time_260611.asc';
        SimParams.Farsite_Sensor_Spacing_m = 300;
        SimParams.Farsite_Sensor_Margin_m = 100;
        SimParams.Farsite_Use_Only_Reachable_Sensors = 1;
        SimParams.Farsite_Max_Alarm_STA = inf;
        SimParams.Farsite_Sensor_Select_Mode = 'earliest'; % earliest|random, used only when max is finite
        SimParams.Farsite_Time_Compression = 1; % 1 preserves real FARSITE minutes; larger values are for smoke tests
        SimParams.Farsite_Set_AP_Pos = 1;

        % FARSITE front animation options. Disabled by default because full
        % animations are much heavier than static validation figures.
        SimParams.On_Plot_Farsite_Front_Animation = 1;
        SimParams.Farsite_Animation_TStart_Min = 0;
        SimParams.Farsite_Animation_TStep_Min = 60;
        SimParams.Farsite_Animation_TEnd_Mode = 'triggered'; % triggered|raster|manual
        SimParams.Farsite_Animation_TEnd_Min = [];
        SimParams.Farsite_Animation_Max_Frames = 80;
        SimParams.Farsite_Animation_Pause_Sec = 0.10;
        SimParams.Farsite_Animation_Visible = 'on';
        SimParams.Farsite_Animation_Save_Video = 0;
        SimParams.Farsite_Animation_Video_File = 'farsite_front_sim_activation.mp4';
        SimParams.Farsite_Animation_Video_FPS = 5;
        SimParams.Farsite_Animation_Save_GIF = 0;
        SimParams.Farsite_Animation_GIF_File = 'farsite_front_sim_activation.gif';
        SimParams.Farsite_Animation_Save_Onset_Table = 0;
        SimParams.Farsite_Animation_Onset_Table_File = 'farsite_simulated_sensor_onset_times.csv';

        % Real-time front reconstruction from alarm packets observed at APs.
        % The reconstructed front uses only alarm STAs whose DATA packets
        % have been successfully delivered to an AP.
        SimParams.Farsite_Reconstruction_Enable = 1;
        SimParams.Farsite_Reconstruction_Source = 'ap-success'; % ap-success|trigger
        SimParams.Farsite_Reconstruction_Front_Method = 'active-boundary'; % active-boundary|arrival-interp
        SimParams.Farsite_Reconstruction_Min_Sensors = 5;
        SimParams.Farsite_Reconstruction_Boundary_Shrink = 0.75;
        SimParams.Farsite_Reconstruction_Line_Color = [0 0.45 1];
        SimParams.Farsite_Reconstruction_Line_Width = 2.0;
        SimParams.Farsite_Reconstruction_Line_Style = '--';
        SimParams.Farsite_Reconstruction_Deactivate_Missed_Count = 3;
        SimParams.Farsite_Reconstruction_Deactivate_Time_Min = 2;

        % Alarm traffic profile for fire-detection sensors.
        % Detection: short burst to improve AP observation probability.
        % After detection: low-rate keep-alive for real-time front tracking.
        SimParams.Farsite_Alarm_Packet_Length_Bytes = [100 100];
        SimParams.Farsite_Alarm_Burst_Count = 3;
        SimParams.Farsite_Alarm_Burst_Interval_Sec = 1;
        SimParams.Farsite_Alarm_Burst_Interval_Slots = ...
            max(1, round(SimParams.Farsite_Alarm_Burst_Interval_Sec / SimParams.T_slot)) * [1 1];
        SimParams.Farsite_Alarm_KeepAlive_Interval_Sec = 30;
        SimParams.Farsite_Alarm_KeepAlive_Jitter_Ratio = 0.10;
        keepalive_center_slots = max(1, round(SimParams.Farsite_Alarm_KeepAlive_Interval_Sec / SimParams.T_slot));
        keepalive_jitter_slots = round(keepalive_center_slots * SimParams.Farsite_Alarm_KeepAlive_Jitter_Ratio);
        SimParams.Farsite_Reconstruction_Expected_Interval_Slots = keepalive_center_slots;

        SimParams.Range_Frame_Length_al = SimParams.Farsite_Alarm_Packet_Length_Bytes;
        SimParams.Range_Frame_Interval_al = [ ...
            max(1, keepalive_center_slots - keepalive_jitter_slots), ...
            keepalive_center_slots + keepalive_jitter_slots];
        SimParams.Prob_Frame_Generation_al = 1.0;

        SimParams = Build_Farsite_Activation_Model(SimParams);
    end

    SimParams.On_Measure_Traffic_Temporal_Evolution = 1;
    SimParams.Opt_Measure_Interval = 2000;
    SimParams.On_Plot_Alarm_Activation_Validation = 1;  % Plot figure regarding beta-dist.
    SimParams.On_Plot_MultiBSS_Results = 1;  % Plot topology, per-BSS surge, and per-BSS metrics.

    % RAW Settings
    SimParams.On_RAW = 1;
    if SimParams.On_RAW
        SimParams.On_CSB = 0;
        SimParams.On_BSR = 0;
        if SimParams.On_BSR
            SimParams.L_BSR = 560*10^-6;
            SimParams.L_BSR_in_Slot = ceil(SimParams.L_BSR/SimParams.T_slot);
        end

        C = SimParams.Opt_Slot_Duration_Count;
        SimParams.T_RAW_Slot = 500*10^-6 + C*120*10^-6;
        SimParams.N_RAW = SimParams.Opt_N_RAW;
        SimParams.T_RAW_Slot_in_Slot = ceil(SimParams.T_RAW_Slot/SimParams.T_slot);
        SimParams.Beacon_Interval = SimParams.T_RAW_Slot_in_Slot * SimParams.N_RAW;

        % Per-BSS RAW configuration options.
        % uniform: all BSSs use the scalar legacy RAW configuration.
        % custom: set BSS_Opt_N_RAW and BSS_Opt_Slot_Duration_Count as vectors.
        SimParams.BSS_RAW_Config_Mode = 'uniform'; % uniform|custom
        SimParams.BSS_Opt_N_RAW = SimParams.Opt_N_RAW * ones(1, SimParams.N_AP);
        SimParams.BSS_Opt_Slot_Duration_Count = SimParams.Opt_Slot_Duration_Count * ones(1, SimParams.N_AP);
        SimParams = Build_BSS_RAW_Config(SimParams);

        % Multi-BSS Beacon/RAW timing offset options.
        % sync: all BSSs open RAW windows at the same timing.
        % uniform: BSS timings are evenly staggered over one RAW cycle.
        % custom: use BSS_Beacon_Offset as a per-BSS offset vector in slots.
        SimParams.BSS_Beacon_Offset_Mode = 'sync'; % sync|uniform|custom
        SimParams.BSS_Beacon_Offset = zeros(1, SimParams.N_AP);
    end

    % RAW Mode Specifics
    if SimParams.RAW_Mode == 1 || SimParams.RAW_Mode == 2
        SimParams.Opt_Interval = 10;
        SimParams.Opt_Threshold = SimParams.N_RAW * SimParams.Opt_Interval;
        SimParams.Opt_decisionFactor = 8;
        SimParams.Opt_Max = SimParams.Opt_Threshold * SimParams.Opt_decisionFactor;
    end

    if SimParams.RAW_Mode == 2
       SimParams.Opt_Range_Interval = [1 10];
       SimParams.Opt_Range_decisionFactor = [1 10];
       SimParams.Opt_Inc_Interval = 1;
       SimParams.Opt_Dec_Interval = 1;
       SimParams.Opt_Inc_decisionFactor = 1;
       SimParams.Opt_Dec_decisionFactor = 1;
    end

    if SimParams.RAW_Mode == 3
        SimParams.TX_Th = 0.5;
        % Keep TxWeight neutral for the current TX_LOG study. TX_LOG is
        % assumed to be updated by AP downlink between disaster events.
        SimParams.Enable_TxWeight = 1;
        SimParams.Init_TxWeight = 1.0;
        SimParams.Max_TxWeight = 1.0;
        SimParams.Min_TxWeight = 1.0;
        SimParams.Dec_TxWeight = 0.0;
        SimParams.Inc_TxWeight = 0.0;

        SimParams.On_Log_TxWeight = 1;
        SimParams.Target_Node_Log_TxWeight = [2 5 10];
        SimParams.Measure_Interval_Log_TxWeight = SimParams.Net_Congestion_Measure_Interval;

        if SimParams.On_Save_TX_Log == 2
            filename = sprintf('TX_LOG_TEST.mat');
        else
            filename = sprintf('TX_LOG_Nal_%d_Nbk_%d_Nraw_%d_SDC_%d.mat', ...
            SimParams.N_alarmSTA, SimParams.N_bkSTA, SimParams.Opt_N_RAW, SimParams.Opt_Slot_Duration_Count);
        end
        loaded_data = load(filename);
        SimParams.TX_LOG = loaded_data.Unnamed_Tab;

        SimParams.Bin_CH_Usage = 0.1000;
        SimParams.Bin_N_ACK = 5;
        SimParams.Norm_TX_LOG = [ SimParams.TX_LOG(:,1)/max(SimParams.TX_LOG(:,1)) SimParams.TX_LOG(:,2)/max(SimParams.TX_LOG(:,2)) ];
    end

    % Index Helpers
    SimParams.idx_AP = 1:SimParams.N_AP;
    SimParams.idx_STA_Type0 = SimParams.N_AP+1 : SimParams.N_AP+SimParams.N_bkSTA;
    SimParams.idx_STA_Type1 = SimParams.N_AP+SimParams.N_bkSTA+1 : SimParams.N_Node;
    SimParams.idx_STA = SimParams.N_AP+1 : SimParams.N_Node;
end

