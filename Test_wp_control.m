clear all;
close all;

N_Sim = 100;
Period = 10;

Log_P = 0.6;
Measure_P = 0;

w = 1.0;
max_w = 2.0;
min_w = 0.1;

dec_w = 0.1;
inc_w = 0.1;

Col_P = 0.5;

R_w = zeros(N_Sim, 1);
R_col = zeros(N_Sim, 1);

for n=1:N_Sim
    n_acc = 0;
    n_suc = 0;
    
    for p = 1:Period
        if rand <= Log_P
           n_acc = n_acc + 1;
           
           if rand < Col_P
                
           else
              n_suc = n_suc + 1; 
           end
           
        end
        
    end
    
    Measure_P = n_suc/n_acc;
    
    if Measure_P < w*Log_P
       w = w - dec_w;
       Col_P = Col_P - 0.05;
       
    else
       w = w + inc_w;
       Col_P = Col_P + 0.05;  
    end
    
    
    if w > max_w
       w = max_w;
    elseif w < min_w
       w = min_w;
    end
    
    if Col_P > 1.0
       Col_P = 1.0;
    elseif Col_P < 0.0
       Col_P = 0.0;
    end
    
    
    R_w(n) = w;
    R_col(n) = Col_P;
    R_wp(n) = w*Log_P;
    R_mp(n) = Measure_P;
end

figure;
hold on;
plot(1:N_Sim, R_w);
plot(1:N_Sim, R_col);

plot(1:N_Sim, R_wp);
plot(1:N_Sim, R_mp);

plot(1:N_Sim, Log_P*ones(N_Sim,1));

xlabel('n-th trial');
ylabel('w');
legend('w', 'col','wp', 'mp');
grid on;

