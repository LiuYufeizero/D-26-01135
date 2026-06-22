clc;
clear;
close all;

% 定义权重矩阵（34×34）
W = readmatrix('Weighted.csv');

% 创建有向图
G = digraph(W);

% 准备节点标签
labels = cell(1, 34);
for i = 1:34
    labels{i} = num2str(i-1);
end

% 绘制图形
figure;
h = plot(G, 'NodeLabel', labels, 'Layout', 'force');

% 设置边的宽度
edge_weights = G.Edges.Weight;
h.LineWidth = edge_weights * 5 + 0.5;  % 权重越大，边越宽

% 设置标题
title('有向赋权图 (34个节点)');