close all;
clear all;

R = load('Temporal_Evolution_231224.out');

R(:,1) = R(:,1)*52*10^-6;

figure;
hold on;
plot(R(:,1), R(:,2), '--');
plot(R(:,1), R(:,6), '--');
plot(R(:,1), R(:,10), '--');


plot(R(:,1), R(:,4));
plot(R(:,1), R(:,8));
plot(R(:,1), R(:,12));

xlabel('time(sec)')
ylabel('number of STAs that have buffered frames');
grid on;
legend('Legacy(N_{STA}= 100)', 'Legacy(N_{STA}= 500)', 'Legacy(N_{STA}= 1000)', ...
       'Proposed(N_{STA}= 100)','Proposed(N_{STA}= 500)','Proposed(N_{STA}= 1000)', ...
       'Location', 'Best');
hold off;


figure;
hold on;
plot(R(:,1), R(:,3), '--');
plot(R(:,1), R(:,7), '--');
plot(R(:,1), R(:,11), '--');


plot(R(:,1), R(:,5));
plot(R(:,1), R(:,9));
plot(R(:,1), R(:,13));


xlabel('time(sec)')
ylabel('collision rate');
legend('Legacy(N_{STA}= 100)', 'Legacy(N_{STA}= 500)', 'Legacy(N_{STA}= 1000)', ...
       'Proposed(N_{STA}= 100)','Proposed(N_{STA}= 500)','Proposed(N_{STA}= 1000)', ...
       'Location', 'Best');
grid on;
hold off;
