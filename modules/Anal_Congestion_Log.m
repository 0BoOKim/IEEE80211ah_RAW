% Anal_Congestion_Log.m
% Build TX_LOG lookup table for RAW_Mode 3.
%
% Preferred input:
%   TX_LOG_Access_Log, collected per DATA access attempt.
%   Columns: node, bss, access_start_slot, ch_util, n_ack, mpdu_gid,
%            ack_timeout, acked_success, retry_loss, data_collision,
%            completed.
%
% Fallback input:
%   Net_Congestion_Measure interval counters from older simulations.

Bin_CH_Usage = 0.1000;
Bin_N_ACK = 5;
tx_log_build_start = clock;

if exist('TX_LOG_Access_Log', 'var') && ~isempty(TX_LOG_Access_Log)
    Unnamed_Tab = Build_TX_LOG_From_Access_Events( ...
        TX_LOG_Access_Log, Bin_CH_Usage, Bin_N_ACK);
else
    if exist('idx_STA', 'var') && ~isempty(idx_STA)
        tx_log_sta_idx = idx_STA;
    elseif exist('N_AP', 'var') && ~isempty(N_AP)
        tx_log_sta_idx = (N_AP+1):length(Net_Congestion_Measure);
    elseif exist('N_Node', 'var') && exist('N_STA', 'var') && ...
            ~isempty(N_Node) && ~isempty(N_STA)
        tx_log_sta_idx = (N_Node-N_STA+1):N_Node;
    else
        tx_log_sta_idx = 2:length(Net_Congestion_Measure); % legacy single-AP fallback
    end

    Unnamed_Tab = Build_TX_LOG_From_Interval_Counters( ...
        Net_Congestion_Measure, Bin_CH_Usage, Bin_N_ACK, tx_log_sta_idx);
end

Unnamed_Tab = sortrows(Unnamed_Tab, [1 2]);

if On_Save_TX_Log == 1
    filename = sprintf('TX_LOG_Nal_%d_Nbk_%d_Nraw_%d_SDC_%d.mat', ...
        N_alarmSTA, N_bkSTA, N_RAW, C);
elseif On_Save_TX_Log == 2
    filename = sprintf('TX_LOG_TEST.mat');
else
    error('Unsupported On_Save_TX_Log value: %d', On_Save_TX_Log);
end

save(filename, 'Unnamed_Tab');
fprintf('TX_LOG build elapsed time: %.6f seconds.\n', etime(clock, tx_log_build_start));

function Unnamed_Tab = Build_TX_LOG_From_Access_Events(AccessLog, Bin_CH_Usage, Bin_N_ACK)
    completed_col = 11;
    valid = AccessLog(:, completed_col) == 1;
    AccessLog = AccessLog(valid, :);

    if isempty(AccessLog)
        error('TX_LOG_Access_Log has no completed access attempts.');
    end

    ch_util = AccessLog(:, 4);
    n_ack = AccessLog(:, 5);
    ack_timeout = AccessLog(:, 7);
    acked_success = AccessLog(:, 8);

    binned_ch = ceil(ch_util / Bin_CH_Usage) * Bin_CH_Usage;
    binned_ack = ceil(n_ack / Bin_N_ACK) * Bin_N_ACK;

    Unnamed_Tab = zeros(0, 11);
    for i = 1:size(AccessLog, 1)
        Unnamed_Tab = Accumulate_TX_LOG_Row( ...
            Unnamed_Tab, binned_ch(i), binned_ack(i), ...
            1, ack_timeout(i), acked_success(i));
    end

    Unnamed_Tab = Finalize_TX_LOG_Table(Unnamed_Tab);
end

function Unnamed_Tab = Build_TX_LOG_From_Interval_Counters(Net_Congestion_Measure, Bin_CH_Usage, Bin_N_ACK, sta_log_idx)
    if nargin < 4 || isempty(sta_log_idx)
        sta_log_idx = 2:length(Net_Congestion_Measure); % legacy single-AP fallback
    end

    sta_log_idx = sta_log_idx(:).';
    sta_log_idx = sta_log_idx(sta_log_idx >= 1 & sta_log_idx <= length(Net_Congestion_Measure));
    if isempty(sta_log_idx)
        error('No valid STA indices are available for TX_LOG generation.');
    end

    n_rows = 0;
    for node_idx = sta_log_idx
        n_rows = n_rows + size(Net_Congestion_Measure(node_idx).CH_Util, 1);
    end

    if n_rows == 0
        error('No interval-counter samples are available for STA TX_LOG generation.');
    end

    R = zeros(n_rows, 6);
    row_idx = 0;

    for node_idx = sta_log_idx
        for i = 1:size(Net_Congestion_Measure(node_idx).CH_Util, 1)
            row_idx = row_idx + 1;
            R(row_idx, :) = [ ...
                Net_Congestion_Measure(node_idx).CH_Util(i,1), ...
                Net_Congestion_Measure(node_idx).CH_Util(i,2), ...
                Net_Congestion_Measure(node_idx).N_ACK(i,2), ...
                Net_Congestion_Measure(node_idx).N_Acc(i,2), ...
                Net_Congestion_Measure(node_idx).N_Fail(i,2), ...
                Net_Congestion_Measure(node_idx).N_Suc(i,2)];
        end
    end

    R(R(:,4) == 0, :) = [];
    if isempty(R)
        error('No STA access attempts are available for TX_LOG generation.');
    end

    Unnamed_Tab = zeros(0, 11);
    for i = 1:size(R, 1)
        temp_bin_ch_usage = ceil(R(i,2) / Bin_CH_Usage) * Bin_CH_Usage;
        temp_bin_n_ack = ceil(R(i,3) / Bin_N_ACK) * Bin_N_ACK;

        Unnamed_Tab = Accumulate_TX_LOG_Row( ...
            Unnamed_Tab, temp_bin_ch_usage, temp_bin_n_ack, ...
            R(i,4), R(i,5), R(i,6));
    end

    Unnamed_Tab = Finalize_TX_LOG_Table(Unnamed_Tab);
end

function Tab = Accumulate_TX_LOG_Row(Tab, bin_ch_usage, bin_n_ack, n_acc, n_fail, n_suc)
    idx = find(Tab(:,1) == bin_ch_usage & Tab(:,2) == bin_n_ack);

    if length(idx) > 1
        error('unexpected indexing!');
    end

    if isempty(idx)
        Tab = [Tab; bin_ch_usage, bin_n_ack, 1, n_acc, n_fail, n_suc, zeros(1, 5)];
    else
        Tab(idx, 3) = Tab(idx, 3) + 1;
        Tab(idx, 4) = Tab(idx, 4) + n_acc;
        Tab(idx, 5) = Tab(idx, 5) + n_fail;
        Tab(idx, 6) = Tab(idx, 6) + n_suc;
    end
end

function Tab = Finalize_TX_LOG_Table(Tab)
    if isempty(Tab)
        error('No data available to build TX_LOG.');
    end

    for i = 1:size(Tab, 1)
        Tab(i, 7:9) = Tab(i, 4:6) / Tab(i, 3);
        Tab(i, 10:11) = Tab(i, 5:6) / Tab(i, 4);
    end
end
