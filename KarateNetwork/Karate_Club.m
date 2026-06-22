clc;
clear;

% 读取边列表数据
edges = [
0 1; 0 2; 0 3; 0 4; 0 5; 0 6; 0 7; 0 8; 0 10; 0 11; 0 12; 0 13; 0 17; 0 19; 0 21; 0 31;
1 2; 1 3; 1 7; 1 13; 1 17; 1 19; 1 21; 1 30;
2 3; 2 7; 2 8; 2 9; 2 13; 2 27; 2 28; 2 32;
3 7; 3 12; 3 13;
4 6; 4 10;
5 6; 5 10; 5 16;
6 16;
8 30; 8 32; 8 33;
9 33;
13 33;
14 32; 14 33;
15 32; 15 33;
18 32; 18 33;
19 33;
20 32; 20 33;
22 32; 22 33;
23 25; 23 27; 23 29; 23 32; 23 33;
24 25; 24 27; 24 31;
25 31;
26 29; 26 33;
27 33;
28 31; 28 33;
29 32; 29 33;
30 32; 30 33;
31 32; 31 33;
32 33
];

% 由于MATLAB索引从1开始，需要将节点编号加1
edges = edges + 1;

% 创建图对象
G = graph(edges(:,1), edges(:,2));

% 创建图形窗口，设置白色背景
figure('Position', [100, 100, 1000, 800], ...
       'Color', [1, 1, 1], ...  % 白色背景
       'InvertHardcopy', 'off');

% 使用subgraph绘制网络
p = plot(G, 'Layout', 'force', 'UseGravity', true, 'Iterations', 300);

% 获取节点位置
x = p.XData;
y = p.YData;

% 隐藏原始图形对象
p.NodeLabel = {};
p.MarkerSize = 0.1; % 设置非常小的节点
p.NodeColor = [1, 1, 1]; % 白色节点，使其几乎不可见

% 设置边属性
p.LineWidth = 1.5;
p.EdgeColor = [0.3, 0.3, 0.3];
p.EdgeAlpha = 0.6; % 设置边的透明度

% 重新绘制节点为空心圆并在中心添加编号
hold on;
for i = 1:numnodes(G)
    % 绘制空心圆节点
    plot(x(i), y(i), 'o', 'MarkerSize', 30, ...
         'MarkerEdgeColor', [0.2, 0.4, 0.8], ...
         'MarkerFaceColor', [1, 1, 1], ... % 白色填充
         'LineWidth', 1.5);
    
    % 在节点中心添加节点编号
    text(x(i), y(i), num2str(i-1), ... % 显示原始编号（i-1）
         'FontSize', 20, ...
         'FontWeight', 'bold', ...
         'HorizontalAlignment', 'center', ...
         'VerticalAlignment', 'middle', ...
         'Color', [0.2, 0.2, 0.2]); % 深灰色文本
end
hold off;

% 设置白色背景，移除边框
axis off;
set(gca, 'Position', [0 0 1 1]);  % 让坐标轴充满整个图形
set(gca, 'Color', [1, 1, 1]);  % 设置坐标轴背景为白色
set(gca, 'XColor', [1, 1, 1], 'YColor', [1, 1, 1]);  % 隐藏坐标轴颜色
set(gcf, 'Color', [1, 1, 1]);  % 设置图形窗口背景为白色
set(gcf, 'InvertHardcopy', 'off');  % 确保保存时保持当前颜色

% % 如果要保存为透明背景的PNG，使用以下命令：
% % 保存图片
% filename = 'network_graph.png';
% print(gcf, filename, '-dpng', '-r300', '-opengl', '-noui');
% % 或者使用exportgraphics（R2020a以上版本）
% % exportgraphics(gcf, filename, 'BackgroundColor', 'none', 'ContentType', 'vector');

% fprintf('图片已保存为: %s\n', filename);
fprintf('网络基本信息:\n');
fprintf('节点数量: %d\n', numnodes(G));
fprintf('边数量: %d\n', numedges(G));
fprintf('网络密度: %.4f\n', numedges(G)/(numnodes(G)*(numnodes(G)-1)/2));
fprintf('平均度: %.2f\n', mean(degree(G)));