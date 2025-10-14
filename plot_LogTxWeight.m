close all;

L = Log_TxWeight;
L(L==0) = NaN;

N_LogNode = length(Target_Node_Log_TxWeight);

PlotTarget = 3;
TargetCol = 3*PlotTarget-2;

figure;
hold on;
plot(L(:,TargetCol)*T_slot, L(:,TargetCol+1));
plot(L(:,TargetCol)*T_slot, L(:,TargetCol+2)); 
xlabel('time(sec)');
ylabel('value');
legend('Tx Weight', 'Tx Prob', 'Location', 'Best');
grid on;
hold off;

