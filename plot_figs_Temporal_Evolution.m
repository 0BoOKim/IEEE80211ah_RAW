close all;

R = Traffic_Temporal_Evolution;
figure;
plot(R(:,1), R(:,2));
xlabel('time slot');
ylabel('total number of frames');


figure;
plot(R(:,1), R(:,3));
xlabel('time slot');
ylabel('avg. number of frames');


figure;
plot(R(:,1), R(:,4));
xlabel('time slot');
ylabel('total buffered bytes');


figure;
plot(R(:,1), R(:,5));
xlabel('time slot');
ylabel('avg. buffered bytes');


figure;
plot(R(:,1), R(:,6));
xlabel('time slot');
ylabel('number of STAs who has bufferd frames');

R2 = R(2:length(R),2:6) - R(1:length(R)-1,2:6);
T = R(2:length(R),1);

figure;
plot(T(:,1), R2(:,1));
xlabel('time slot');
ylabel('total number of frames');


figure;
plot(T(:,1), R2(:,2));
xlabel('time slot');
ylabel('avg. number of frames');


figure;
plot(T(:,1), R2(:,3));
xlabel('time slot');
ylabel('total buffered bytes');


figure;
plot(T(:,1), R2(:,4));
xlabel('time slot');
ylabel('avg. buffered bytes');


figure;
plot(T(:,1), R2(:,5));
xlabel('time slot');
ylabel('number of STAs who has bufferd frames');
