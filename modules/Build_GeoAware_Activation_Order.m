function [Alarm_Activation_Order] = Build_GeoAware_Activation_Order(Node_Pos, Alarm_Node_Idx, SimParams, GeoCfg)
    % Build activation order by anisotropic distance from disaster seeds.
    % This preserves A(t) from BetaCDF, while changing spatial activation order.

    if nargin < 4
        GeoCfg = [];
    end

    Alarm_Pos = Node_Pos(Alarm_Node_Idx, :);

    if ~isempty(GeoCfg) && isfield(GeoCfg, 'Seed_Coords') && ~isempty(GeoCfg.Seed_Coords)
        Seed_Pos = GeoCfg.Seed_Coords;
    elseif isfield(SimParams, 'Geo_Seed_Coords') && ~isempty(SimParams.Geo_Seed_Coords)
        Seed_Pos = SimParams.Geo_Seed_Coords;
    else
        Seed_Pos = Node_Pos(SimParams.idx_AP(1), :);
    end

    if size(Seed_Pos, 2) ~= 2
        error('Geo_Seed_Coords must be Kx2 coordinates.');
    end

    if ~isempty(GeoCfg) && isfield(GeoCfg, 'Dominant_Direction')
        dir_u = GeoCfg.Dominant_Direction;
    else
        dir_u = SimParams.Geo_Dominant_Direction;
    end

    if ~isfield(SimParams, 'Geo_Dominant_Direction') && isempty(GeoCfg)
        error('Geo_Dominant_Direction must be provided.');
    end
    if numel(dir_u) ~= 2
        error('Geo_Dominant_Direction must be a 2D vector.');
    end

    u = dir_u(:).';
    norm_u = norm(u);
    if norm_u == 0
        error('Geo_Dominant_Direction must be non-zero.');
    end
    u = u / norm_u;

    if ~isempty(GeoCfg) && isfield(GeoCfg, 'Anisotropy_A') && isfield(GeoCfg, 'Anisotropy_B')
        a = max(GeoCfg.Anisotropy_A, eps);
        b = max(GeoCfg.Anisotropy_B, eps);
    else
        a = max(SimParams.Geo_Anisotropy_A, eps);
        b = max(SimParams.Geo_Anisotropy_B, eps);
    end
    if a < b
        tmp = a;
        a = b;
        b = tmp;
    end

    N_alarm = size(Alarm_Pos, 1);
    d_prime = inf(N_alarm, 1);

    for i = 1:N_alarm
        for k = 1:size(Seed_Pos, 1)
            v = Alarm_Pos(i,:) - Seed_Pos(k,:);
            v_par = dot(v, u) * u;
            v_perp = v - v_par;

            cand_dist = sqrt(sum(v_par.^2)/(a^2) + sum(v_perp.^2)/(b^2));
            if cand_dist < d_prime(i)
                d_prime(i) = cand_dist;
            end
        end
    end

    jitter = zeros(N_alarm, 1);
    if ~isempty(GeoCfg) && isfield(GeoCfg, 'Jitter_Sigma')
        jitter_sigma = GeoCfg.Jitter_Sigma;
    else
        jitter_sigma = SimParams.Geo_Jitter_Sigma;
    end

    if jitter_sigma > 0
        if isfield(SimParams, 'Geo_Order_Seed')
            local_seed = SimParams.Geo_Order_Seed;
        else
            local_seed = SimParams.PNRG_Seed1 + 991;
        end
        local_stream = RandStream('mt19937ar', 'Seed', local_seed);
        jitter = jitter_sigma * randn(local_stream, N_alarm, 1);
    end

    d = d_prime + jitter;
    [~, order] = sort(d, 'ascend');
    Alarm_Activation_Order = Alarm_Node_Idx(order);
end
