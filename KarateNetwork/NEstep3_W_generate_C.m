% 假设矩阵W已存在
% 这里假设W是一个方阵
% 如果不是方阵，主对角线的定义可能不明确，需要调整
clc;
clear;
close all;


W = readmatrix('Weighted.csv');
% 检查W的大小
[m, n] = size(W);

% 确保W是方阵
if m ~= n
    error('矩阵W必须是方阵才能定义主对角线');
end

% 初始化矩阵C，大小与W相同
C = zeros(m, n);
Cai = {};

for rng1 = 123:1:130
    rng(rng1);
    % 遍历W的所有元素
    for i = 1:m
        for j = 1:n
            % 跳过主对角线
            if i == j
                C(i, j) = 0;  % 主对角线元素为0
            elseif W(i, j) ~= 0
                % 非对角线且W(i,j)不为0的位置
                C(i, j) = randi([1, 5]);  % 生成1-5的随机整数
            end
            % 其他情况C(i,j)保持为0
        end
    end

    % 显示结果
    disp('原始矩阵W:');
    disp(W);
    disp('生成的矩阵C:');
    disp(C);
    Cai{rng1-122} = C;
end