close all;
clear all;

R = load('results_240103.out');

X = [100 500 1000 1500 2000];

figure;
hold on;
plot(X, R(1:5,1),'--o');
plot(X, R(6:10,1),'--x');
plot(X, R(11:15,1),'--s');
plot(X, R(16:20,1),'-d');
legend('normal RAW(N_{RAW}=4)', 'normal RAW(N_{RAW}=8)','normal RAW(N_{RAW}=32)', 'proposed scheme', 'Location', 'Best');
xlabel('number of uplink STAs');
ylabel('total throughput(Mb/s)');
grid on;
hold off;

figure;
hold on;
plot(X, R(1:5,3),'--o');
plot(X, R(6:10,3),'--x');
plot(X, R(11:15,3),'--s');
plot(X, R(16:20,3),'-d');
legend('normal RAW(N_{RAW}=4)', 'normal RAW(N_{RAW}=8)','normal RAW(N_{RAW}=32)', 'proposed scheme', 'Location', 'Best');
xlabel('number of uplink STAs');
ylabel('utilization');
grid on;
hold off;

figure;
hold on;
plot(X, R(1:5,5),'--o');
plot(X, R(6:10,5),'--x');
plot(X, R(11:15,5),'--s');
plot(X, R(16:20,5),'-d');
legend('normal RAW(N_{RAW}=4)', 'normal RAW(N_{RAW}=8)','normal RAW(N_{RAW}=32)', 'proposed scheme', 'Location', 'Best');
xlabel('number of uplink STAs');
ylabel('collision ratio');
grid on;
hold off;

figure;
hold on;
plot(X, R(1:5,5),'--o');
plot(X, R(6:10,5),'--x');
plot(X, R(11:15,5),'--s');
plot(X, R(16:20,5),'-d');
legend('normal RAW(N_{RAW}=4)', 'normal RAW(N_{RAW}=8)','normal RAW(N_{RAW}=32)', 'proposed scheme', 'Location', 'Best');
xlabel('number of uplink STAs');
ylabel('average number of channel accesses per each STAs');
grid on;
hold off;

figure;
hold on;
plot(X, R(1:5,7),'--o');
plot(X, R(6:10,7),'--x');
plot(X, R(11:15,7),'--s');
plot(X, R(16:20,7),'-d');
legend('normal RAW(N_{RAW}=4)', 'normal RAW(N_{RAW}=8)','normal RAW(N_{RAW}=32)', 'proposed scheme', 'Location', 'Best');
xlabel('number of uplink STAs');
ylabel('average access delay(sec)');
grid on;
hold off;

figure;
hold on;
plot(X, R(1:5,8),'--o');
plot(X, R(6:10,8),'--x');
plot(X, R(11:15,8),'--s');
plot(X, R(16:20,8),'-d');
legend('normal RAW(N_{RAW}=4)', 'normal RAW(N_{RAW}=8)','normal RAW(N_{RAW}=32)', 'proposed scheme', 'Location', 'Best');
xlabel('number of uplink STAs');
ylabel('average minimum of access delay(sec)');
grid on;
hold off;

figure;
hold on;
plot(X, R(1:5,9),'--o');
plot(X, R(6:10,9),'--x');
plot(X, R(11:15,9),'--s');
plot(X, R(16:20,9),'-d');
legend('normal RAW(N_{RAW}=4)', 'normal RAW(N_{RAW}=8)','normal RAW(N_{RAW}=32)', 'proposed scheme', 'Location', 'Best');
xlabel('number of uplink STAs');
ylabel('average maximum of access delay(sec)');
grid on;
hold off;