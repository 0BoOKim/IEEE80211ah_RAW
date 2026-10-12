function Events = ED_Build_Beta_Activation_Events( ...
    alpha, beta_param, start_slot, period_slots, active_target)
%ED_BUILD_BETA_ACTIVATION_EVENTS Store one activation event per reference STA.
%
% Columns:
%   1: absolute activation slot
%   2: cumulative active reference-STA count
%   3: normalized physical fire time in [0, 1]

    validateattributes(alpha, {'numeric'}, {'scalar', 'real', 'positive'});
    validateattributes(beta_param, {'numeric'}, {'scalar', 'real', 'positive'});
    validateattributes(start_slot, {'numeric'}, {'scalar', 'integer', 'nonnegative'});
    validateattributes(period_slots, {'numeric'}, {'scalar', 'integer', 'positive'});
    validateattributes(active_target, {'numeric'}, {'scalar', 'integer', 'nonnegative'});

    if active_target == 0
        Events = zeros(0, 3);
        return;
    end

    cumulative_count = (1:active_target).';
    probability = cumulative_count / active_target;
    normalized_time = zeros(active_target, 1);

    interior = probability < 1;
    normalized_time(interior) = Inverse_Regularized_Beta( ...
        probability(interior), alpha, beta_param);
    normalized_time(~interior) = 1;

    activation_slot = start_slot + round(normalized_time * period_slots);
    activation_slot = min(start_slot + period_slots, ...
        max(start_slot + 1, activation_slot));
    activation_slot = cummax(activation_slot);

    Events = [activation_slot, cumulative_count, normalized_time];
end

function x = Inverse_Regularized_Beta(p, alpha, beta_param)
    if exist('betaincinv', 'builtin') == 5 || exist('betaincinv', 'file') == 2
        x = betaincinv(p, alpha, beta_param);
        return;
    end

    % Toolbox-independent monotone bisection fallback.
    lo = zeros(size(p));
    hi = ones(size(p));
    for iteration = 1:60
        mid = (lo + hi) / 2;
        below = betainc(mid, alpha, beta_param) < p;
        lo(below) = mid(below);
        hi(~below) = mid(~below);
    end
    x = (lo + hi) / 2;
end
