close all
clear all

N = 1000;

Max = 100;
Min = 100;

for i = 1:N
    R(i) = ceil( (Max-Min)*rand + Max);
end