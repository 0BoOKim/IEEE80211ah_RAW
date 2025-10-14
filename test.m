close all;
%clear all;

rng(1731);

A = 0.01:0.00001:1000.0;
%A = Tab_Traffic_Model(2,:);
B = 1:length(A);

Intv = 10;
idx_intv = 1;
idx_last = 1;
A_ = [];
Cum_A = 0;
C = [];

Log = [];

for i=1:length(A)
    if rand < 0.99
        continue;
    end
    %R = floor(A(i) - A(idx_last));
    R = floor(A(i)) - floor(A(idx_last));
    Log = [Log; i idx_last A(i) A(idx_last) R];
    if R > 0
        idx_last = i;
        Cum_A = Cum_A + R;
        A_ = [A_; Cum_A];
        C = [C; B(i)];
    end
    
    
end

figure;
hold on;

plot(B, A, '-');
plot(C, A_, '.');

hold off;