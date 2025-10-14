close all;
clear all;

var_alpha = 2.029;
var_beta = 2.4513;

N = 1000; % total number of STAs

T = 10; % (sec)
t = 0:0.0001:T;

p_t = (t.^(var_alpha-1).*(T-t).^(var_beta-1)) ./ (T^(var_alpha+var_beta-1)*beta(var_alpha,var_beta));
CumSum_p_t = cumsum(p_t)/length(p_t)*T;

var_alpha = 1.9588;
var_beta = 1.484;

%T = 10; % (sec)

%t = 0:0.0001:T;

p_t2 = (t.^(var_alpha-1).*(T-t).^(var_beta-1)) ./ (T^(var_alpha+var_beta-1)*beta(var_alpha,var_beta));
CumSum_p_t2 = cumsum(p_t2)/length(p_t2)*T;

var_alpha = 1.7013;
var_beta = 8.1347;

%T = 10; % (sec)

%t = 0:0.0001:T;

p_t3 = (t.^(var_alpha-1).*(T-t).^(var_beta-1)) ./ (T^(var_alpha+var_beta-1)*beta(var_alpha,var_beta));
CumSum_p_t3 = cumsum(p_t3)/length(p_t3)*T;

figure;
hold on;
plot(t, p_t);
plot(t, p_t2);
plot(t, p_t3);
xlabel('time(sec)');
ylabel('probability');
legend('\alpha=2.029 , \beta=2.4513', '\alpha=1.9588, \beta=1.484', '\alpha=1.7013, \beta=8.1347','Location', 'Best');
grid on;
hold off;

figure;
hold on;
plot(t, N*p_t);
plot(t, N*p_t2);
plot(t, N*p_t3);
xlabel('time(sec)');
ylabel('The expected number of triggered STAs');
legend('\alpha=2.029 , \beta=2.4513', '\alpha=1.9588, \beta=1.484', '\alpha=1.7013, \beta=8.1347','Location', 'Best');
grid on;
hold off;

figure;
hold on;
plot(t, N*CumSum_p_t);
plot(t, N*CumSum_p_t2);
plot(t, N*CumSum_p_t3);
xlabel('time(sec)');
ylabel('The expected cummulative number of triggered STAs');
legend('\alpha=2.029 , \beta=2.4513', '\alpha=1.9588, \beta=1.484', '\alpha=1.7013, \beta=8.1347','Location', 'Best');
grid on;
hold off;

C1 = N*CumSum_p_t;
C2 = N*CumSum_p_t2;
C3 = N*CumSum_p_t3;

for i = 1:length(C1)
    if i == length(C1)
        P1(i) = C1(i);
        P2(i) = C2(i);
        P3(i) = C3(i);
    else
        P1(i) = C1(i+1)-C1(i);
        P2(i) = C2(i+1)-C2(i);
        P3(i) = C3(i+1)-C3(i);
    end
    
    
end

figure;
hold on;
plot(t, P1);
plot(t, P2);
plot(t, P3);
xlabel('time(sec)');
ylabel('The expected number of triggered STAs');
legend('\alpha=2.029 , \beta=2.4513', '\alpha=1.9588, \beta=1.484', '\alpha=1.7013, \beta=8.1347','Location', 'Best');
grid on;
hold off;