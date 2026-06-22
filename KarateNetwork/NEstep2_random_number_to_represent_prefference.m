clc;
clear;

for i = 100:1:133
    rng(i);
    unique_random = randperm(8, 8);
    disp(unique_random);
end