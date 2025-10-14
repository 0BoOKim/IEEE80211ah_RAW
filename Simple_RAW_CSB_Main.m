tic;
%--------------------------------------------------------------------------
% Simple RAW (Restricted Access Window) in IEEE 802.11ah with CSB
% revision 5 (24-09-24) : IEEE 802.11ah Channel Model was added.
%--------------------------------------------------------------------------
clear all;
close all;

PNRG_Seed1 = 1731;  % random seed for Node deployment(allocation) 
PNRG_Seed2 = 1731;  % random seed for other random processes



BEB_ENABLE = 1;
    

%------------------------------------------
% PARAMETERS & VARIABLES
%------------------------------------------
N_slot = 1000000;         % total number of slots ( 1,000,000 -> 52 sec, 200,000 -> 10.04 sec )
N_alarmSTA = 50; % 100/500/1000/1500/2000/2500/3000 % number of users
N_bkSTA = 100; % number of users that generate background traffics
N_STA = N_alarmSTA + N_bkSTA;
N_AP = 1;
N_Node = N_AP + N_STA;

% (Additional Descriptions of STA Type, 24-10-02) 
% [N_bkSTA] is the number of AH-STAs which have no battery limitation. And
%           also, they generates a seamless traffics based on the our simple propabilistic
%           traffic geneation model.
% [N_alarmSTA] is the number of AH-STAs which have the battery-limitation.
%              Thus, Their transmission power is bounded to 0 dBm. And they generates
%              traffic surge based on the beta distribution desinged by 3GPP TG.

% RAW Config.
Opt_N_RAW = 8; 
Opt_Slot_Duration_Count = 255;

% RAW operation mode
RAW_Mode = 3;
% mode 0: normal RAW mode (based on Radom Distribution) --> (추가) 전송할 프레임이 있는 경우만 RAW slot에 할당되도록 수정
% mode 1: (proposed I) distributed access (사용하지 않음)
% mode 2: (proposed II) (Adaptation) distributed access (사용하지 않음)
% mode 3: (Proposed III) 이름을 정하지 않은 (unnamed) 제안 기법
% mode 4: Legacy RAW mode (based on IEEE 802.11ah std.)  i.e., slot_i = ( x + N_offset ) mod N_RAW

Traffic_Surge_Mode = 3;
    % Mode 1: based on simple random distribution
    % Mode 2: based on beta distibution (refferd from 3GPP TR 37.868 V11.0.0 (2011-09))
    % Mode 3: Proposed Traffic Surge model based on beta distribution

On_Save_TX_Log = 2;
% 1: Normal TX Log
% 2: Test Mode
if On_Save_TX_Log == 1 && RAW_Mode ~= 0
   error('TX_Log cannot be saved this RAW Mode!'); 
end

On_Log_Tx_Fail_Ratio = 1;
% if 1, the ratio of transmission failure is recored according to temporal
% evolution
if On_Log_Tx_Fail_Ratio
    Interval_Log_Tx_Fail_Ratio = 1000;
    Next_Log_Tx_Fail_Ratio = Interval_Log_Tx_Fail_Ratio;
    
    Log_Tx_Fail_Ratio = [];
   
end

% Antenna Config.
Ant_Height_AP = 30.0;  % Antenna height of APs 12/15/30 meter
Ant_Height_STA = 1.5;  % Antenna height of STAs

TX_Power_AP = 0; % (dBm)
TX_Power_STA_Battery_Limit = 0; % (dBm)
TX_Power_STA_Battery_NonLimit = TX_Power_AP; % Due to implement symmetric available transmission distance, TX power was configured to the idnetical.

CSTh = -82.0; % (dBm) Common Carrier Sensing Threshold.



Mode_Net_Congestion_Measure = 1;
if Mode_Net_Congestion_Measure
    Net_Congestion_Measure_Interval = 1000; % slots
    for i = 1:N_Node
%         Net_Congestion_Measure(i).CH_Util = [Net_Congestion_Measure_Interval 0];  % channel에서 얻음
%         Net_Congestion_Measure(i).N_ACK = [Net_Congestion_Measure_Interval 0];    % 모든 전송 성공 이벤트 발생 시 처리
%         Net_Congestion_Measure(i).N_Acc = [Net_Congestion_Measure_Interval 0];    % 자신의 접속 시도 이벤트 발생 시 처리
%         Net_Congestion_Measure(i).N_Fail = [Net_Congestion_Measure_Interval 0];   % 자신의 전송 실패 이벤트 발생 시 처리
%         Net_Congestion_Measure(i).N_Suc = [Net_Congestion_Measure_Interval 0];
%         Net_Congestion_Measure(i).N_MPDU = [Net_Congestion_Measure_Interval 0];   % 모든 전송 성공 이벤트 발생 시 처리
%         Net_Congestion_Measure(i).L_QTime = [Net_Congestion_Measure_Interval 0];  % (보류) 
        Net_Congestion_Measure(i).CH_Util = [0 0];  % channel에서 얻음
        Net_Congestion_Measure(i).N_ACK = [0 0];    % 모든 전송 성공 이벤트 발생 시 처리
        Net_Congestion_Measure(i).N_Acc = [0 0];    % 자신의 접속 시도 이벤트 발생 시 처리
        Net_Congestion_Measure(i).N_Fail = [0 0];   % 자신의 전송 실패 이벤트 발생 시 처리
        Net_Congestion_Measure(i).N_Suc = [0 0];
        Net_Congestion_Measure(i).N_MPDU = [0 0];   % 모든 전송 성공 이벤트 발생 시 처리
        Net_Congestion_Measure(i).L_QTime = [0 0];  % (보류) 
        % 1st col: meaured time in slot
        % 2nd col: its value
    end
    Init_Net_Congestion_Measure_Time = 0;
    Next_Net_Congestion_Measure_Time = Init_Net_Congestion_Measure_Time + Net_Congestion_Measure_Interval;
    
end

% if N_Gram_Anal
%     if ~Mode_Net_Congestion_Measure
%         error('Mode_Net_Congestion_Measure should be enabled!');
%     end
%     N_Gram_Size = 5;
%     
% end
    
Mode_Dynamic_Sim_Time = 0;
% if this mode is enabled, the simulation is continued until every STAs do not have any packet to send.
if Mode_Dynamic_Sim_Time
    Crit_Remaied_Slot = 500000;  % A criterion to check a shortage of remained simulation time (500,000 is about 10 sec)
    N_Extending_Slot = 500000;   % A simulation time to extend.
end

R_data = 0.3*10^6*ones(1,N_Node);      % transmission rate 

Node.CW_min = 16*ones(1,N_Node);             % minimum contention window
%CW_min = [64 32 16];
Node.CW_max = 1024*ones(1,N_Node);              
            % when BEB is enabled, CW is doubled if collision occurs
            % its maximum value is CW_max
Node.CW = Node.CW_min.*ones(1,N_Node);                % initial contention window 

Node.Retry_Limit = 7*ones(1,N_Node);
Node.N_retry = zeros(1, N_Node);


L_data = 100*ones(1,N_Node);   % data frame size (byte)
L_data(1:N_AP) = 0;            % Only uplink data transmission is available.

%L_data = [1000 1000 1000];

% 802.11g MAC/PHY spec.  -->    ('22.01.12) 
T_slot = 52*10^-6;            % time slot = 20 us
L_macH = 18;                  % length of the short MAC Header (bytes), Frame Control(2) + A1(6) + A2(6) + Seq. Ctrl.(2) + Duration(2) = 18 Bytes for short MAC header
T_phyH = 560*10^-6 + 32/R_data(1);           % PHY Header transmission time (sec): 560 usec(PLCP Preamble) + 32 bit/basic_data_rate (PLCP/PHY Header)          
T_sifs = 160*10^-6;           % SIFS time (sec)
L_ack  = 14;                  % length of ACK (byte)
R_ack  = 0.3*10^6;            % 6*10^6;    % basic rate for ACK (bit/sec)
T_ack  = T_phyH + L_ack*8/R_ack; % ACK transmission time (sec)
T_ack_Timeout = T_sifs + T_ack + 0;

T_data = zeros(N_Node,1);      % T_phyH + (L_macH + L_data)*8./R_data; 
                              % data frame transmission time (sec)

T_txslot = zeros(N_Node,1);    % ceil( (T_data + T_sifs + T_ack)/T_slot);  % number of slots required to transmit one data frame   
                              
T_difs = T_sifs + 2*T_slot;   % 160 + 2x52 = 264 usec
AIFSN = ceil(T_difs/T_slot)*ones(1,N_Node);  % AIFSN for EDCA, default = 3 considering DIFS,  264/52 is about 5 slots.

SIFSN = ceil(T_sifs/T_slot);
T_ackN = ceil(T_ack/T_slot);


if N_bkSTA > 0
    
    Range_Frame_Length_bk = [100 100]; %(Byte) [min max]
    Range_Frame_Interval_bk = [19240 19240];   % (slots) [min max]
    Prob_Frame_Generation_bk = 1.0; 
    
end

Traffic_Surge_Mode = 3;
    % Mode 1: based on simple random distribution
    % Mode 2: based on beta distibution (refferd from 3GPP TR 37.868 V11.0.0 (2011-09))
    % Mode 3: Proposed Traffic Surge model based on beta distribution
    
if Traffic_Surge_Mode > 0
    Allowed_MAX_Next_Traffic_Event = 1000;
    % if exceed this time(in slot), packet arrival event occurs
    % violently..
    Prev_Traffic_Event = 0;
    

end
    
if Traffic_Surge_Mode == 1 % [Traffic Surge Mode 1] Decretionary 
    Range_Frame_Length_al = [100 100]; %(Byte) [min max]
    Range_Frame_Interval_al = [100 100];   % (msec) [min max]
    Prob_Frame_Generation_al = 1.0;
    Traffic_Gen_Mode = 1;
    % mode 0: traffic pattern is chracterized for each STA.
    % mode 1: traffic pattern is chracterized for all STAs. That is, every 
    if Traffic_Gen_Mode == 1
        Noise_Arrival_Time = [10 50];
    end
    Opt_Start = 0;% ceil(N_slot*0.05);  % start time
    Opt_End = N_slot; %Opt_Start + 100000;%ceil(N_slot*0.2);    % end time
    
elseif Traffic_Surge_Mode == 2 % [Traffic Surge Mode 2] Alarm-triggered Traffic 
%     var_alpha = 2.029;
%     var_beta = 2.4513;
    
%     var_alpha = 1.9588;
%     var_beta = 1.484;
    
    var_alpha = 1.7013;
    var_beta = 8.1347;
    
    Opt_Start = 10000;% ceil(N_slot*0.05);  % start time
    Opt_End = 150000; %Opt_Start + 100000;%ceil(N_slot*0.2);    % end time
    
    Period = Opt_End-Opt_Start+1; % (note) the unit is a slot.
    
    Tab_Traffic_Model = Build_Traffic_Surge_Model(var_alpha, var_beta, Period, N_alarmSTA, Opt_Start);
    Tab_Traffic_Model(1,:) = Tab_Traffic_Model(1,:) + Opt_Start;
    
    Range_Frame_Length_al = [100 100];
    
    Last_Time = 1;
    
    Measure_Cummulated_N_Triggerd_STAs = [0 0];
    L_Measure_Cummulated_N_Triggerd_STAs = 1;

elseif Traffic_Surge_Mode == 3 % [Traffic Surge Mode 2] Traffic surge based on alarm-triggered traffic
    
  var_alpha = 2.029;
  var_beta = 2.4513;
%   var_alpha = 1.9588;
%   var_beta = 1.484;  
%   var_alpha = 1.7013;
%   var_beta = 8.1347;
     
    Opt_Start = 10; % ceil(N_slot*0.05);  % start time
    Opt_End = 50000+Opt_Start; %Opt_Start + 100000;%ceil(N_slot*0.2);    % end time
    %Opt_End = N_slot; %Opt_Start + 100000;%ceil(N_slot*0.2);    % end time
    
    Period = Opt_End-Opt_Start+1; % (note) the unit is a slot.
    
    Tab_Traffic_Model = Build_Traffic_Surge_Model(var_alpha, var_beta,Period, N_alarmSTA, Opt_Start);
    Tab_Traffic_Model(1,:) = Tab_Traffic_Model(1,:) + Opt_Start;
    
    
    Range_Frame_Length_al = [100 100]; % (Byte)
    Range_Frame_Interval_al = [1924 1924];  % (slots) 1,924 slots is about 0.1 sec
    Prob_Frame_Generation_al = 1.0;
    
    Last_Time = 1;
    
    Measure_Cummulated_N_Triggerd_STAs = [0 0];
    L_Measure_Cummulated_N_Triggerd_STAs = 1;
end


On_Measure_Traffic_Temporal_Evolution = 1;
if On_Measure_Traffic_Temporal_Evolution
   Opt_Measure_Interval = 2000; % (in slot) measure interval
   Next_Measure_Time = Opt_Measure_Interval;
   Traffic_Temporal_Evolution = [0 0 0 0 0 0 0 0 0];
   % 1st col: time in slot
   % 2nd col: sum of buffered number of frames
   % 3rd col: avg. of buffered number of frames
   % 4th col: sum of buffered number of bytes
   % 5th col: avg. of buffered number of frames
   % 6th col: number of STAs who has buffered frames.
   % 7th col: avg. of access
   % 8th col: avg. of success rate
   % 9th col: avg. of collision rate
end

%------------------------------------------
% Initilization: Network Topology
%------------------------------------------
rng(PNRG_Seed1);

if N_AP ~= 1
    error('In this simulation version, the number of APs should be one!');
end

TX_Radius_AP = Get_MaxDist(1, Ant_Height_AP, Ant_Height_STA, TX_Power_AP, CSTh);
TX_Radius_STA = Get_MaxDist(2, Ant_Height_STA, Ant_Height_AP, TX_Power_STA_Battery_Limit, CSTh);
%AP.Pos(1,:) = [TX_Radius_AP, TX_Radius_AP];
Node.Pos(1,:) = [TX_Radius_AP, TX_Radius_AP];
Node.Type(1)  =  -1; % '-1' means the AP... not the STA. 
Node.ACK_Timer(1,:) = [-1 -1];

for i= N_AP+1:N_AP+N_bkSTA
    
    Node.Type(i) = 0; % '0' means the backgroud STA, which generates constant backgroud traffics.
    rand_radian = rand*2*pi;
    rand_radius = rand*TX_Radius_AP;
    Node.Pos(i,:) = [rand_radius*cos(rand_radian)+TX_Radius_AP rand_radius*sin(rand_radian)+TX_Radius_AP];
    
    Node.ACK_Timer(i,:) =[-1 -1];
    % -1: ACK_Timer is not enabled since the STA did not transmit any MPDU.
    % 0 or Positive value as slot time: a remained slot time for the ACK Timer
end

for i=N_AP+N_bkSTA+1:N_Node
    
    Node.Type(i) = 1; % '1' means the alarm STA, which generates traffic surge.
    rand_radian = rand*2*pi;
    rand_radius = rand*TX_Radius_STA;
    %STA.Pos(i,:) = [TX_Radius_AP+(rand-0.5)*TX_Radius_STA TX_Radius_AP+(rand-0.5)*TX_Radius_STA]; 
    Node.Pos(i,:) = [rand_radius*cos(rand_radian)+TX_Radius_AP rand_radius*sin(rand_radian)+TX_Radius_AP];
    
    Node.ACK_Timer(i,:) = [-1 -1];
    % -1: ACK_Timer is not enabled since the STA did not transmit any MPDU.
    % 0 or Positive value as slot time: a remained slot time for the ACK Timer
end

idx_AP = N_AP;
idx_STA_Type0 = N_AP+1:N_AP+N_bkSTA;
idx_STA_Type1 = N_AP+N_bkSTA+1:N_Node;
idx_STA = N_AP+1:N_Node;

figure;
hold on;
plot(Node.Pos(idx_AP,1), Node.Pos(idx_AP,2), 'kd', 'MarkerFaceColor','k')
plot(Node.Pos(idx_STA_Type1,1), Node.Pos(idx_STA_Type1,2), 'rx');
plot(Node.Pos(idx_STA_Type0,1), Node.Pos(idx_STA_Type0,2), 'bx');
legend('AP', 'Alarm STAs', 'BK STAs', 'Location' , 'Best');
xlabel('X-axis (m)');
ylabel('Y-axis (m)');
grid on;
hold off;

% Build Network Information Maps
[MAP_LoS, MAP_RSS] = Build_NetworkInfoMaps(Node.Pos(idx_AP,:), Node.Pos(idx_STA,:), Node.Type, Ant_Height_AP, Ant_Height_STA, Ant_Height_STA, ...
                                                    TX_Power_AP, TX_Power_STA_Battery_Limit, TX_Power_STA_Battery_NonLimit);
                                                

%---------------------------------------------------------------------------------------------------------


rng(PNRG_Seed2);


if RAW_Mode == 1 || RAW_Mode == 2
    
    Opt_Interval = 10;  % \delta
    Opt_Threshold = 0;  % \gamma_{TH}
    Opt_MAX = 0;        % \gamma_{MAX}
    Opt_decisionFactor = 8;  % \rho
    List_Assigned_STA = [];
end

if RAW_Mode == 2
    
   Opt_Range_Interval = [1 10];
   Opt_Range_decisionFactor = [1 10];
   
   Opt_Inc_Interval = 1;
   Opt_Dec_Interval = 1;
   
   Opt_Inc_decisionFactor = 1;
   Opt_Dec_decisionFactor = 1;

end
    
if RAW_Mode == 3  % Proposed
    TX_Th = 0.5;  % not used longer
    
    Enable_TxWeight = 1; % 
    
    if Enable_TxWeight
       
        Init_TxWeight = 1.0;  % Weightage Value
              
        Max_TxWeight = 2.0; % Maximum Value of Weightage
        Min_TxWeight = 0.01; % minimum Value of Weightage
       
        Dec_TxWeight = 0.3; % Decrement amount of Weightage
        Inc_TxWeight = 0.3; % Increment amount of Weightage
        
        Prev_TxConfig = -1*ones(N_Node, 2);
        % 1st col: Previous TX_Prob attained from TX_LOG
        % 2nd col: Previous TxWeight Value
        % "-1" means initial state of each value.
        
        On_Log_TxWeight = 1;
        if On_Log_TxWeight
           
            Target_Node_Log_TxWeight = [2 5 10];
            Measure_Interval_Log_TxWeight = Net_Congestion_Measure_Interval;  % (slots);
            % (note) NetCongestionMeasure와 동일한 측정/조정 주기를 갖도록 함
            Next_Measure_Interval_Log_TxWeight = Measure_Interval_Log_TxWeight;
            %TxWeight_LogTime = 1000:Measure_Interval_Log_TxWeight:N_slot;
            %Log_TxWeight = [TxWeight_LogTime' -1*ones(length(TxWeight_LogTime), length(Target_Node_Log_TxWeight)*2)];
            Log_TxWeight = zeros(1, 3*length(Target_Node_Log_TxWeight));
            Ptr_EachNodeLog = ones(1,length(Target_Node_Log_TxWeight));
            % 1st col: Time when measured
            % 2nd col: Temporal TxWeight
            % 3rd col: Temporal TxProb
                                 
        end
    end
    
    
    Cnt_NoLog = zeros(N_Node,1);
    
    if On_Save_TX_Log == 2
        filename = sprintf('TX_LOG_TEST.mat');
    else
        filename = sprintf('TX_LOG_Nal_%d_Nbk_%d_Nraw_%d_SDC_%d.mat', ...
        N_alarmSTA, N_bkSTA, Opt_N_RAW, Opt_Slot_Duration_Count);
    end
    TX_LOG = load(filename);  % the temporary name of loaded data for TX_LOG is 'Unnamed_Tab'
    TX_LOG = TX_LOG.Unnamed_Tab;
    Bin_CH_Usage = 0.1000;
    Bin_N_ACK = 5;
    if ~Mode_Net_Congestion_Measure
        error('RAW_MODE(3) should work with "Mode_Net_Congestion_Measure"!');
    end
    
    Norm_TX_LOG = [ TX_LOG(:,1)/max(TX_LOG(:,1)) TX_LOG(:,2)/max(TX_LOG(:,2)) ];
     

end

if RAW_Mode == 4 % Legacy RAW Mode, Legacy RAW mode (based on IEEE 802.11ah std.)  i.e., slot_i = ( x + N_offset ) mod N_RAW
   
   % X: AID 
   % N_RAW: Number of RAW Slots
   N_offset = 0; % offset determines the start point of RAW slot which assigned to a STA.
end

% Inititlization: Transmission Buffer, and etc.

GID = 0;  % Global ID for each MPDUs

for i = 1:N_Node
    Node.TX_Buffer(i).Length = 0; % number of MPDUs in TX Buffer
    Node.TX_Buffer(i).ACK_Length = 0;  % number of ACK frames in TX Buffer
    Node.TX_Buffer(i).ACK = [ ];%[-1 -1 -1 -1 -1]; % GID GID_Src Src_ID L_ack GenTime
    Node.TX_Buffer(i).MPDU= [ ];%[-1 -1 -1];  % [stack] (GID, Length in Bytes, arrival time in slot)
    %Node.TX_Buffer_ACK(i,:) = NaN;
    %Node.TX_Buffer_MPDU(i,:)= NaN;  % [stack] (GID, Length in Bytes, arrival time in slot)
    if Node.Type(i) == -1 % AP
        % do nothing
    elseif Node.Type(i) == 0  % BK STA
        
        % initialize traffic model for a backgroud STAs (bkSTA)
        Next_Frame_Length_bk(i) = ceil( (Range_Frame_Length_bk(2)-Range_Frame_Length_bk(1))*rand + Range_Frame_Length_bk(1) );
        Next_Frame_Interval_bk(i) = ceil( (Range_Frame_Interval_bk(2)-Range_Frame_Interval_bk(1))*rand + Range_Frame_Interval_bk(1) );
        
    elseif Node.Type(i) == 1  % Alarm STA
        if Traffic_Surge_Mode == 1
            if Traffic_Gen_Mode == 0
                Next_Frame_Length_al(i) = ceil( (Range_Frame_Length_al(2)-Range_Frame_Length_al(1))*rand + Range_Frame_Length_al(1) );
                Next_Frame_Interval_al(i) = ceil( (Range_Frame_Interval_al(2)-Range_Frame_Interval_al(1))*rand + Range_Frame_Interval_al(1) );
            end

        elseif Traffic_Surge_Mode == 2 || Traffic_Surge_Mode == 3

            Node.TX_Buffer(i).Triggered = 0;
            % 0: not triggered yet 
            % 1: aleady triggered
            if Traffic_Surge_Mode == 3
                Next_Frame_Length_al(i) = ceil( (Range_Frame_Length_al(2)-Range_Frame_Length_al(1))*rand + Range_Frame_Length_al(1) );
                Next_Frame_Interval_al(i) = ceil( (Range_Frame_Interval_al(2)-Range_Frame_Interval_al(1))*rand + Range_Frame_Interval_al(1) );
            end
        end
    end
    
    Delay(i).delay = [];
    % 1st col: i-th user's n-th MPDU's enqueing time
    % 2nd col: i-th user's n-th MPDU's dequed time
    % 3rd col: i-th user's n-th MPDU's queueing + Time when received ACK (in slots)
    % 4th col: i-th user's n-th MPDU's only Time when received ACK from enqued(in slots), Access Delay (except for queuing delay)
    
end



if Traffic_Surge_Mode == 1
    if Traffic_Gen_Mode == 1
            Next_Frame_Length_al = ceil( (Range_Frame_Length_al(2)-Range_Frame_Length_al(1))*rand + Range_Frame_Length_al(1) );
            Next_Frame_Interval_al = ceil( (Range_Frame_Interval_al(2)-Range_Frame_Interval_al(1))*rand + Range_Frame_Interval_al(1) );
     end     
end
% RAW setting

On_RAW = 1;
if On_RAW
    On_CSB = 0; 
    % Option for Cross Slot Boundary (CSB) 
    % 0: CSB is disabled.
    % 1: CSB is enabled.( a transmission is allowed to ongoing after the end of RAW slot duration )
    % 2: [proposed] RAW Slot Boundary is finished earlier for a BSR transmission. 
    
    % L_Beacon = 0;  % length of Beacon Frame. (TBD)
    % % Beacon_Interval = 100*10^-6; % (sec) beacon interval
    % % Beacon_Interval = ceil(Beacon_Interval/T_slot);
    
    if On_CSB == 0
       
        List_Remained_Slot = [];  
        STATE_Prev_Remained_Slot = 0;
        % 0: slot was occupied. 
        % 1: slot was idle.
        
    end
    
    On_BSR = 0;
    if On_BSR
        L_BSR = 560*10^-6; % (sec), length of NDP-BSR, 
                           % (1) 560 usec (14 Symbols, if BW is 1MHz)
                           % (2) 240 usec (6 Symbols, if BW is 2MHz)
        L_BSR_in_Slot = ceil(L_BSR/T_slot);
    end

   
    C = Opt_Slot_Duration_Count;       % Slot Duration Count
    T_RAW_Slot = 500*10^-6 + C*120*10^-6;  % Duration of RAW Slot 
    N_RAW = Opt_N_RAW;   % number of RAW Slots

    T_RAW_Slot_in_Slot = ceil(T_RAW_Slot/T_slot);
    L_Beacon = 0;  % length of Beacon Frame. (TBD)
    Beacon_Interval = T_RAW_Slot_in_Slot*N_RAW; % (slots) beacon interval
    Next_BTT = 1;%T_RAW_Slot_in_Slot;  % Next_Beacon_Transmission Time(BTT)
    
    if RAW_Mode == 1 || RAW_Mode == 2
        Opt_Threshold = N_RAW * Opt_Interval;
        Opt_Max = Opt_Threshold*Opt_decisionFactor;
        % Opt_interval(delta) --> (Probabilistic) SPACE Size
        % Opt_decisionFactor(rho)  --> weightage vale
    end
    
    if RAW_Mode == 2
       % do nothing to initilize 
    
    end
    % initialize RAW related parameters
        % Next_RAW_Duration = 2; % Beacon_Interval;
        % STATE_RAW = 0;    
%     Tab_RAW = [T_RAW_Slot_in_Slot  T_RAW_Slot_in_Slot+T_RAW_Slot_in_Slot 0];
%     if N_RAW > 1
%         for idx_RAW = 2:N_RAW
%             Tab_RAW(idx_RAW, 1) = Tab_RAW(idx_RAW-1, 2) + 1;
%             Tab_RAW(idx_RAW, 2) = Tab_RAW(idx_RAW, 1)+T_RAW_Slot_in_Slot;
%             Tab_RAW(idx_RAW, 3)  = 0;
%         end  
%     end
    
    if RAW_Mode == 0
        
        N_Assigned_STA = ceil(N_STA/N_RAW);  % number of assigned STAs in each RAW duration.
        % (note 24-05-08) 채널 접속 경쟁에 참여하는 STA의 수가 실시간으로 변경되면, 이 방식은 좀 더 타당하게 수정될 필요가 있음?
        %                 IEEE 802.11ah 에서 AP는 채널 접속 경쟁에 참여할 STA의 수를 측정할 수 있는가? (ex: implicit/explicit BSR)
    elseif RAW_Mode > 0 
        
        N_Assigned_STA = [];
        
    end
    
    if N_Assigned_STA > N_STA
        error('N_Assigned_STA cannot be larger than N_STA!');
    
    elseif N_RAW > N_STA
        % error('It is not allowed that N_RAW is larger that N_STA!');
        % [note:'22.09.07] 현재 Beacon Interval 에서 더이상 할당할 노드가 남아있지 않은 경우가 발생할 것.
        %                  시뮬레이션에 이 부분에 대한 고려가 있었는 지 검토해야 함. 
    end
end


%initial backoff counter & aifs
Node.bc = ceil(rand(1,N_Node).*Node.CW);
Node.Init_aifs = AIFSN;
Node.aifs = Node.Init_aifs;
%aifs_reset = zeros(1,N_STA);

tx_state = zeros(N_slot,N_Node);
%tx_state_AP = zeros(N_slot, N_AP);

tx_status = zeros(N_Node, 5) -1;
%tx_status_AP = zeros(N_STA, 3) -1;
% tx_status & txtime_AP has time slot values when transmission is begin(1st col) and finished(2nd col).
% 3rd col is the destination of its transmission
% if the value is -1, the STA or AP is not transmitting any MPDU.
% 4th col is the number of interfered trasmission during its transmission time.
% 5th col: the type of MPDU, DATA(0), ACK(1)

% tx_state(i,j) = transmission status at time slot i for user j
STATE_BC  = 0;   % backoff state or IDLE state
STATE_TX  = 1;   % transmission state (without collision)
STATE_CS  = 2;   % carrier-sensing state.It could be accumulated.
STATE_COL = 3;   % collision state (사용하지 않음)

% 
% for i=1:N_AP
%     n_txnode_AP(i) = 0;  % number of TX nodes for each AP.
% end
for i=1:N_Node
    n_txnode(i) = 0; % number of TX nodes for each STA(X) --> Node.
end

n_access = zeros(1,N_Node);
    % number of channel access per user
    % (note) AP의 ACK 전송을 위한 채널 접속을 포함함
    
n_collision = zeros(1,N_Node);
    % number of collisions per user
    % ACK 수신 여부와 무관하게 전송이 실패한 경우
    
n_collision2 = zeros(1,N_Node);
    % ACK Time Out으로 인해 전송이 실패하였다고 판단되는 경우
    
n_success = zeros(1,N_Node);
    % number of successful channel access without collision
    % n_access = n_collision + n_success
    % ACK 수신 여부와 무관하게, 전송이 성공한 경우
n_success2 = zeros(1,N_Node);
    % ACK가 수신되어 전송이 성공이라고 판단하는 경우
    
    
L_success = zeros(1,N_Node);

n_loss = zeros(1,N_Node);  % number of discarded packets (due to retry limits)
n_enq = zeros(1,N_Node);   % number of enqued packets

i=1;
if On_RAW
    i = 2; %T_RAW_Slot_in_Slot;
    RAW_TX_Mode = 0;
    % 0: Each assigned STA try to trasmit several times within their RAW slot.
    % 1:Each assigned STA is allowed to trasmit only single MPDU within their RAW slot.
    %   (i.e., After one successful transmission, STA do not try a secondary transmission during RAW slot) 
end
%------------------------------------------------------------------
% START SIMULATION
%------------------------------------------------------------------
while(i <= N_slot)
    
    
    
    if On_RAW
        
        if i == Next_BTT+1  % at the begin of RAW slot
           
           %initial backoff counter & aifs
            %Node.bc(idx_STA) = ceil(rand(1,N_STA).*Node.CW(idx_STA));
            %Node.aifs(idx_STA) = Node.Init_aifs(idx_STA);
            %aifs_reset = zeros(1,N_STA);
            
            
           % configure the RAW slot
           
           Tab_RAW = [i+1 i+T_RAW_Slot_in_Slot 0];
           
           if N_RAW > 1
               for idx_RAW = 2:N_RAW
                    Tab_RAW(idx_RAW, 1) = Tab_RAW(idx_RAW-1, 2) + 1;
                    Tab_RAW(idx_RAW, 2) = Tab_RAW(idx_RAW, 1)+T_RAW_Slot_in_Slot;
                    Tab_RAW(idx_RAW, 3)  = 0;
               end  
           end
           
           if RAW_Mode == 0
              % allocate STAs for each RAW slot based on uniform random distrubution
              All_User = []; 
              for j = 1:length(idx_STA)
                if 1 %Node.TX_Buffer(idx_STA(j)).Length > 0
                   All_User = [All_User;  idx_STA(j)];
                end
              end
               
               %All_User(All_User==idx_AP) = []; 
               List_Assigned_STA = [];

               for idx_RAW = 1:N_RAW
                   for idx = 1:N_Assigned_STA
                       if isempty(All_User)
                          break;  
                       end
                       Temp_Assigned_STA = All_User(ceil(rand*length(All_User)));
                       List_Assigned_STA(idx_RAW, idx) = Temp_Assigned_STA;
                       All_User(All_User == Temp_Assigned_STA) = [];

                   end
               end
           
           elseif RAW_Mode == 1  % 사용하지 않음
               List_Assigned_STA = zeros(N_RAW, N_STA);  % initialization, 0: non-assigned STA, 1: assigned STA
               List_Buffered_STAs = [];
               for j = 1:length(idx_STA)
                if Node.TX_Buffer(idx_STA(j)).Length > 0
                   List_Buffered_STAs = [List_Buffered_STAs;  idx_STA(j)];
                end
               end
                
               
               if ~isempty(find(List_Buffered_STAs~=0))  % if one and more STAs have buffered frames,...
                   All_User_RandomNumber = ceil(Opt_Max*rand(1,N_STA));  % choose a random number [1, Opt_Max(\gamma_{max})] for each STAs
                   All_User_RandomNumber(All_User_RandomNumber >= Opt_Threshold) = -1;  
                   % Any STAs that random number is more than threshold and tagged to -1 dose not have a opportunity to access channel(RAW slot).
                   for idx_RAW = 1:N_RAW
                       % 크기 동적임(최대 크기로 초기화해서 진행할 것)
                       Temp_List_Assigned_STA = find(All_User_RandomNumber >= Opt_Interval*(idx_RAW-1)+1 & ...
                                                              All_User_RandomNumber <= Opt_Interval*(idx_RAW)); 
                       List_Assigned_STA(idx_RAW, :) =  [ Temp_List_Assigned_STA zeros(1,N_STA-length(Temp_List_Assigned_STA))]; 
                       % (note) 2nd col is just for padding.              

                   end
               end
               
           elseif RAW_Mode == 3
              
               List_Assigned_STA = zeros(N_RAW, N_STA);  % initialization, 0: non-assigned STA, 1+: assigned STA's AID
               
               for j = 1:N_STA
                   
                   if( Node.TX_Buffer(idx_STA(j)).Length > 0 )  % only STAs that have buffered frames should access RAWs.
                       
                       if ~isempty(Net_Congestion_Measure(idx_STA(j)).CH_Util)
                           
                           current_idx = length(Net_Congestion_Measure(idx_STA(j)).CH_Util);
                           Temp_Bin_CH_Usage =  ceil(Net_Congestion_Measure(idx_STA(j)).CH_Util(current_idx,2)/Bin_CH_Usage)*Bin_CH_Usage;
                           Temp_Bin_ACK = ceil(Net_Congestion_Measure(idx_STA(j)).N_ACK(current_idx,2)/Bin_N_ACK)*Bin_N_ACK;

                           Temp_Idx_TX_LOG = find(TX_LOG(:,1) == Temp_Bin_CH_Usage & TX_LOG(:,2) == Temp_Bin_ACK);
                           
                           
                           if isempty(Temp_Idx_TX_LOG)
                               disp('There is no corresponding data in TX_LOG!');
                               Cnt_NoLog(idx_STA(j)) = Cnt_NoLog(idx_STA(j)) + 1; 
                               
                               EuclDist = sqrt( (Norm_TX_LOG(:,1) - Temp_Bin_CH_Usage/max(TX_LOG(:,1))).^2 + (Norm_TX_LOG(:,2) - Temp_Bin_ACK/max(TX_LOG(:,2))).^2);
                               [minEuclDist, Temp_Idx_TX_LOG] = min(EuclDist);  
                               
                               %TX_Prob = TX_LOG(Temp_Idx_TX_LOG,11);
                               
%                                if TX_LOG(Temp_Idx_TX_LOG,11) >= rand % TX_Th
%                                   List_Assigned_STA(ceil(N_RAW*rand), j) = idx_STA(j); 
%                                end
                               
%                                if rand >= TX_Th
%                                   List_Assigned_STA(ceil(N_RAW*rand), j) = idx_STA(j);                                 
%                                end
                               
                           else
                                % TX_Prob = TX_LOG(Temp_Idx_TX_LOG,11);
                              
%                               if TX_LOG(Temp_Idx_TX_LOG,11) >= rand % TX_Th
%                                  List_Assigned_STA(ceil(N_RAW*rand), j) = idx_STA(j); 
%                               end
                           end
                           
                           TX_Prob = TX_LOG(Temp_Idx_TX_LOG,11);
                           
                           if Enable_TxWeight 
                              
                              % (1) NetCongestionMeasure로 부터 직전 전송 주기에서의 전송
                              %     성공률 R_suc 계산
                              
                              % (2) PrevTxConfing으로 부터, 직전 전송 주기에 사용한
                              %     Tx_Prob 과 TxWeight을 추출
                              % (3) R_suc과 Tx_Prob을 비교함
                              %     (3-1) R_suc <= Tx_Prob --> TxWeight 감소
                              %     (3-2) R_suc >  Tx_Prob --> TxWeight 증가
                              % (4) TxWeight이 상한이거나 하한을 벗어나면, 조정
                              % (5) Tx_Prob 과 TxWeight을 이용하여, 새로운 Tx_Prob으로
                              %     갱신
                              % (6) 갱신한 Tx_Prob 과 TxWeight을 PrevTxConfing에 기록
                              
                              [PrevTxProb, PrevTxWeight] = Get_PrevTxConfig(idx_STA(j), Prev_TxConfig);
                              if PrevTxProb == -1 || PrevTxWeight == -1% -1 means initial state, that is, there is no NetCongestionMeasure for previous period
                                 % do nothing
                                 TxWeight = Init_TxWeight;   
                              else
                                 [R_Suc] = Calc_SucRatio(idx_STA(j), Net_Congestion_Measure);  
                                 
                                 if R_Suc <= PrevTxProb
                                    TxWeight = TxWeight - Dec_TxWeight;
                                    if TxWeight < Min_TxWeight
                                       TxWeight = Min_TxWeight; 
                                    end
                                 elseif R_Suc > PrevTxProb
                                    TxWeight = TxWeight + Inc_TxWeight;
                                    if TxWeight > Max_TxWeight
                                       TxWeight = Max_TxWeight; 
                                    end
                                    
                                 elseif isnan(R_Suc) % 
                                    % Do nothing 
                                    TxWeight = PrevTxWeight;
                                 else
                                     error('unexpected case!\ of the variable R_suc!');
                                 end
                              end
                              
                              TX_Prob = TxWeight*TX_Prob;
                              [Prev_TxConfig] = Set_PrevTxConfig(idx_STA(j),Prev_TxConfig, TX_Prob, TxWeight);   
                              
                              if On_Log_TxWeight
                                  NodeID_Log_TxWeight = find(Target_Node_Log_TxWeight == idx_STA(j));
                                  if i >= Next_Measure_Interval_Log_TxWeight && ~isempty(NodeID_Log_TxWeight)
                                     idx_row = Ptr_EachNodeLog(NodeID_Log_TxWeight); % find(Log_TxWeight(:,1) == i);
                                     idx_col = NodeID_Log_TxWeight*3-2;
                                     Ptr_EachNodeLog(NodeID_Log_TxWeight) = Ptr_EachNodeLog(NodeID_Log_TxWeight) + 1;
                                     
                                     Log_TxWeight(idx_row, idx_col:idx_col+2) = [i TxWeight TX_Prob];
                                     Next_Measure_Interval_Log_TxWeight = Next_Measure_Interval_Log_TxWeight + Measure_Interval_Log_TxWeight;
                                     
                                  end
                                  
                                  
                              end
                              
                           else
                              % do nothing 
                           end
                           
                           if TX_Prob >= rand 
                               
                              List_Assigned_STA(ceil(N_RAW*rand), j) = idx_STA(j); 
                           
                           end
                           
                           
                           
                       else
                            %disp('There is no TX_Log!');
                            error('There is no TX_Log!');
%                             if rand >= TX_Th
%                                  List_Assigned_STA(ceil(N_RAW*rand), j) = idx_STA(j);  
%                             end

                       end 
                   
                   end
               
               end
                            
           elseif RAW_Mode == 4
            % allocate STAs for each RAW slot based on uniform random distrubution
              All_User = []; 
              for j = 1:length(idx_STA)
                if Node.TX_Buffer(idx_STA(j)).Length > 0
                   All_User = [All_User;  idx_STA(j)];
                end
              end
               
               %All_User(All_User==idx_AP) = []; 
               List_Assigned_STA = zeros(N_RAW, N_STA);  % initialization, 0: non-assigned STA, 1+: assigned STA's AID

               
               for idx = 1:length(All_User)
                   Temp_Assigned_RAW_Slot = mod((All_User(idx) + N_offset), N_RAW)+1;
                   List_Assigned_STA(Temp_Assigned_RAW_Slot, idx) = All_User(idx);         
               end
            
            
           end
           
           % update Next Beacon Transmission Time
               Next_BTT = Next_BTT + Beacon_Interval + (N_RAW-1) + 1;
        end
        
        if On_CSB == 0
            % check if there exist any activated RAW slot
            for idx_RAW = 1:N_RAW
                
                if Tab_RAW(idx_RAW, 1) == i % when the start time of a RAW slot has reached
                    if Tab_RAW(idx_RAW, 3) ~= 0 % if the STATE of a RAW slot is disabled here, something is wrong.
                         error('Unexpected RAW STATE!');
                    end
                    Tab_RAW(idx_RAW, 3) = 1; % the STATE of a RAW slot is changed to the enabled.

                end

                 if Tab_RAW(idx_RAW, 2) == i % when the end time of a RAW slot has reached
                     if Tab_RAW(idx_RAW, 3) ~= 1 % if the STATE of a RAW slot is enabled here, something is wrong.
                         error('Unexpected RAW STATE!');
                     end
                     Tab_RAW(idx_RAW, 3) = 0;  % the STATE of a RAW slot is changed to the disabled.
                     %Temp_Channel_State = sum(tx_state(Tab_RAW(idx_RAW, 1):Tab_RAW(idx_RAW, 2),:)');  % for post processing. List_Remained_Slot could be index related to channel efficiency.
                     Temp_Channel_State = sum(tx_state(Tab_RAW(idx_RAW, 1):Tab_RAW(idx_RAW, 2),idx_AP(1))');
                     idx_last_CH_access_time = find(Temp_Channel_State ~= 0, 1, 'last');              % (note) It should be changed ... AP의 채널 상태를 기준으로 RAW slot의 남은 기간을 측정한는 
                                                                                                      % 것으로 변경 --> 추후 AP가 여러개인 상황에서는 다른 AP도 고려해야할 수 있음.
                     
                     if isempty(idx_last_CH_access_time)
                         List_Remained_Slot = [List_Remained_Slot; length(Temp_Channel_State)-1 idx_RAW];
                     else
                         List_Remained_Slot = [List_Remained_Slot; length(Temp_Channel_State) - find(Temp_Channel_State ~= 0, 1, 'last')-1 idx_RAW];
                     end
                     
                 end

            end
            
        elseif On_CSB == 1
             for idx_RAW = 1:N_RAW
                if Tab_RAW(idx_RAW, 1) >= i % when the start time of a RAW slot has reached
                    if Tab_RAW(idx_RAW, 3) ~= 0 % if the STATE of a RAW slot is disabled here, something is wrong.
                         error('Unexpected RAW STATE!');
                    end
                    Tab_RAW(idx_RAW, 3) = 1; % the STATE of a RAW slot is changed to the enabled.
                    
                end

                 if Tab_RAW(idx_RAW, 2) <= i % when the end time of a RAW slot has reached
                     if Tab_RAW(idx_RAW, 3) ~= 1 % if the STATE of a RAW slot is enabled here, something is wrong.
                         error('Unexpected RAW STATE!');
                     end
                     Tab_RAW(idx_RAW, 3) = 0;  % the STATE of a RAW slot is changed to the disabled.
                 end

            end
        else
            error('unexpected CSB MODE!');
        end
        
        
        if length(find(Tab_RAW(:,3) == 1)) > 1
            error('only one RAW slot can be enabled!');
        end
        
        Idx_Enabled_RAW = find(Tab_RAW(:,3) == 1); 
        
        if Idx_Enabled_RAW <= length(List_Assigned_STA)        
            Assigned_STA = List_Assigned_STA(Idx_Enabled_RAW,:);
            
        else
            Assigned_STA = [];
        end
        
        if ismember(0, Assigned_STA)    % the ID "0" is not for STA's ID.
            Assigned_STA(Assigned_STA == 0) = [];
        end
        
        N_user_in_RAW_Slot = length(Assigned_STA);
        
      
        % check if channel is idle, then backoff procedure is progressd.
        for j=1:N_user_in_RAW_Slot
            if (Node.aifs(Assigned_STA(j)) > 0 && ...
                    Node.TX_Buffer(Assigned_STA(j)).Length > 0 && ...
                    n_txnode(Assigned_STA(j)) == 0 && ...
                    tx_status(Assigned_STA(j),1) == -1 && ...
                    Node.ACK_Timer(Assigned_STA(j),1) == -1)
                
                Node.aifs(Assigned_STA(j)) = Node.aifs(Assigned_STA(j)) - 1;
                % wait for AIFS
            end
        end

        for j=1:N_user_in_RAW_Slot
            if (Node.aifs(Assigned_STA(j)) == 0 && ...
                    Node.TX_Buffer(Assigned_STA(j)).Length > 0 && ...
                    n_txnode(Assigned_STA(j)) == 0 && ...
                    tx_status(Assigned_STA(j),1) == -1 && ...
                    Node.ACK_Timer(Assigned_STA(j),1) == -1)
                
                %if (aifs_reset(j) == 1)
                    Node.bc(Assigned_STA(j)) = Node.bc(Assigned_STA(j)) -1; 
                %elseif (aifs_reset(j) == 0)
                %    bc(j) = 0;
                %end
            end
        end
        % decrement backoff counter by 1 for users after waiting for AIFSN
       
        
        
        % if channel is busy, do not change aifs & backoff counter 
        % check whether BC = 0
        for j=1:N_user_in_RAW_Slot
            if (Node.bc(Assigned_STA(j)) == 0 && n_txnode(Assigned_STA(j)) == 0 && tx_status(Assigned_STA(j),1) == -1) 
                
                T_data(Assigned_STA(j)) = 8*Node.TX_Buffer(Assigned_STA(j)).MPDU(1,2)/R_data(Assigned_STA(j));
                %T_txslot(Assigned_STA(j)) = ceil( (T_data(Assigned_STA(j)) + T_sifs + T_ack)/T_slot);   
                T_txslot(Assigned_STA(j)) = ceil( (T_data(Assigned_STA(j)))/T_slot);
                Node.aifs(Assigned_STA(j)) = Node.Init_aifs(Assigned_STA(j));
                %Node.bc(Assigned_STA(j)) = ceil(rand*Node.CW(Assigned_STA(j)));
                
                if On_CSB == 0  % if CSB is not allowed,
                    
                    if  T_txslot(Assigned_STA(j))  < Tab_RAW(Idx_Enabled_RAW, 2) - i   % (CSB on) Only if the rest of RAW slot is longer than a transmission time, the transmission is allowed.    
                        % tx_state(i:(i+T_txslot(Assigned_STA(j))-1),Assigned_STA(j)) = STATE_TX;
                        % set sate from i to i+T_txslot-1 = STATE_TX
                        
                        % n_txnode(Assigned_STA(j)) = n_txnode(Assigned_STA(j)) + 1;          
                                                
                        n_access(Assigned_STA(j)) = n_access(Assigned_STA(j)) + 1;
                        
                        if  Mode_Net_Congestion_Measure
%                             Net_Congestion_Measure(Assigned_STA(j)).N_Acc(length(Net_Congestion_Measure(Assigned_STA(j)).N_Acc), 2) ...
%                                     = Net_Congestion_Measure(Assigned_STA(j)).N_Acc(length(Net_Congestion_Measure(Assigned_STA(j)).N_Acc), 2) + 1;
                              Net_Congestion_Measure(Assigned_STA(j)).N_Acc(size(Net_Congestion_Measure(Assigned_STA(j)).N_Acc, 1), 2) ...
                                    = Net_Congestion_Measure(Assigned_STA(j)).N_Acc(size(Net_Congestion_Measure(Assigned_STA(j)).N_Acc, 1), 2) + 1;
                        end
                        
                        %N_retry(Assigned_STA(j)) = N_retry(Assigned_STA(j)) + 1;
                        if length(find(tx_status(Assigned_STA(j),:) == -1)) ~= 5 % tx_status가 제대로 초기화되지 않거나 하는 문제를 체크함.
                            error('unexpected tx_status!');
                        else
                            tx_status(Assigned_STA(j),:) = [i i+T_txslot(Assigned_STA(j))-1 1 0 0];
                        end
                        
                    else
                        
                        T_data(Assigned_STA(j)) = 0;
                        T_txslot(Assigned_STA(j)) = 0;
                        
                    end
                    
                elseif On_CSB == 1 % if CSB is allowed, (note 241023) Not used so far.
%                         tx_state(i:(i+T_txslot(Assigned_STA(j))-1),Assigned_STA(j)) = STATE_TX;
%                         % set sate from i to i+T_txslot-1 = STATE_TX
%                         [Idx_IntfSTA, Idx_IntfAP] = Get_InteferedSTAs(MAP_RSS, Assigned_STA(j), CSTh, N_AP);
%                         
%                         if ~isempty(Idx_IntfSTA)
%                             n_txnode(Idx_IntfSTA) = n_txnode(Idx_IntfSTA) + 1;
%                         end
%                         
%                         if ~isempty(Idx_IntfAP)
%                             %n_txnode_AP(Idx_IntfAP) = n_txnode_AP(Idx_IntfAP) + 1;
%                         end
%                         
%                         n_access(Assigned_STA(j)) = n_access(Assigned_STA(j)) + 1;
%                         %N_retry(Assigned_STA(j)) = N_retry(Assigned_STA(j)) + 1;
%                         if  Mode_Net_Congestion_Measure                         
%                             Net_Congestion_Measure(Assigned_STA(j)).N_Acc(length(Net_Congestion_Measure(Assigned_STA(j)).N_Acc), 2) = Net_Congestion_Measure(Assigned_STA(j)).N_Acc(length(Net_Congestion_Measure(Assigned_STA(j)).N_Acc), 2) + 1;
%                         end
                          error('CSB mode 1 is not used longer.');
                else
                    error('unexpected CSB mode');
                end
                
                % (note) 수정 필요: backoff counter 및 aifs는 전송 성공 또는 재전송 시도가 확정되는 시점이여야 함.
                % bc(Assigned_STA(j)) = ceil(rand*CW(Assigned_STA(j)));
                % aifs(Assigned_STA(j)) = AIFSN(Assigned_STA(j));            
                % re-select a new random backoff & aifs
            end
        end
        
        for j=1:N_AP
            % (1) An AP has a ACK in the ACK_Buffer?
            if Node.TX_Buffer(idx_AP(j)).ACK_Length > 0 && tx_status(idx_AP(j), 1) == -1
                if ~isempty(Node.TX_Buffer(idx_AP(j)).ACK(1))
            
                    % (2) ACK 전송 시간이 도래하였는가?
                    if Node.TX_Buffer(idx_AP(j)).ACK(1,5) + SIFSN <= i  % (note) ACK generated time + SIFS is defined as ACK transmission time.
                    
                       % (3) AP의 채널 상태는 IDLE 인가? n_txnode(j) == 0
                       if n_txnode(idx_AP(j)) == 0 
                          
                          % (4) Transmit ACK
                          % (4-1) ACK 전송 기간 만큼 tx_state 변경
                          tx_state(i:(i+T_ackN-1), idx_AP(j)) = STATE_TX;
                          
                          % (4-2) ACK 전송에 대하여 tx_status 갱신
                          tx_status(idx_AP(j), :) = [i i+T_ackN-1 Node.TX_Buffer(idx_AP(j)).ACK(1,3) 0 1];
                          
                          % (4-3) ACK 전송이 영향을 미치는 노드 갱신
                          
                          % (4-4) ACK를 전송 버퍼에서 제거
                          Node.TX_Buffer(idx_AP(j)) = Deque_ACK(Node.TX_Buffer(idx_AP(j)));
                          
                          % (5) post processing
                          n_access(idx_AP(j)) = n_access(idx_AP(j)) + 1;
                       end
                    end
                end
            end
        end
        
        % Update channel state based on tx_status
        for j=1:N_Node
            if tx_status(j,1) == i  % STATE TX and begin of Transmission for j-th node
                    % (c) 이 전송이 영향을 미치는 STA과 AP를 선별함. 이들에 대한 MAC_ID를 Idx_IntfNode에 index로 저장하여, 색인으로 사용.
                    [Idx_IntfSTA, Idx_IntfAP] = Get_InteferedSTAs(MAP_RSS, j, CSTh, N_AP);
                    Idx_IntfNode = unique([Idx_IntfSTA; Idx_IntfAP]);
                    tx_state(i:tx_status(j,2), j) = STATE_TX;
                    
                    % (c) 이 전송이 영향을 미치는 노드가 하나 이상 존재한다면,
                    if ~isempty(Idx_IntfNode)
                        % (c) 해당 노드의 전송 상태, tx_state를 Carrier Sensing 상태로 갱신함. 
                        % (c) 단, CS 상태로 갱신되는 기간은 전송 정보를 유지하는 데이터셋인 tx_status로 부터 획득하며, CS 값을 누적하여 감지되는 전송의 총 수를 유지함.
                        % (c) 이렇게 하면, tx_state와 tx_status로 부터 얻을 수 있는 정보인 전송 기간 동안 간섭을 발생시킨 다른 전송의 수를 상호 검증할 수 있음.
                        tx_state(i:tx_status(j,2),Idx_IntfNode) = tx_state(i:tx_status(j,2),Idx_IntfNode) + STATE_CS;  % (note) 누적 형태로 변경할 것.--> 변경하였음
                        Node.aifs(Idx_IntfNode) = Node.Init_aifs(Idx_IntfNode);
                        n_txnode(Idx_IntfNode) = n_txnode(Idx_IntfNode) + 1;
                        % (c) n_txnode는 현재 시간을 기준으로 해당 노드가 수신 중인 전송의 수를 유지하므로, 누적한 것과는 다름.
                    end
                    
                    % (수정 필요) IntfNode 들의 전송이 간섭을 받는 것이 아니므로 이하의 코드 블록은 수정되어야 함.
                    % [수정안] : (이하 for 문 제거) --> 
                    % 어떤 노드의 전송이 시작되면, 해당 전송이 유의미한 영향을 미치는 노드를 알 수 있음
                    % 이 노드들의 인덱스의 집합이 "Idx_IntfNode"임
                    % 다음으로, 활성화된 전송 정보모음인 tx_status에서 Idx_IntfNode를 목적지로 하는 tx_status를 탐색함.
                    % 그리고 해당 전송 정보에서 간섭을 겪은 횟수를 카운트함.
                    for temp_idx = 1:N_Node
                        if temp_idx == j
                            continue;
                        end
                        if tx_status(temp_idx,1) ~= -1 && ismember(tx_status(temp_idx,3), Idx_IntfNode) 
                           tx_status(temp_idx,4) = tx_status(temp_idx,4) + 1;
                        end
                       
                    end
                    % (note) 어떤 노드의 전송이 시작되었을 때, 추가적으로 할 일은 없는가?
            end
        end
        
        for j=1:N_Node
            if tx_status(j,2) == i  % At the End of Node j's Transmission 
                    
                    [Idx_IntfSTA, Idx_IntfAP] = Get_InteferedSTAs(MAP_RSS, j, CSTh, N_AP);
                    Idx_IntfNode = unique([Idx_IntfSTA; Idx_IntfAP]);
                    Node.aifs(j) = Node.Init_aifs(j);
                    Node.bc(j) = ceil(rand*Node.CW(j));
                    
                    if ~isempty(Idx_IntfNode)
                        %tx_state(i:tx_status(j,2),Idx_IntfNode) = tx_state(i:tx_status(j,2),Idx_IntfNode) - STATE_CS;  % (note) 누적 형태로 변경할 것.
                        Node.aifs(Idx_IntfNode) = Node.Init_aifs(Idx_IntfNode);
                        n_txnode(Idx_IntfNode) = n_txnode(Idx_IntfNode) - 1;
                        % (note) n_txnode도 누적? --> 누적하지 않음. 대신 누적된 전송 수는 tx_status의 4번째 열에 추가함.
                    end
                    
                    if ~isempty(find(n_txnode < 0, 1))  % In no case can n_txnode, the total number of transmissions detected, be a negative value.
                        error('unexpected channel state!');
                    end
                    
                    % check if there any interfered transmission for this transmission,....
                    if tx_status(j,4) > 0  % fail
                        
                        % if failed, AP does nothing
                        
                        % 전송 실패 여부와 상관 없이, 송신 측은 ACK 타이머를 가동함.
                        if tx_status(j,5) == 0
                            GID_Src = Node.TX_Buffer(j).MPDU(1,1);
                            Node.ACK_Timer(j,:) = Set_AckTimer(T_ack_Timeout, T_slot, i, GID_Src);
                        end
                        n_collision(j) = n_collision(j) + 1;
                        
                    elseif tx_status(j,4) == 0 && tx_status(j,5) == 0 % success in Data Transmission(0)
                        % An AP enques ACK in AP's buffer
                        GID_Src = Node.TX_Buffer(j).MPDU(1,1); 
                        [Node.TX_Buffer(tx_status(j,3)), GID] = Enque_ACK(Node.TX_Buffer(tx_status(j,3)), GID, GID_Src, j, L_ack, i);
                        n_success(j) = n_success(j) + 1;
                        % (note) 전송이 성공함. 단, ACK 수신 여부로 판단하지 않는 전송의 성공으로,
                        %        추후, ACK 수신 여부로 판단한 전송의 성공 횟수 n_success2 와 비교할 목적을 갖고 있음.
                        
                        % 전송 실패 여부와 상관 없이, 송신 측은 ACK 타이머를 가동함.
                        Node.ACK_Timer(j,:) = Set_AckTimer(T_ack_Timeout, T_slot, i, GID_Src);
                        
                    elseif tx_status(j,4) == 0 && tx_status(j,5) == 1 % success in ACK Transmission(1)
                        % (1) ACK의 수신이 ACK Timeout이 발생하기 전에 이루어졌는지 검토함.
                        %     - 노드 j의 수신측에서 설정한 ACK Timer
                        Temp_TX_Node_ID = tx_status(j,3); % ACK의 목적지(즉, MPDU를 전송한 노드의 ID)
                        
                        if Node.ACK_Timer(Temp_TX_Node_ID,1) >= i % ACK Timeout 시간 이내이면,
                            Temp_GID_Src = Node.TX_Buffer(Temp_TX_Node_ID).MPDU(1,1); % MPDU의 GID를 추출하고
                            if Node.ACK_Timer(Temp_TX_Node_ID,2) == Temp_GID_Src % MPDU의 seqID와 ACK Timer의 seqID를 비교하여, desired ACK인지 검토함.
                                % (note) Node.ACK_Timer(j)는 node j의 ACK Timer로, 현재 시간(slot 단위)에 ACK_Timeout 시간을 더한 값이다.
                                % 따라서, ACK Timer의 만료 여부는 현재 시간이 ACK_Timer에 기록된 시간을 초과하였는지 검토하는 것으로 이루어진다.       
                                % ACK Timer에 추가 정보로 전송한 MPDU의 GID를 기록하면, 의도한 MPDU의 수신이 맞는지 검토할 수 있다.
                                % 이는 ACK의 지연된 수신이 발생하는 상황을 올바르게 처리하기 위함이다.
                                % (note 25-01-07) 이러한 기능을 하도록 Set_AckTimer 함수를 변경하였다.

                                % (2-1) ACK Timeout 전에 수신되었다면, 수신 노드는 해당 프레임을 전송 버퍼에서 제거하고 전송 성공으로 처리
                                Delay(Temp_TX_Node_ID).delay = [Delay(Temp_TX_Node_ID).delay; Node.TX_Buffer(Temp_TX_Node_ID).MPDU(1, 3)  i i-Node.TX_Buffer(Temp_TX_Node_ID).MPDU(1, 3)];
                                L_success(Temp_TX_Node_ID) = L_success(Temp_TX_Node_ID) + Node.TX_Buffer(Temp_TX_Node_ID).MPDU(1, 2);
                                n_success2(Temp_TX_Node_ID) = n_success2(Temp_TX_Node_ID) + 1;
                                n_success(j) = n_success(j) + 1; % (note) AP의 ACK 전송 성공 여부를 체크할 수 있음--> 추후 ACK 전송 성공 여부를 측정할 수 있는 별도의 변수를 정의하여 이용할 것
                                
                                Node.TX_Buffer(Temp_TX_Node_ID) = Deque_MPDU(Node.TX_Buffer(Temp_TX_Node_ID));                              
                                Node.ACK_Timer(Temp_TX_Node_ID,:) = Init_AckTimer(Node.ACK_Timer(Temp_TX_Node_ID,:));

                                if BEB_ENABLE
                                    Node.CW(j) = Node.CW_min(j);
                                    Node.bc(j) = ceil(rand*Node.CW(j));
                                    Node.N_retry(j) = 0;
                                end
                                
                                if  Mode_Net_Congestion_Measure                      
                                    Net_Congestion_Measure(Temp_TX_Node_ID).N_Suc(length(Net_Congestion_Measure(Temp_TX_Node_ID).N_Suc), 2) = ...
                                        Net_Congestion_Measure(Temp_TX_Node_ID).N_Suc(length(Net_Congestion_Measure(Temp_TX_Node_ID).N_Suc), 2) + 1;
                                    %Net_Congestion_Measure(Assigned_STA(j)).N_ACK(length(Net_Congestion_Measure(Assigned_STA(j)).N_ACK), 2) = Net_Congestion_Measure(Assigned_STA(j)).N_ACK(length(Net_Congestion_Measure(Assigned_STA(j)).N_ACK), 2) + 1;
                                    %Temp_ACK_Cnt = Temp_ACK_Cnt + 1;
                                    
                                    if ~isempty(Idx_IntfNode)
                                        % - [ ]  ACK Overhearing 절차
                                        % - [x]  (1) ACK 전송이 도달하는 STA들의 ID를 Idx_IntfNode를 통해 얻음
                                        %         - Idx_IntfNode 와 동일함
                                        % - [ ]  (2) 해당 STA들이 ACK를 간 섭 없이 성공적으로 수신하였는 지 판별
                                        %         - [ ]  ACK에 대한 tx_status에서 전송의 시작과 종료 시간을 얻음
                                        %         - [ ]  Idx_IntfNode의 tx_state에서 해당 기간 동안 전송의 상태를 얻음
                                        %         - [ ]  모든 STATE가 2로 측정 되는 경우에만 ACK를 간섭 없이 수신한 것으로 취급함
                                        %             - 1: TX, 2: CS이며, 전송 상태는 해당 값이 누적됨,
                                        %             - 예로 들어, 3(1+2)은 전송 중인데 신호가 수신되는 상황 4(2+2)는 두개 이상의 신호가 수신 중인 상황임
                                        % - [ ]  (3) 성공적으로 수신하였다면, .N_ACK를 카운트함.
                                        
                                        Temp_Begin = tx_status(j,1);
                                        Temp_End = tx_status(j,2);
                                        
                                        for Temp_Idx=1:length(Idx_IntfNode)
                                            if length(find(tx_state(Temp_Begin:Temp_End, Idx_IntfNode(Temp_Idx)) == STATE_CS)) == Temp_End - Temp_Begin + 1
                                               Net_Congestion_Measure(Idx_IntfNode(Temp_Idx)).N_ACK(length(Net_Congestion_Measure(Idx_IntfNode(Temp_Idx)).N_ACK), 2) ...
                                                   = Net_Congestion_Measure(Idx_IntfNode(Temp_Idx)).N_ACK(length(Net_Congestion_Measure(Idx_IntfNode(Temp_Idx)).N_ACK), 2) + 1; 
                                            else
                                                % do nothing
                                            end
                                        end
                                     
                                        
                                    end
                                end
                                
                            
                            end
                        else
                            % (2-2) ACK Timeout 이후에 수신되었다면, 수신 노드는 이 ACK를 무시함.
                            % Do Nothing
                            
                        end                    
                        
                        
                        % (note) ACK Timeout으로 인해 재전송될 프레임은 GID를 갱신해서 보내도록 코드가 수정되어야 함. (수정하였음)
                        
                    else
                        error('unexpected value odf tx_status!');
                    end
                    
                    tx_status(j, :) = Init_tx_status(tx_status(j, :)); % initialize tx_staus for node j

            end     
        end
        
        
        % ACK Timer 만료(전송 실패) 여부 체크
        for j=1:N_Node
            if Node.ACK_Timer(j,1) ~= -1 
                
                if Node.ACK_Timer(j,1) < i
                   n_collision2(j) = n_collision2(j) + 1;
                   Node.ACK_Timer(j,:) = Init_AckTimer(Node.ACK_Timer(j,:));
                   Node.N_retry(j) = Node.N_retry(j) + 1;
                   [Node.TX_Buffer(j) GID] = Reset_GID(Node.TX_Buffer(j), GID);
                   Node.ACK_Timer(j,:) = Init_ACK_Timer(Node.ACK_Timer(j,:));
                   
                   if  Mode_Net_Congestion_Measure                         
                       Net_Congestion_Measure(j).N_Fail(length(Net_Congestion_Measure(j).N_Fail), 2) = ...
                           Net_Congestion_Measure(j).N_Fail(length(Net_Congestion_Measure(j).N_Fail), 2) + 1;
                   end
                        
                   if BEB_ENABLE
                      Node.CW(j) = min(Node.CW(j) * 2, Node.CW_max(j));
                      Node.bc(j) = ceil(rand*Node.CW(j));
                   end
                   
                   if Node.N_retry(j) == Node.Retry_Limit(j)
                      % Drop MPDU
                       Node.TX_Buffer(j) = Deque_MPDU(Node.TX_Buffer(j));
                       Node.N_retry(j) = 0;
                       n_loss(j) = n_loss(j) + 1;
                       if BEB_ENABLE
                            Node.CW(j) = Node.CW_min(j);
                            Node.bc(j) = ceil(rand*Node.CW(j));
                       end
                       
                   end
                   
                   
                end
                
            end
        
        end
        
        if Mode_Net_Congestion_Measure
            if i > Next_Net_Congestion_Measure_Time
%                 Temp_CH_Util = sum(sum(tx_state(Next_Net_Congestion_Measure_Time-Net_Congestion_Measure_Interval+1:Next_Net_Congestion_Measure_Time,:)') > 0)/Net_Congestion_Measure_Interval;
                for j = 1:N_STA
                   Temp_CH_Util = sum(tx_state(Next_Net_Congestion_Measure_Time-Net_Congestion_Measure_Interval+1:Next_Net_Congestion_Measure_Time,idx_STA(j))>0)/Net_Congestion_Measure_Interval;
                   Net_Congestion_Measure(idx_STA(j)).CH_Util = [Net_Congestion_Measure(idx_STA(j)).CH_Util; Next_Net_Congestion_Measure_Time Temp_CH_Util];
                   Net_Congestion_Measure(idx_STA(j)).N_ACK = [Net_Congestion_Measure(idx_STA(j)).N_ACK; Next_Net_Congestion_Measure_Time 0];
                   Net_Congestion_Measure(idx_STA(j)).N_Acc = [Net_Congestion_Measure(idx_STA(j)).N_Acc; Next_Net_Congestion_Measure_Time 0];
                   Net_Congestion_Measure(idx_STA(j)).N_Fail = [Net_Congestion_Measure(idx_STA(j)).N_Fail; Next_Net_Congestion_Measure_Time 0];
                   Net_Congestion_Measure(idx_STA(j)).N_Suc = [Net_Congestion_Measure(idx_STA(j)).N_Suc; Next_Net_Congestion_Measure_Time 0];
                   Net_Congestion_Measure(idx_STA(j)).N_MPDU = [Net_Congestion_Measure(idx_STA(j)).N_MPDU; Next_Net_Congestion_Measure_Time 0];
                   Net_Congestion_Measure(idx_STA(j)).L_QTime = [Net_Congestion_Measure(idx_STA(j)).L_QTime; Next_Net_Congestion_Measure_Time 0];
                end
                
                Next_Net_Congestion_Measure_Time = Next_Net_Congestion_Measure_Time + Net_Congestion_Measure_Interval ;
            end
                
        end
        
        % Traffic generation for the backgroud STAs
        if N_bkSTA > 0
           for j = 1:N_bkSTA
               
               if  Node.Type(idx_STA_Type0(j)) ~= 0
                   error('unexpected Type of STA');
               end
               
               if Next_Frame_Interval_bk(idx_STA_Type0(j)) <= i

                    if rand <= Prob_Frame_Generation_bk 

                        GID = GID + 1;
                        Node.TX_Buffer(idx_STA_Type0(j)).Length = Node.TX_Buffer(idx_STA_Type0(j)).Length + 1;

    %                     if TX_Buffer(j).Length == 1
    %                         TX_Buffer(j).MPDU = [GID Next_Frame_Length(j)];
    %                     else
    %                         TX_Buffer(j).MPDU(TX_Buffer(j).Length, :) = [TX_Buffer(j).MPDU; GID Next_Frame_Length(j)];
    %                     end
                        Node.TX_Buffer(idx_STA_Type0(j)).MPDU = [Node.TX_Buffer(idx_STA_Type0(j)).MPDU; GID Next_Frame_Length_bk(idx_STA_Type0(j)) i];
                        n_enq(j) = n_enq(idx_STA_Type0(j)) + 1;
                    end

                    % reset configurations for a next arrival frame
                    Next_Frame_Length_bk(idx_STA_Type0(j)) = ceil( (Range_Frame_Length_bk(2)-Range_Frame_Length_bk(1))*rand + Range_Frame_Length_bk(1) );
                    Next_Frame_Interval_bk(idx_STA_Type0(j)) = i + ceil( (Range_Frame_Interval_bk(2)-Range_Frame_Interval_bk(1))*rand + Range_Frame_Interval_bk(1) );
                            
               end                  
           end
        end
        
        if Opt_Start < i && Opt_End >= i %|| ( (i- Prev_Traffic_Event) >= Allowed_MAX_Next_Traffic_Event )
            Prev_Traffic_Event = i;
            
            if Traffic_Surge_Mode == 1
                if Traffic_Gen_Mode == 0
                    for j = 1:N_STA
                            if  Node.Type(idx_STA_Type1(j)) ~= 1
                                error('unexpected Type of STA');
                            end
                            
                            if Next_Frame_Interval(idx_STA_Type1(j)) <= i

                                if rand <= Prob_Frame_Generation_al 

                                    GID = GID + 1;
                                    Node.TX_Buffer(idx_STA_Type1(j)).Length = Node.TX_Buffer(idx_STA_Type1(j)).Length + 1;

                %                     if TX_Buffer(j).Length == 1
                %                         TX_Buffer(j).MPDU = [GID Next_Frame_Length(j)];
                %                     else
                %                         TX_Buffer(j).MPDU(TX_Buffer(j).Length, :) = [TX_Buffer(j).MPDU; GID Next_Frame_Length(j)];
                %                     end
                                    Node.TX_Buffer(idx_STA_Type1(j)).MPDU = [Node.TX_Buffer(idx_STA_Type1(j)).MPDU; GID Next_Frame_Length_al(idx_STA_Type1(j)) i];
                                    n_enq(idx_STA_Type1(j)) = n_enq(idx_STA_Type1(j)) + 1;
                                end

                                % reset configurations for a next arrival frame
                                Next_Frame_Length_al(idx_STA_Type1(j)) = ceil( (Range_Frame_Length_al(2)-Range_Frame_Length_al(1))*rand + Range_Frame_Length_al(1) );
                                Next_Frame_Interval_al(idx_STA_Type1(j)) = i + ceil( (Range_Frame_Interval_al(2)-Range_Frame_Interval_al(1))*rand + Range_Frame_Interval_al(1) );

                            end
                    end

                elseif Traffic_Gen_Mode == 1
                    if Next_Frame_Interval_al <= i && rand <= Prob_Frame_Generation_al
                       for j = 1:N_alarmSTA   
                            if  Node.Type(idx_STA_Type1(j)) ~= 1
                                error('unexpected Type of STA');
                            end                                    
                                    GID = GID + 1;
                                    Node.TX_Buffer(idx_STA_Type1(j)).Length = Node.TX_Buffer(idx_STA_Type1(j)).Length + 1;

                %                     if TX_Buffer(j).Length == 1
                %                         TX_Buffer(j).MPDU = [GID Next_Frame_Length(j)];
                %                     else
                %                         TX_Buffer(j).MPDU(TX_Buffer(j).Length, :) = [TX_Buffer(j).MPDU; GID Next_Frame_Length(j)];
                %                     end
                                    Node.TX_Buffer(idx_STA_Type1(j)).MPDU = [Node.TX_Buffer(idx_STA_Type1(j)).MPDU; GID Next_Frame_Length_al i];
                                    n_enq(idx_STA_Type1(j)) = n_enq(idx_STA_Type1(j)) + 1;

                                % reset configurations for a next arrival frame
                                Next_Frame_Length_al = ceil( (Range_Frame_Length_al(2)-Range_Frame_Length_al(1))*rand + Range_Frame_Length_al(1) );
                                Next_Frame_Interval_al = i + ceil( (Range_Frame_Interval_al(2)-Range_Frame_Interval_al(1))*rand + Range_Frame_Interval_al(1) );
                       end
                    end
                end
            
            elseif Traffic_Surge_Mode == 2 || Traffic_Surge_Mode == 3
                
%                    if Last_Time == 0
%                       % do nothing (X)
%                       % break; (X)
%                       N_buffered_STAs = 0;
%                       Last_Time = i;
%                    else
%                       N_buffered_STAs = floor(Tab_Traffic_Model(2, i-Opt_Start)- Tab_Traffic_Model(2, Last_Time));
%                    end

                   N_buffered_STAs = floor(Tab_Traffic_Model(2, i-Opt_Start)) - floor(Tab_Traffic_Model(2, Last_Time));
                   %N_buffered_STAs = round(Access_intensity(i-Opt_Start, Last_Time, N_STA, Period, var_alpha, var_beta));
                   
                   if N_buffered_STAs > 0
                       Last_Time = i-Opt_Start;
                       Measure_Cummulated_N_Triggerd_STAs = [Measure_Cummulated_N_Triggerd_STAs; i Measure_Cummulated_N_Triggerd_STAs(L_Measure_Cummulated_N_Triggerd_STAs,2)+N_buffered_STAs];
                       L_Measure_Cummulated_N_Triggerd_STAs = L_Measure_Cummulated_N_Triggerd_STAs +1;
                       
                       Temp_cnt = 0;
                       for idx_N_buffered_STAs=1:N_alarmSTA

                           if  Node.Type(idx_STA_Type1(idx_N_buffered_STAs)) ~= 1
                                error('unexpected Type of STA');
                           end
                            
                           if Node.TX_Buffer(idx_STA_Type1(idx_N_buffered_STAs)).Triggered == 0
                              Node.TX_Buffer(idx_STA_Type1(idx_N_buffered_STAs)).Triggered = 1;
                              
                              if Traffic_Surge_Mode == 2
                                  GID = GID + 1;
                                  % reset configurations for a next arrival frame
                                  Next_Frame_Length_al(idx_STA_Type1(idx_N_buffered_STAs)) = ceil( (Range_Frame_Length_al(2)-Range_Frame_Length_al(1))*rand + Range_Frame_Length_al(1) );
                                  %Next_Frame_Interval = i + ceil( (Range_Frame_Interval(2)-Range_Frame_Interval(1))*rand + Range_Frame_Interval(1) );
                                  Node.TX_Buffer(idx_STA_Type1(idx_N_buffered_STAs)).Length = Node.TX_Buffer(idx_STA_Type1(idx_N_buffered_STAs)).Length + 1;
                                  Node.TX_Buffer(idx_STA_Type1(idx_N_buffered_STAs)).MPDU = [Node.TX_Buffer(idx_STA_Type1(idx_N_buffered_STAs)).MPDU; GID Next_Frame_Length_al i];
                                  n_enq(idx_STA_Type1(idx_N_buffered_STAs)) = n_enq(idx_STA_Type1(idx_N_buffered_STAs)) + 1;
                              end
%                               if Traffic_Surge_Mode == 3
%                                   Next_Frame_Length(idx_STA_Type1(idx_N_buffered_STAs)) = ceil( ( (2)-Range_Frame_Length(1))*rand + Range_Frame_Length(1) );
%                                   Next_Frame_Interval(idx_STA_Type1(idx_N_buffered_STAs)) = i + ceil( (Range_Frame_Interval(2)-Range_Frame_Interval(1))*rand + Range_Frame_Interval(1) );                                
%                               end
                              
                              Temp_cnt = Temp_cnt + 1;
                              if Temp_cnt == N_buffered_STAs
                                 break;  
                              end
                               
                           end                
                       end
                       
                       if Traffic_Surge_Mode == 3
                          for j = 1:N_alarmSTA
                              
                            if  Node.Type(idx_STA_Type1(j)) ~= 1
                                error('unexpected Type of STA');
                            end
                            
                            if Next_Frame_Interval_al(idx_STA_Type1(j)) <= i && Node.TX_Buffer(idx_STA_Type1(j)).Triggered == 1

                                if rand <= Prob_Frame_Generation_al 
                                    
                                    [Node.TX_Buffer(idx_STA_Type1(j)) GID] = Enque_MPDU(Node.TX_Buffer(idx_STA_Type1(j)), GID, Next_Frame_Length_al(idx_STA_Type1(j)), i);
                                    
                                    %GID = GID + 1;
                                    %Node.TX_Buffer(idx_STA_Type1(j)).Length = Node.TX_Buffer(idx_STA_Type1(j)).Length + 1;

                %                     if TX_Buffer(j).Length == 1
                %                         TX_Buffer(j).MPDU = [GID Next_Frame_Length(j)];
                %                     else
                %                         TX_Buffer(j).MPDU(TX_Buffer(j).Length, :) = [TX_Buffer(j).MPDU; GID Next_Frame_Length(j)];
                %                     end
                                    %Node.TX_Buffer(idx_STA_Type1(j)).MPDU = [Node.TX_Buffer(idx_STA_Type1(j)).MPDU; GID Next_Frame_Length(idx_STA_Type1(j)) i];
                                    n_enq(idx_STA_Type1(j)) = n_enq(idx_STA_Type1(j)) + 1;
                                end

                                % reset configurations for a next arrival frame
                                Next_Frame_Length_al(idx_STA_Type1(j)) = ceil( ( Range_Frame_Length_al(2)-Range_Frame_Length_al(1))*rand + Range_Frame_Length_al(1) );
                                Next_Frame_Interval_al(idx_STA_Type1(j)) = i + ceil( (Range_Frame_Interval_al(2)-Range_Frame_Interval_al(1))*rand + Range_Frame_Interval_al(1) );

                            end
                         end 
                       end
                       
                   else
                       % do nothing
                   end
            end
            
            
        end
        
        
        
        if On_Measure_Traffic_Temporal_Evolution
           if Next_Measure_Time  <= i
                Temp_sum_N_Frame = 0;
                Temp_sum_Length = 0;
                N_STAs_has_buffered_Frames = 0;
                for j = 1:N_Node
                    if Node.Type(j) == -1  
                       continue; 
                    end
                    
                    if Node.TX_Buffer(j).Length > 0
                        Temp_sum_N_Frame = Temp_sum_N_Frame + Node.TX_Buffer(j).Length;
                        Temp_sum_Length = Temp_sum_Length + Node.TX_Buffer(j).MPDU(2);
                        N_STAs_has_buffered_Frames  = N_STAs_has_buffered_Frames +1;
                    else
                        % do nothing
                    end
                end
                
                Traffic_Temporal_Evolution = [Traffic_Temporal_Evolution;  Next_Measure_Time Temp_sum_N_Frame Temp_sum_N_Frame/N_STA Temp_sum_Length Temp_sum_Length/N_STA N_STAs_has_buffered_Frames ...
                                         mean(n_access) mean(n_success./n_access) mean(n_collision./n_access)];
                Next_Measure_Time = Next_Measure_Time + Opt_Measure_Interval;
           
               
           
           end
           
        end
        
        if Mode_Dynamic_Sim_Time &&  N_slot - i < Crit_Remaied_Slot
            
            isAdjustSimTimeExtend = 0;
            
            if 0 %On_Measure_Traffic_Temporal_Evolution
                if N_STAs_has_buffered_Frames
                    isAdjustSimTimeExtend = 1;
                end
            else
                for j = 1:N_alarmSTA
                    if Node.TX_Buffer(idx_STA_Type1(j)).Length > 0
                        isAdjustSimTimeExtend = 1;
                        break;
                    end
                end
            end
            
            if isAdjustSimTimeExtend 
                
                N_slot = N_slot + N_Extending_Slot;
                tx_state = [tx_state; zeros(N_Extending_Slot, N_STA)];
                
            end
               
        end
        
        i=i+1;  % increase time index by 1
        %temp_i = i;
          % for DEBUGGING
%         for k=1:N_Node
%             if tx_status(k,1) > 0 && tx_status(k,1) >= tx_status(k,2)
%                 error('unexpected tx_status');
%             end
%         end
    else % No RAW, normal DCF
         % do nothing               
    end
    
end

%------------------------------------------------------------------


%------------------------------
% statistics
%------------------------------
n_access 
%t_access = n_access.*T_data
    % channel access time
%n_collision
%n_success
%per_user_access = n_access/(sum(n_access))

plot(Measure_Cummulated_N_Triggerd_STAs(:,1), Measure_Cummulated_N_Triggerd_STAs(:,2),'.');
hold off;
Diff_Measure_Cummulated_N_Triggerd_STAs = Measure_Cummulated_N_Triggerd_STAs(2:length(Measure_Cummulated_N_Triggerd_STAs(:,2)),2) ...
                                        - Measure_Cummulated_N_Triggerd_STAs(1:length(Measure_Cummulated_N_Triggerd_STAs(:,2))-1,2);
figure;
hold on;
plot(Measure_Cummulated_N_Triggerd_STAs(2:length(Measure_Cummulated_N_Triggerd_STAs(:,2)),1), Diff_Measure_Cummulated_N_Triggerd_STAs);
hold off;


cnt_empty_delay_measure = 0;
for j =1:N_Node
    
    if (isempty(Delay(j).delay))
        cnt_empty_delay_measure = cnt_empty_delay_measure + 1;
    else
        L_Delay_Data = length(Delay(j).delay(:,1));
        if L_Delay_Data == 1
            Delay(j).delay(1,4) =  Delay(j).delay(1,3);
        else
            
            Delay(j).delay(:,4) = Delay(j).delay(:,2)-[0;Delay(j).delay(1:L_Delay_Data-1,2)];
            Delay(j).delay(1,4) =  Delay(j).delay(1,3);
        end
        Avg_Delay(j, :) = [nanmean(Delay(j).delay(:,3))*T_slot nanmin(Delay(j).delay(:,3))*T_slot nanmax(Delay(j).delay(:,3))*T_slot];
        Avg_AccessDelay(j,:) = [nanmean(Delay(j).delay(:,4))*T_slot nanmin(Delay(j).delay(:,4))*T_slot nanmax(Delay(j).delay(:,4))*T_slot];
    end 
end

if Opt_Start == 0 && Opt_End == N_slot
    Temp_Solve_Time = N_slot;
else
    Idx_Solved_Time = find(Traffic_Temporal_Evolution(find(Traffic_Temporal_Evolution(:,1) > Opt_End),6)==0,1);
    Temp_Solve_Time = Traffic_Temporal_Evolution(find(Traffic_Temporal_Evolution(:,1) > Opt_End),1);
    Temp_Solve_Time = Temp_Solve_Time(Idx_Solved_Time);
end
% (note) 임시로 지정함.
Temp_Solve_Time = Opt_End;

% per_user_th = (L_success * 8) / ((Temp_Solve_Time-Opt_Start)*T_slot) / 10^6;  % Mb/s , (note 24-01-11) the real simulation time should be compesanted considering a period of traffic surge.
% total_th = sum(L_success * 8) / ((Temp_Solve_Time-Opt_Start)*T_slot) / 10^6;
per_user_th = (L_success * 8) / ((N_slot)*T_slot) / 10^6;  % Mb/s
total_th = sum(L_success * 8) / ((N_slot)*T_slot) / 10^6;
normalized_th = total_th/(R_data(1)*10^-6)  % normalized throughput
fairness_index = total_th^2 / (N_STA * sum(per_user_th.*per_user_th))

%collision_prob = sum(n_collision)/sum(n_access)
avg_collision_ratio = [nanmean(n_collision(idx_STA)./n_access(idx_STA)) nanmean(n_collision2(idx_STA)./n_access(idx_STA))];
% utilization = sum(sum(tx_state==1)) / (Temp_Solve_Time-Opt_Start) % (note 24-01-11) the real simulation time should be compesanted considering a period of traffic surge.
avg_n_access = mean(n_access(idx_STA));
avg_success_ratio = [nanmean(n_success(idx_STA)./n_access(idx_STA)) nanmean(n_success2(idx_STA)./n_access(idx_STA))]; 

loss_ratio = n_loss(idx_STA)./n_enq(idx_STA);
%avg_loss_ratio = nanmean(n_loss(idx_STA)./n_enq(idx_STA));
avg_loss_ratio = nanmean(loss_ratio);
avg_loss = mean(n_loss(idx_STA));

%RESULT_SET = [total_th normalized_th utilization avg_n_access collision_prob2 fairness_index mean(Avg_Delay) mean(Avg_AccessDelay) avg_loss_ratio mean(n_loss) Temp_Solve_Time*T_slot];
RESULT_SET2 = [total_th normalized_th avg_n_access avg_success_ratio avg_collision_ratio avg_loss_ratio avg_loss mean(Avg_Delay)];
cnt_empty_delay_measure
if(RAW_Mode == 3)
    sum(Cnt_NoLog)
    mean(Cnt_NoLog(2:N_Node))
end
toc;
if On_Save_TX_Log
    Anal_Congestion_Log;
end

pause(0.7);
beep;
pause(0.7);
beep;
pause(0.7);
beep;
pause(0.7);
beep;
pause(0.7);
