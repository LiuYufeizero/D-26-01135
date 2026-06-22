clc;
clear;

% 设置随机种子以便结果可重现
rng(123);

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
original_edges = edges;
edges = edges + 1;
n = max(edges(:)); % 节点总数

fprintf('原始无向网络信息:\n');
fprintf('节点数量: %d\n', n);
fprintf('无向边数量: %d\n', size(edges, 1));

%% 步骤1: 有向化处理
fprintf('\n=== 有向化处理 ===\n');
fprintf('边有向化规则: 0.8概率为双向边, 0.2概率为单向边\n');

% 存储有向边
directed_edges = [];

% 遍历所有原始无向边
for i = 1:size(original_edges, 1)
    u = original_edges(i, 1) + 1; % 转换为MATLAB索引
    v = original_edges(i, 2) + 1; % 转换为MATLAB索引
    
    r = rand(); % 生成随机数决定边方向
    
    if r <= 0.2
        % 0.2概率为单向边，随机选择方向
        if rand() < 0.5
            directed_edges = [directed_edges; u, v];
        else
            directed_edges = [directed_edges; v, u];
        end
    else
        % 0.8概率为双向边
        directed_edges = [directed_edges; u, v; v, u];
    end
end

% 创建有向图
G_directed = digraph(directed_edges(:,1), directed_edges(:,2));

fprintf('有向化后网络信息:\n');
fprintf('节点数量: %d\n', numnodes(G_directed));
fprintf('有向边数量: %d\n', numedges(G_directed));

%% 步骤2: 添加自环和分配权重
fprintf('\n=== 添加自环和分配权重 ===\n');
fprintf('自环权重范围: (0,1]，保留2位小数\n');

% 初始化权重矩阵W
W = zeros(n, n);

% 修改后的自环权重生成逻辑：确保自环权重在(0,1]范围内
% 为每个节点j生成自环权重w_{jj}，保留2位小数
% 自环权重在(0.01, 1]范围内均匀分布，避免为0
% 生成1到100的随机整数，然后除以100，确保权重在[0.01, 1]之间，最小为0.01
fprintf('生成自环权重 (范围: 0.01-1.00，保留2位小数)...\n');
self_weights = randi([10, 100], n, 1) / 100; % 生成1-100的整数，除以100得到0.01-1.00

% 分配权重
for j = 1:n
    % 找出节点j的所有出边（不包括自环）
    out_neighbors = successors(G_directed, j);
    
    % 移除自环（如果有的话）
    out_neighbors(out_neighbors == j) = [];
    
    % 计算节点j的出度（不包括自环）
    out_degree = length(out_neighbors);
    
    if out_degree > 0
        % 如果有出边，则按照规则分配权重
        w_jj = self_weights(j);
        
        % 确保自环权重在(0,1)范围内，不能为1，否则出边权重为0
        % 但出边权重为0是允许的，所以这里不做调整
        % 不过为了符合(0,1]范围，我们允许自环权重为1，此时出边权重为0
        remaining_weight = 1 - w_jj;
        
        % 如果remaining_weight太小，可以调整自环权重
        if remaining_weight < 0.01 && out_degree > 0
            % 如果剩余权重太小，调整自环权重，确保有至少0.01的权重可以分配给出边
            w_jj = 1 - 0.01 * out_degree;
            if w_jj < 0.01
                w_jj = 0.01; % 确保自环权重至少为0.01
            end
            remaining_weight = 1 - w_jj;
        end
        
        % 随机分配剩余权重给出边，确保和为remaining_weight
        if out_degree == 1
            % 如果只有一条出边，全部剩余权重都给它
            edge_weights = remaining_weight;
        else
            % 如果有多个出边，生成随机数并归一化
            random_weights = rand(out_degree, 1);
            edge_weights = random_weights / sum(random_weights) * remaining_weight;
        end
        
        % 保留2位小数
        edge_weights = round(edge_weights * 100) / 100;
        w_jj = round(w_jj * 100) / 100;
        
        % 确保权重和为remaining_weight（考虑四舍五入的误差）
        weights_sum = sum(edge_weights);
        if abs(weights_sum - remaining_weight) > 0.01
            % 调整最后一个权重，使总和正确
            edge_weights(end) = edge_weights(end) + (remaining_weight - weights_sum);
            edge_weights(end) = round(edge_weights(end) * 100) / 100;
        end
        
        % 重新计算remaining_weight，因为w_jj可能被四舍五入
        remaining_weight = 1 - w_jj;
        weights_sum = sum(edge_weights);
        
        % 如果还有误差，调整自环权重
        if abs(weights_sum - remaining_weight) > 0.001
            w_jj = 1 - weights_sum;
            w_jj = round(w_jj * 100) / 100;
        end
        
        % 设置自环权重
        W(j, j) = w_jj;
        
        % 设置出边权重
        for k = 1:out_degree
            neighbor = out_neighbors(k);
            W(j, neighbor) = round(edge_weights(k) * 100) / 100;
        end
    else
        % 如果没有出边（只有自环），设置自环权重为1.00
        W(j, j) = 1.00;
    end
end

% 最终检查，确保每行权重和为1.00，且自环权重大于0
fprintf('\n验证权重矩阵...\n');
valid = true;
for j = 1:n
    row_sum = round(sum(W(j, :)) * 100) / 100;
    
    % 检查权重和是否为1.00
    if abs(row_sum - 1.00) > 0.001
        fprintf('警告: 节点%d权重和为%.2f，不等于1.00\n', j-1, row_sum);
        valid = false;
        
        % 调整权重
        diff = 1.00 - row_sum;
        W(j, j) = W(j, j) + diff;
        W(j, j) = round(W(j, j) * 100) / 100;
    end
    
    % 检查自环权重是否大于0
    if W(j, j) <= 0
        fprintf('错误: 节点%d自环权重为%.2f，小于等于0\n', j-1, W(j, j));
        valid = false;
        
        % 修正自环权重
        W(j, j) = 0.01; % 设置为最小值0.01
        
        % 重新调整其他权重
        row_sum_without_self = sum(W(j, :)) - W(j, j);
        if row_sum_without_self > 0
            scale = (1 - W(j, j)) / row_sum_without_self;
            for k = 1:n
                if k ~= j && W(j, k) > 0
                    W(j, k) = W(j, k) * scale;
                    W(j, k) = round(W(j, k) * 100) / 100;
                end
            end
        end
    end
end

if valid
    fprintf('✓ 所有权重验证通过:\n');
    fprintf('  - 所有节点权重和均为1.00 (2位小数精度)\n');
    fprintf('  - 所有自环权重均大于0\n');
end

%% 输出权重矩阵W
fprintf('\n=== 权重矩阵W ===\n');
fprintf('格式: 34x34矩阵，每行权重和为1.00\n\n');

% 显示整个矩阵（由于矩阵较大，可以分批显示）
fprintf('权重矩阵W (非零元素):\n');
for i = 1:n
    fprintf('节点%2d: ', i-1);
    for j = 1:n
        if W(i, j) > 0
            fprintf('%2d:%.2f ', j-1, W(i, j));
        end
    end
    fprintf('(合计: %.2f)\n', round(sum(W(i, :)) * 100) / 100);
end

fprintf('\n权重矩阵W (表格形式，前10行10列):\n');
disp(array2table(round(W(1:10, 1:10)*100)/100, 'VariableNames', arrayfun(@(x) sprintf('%d', x-1), 1:10, 'UniformOutput', false), ...
    'RowNames', arrayfun(@(x) sprintf('%d', x-1), 1:10, 'UniformOutput', false)));

%% 计算自环权重范围和出边权重范围
fprintf('\n=== 权重范围分析 ===\n');

% 自环权重范围
self_loop_weights = diag(W);
fprintf('自环权重范围: %.2f - %.2f\n', min(self_loop_weights), max(self_loop_weights));
fprintf('自环权重均值: %.4f\n', mean(self_loop_weights));
fprintf('自环权重标准差: %.4f\n', std(self_loop_weights));
fprintf('自环数量: %d (共%d个节点)\n', sum(self_loop_weights > 0), n);

% 出边权重范围（不包括自环）
out_weights = W - diag(diag(W));
out_weights_nonzero = out_weights(out_weights > 0);
if ~isempty(out_weights_nonzero)
    fprintf('\n出边权重范围: %.2f - %.2f\n', min(out_weights_nonzero), max(out_weights_nonzero));
    fprintf('出边权重均值: %.4f\n', mean(out_weights_nonzero));
    fprintf('出边权重标准差: %.4f\n', std(out_weights_nonzero));
    fprintf('出边数量: %d\n', length(out_weights_nonzero));
    
    % 统计出边权重的分布
    unique_weights = unique(round(out_weights_nonzero*100)/100);
    fprintf('出边权重的不同取值: %d个\n', length(unique_weights));
    fprintf('最常见的出边权重: ');
    [counts, values] = hist(out_weights_nonzero, unique_weights);
    [max_count, max_idx] = max(counts);
    fprintf('%.2f (出现%d次)\n', values(max_idx), max_count);
else
    fprintf('\n无出边权重\n');
end

% 所有权重统计
all_weights = W(W > 0);
fprintf('\n所有权重(包括自环)范围: %.2f - %.2f\n', min(all_weights), max(all_weights));
fprintf('所有权重均值: %.4f\n', mean(all_weights));
fprintf('所有权重标准差: %.4f\n', std(all_weights));

fprintf('\n权重矩阵基本信息:\n');
fprintf('权重矩阵维度: %d x %d\n', size(W, 1), size(W, 2));
fprintf('权重矩阵非零元素数量: %d\n', nnz(W));
fprintf('权重矩阵密度: %.4f\n', nnz(W) / (n * n));

% 检查每行权重和是否为1.00
row_sums = round(sum(W, 2) * 100) / 100;
fprintf('每行权重和验证 (最小值, 最大值): [%.2f, %.2f]\n', min(row_sums), max(row_sums));

% 输出每个节点的自环权重
fprintf('\n节点自环权重统计:\n');
for j = 1:n
    fprintf('节点 %2d: w_%d%d = %.2f', j-1, j-1, j-1, W(j, j));
    if W(j, j) <= 0
        fprintf(' (警告: 自环权重小于等于0!)');
    end
    fprintf('\n');
end

%% 创建带权重的有向图
fprintf('\n=== 创建带权重的有向图 ===\n');

% 创建有向图，边权重来自W矩阵
[s, t] = find(W > 0);  % 找到所有权重大于0的边
weights = zeros(length(s), 1);
for i = 1:length(s)
    weights(i) = W(s(i), t(i));
end

% 创建带权重的有向图
G_weighted = digraph(s, t, weights);

% 统计边数
fprintf('带权有向图边数: %d\n', numedges(G_weighted));
fprintf('其中自环数量: %d\n', sum(diag(W) > 0));

%% 可视化有向网络
figure('Position', [100, 100, 1000, 800], ...
       'Color', [1, 1, 1], ...
       'Name', '有向加权网络 (自环权重∈(0,1])');

% 使用力导向布局
p = plot(G_weighted, 'Layout', 'force', 'UseGravity', true, 'Iterations', 500);

% 设置节点样式
p.MarkerSize = 8;
p.NodeColor = [0.2, 0.4, 0.8];
p.NodeLabel = arrayfun(@(x) num2str(x-1), 1:n, 'UniformOutput', false);
p.NodeFontSize = 10;
p.NodeFontWeight = 'bold';

% 设置边样式
edge_weights = G_weighted.Edges.Weight;
% 边宽度与权重成正比
max_weight = max(edge_weights);
min_weight = min(edge_weights(edge_weights > 0));
if max_weight > min_weight
    p.LineWidth = 1 + 3 * (edge_weights - min_weight) / (max_weight - min_weight);
else
    p.LineWidth = 2 * ones(size(edge_weights));
end
p.EdgeColor = [0.3, 0.3, 0.3];
p.EdgeAlpha = 0.6;

% 添加箭头表示方向
p.ArrowSize = 8;
p.ArrowPosition = 0.9; % 箭头位置（0-1之间）

% 在边上添加权重标签（只显示非零权重）
for i = 1:length(s)
    if s(i) ~= t(i) % 非自环边
        x_mid = (p.XData(s(i)) + p.XData(t(i))) / 2;
        y_mid = (p.YData(s(i)) + p.YData(t(i))) / 2;
        
        % 稍微偏移避免重叠
        offset_x = (p.YData(t(i)) - p.YData(s(i))) * 0.05;
        offset_y = (p.XData(s(i)) - p.XData(t(i))) * 0.05;
        
        text(x_mid + offset_x, y_mid + offset_y, sprintf('%.2f', W(s(i), t(i))), ...
             'FontSize', 8, 'Color', [0.8, 0.2, 0.2], 'FontWeight', 'bold');
    end
end

% 为自环添加特殊标记
hold on;
for i = 1:n
    if W(i, i) > 0
        % 找到节点的位置
        x_pos = p.XData(i);
        y_pos = p.YData(i);
        
        % 绘制自环
        theta = linspace(0, 2*pi, 100);
        radius = 0.1;
        x_circle = x_pos + radius * cos(theta);
        y_circle = y_pos + radius * sin(theta);
        plot(x_circle, y_circle, 'r-', 'LineWidth', 2);
        
        % 在节点旁边标注自环权重
        text(x_pos + radius*1.5, y_pos, sprintf('%.2f', W(i,i)), ...
             'FontSize', 9, 'Color', 'r', 'FontWeight', 'bold');
    end
end
hold off;

% 添加颜色条表示权重
colormap(jet);
colorbar;
caxis([min(edge_weights), max(edge_weights)]);
ylabel(colorbar, '边权重');

% 设置图形属性
title('有向加权网络图 (自环权重∈(0,1])', 'FontSize', 16, 'FontWeight', 'bold');
axis off;
set(gca, 'Position', [0 0 1 1]);

%% 绘制权重分布图
figure('Position', [1200, 100, 800, 600], ...
       'Color', [1, 1, 1], ...
       'Name', '权重分析 (自环权重>0)');

% 子图1: 权重分布直方图
subplot(2, 2, 1);
all_weights = W(W > 0);
histogram(all_weights, 20, 'FaceColor', [0.2, 0.6, 0.8], 'EdgeColor', 'k');
xlabel('权重值');
ylabel('频数');
title('所有权重值分布');
grid on;

% 标记特殊权重值
hold on;
unique_weights = unique(round(all_weights*100)/100);
for i = 1:min(5, length(unique_weights))
    text(unique_weights(i), 5, sprintf('%.2f', unique_weights(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 8);
end
hold off;

% 子图2: 自环权重分布
subplot(2, 2, 2);
self_loop_weights = diag(W);
histogram(self_loop_weights, 10, 'FaceColor', [0.8, 0.4, 0.4], 'EdgeColor', 'k');
xlabel('自环权重');
ylabel('频数');
title('自环权重分布 (严格大于0)');
grid on;

% 标记最小值
hold on;
min_self = min(self_loop_weights);
text(min_self, 5, sprintf('最小值: %.2f', min_self), ...
     'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', 'r');
hold off;

% 子图3: 出边权重分布（不包括自环）
subplot(2, 2, 3);
out_weights = W - diag(diag(W)); % 移除对角线
out_weights = out_weights(out_weights > 0);
histogram(out_weights, 20, 'FaceColor', [0.4, 0.8, 0.4], 'EdgeColor', 'k');
xlabel('出边权重');
ylabel('频数');
title('出边权重分布 (不含自环)');
grid on;

% 子图4: 行权重和验证
subplot(2, 2, 4);
row_sums = round(sum(W, 2) * 100) / 100;
bar(row_sums, 'FaceColor', [0.8, 0.6, 0.2], 'EdgeColor', 'k');
hold on;
plot([0, n+1], [1, 1], 'r--', 'LineWidth', 2);
xlabel('节点编号');
ylabel('行权重和');
title('行权重和验证 (应为1.00)');
xlim([0, n+1]);
grid on;
hold off;

%% 最终验证
fprintf('\n=== 最终验证结果 ===\n');

% 检查自环权重是否都大于0
self_positive = all(diag(W) > 0);
if self_positive
    fprintf('✓ 所有自环权重均大于0 (最小值: %.2f)\n', min(diag(W)));
else
    fprintf('✗ 存在自环权重小于等于0\n');
    problematic_nodes = find(diag(W) <= 0);
    for i = 1:length(problematic_nodes)
        fprintf('   节点%d: 自环权重=%.2f\n', problematic_nodes(i)-1, W(problematic_nodes(i), problematic_nodes(i)));
    end
end

% 检查每行权重和是否为1.00
row_sums_valid = all(abs(row_sums - 1.00) < 0.001);
if row_sums_valid
    fprintf('✓ 所有节点权重和均为1.00 (2位小数精度)\n');
else
    fprintf('✗ 部分节点权重和不为1.00\n');
    problematic_rows = find(abs(row_sums - 1.00) >= 0.001);
    for i = 1:length(problematic_rows)
        fprintf('   节点%d: 权重和=%.2f\n', problematic_rows(i)-1, row_sums(problematic_rows(i)));
    end
end

% 检查所有权重是否在[0,1]范围内
all_weights_valid = all(W(:) >= 0) && all(W(:) <= 1);
if all_weights_valid
    fprintf('✓ 所有权重均在[0,1]范围内\n');
else
    fprintf('✗ 存在超出[0,1]范围的权重\n');
    [invalid_rows, invalid_cols] = find(W < 0 | W > 1);
    for i = 1:length(invalid_rows)
        fprintf('   W(%d,%d) = %.4f\n', invalid_rows(i)-1, invalid_cols(i)-1, W(invalid_rows(i), invalid_cols(i)));
    end
end

if self_positive && row_sums_valid && all_weights_valid
    fprintf('\n✅ 所有验证通过！权重矩阵W符合要求。\n');
else
    fprintf('\n⚠️ 存在未通过的验证项。\n');
end