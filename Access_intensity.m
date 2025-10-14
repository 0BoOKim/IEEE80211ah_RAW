function [intensity] = Access_intensity(ti, tj, N, T, var_alpha, var_beta)
% Define the p(t) function as given in the provided image.
    p = @(t) (t.^(var_alpha-1) .* (T-t).^(var_beta-1)) ./ (T^(var_alpha+var_beta-1) * beta(var_alpha, var_beta));
    
    % Calculate the integral of p(t) from ti to tj.
    integral_value = integral(p, ti, tj);
    
    % Calculate Access_intensity
    intensity = integral_value / N;

% Usage example:
% Assuming the values for N, T, alpha, beta, ti, and tj are known.
%   N = ...; % Total number of nodes
%   T = ...; % Maximum time value
%   alpha = ...; % Alpha parameter for p(t)
%   beta = ...; % Beta parameter for p(t)
%   ti = ...; % Start time for node i
%   tj = ...; % End time for node i
%   result = Access_intensity(ti, tj, N, T, alpha, beta);
end

