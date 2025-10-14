%close all;

Net_Congestion_Measure(1) = []; % remove data for AP
L_Log = length(Net_Congestion_Measure);
R = [];

for j = 1:L_Log
    for i = 1:length(Net_Congestion_Measure(j).CH_Util(:,1))
        R((j-1)*length(Net_Congestion_Measure(j).CH_Util(:,1))+i, :) = [Net_Congestion_Measure(j).CH_Util(i,1)...
                    Net_Congestion_Measure(j).CH_Util(i,2)...
                    Net_Congestion_Measure(j).N_ACK(i,2)...
                    Net_Congestion_Measure(j).N_Acc(i,2)...
                    Net_Congestion_Measure(j).N_Fail(i,2)...
                    Net_Congestion_Measure(j).N_Suc(i,2)];
    end
end

% Filtering: Data 중에서 접속 시도 횟수(N_Acc)가 0 인 경우를 제외함(이유: 확률로 변환할 수 없음)
Temp_Idx = find(R(:,4)==0);
R(Temp_Idx,:) = [];

L = length(R);
Bin_CH_Usage = 0.1000;
Bin_N_ACK = 5;
Unnamed_Tab = [];

for i = 1:L
    
    Temp_Bin_CH_Usage = ceil(R(i,2)/Bin_CH_Usage)*Bin_CH_Usage;
    Temp_Bin_N_ACK = ceil(R(i,3)/Bin_N_ACK)*Bin_N_ACK;
    
%     if R(i,2) ~=0 && Temp_Bin_CH_Usage == 0
%        disp('here'); 
%     end
%     
%     if Temp_Bin_CH_Usage == 0 && Temp_Bin_N_ACK == 5
%        disp('here'); 
%     end
    
    if i == 1
        Unnamed_Tab = [Temp_Bin_CH_Usage Temp_Bin_N_ACK 0 R(i,4) R(i,5) R(i,6)]; 
        continue;
    end
    
    Temp_Idx =  find(Unnamed_Tab(:,1) ==Temp_Bin_CH_Usage & Unnamed_Tab(:,2) == Temp_Bin_N_ACK);
    
    if length(Temp_Idx) > 1
        error('unexpected indexing!');
    end
    
    if isempty(Temp_Idx)
        
        Unnamed_Tab = [Unnamed_Tab; Temp_Bin_CH_Usage Temp_Bin_N_ACK 0 R(i,4) R(i,5) R(i,6)];
        
    else
        if R(i,4)  ~=  0
            
            Unnamed_Tab(Temp_Idx,3) = Unnamed_Tab(Temp_Idx,3) + 1;
            Unnamed_Tab(Temp_Idx,4) = Unnamed_Tab(Temp_Idx,4) + R(i,4);
            Unnamed_Tab(Temp_Idx,5) = Unnamed_Tab(Temp_Idx,5) + R(i,5);
            Unnamed_Tab(Temp_Idx,6) = Unnamed_Tab(Temp_Idx,6) + R(i,6);
                            
        end
        
        
       
    end
        
end
    
L = length(Unnamed_Tab);

for i = 1:L
   
    Unnamed_Tab(i,7:9) = Unnamed_Tab(i,4:6)/Unnamed_Tab(i,3);
    Unnamed_Tab(i,10:11) = Unnamed_Tab(i,5:6)/Unnamed_Tab(i,4);
    
end

 Unnamed_Tab = sortrows(Unnamed_Tab, [1 2]);

if On_Save_TX_Log == 1
% 1. 저장할 파일 이름 생성
filename = sprintf('TX_LOG_Nal_%d_Nbk_%d_Nraw_%d_SDC_%d.mat', ...
    N_alarmSTA, N_bkSTA, N_RAW, C);
elseif On_Save_TX_Log == 2
    filename = sprintf('TX_LOG_TEST.mat');
end
% 2. 파일로 저장
% 'Unnamed_Tab' 변수만 저장하고 싶다면 아래와 같이 작성합니다.
save(filename, 'Unnamed_Tab');
toc;