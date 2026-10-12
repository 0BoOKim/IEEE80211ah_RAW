

Temp_Delay = Delay(3).delay(:,2:3)*T_slot;
figure;
plot(Temp_Delay(:,1), Temp_Delay(:,2));
xlabel('time (sec)');ylabel('access delay (sec)');
grid on