close all;
clear all;

R = load('R_250207.out');


X = 20:20:100;

figure;
set(gcf,'position', [681   559   991   420]);
hold on;

plot(X, R(1:5,3),'--o', 'color', [0.00,0.45,0.74]);
plot(X, R(6:10,3),'--x', 'color', [0.85,0.33,0.10]);
plot(X, R(11:15,3),'--d', 'color', [0.93,0.69,0.13]);
plot(X, R(16:20,3),'--s', 'color', [0.49,0.18,0.56]);

plot(X, R(21:25,3),'-o','color', [0.00,0.45,0.74]);
plot(X, R(26:30,3),'-x', 'color', [0.85,0.33,0.10]);
plot(X, R(31:35,3),'-d', 'color', [0.93,0.69,0.13]);
plot(X, R(36:40,3),'-s', 'color', [0.49,0.18,0.56]);

legend('Legacy(N_{raw} = 1)', 'Legacy(N_{raw} = 2)', 'Legacy(N_{raw} = 4)', 'Legacy(N_{raw} = 8)', ...
    'Proposed(N_{raw} = 1)', 'Proposed(N_{raw} = 2)', 'Proposed(N_{raw} = 4)', 'Proposed(N_{raw} = 8)',...
    'Location', 'BestOutSide');

xlabel('number of Alarm STAs');
ylabel('number of access');
grid on;
hold off;

figure;
set(gcf,'position', [681   559   991   420]);
hold on;

plot(X, R(1:5,2),'--o', 'color', [0.00,0.45,0.74]);
plot(X, R(6:10,2),'--x', 'color', [0.85,0.33,0.10]);
plot(X, R(11:15,2),'--d', 'color', [0.93,0.69,0.13]);
plot(X, R(16:20,2),'--s', 'color', [0.49,0.18,0.56]);

plot(X, R(21:25,2),'-o','color', [0.00,0.45,0.74]);
plot(X, R(26:30,2),'-x', 'color', [0.85,0.33,0.10]);
plot(X, R(31:35,2),'-d', 'color', [0.93,0.69,0.13]);
plot(X, R(36:40,2),'-s', 'color', [0.49,0.18,0.56]);

legend('Legacy(N_{raw} = 1)', 'Legacy(N_{raw} = 2)', 'Legacy(N_{raw} = 4)', 'Legacy(N_{raw} = 8)', ...
    'Proposed(N_{raw} = 1)', 'Proposed(N_{raw} = 2)', 'Proposed(N_{raw} = 4)', 'Proposed(N_{raw} = 8)',...
    'Location', 'BestOutSide');

xlabel('number of Alarm STAs');
ylabel('norm. throughput');
grid on;
hold off;


figure;
set(gcf,'position', [681   559   991   420]);
hold on;

plot(X, R(1:5,4),'--o','color', [0.00,0.45,0.74]);
plot(X, R(6:10,4),'--x', 'color', [0.85,0.33,0.10]);
plot(X, R(11:15,4),'--d', 'color', [0.93,0.69,0.13]);
plot(X, R(16:20,4),'--s', 'color', [0.49,0.18,0.56]);

plot(X, R(21:25,4),'-o','color', [0.00,0.45,0.74]);
plot(X, R(26:30,4),'-x',  'color', [0.85,0.33,0.10]);
plot(X, R(31:35,4),'-d',  'color', [0.93,0.69,0.13]);
plot(X, R(36:40,4),'-s',  'color', [0.49,0.18,0.56]);

legend('Legacy(N_{raw} = 1)', 'Legacy(N_{raw} = 2)', 'Legacy(N_{raw} = 4)', 'Legacy(N_{raw} = 8)', ...
    'Proposed(N_{raw} = 1)', 'Proposed(N_{raw} = 2)', 'Proposed(N_{raw} = 4)', 'Proposed(N_{raw} = 8)',...
    'Location', 'BestOutSide');

xlabel('number of Alarm STAs');
ylabel('success ratio');
grid on;
hold off;


figure;
set(gcf,'position', [681   559   991   420]);
hold on;

plot(X, R(1:5,6),'--o', 'color', [0.00,0.45,0.74]);
plot(X, R(6:10,6),'--x', 'color', [0.85,0.33,0.10]);
plot(X, R(11:15,6),'--d', 'color', [0.93,0.69,0.13]);
plot(X, R(16:20,6),'--s', 'color', [0.49,0.18,0.56]);

plot(X, R(21:25,6),'-o','color', [0.00,0.45,0.74]);
plot(X, R(26:30,6),'-x', 'color', [0.85,0.33,0.10]);
plot(X, R(31:35,6),'-d', 'color', [0.93,0.69,0.13]);
plot(X, R(36:40,6),'-s', 'color', [0.49,0.18,0.56]);

legend('Legacy(N_{raw} = 1)', 'Legacy(N_{raw} = 2)', 'Legacy(N_{raw} = 4)', 'Legacy(N_{raw} = 8)', ...
    'Proposed(N_{raw} = 1)', 'Proposed(N_{raw} = 2)', 'Proposed(N_{raw} = 4)', 'Proposed(N_{raw} = 8)',...
    'Location', 'BestOutSide');

xlabel('number of Alarm STAs');
ylabel('collision ratio');
grid on;
hold off;


figure;
set(gcf,'position', [681   559   991   420]);
hold on;

plot(X, R(1:5,9),'--o', 'color', [0.00,0.45,0.74]);
plot(X, R(6:10,9),'--x', 'color', [0.85,0.33,0.10]);
plot(X, R(11:15,9),'--d', 'color', [0.93,0.69,0.13]);
plot(X, R(16:20,9),'--s', 'color', [0.49,0.18,0.56]);

plot(X, R(21:25,9),'-o','color', [0.00,0.45,0.74]);
plot(X, R(26:30,9),'-x', 'color', [0.85,0.33,0.10]);
plot(X, R(31:35,9),'-d', 'color', [0.93,0.69,0.13]);
plot(X, R(36:40,9),'-s', 'color', [0.49,0.18,0.56]);

legend('Legacy(N_{raw} = 1)', 'Legacy(N_{raw} = 2)', 'Legacy(N_{raw} = 4)', 'Legacy(N_{raw} = 8)', ...
    'Proposed(N_{raw} = 1)', 'Proposed(N_{raw} = 2)', 'Proposed(N_{raw} = 4)', 'Proposed(N_{raw} = 8)',...
    'Location', 'BestOutSide');

xlabel('number of Alarm STAs');
ylabel('number of packet loss');
grid on;
hold off;

figure;
set(gcf,'position', [681   559   991   420]);
hold on;

plot(X, R(1:5,10),'--o', 'color', [0.00,0.45,0.74]);
plot(X, R(6:10,10),'--x', 'color', [0.85,0.33,0.10]);
plot(X, R(11:15,10),'--d', 'color', [0.93,0.69,0.13]);
plot(X, R(16:20,10),'--s', 'color', [0.49,0.18,0.56]);

plot(X, R(21:25,10),'-o','color', [0.00,0.45,0.74]);
plot(X, R(26:30,10),'-x', 'color', [0.85,0.33,0.10]);
plot(X, R(31:35,10),'-d', 'color', [0.93,0.69,0.13]);
plot(X, R(36:40,10),'-s', 'color', [0.49,0.18,0.56]);

legend('Legacy(N_{raw} = 1)', 'Legacy(N_{raw} = 2)', 'Legacy(N_{raw} = 4)', 'Legacy(N_{raw} = 8)', ...
    'Proposed(N_{raw} = 1)', 'Proposed(N_{raw} = 2)', 'Proposed(N_{raw} = 4)', 'Proposed(N_{raw} = 8)',...
    'Location', 'BestOutSide');

xlabel('number of Alarm STAs');
ylabel('delay (sec)');
grid on;
hold off;