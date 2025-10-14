clear all;
close all;

% 저전력(Prototype 구성): 0 dBm, 최대 권장전송 전력(Ideal 구성): 14 dBm
Ptx_AP = 0; % (dBm)
Ptx_STA = 0; % (dBm)

Gtx = 0;   % TX antenna gain (dBi)
Grx = 0;   % RX antenna gain (Prototype: 0 dBi, ideal: 3 dBi)
Ltx = 0;   % system loss at TX (dBi)
Lrx = 0;   % system loss at RX (dBi) 

Dist = 0.1:0.01:500; % meter

% Pathloss Model I)  Macro deployment (AP -> STA)
PL_mcr = 8 + 36.7*log10(Dist);
Prx_mcr = Ptx_AP + Gtx - Ltx - PL_mcr + Grx - Lrx;

% Pathloss Model II)  Pico deployment (STA -> AP)
PL_pc = 23.3 + 36.7*log10(Dist);
Prx_pc = Ptx_STA + Gtx - Ltx - PL_pc + Grx - Lrx;

% Pathloss Model III)  Outdoor Device to Device Pathloss model (STA <-> STA)

PL_od =  -6.17 + 58.6*log10(Dist);  
Prx_od = Ptx_STA + Gtx - Ltx - PL_od + Grx - Lrx;


figure;
hold on;

plot(Dist, Prx_mcr);
plot(Dist, Prx_pc);
plot(Dist, Prx_od);
legend('Macro (AP to STA)', 'Pico (STA to AP)',  'D2D (STA to STA)', 'Location', 'Best');
xlabel('distance (m)');
ylabel('Received Signal Strength (dBm)');
grid on;
hold off;

figure;
hold on;

plot(Dist, PL_mcr);
plot(Dist, PL_pc);
plot(Dist, PL_od);
legend('Macro (AP to STA)', 'Pico (STA to AP)',  'D2D (STA to STA)', 'Location', 'Best');
xlabel('distance (m)');
ylabel('Pathloss (dBm)');
grid on;
hold off;