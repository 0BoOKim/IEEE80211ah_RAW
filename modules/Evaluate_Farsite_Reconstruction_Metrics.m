function Metric = Evaluate_Farsite_Reconstruction_Metrics(Model, sensor_pos, observed_active, t_eval_min, cfg)
%EVALUATE_FARSITE_RECONSTRUCTION_METRICS Compare reconstructed fire state to FARSITE.

    valid = isfinite(Model.Arrival_Time_Min);
    true_burned = valid & Model.Arrival_Time_Min <= t_eval_min;
    reconstructed_burned = false(size(true_burned));
    reconstructed_front = zeros(0, 2);

    Metric = struct();
    Metric.Eval_Time_Min = t_eval_min;
    Metric.N_Observed_Active = sum(observed_active);
    Metric.Reconstruction_Available = false;
    Metric.Burned_Area_IoU = NaN;
    Metric.False_Burned_Ratio = NaN;
    Metric.Missed_Burned_Ratio = NaN;
    Metric.Mean_Front_Distance_m = NaN;
    Metric.Hausdorff_Front_Distance_m = NaN;

    if sum(observed_active) < cfg.Min_Sensors
        return;
    end

    active_pos_all = sensor_pos(observed_active, :);
    if size(unique(active_pos_all, 'rows'), 1) < cfg.Min_Sensors
        return;
    end

    try
        switch lower(cfg.Method)
            case 'active-boundary'
                active_pos = unique(active_pos_all, 'rows');
                boundary_idx = boundary(active_pos(:,1), active_pos(:,2), cfg.Boundary_Shrink);
                bx = active_pos(boundary_idx, 1);
                by = active_pos(boundary_idx, 2);
                reconstructed_front = [bx(:), by(:)];
                reconstructed_burned = inpolygon(Model.Arrival_X, Model.Arrival_Y, bx, by) & valid;

            case 'arrival-interp'
                active_t = cfg.Observed_On_Min(observed_active);
                keep = isfinite(active_t);
                active_pos = active_pos_all(keep, :);
                active_t = active_t(keep);
                if size(active_pos, 1) < cfg.Min_Sensors
                    return;
                end
                F = scatteredInterpolant(active_pos(:,1), active_pos(:,2), active_t(:), ...
                    'natural', 'nearest');
                T_hat = F(Model.Arrival_X, Model.Arrival_Y);
                reconstructed_burned = isfinite(T_hat) & T_hat <= t_eval_min & valid;
                reconstructed_front = Extract_Contour_Points(Model.Arrival_X, Model.Arrival_Y, T_hat, t_eval_min);

            otherwise
                error('Unsupported reconstruction method: %s', cfg.Method);
        end
    catch
        return;
    end

    union_area = true_burned | reconstructed_burned;
    if any(union_area(:))
        Metric.Burned_Area_IoU = sum(true_burned(:) & reconstructed_burned(:)) / sum(union_area(:));
        Metric.False_Burned_Ratio = sum(~true_burned(:) & reconstructed_burned(:)) / sum(union_area(:));
        Metric.Missed_Burned_Ratio = sum(true_burned(:) & ~reconstructed_burned(:)) / sum(union_area(:));
    end

    true_front = Extract_Contour_Points(Model.Arrival_X, Model.Arrival_Y, ...
        Model.Arrival_Time_Min, t_eval_min);
    if ~isempty(true_front) && ~isempty(reconstructed_front)
        d_recon_to_true = Nearest_Distances(reconstructed_front, true_front);
        d_true_to_recon = Nearest_Distances(true_front, reconstructed_front);
        Metric.Mean_Front_Distance_m = mean(d_recon_to_true, 'omitnan');
        Metric.Hausdorff_Front_Distance_m = max([d_recon_to_true(:); d_true_to_recon(:)]);
    end

    Metric.Reconstruction_Available = true;
end

function pts = Extract_Contour_Points(X, Y, Z, level)
    pts = zeros(0, 2);
    if isempty(Z) || all(~isfinite(Z(:)))
        return;
    end

    try
        C = contourc(X(1,:), Y(:,1), Z, [level level]);
    catch
        return;
    end

    col = 1;
    while col < size(C, 2)
        n_pts = C(2, col);
        if n_pts <= 0 || col + n_pts > size(C, 2)
            break;
        end
        seg = C(:, col+1:col+n_pts).';
        pts = [pts; seg]; %#ok<AGROW>
        col = col + n_pts + 1;
    end
end

function d = Nearest_Distances(A, B)
    d = NaN(size(A, 1), 1);
    if isempty(A) || isempty(B)
        return;
    end

    chunk = 1000;
    for s = 1:chunk:size(A, 1)
        e = min(size(A, 1), s + chunk - 1);
        dx = A(s:e,1) - B(:,1).';
        dy = A(s:e,2) - B(:,2).';
        d(s:e) = sqrt(min(dx.^2 + dy.^2, [], 2));
    end
end
