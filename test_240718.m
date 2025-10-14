
X = Net_Congestion_Measure(1).CH_Util;

cnt = 1;
criterion = 1000;
sumX = 0;
R = [0 0];

for k=1:length(X)
    
    sumX = sumX + X(k,2); 
    
    cnt = cnt + 1;
    if cnt == 1000
        R = [R; X(k,1) sumX/1000];
        cnt = 0;
        sumX = 0;
    end
    
end

figure;
plot(R(:,1), R(:,2));