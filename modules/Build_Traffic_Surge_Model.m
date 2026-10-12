function [CumSum_p_t] = Build_Traffic_Surge_Model(var_alpha, var_beta, Period, N_STA, start_time)

T = Period; % (sec)
t = 0:1:T;

p_t = (t.^(var_alpha-1).*(T-t).^(var_beta-1)) ./ (T^(var_alpha+var_beta-1)*beta(var_alpha,var_beta));
CumSum_p_t = [t; N_STA*cumsum(p_t)/length(p_t)*T];

figure;
hold on;
plot(t+start_time, CumSum_p_t(2,:));
xlabel('time(slots)');
ylabel('The expected cummulative number of triggered STAs');
%legend('\alpha=2.029 , \beta=2.4513', '\alpha=1.9588, \beta=1.484', '\alpha=1.7013, \beta=8.1347','Location', 'Best');
grid on;
%hold off;
end

