function [CPD, is_fast] = Update_CPD_State(Node_ID, CPD, s_rate)
%UPDATE_CPD_STATE Update two-sided CUSUM state for CPD based on success ratio.
%
%   [CPD, IS_FAST] = UPDATE_CPD_STATE(NODE_ID, CPD, S_RATE) updates the
%   positive/negative CUSUM accumulators for the specified node using the
%   observed success ratio S_RATE. When a change is detected, the FAST/SLOW
%   flag for the node is toggled accordingly. The function returns the
%   updated CPD structure and the latest FAST-state flag (logical).
%
%   The implementation is intentionally lightweight so that CPD can be
%   evaluated independently from other adaptation features.

    if nargin < 3
        error('Update_CPD_State requires Node_ID, CPD, and s_rate inputs.');
    end

    if ~isfield(CPD, 'kappa') || ~isfield(CPD, 'h')
        error('CPD structure is missing required parameters (kappa/h).');
    end

    % Preserve previous FAST/SLOW state as default output.
    is_fast = CPD.is_fast(Node_ID);

    % If the observation is not valid, keep the previous state without
    % modifying the accumulators.
    if isnan(s_rate) || ~isfinite(s_rate)
        return;
    end

    prev_rate = CPD.prev_s_rate(Node_ID);

    if isnan(prev_rate)
        % Initialize baseline with the first valid observation.
        CPD.prev_s_rate(Node_ID) = s_rate;
        CPD.g_pos(Node_ID) = 0;
        CPD.g_neg(Node_ID) = 0;
        CPD.is_fast(Node_ID) = false;
        is_fast = false;
        return;
    end

    % Two-sided CUSUM update on the success-ratio delta.
    delta = s_rate - prev_rate;
    CPD.prev_s_rate(Node_ID) = s_rate;

    CPD.g_pos(Node_ID) = max(0, CPD.g_pos(Node_ID) + delta - CPD.kappa);
    CPD.g_neg(Node_ID) = min(0, CPD.g_neg(Node_ID) + delta + CPD.kappa);

    if CPD.g_pos(Node_ID) > CPD.h || abs(CPD.g_neg(Node_ID)) > CPD.h
        % Change detected: switch to FAST mode and reset accumulators.
        CPD.is_fast(Node_ID) = true;
        CPD.g_pos(Node_ID) = 0;
        CPD.g_neg(Node_ID) = 0;
    else
        % No change detected: remain (or return) to SLOW mode.
        CPD.is_fast(Node_ID) = false;
    end

    is_fast = CPD.is_fast(Node_ID);
end
