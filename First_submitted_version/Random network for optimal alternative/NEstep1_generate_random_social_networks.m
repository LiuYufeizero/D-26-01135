%% 初始化参数
clear; clc;

rng(123);
% 基本参数设置
n0 = 2;          % 初始节点数
k = 2;           % 每次添加的边数
N = 12;         % 最终网络总节点数
p_bidirectional = 0.7;  % 边为双向的概率（0-1之间）
p_unidirectional = 0.3; % 边为单向的概率

% 检查参数合法性
if k > n0
    error('k必须小于或等于n0');
end

% 确保概率和为1（单向和双向边概率之和）
if p_bidirectional + p_unidirectional > 1
    error('单向边和双向边概率之和不能超过1');
end

fprintf('开始生成改进的无标度有向网络...\n');
fprintf('双向边概率: %.2f, 单向边概率: %.2f\n', p_bidirectional, p_unidirectional);

%% 步骤1: 生成改进的无标度网络（包含单向和双向边）
% 初始化邻接矩阵
W_undirected = zeros(N, N);
W_directed = zeros(N, N);

% 创建初始连接（n0个节点）
% 初始的两个节点之间连接：随机决定是单向还是双向
if rand() <= p_bidirectional
    % 双向连接
    W_directed(1, 2) = 1;
    W_directed(2, 1) = 1;
    W_undirected(1, 2) = 1;
    W_undirected(2, 1) = 1;
else
    % 单向连接：随机决定方向
    if rand() <= 0.5
        W_directed(1, 2) = 1;  % 1->2
        W_undirected(1, 2) = 1;
        W_undirected(2, 1) = 1;
    else
        W_directed(2, 1) = 1;  % 2->1
        W_undirected(1, 2) = 1;
        W_undirected(2, 1) = 1;
    end
end

% 计算当前每个节点的出度和总度（用于偏好连接）
out_degrees = sum(W_directed, 2)';
total_out_degree = sum(out_degrees);

% 逐个添加新节点
for new_node = 3:N
    % 计算每个现有节点的连接概率（基于出度+1，避免概率为0）
    existing_nodes = 1:(new_node-1);
    
    % 如果总出度为0，则均匀分布
    if total_out_degree == 0
        probs = ones(1, new_node-1) / (new_node-1);
    else
        % 使用出度加1的方法，避免概率为0
        probs = (out_degrees(1:new_node-1) + 1) / (total_out_degree + (new_node-1));
    end
    
    % 选择k个节点进行连接（有放回选择，但会避免重复）
    selected_nodes = zeros(1, k);
    for i = 1:k
        % 根据概率选择节点
        r = rand();
        cum_prob = 0;
        selected = 0;
        for j = 1:length(probs)
            cum_prob = cum_prob + probs(j);
            if r <= cum_prob
                selected = j;
                break;
            end
        end
        
        % 如果选择了重复的节点，重新选择
        while ismember(selected, selected_nodes(1:i-1)) && length(unique(selected_nodes(1:i-1))) < length(probs)
            r = rand();
            cum_prob = 0;
            for j = 1:length(probs)
                cum_prob = cum_prob + probs(j);
                if r <= cum_prob
                    selected = j;
                    break;
                end
            end
        end
        
        selected_nodes(i) = selected;
    end
    
    % 为新节点与选中的节点建立连接
    for i = 1:k
        src_node = selected_nodes(i);
        
        % 随机决定连接类型
        connection_type = rand();
        
        if connection_type < p_bidirectional
            % 双向连接
            W_directed(new_node, src_node) = 1;
            W_directed(src_node, new_node) = 1;
            W_undirected(new_node, src_node) = 1;
            W_undirected(src_node, new_node) = 1;
            
        elseif connection_type < (p_bidirectional + p_unidirectional)
            % 单向连接：随机决定方向
            if rand() <= 0.5
                % 新节点指向旧节点
                W_directed(new_node, src_node) = 1;
                W_undirected(new_node, src_node) = 1;
                W_undirected(src_node, new_node) = 1;
            else
                % 旧节点指向新节点
                W_directed(src_node, new_node) = 1;
                W_undirected(new_node, src_node) = 1;
                W_undirected(src_node, new_node) = 1;
            end
        end
    end
    
    % 更新出度和总出度
    out_degrees = sum(W_directed, 2)';
    total_out_degree = sum(out_degrees);
end

fprintf('网络生成完成。\n');
fprintf('总节点数: %d\n', N);
fprintf('有向边总数: %d\n', sum(sum(W_directed > 0)));

%% 步骤2: 生成保留两位小数的随机自环权重
fprintf('\n生成随机自环权重（保留两位小数）...\n');

% 为每个节点生成随机自环权重
min_selfloop = 0.1;
max_selfloop = 0.6;
selfloop_weights_int = randi([round(min_selfloop*100), round(max_selfloop*100)], N, 1);
selfloop_weights = selfloop_weights_int / 100;

fprintf('自环权重范围: [%.2f, %.2f]\n', min(selfloop_weights), max(selfloop_weights));

%% 步骤3: 添加随机自循环
fprintf('\n添加随机自循环...\n');

% 添加自循环（设置对角线为随机权重）
W_weighted = zeros(N, N);  % 初始化权重矩阵
for i = 1:N
    W_weighted(i, i) = selfloop_weights(i);
end

%% 步骤4: 随机分配剩余权重（保留两位小数）并确保行和为1
fprintf('随机分配剩余权重（保留两位小数）并确保行和为1...\n');

% 为每个节点的有向边分配权重
for i = 1:N
    % 找出节点i的所有有向出边（不包括自循环）
    out_edges = find(W_directed(i, :) > 0);
    out_edges = out_edges(out_edges ~= i);  % 移除自循环
    
    % 计算出度（不包括自循环）
    out_degree = length(out_edges);
    
    if out_degree > 0
        % 计算可用于分配的总权重
        remaining_weight = 1 - selfloop_weights(i);
        
        % 如果只有一个出边，所有剩余权重都给它
        if out_degree == 1
            random_weights = remaining_weight;
        else
            % 生成保留两位小数的随机权重
            random_weights = zeros(1, out_degree);
            
            % 首先生成out_degree-1个随机两位小数权重
            for j = 1:out_degree-1
                % 为每个权重分配最小值0.01，确保非负
                min_weight = 0.01;
                max_weight = remaining_weight - (out_degree - j) * min_weight;
                
                if max_weight < min_weight
                    max_weight = min_weight;
                end
                
                % 生成随机权重（两位小数）
                random_int = randi([round(min_weight*100), round(max_weight*100)]);
                random_weights(j) = random_int / 100;
                remaining_weight = remaining_weight - random_weights(j);
            end
            
            % 最后一个权重等于剩余权重，确保和为1
            random_weights(out_degree) = round(remaining_weight * 100) / 100;
            
            % 由于四舍五入，可能需要微调
            total_allocated = sum(random_weights);
            if abs(total_allocated - (1 - selfloop_weights(i))) > 0.0001
                % 调整最后一个权重
                random_weights(out_degree) = random_weights(out_degree) + (1 - selfloop_weights(i) - total_allocated);
            end
        end
        
        % 确保所有权重为非负
        random_weights(random_weights < 0) = 0.01;
        
        % 更新权重矩阵
        W_weighted(i, out_edges) = random_weights;
    end
end

fprintf('随机权重分配完成。\n');

%% 步骤5: 验证权重
fprintf('\n验证权重分配...\n');

all_valid = true;
for i = 1:N
    weight_sum = sum(W_weighted(i, :));
    if abs(weight_sum - 1) > 0.0001
        fprintf('节点 %d 的权重和为 %.4f (应接近1)\n', i, weight_sum);
        all_valid = false;
    end
end
if all_valid
    fprintf('所有权重验证通过。\n');
else
    fprintf('部分节点权重验证未通过。\n');
end

%% 步骤6: 分析有向网络特性
fprintf('\n分析有向网络特性...\n');

% 计算入度和出度
in_degrees = sum(W_directed > 0, 1)';  % 列求和
out_degrees = sum(W_directed > 0, 2);  % 行求和

% 统计边类型
bidirectional_edges = 0;
unidirectional_edges = 0;
for i = 1:N
    for j = i+1:N
        if W_directed(i, j) > 0 && W_directed(j, i) > 0
            bidirectional_edges = bidirectional_edges + 1;
        elseif W_directed(i, j) > 0 || W_directed(j, i) > 0
            unidirectional_edges = unidirectional_edges + 1;
        end
    end
end

fprintf('双向边数量: %d\n', bidirectional_edges);
fprintf('单向边数量: %d\n', unidirectional_edges);
fprintf('总边数: %d\n', bidirectional_edges*2 + unidirectional_edges);
fprintf('平均入度: %.2f\n', mean(in_degrees));
fprintf('平均出度: %.2f\n', mean(out_degrees));

%% 步骤7: 网络可视化
fprintf('\n生成网络可视化...\n');

% 创建图形窗口
figure('Position', [100, 100, 1200, 400]);

% 子图1: 原始无向网络
subplot(1, 3, 1);
G_undirected = graph(W_undirected);
plot(G_undirected, 'NodeLabel', {}, 'Layout', 'force', 'LineWidth', 1.5);
title('无向网络拓扑');
xlabel(sprintf('节点数: %d, 边数: %d', N, numedges(G_undirected)));

% 子图2: 有向网络拓扑
subplot(1, 3, 2);
G_directed = digraph(W_directed);
edge_colors = zeros(numedges(G_directed), 3);

% 为边着色：双向边用蓝色，单向边用红色
for i = 1:numedges(G_directed)
    edge = G_directed.Edges.EndNodes(i, :);
    src = edge(1);
    tgt = edge(2);
    
    if W_directed(tgt, src) > 0
        % 双向边
        edge_colors(i, :) = [0, 0, 1];  % 蓝色
    else
        % 单向边
        edge_colors(i, :) = [1, 0, 0];  % 红色
    end
end

h = plot(G_directed, 'NodeLabel', {}, 'Layout', 'force', ...
    'ArrowSize', 8, 'LineWidth', 1.5, 'EdgeColor', edge_colors);
title('有向网络拓扑');
xlabel(sprintf('双向边: %d, 单向边: %d', bidirectional_edges, unidirectional_edges));

% 添加图例
hold on;
plot([NaN NaN], [NaN NaN], 'b-', 'LineWidth', 2, 'DisplayName', '双向边');
plot([NaN NaN], [NaN NaN], 'r-', 'LineWidth', 2, 'DisplayName', '单向边');
legend('Location', 'best');
hold off;

% 子图3: 入度出度分布
subplot(1, 3, 3);
bar(1:N, [in_degrees, out_degrees], 'grouped');
xlabel('节点编号');
ylabel('度数');
title('节点入度和出度分布');
legend('入度', '出度', 'Location', 'northwest');
grid on;
xlim([0.5, N+0.5]);

%% 步骤8: 显示详细网络信息
fprintf('\n节点详细信息（保留两位小数）:\n');
fprintf('节点\t自环权重\t入度\t出度\t总权重\t连接状态\n');
for i = 1:N
    % 获取邻居节点
    in_neighbors = find(W_directed(:, i) > 0)';
    out_neighbors = find(W_directed(i, :) > 0);
    out_neighbors = out_neighbors(out_neighbors ~= i);
    
    % 统计双向连接
    bidirectional_count = 0;
    for j = in_neighbors
        if ismember(j, out_neighbors)
            bidirectional_count = bidirectional_count + 1;
        end
    end
    
    fprintf('%d\t%.2f\t\t%d\t%d\t%.4f\t双向:%d,单向:%d\n', ...
        i, selfloop_weights(i), length(in_neighbors), length(out_neighbors), ...
        sum(W_weighted(i, :)), bidirectional_count, ...
        length(out_neighbors) + length(in_neighbors) - 2*bidirectional_count);
end

% 显示邻接矩阵
W_weighted_rounded = round(W_weighted, 4);
fprintf('\n加权邻接矩阵（保留四位小数）:\n');
for i = 1:N
    fprintf('节点%d: ', i);
    for j = 1:N
        if W_weighted_rounded(i, j) > 0
            if i == j
                fprintf('自环:%.4f ', W_weighted_rounded(i, j));
            else
                fprintf('%d->%d:%.4f ', i, j, W_weighted_rounded(i, j));
            end
        end
    end
    fprintf('\n');
end

% 验证每个节点的权重和
fprintf('\n节点权重和验证:\n');
for i = 1:N
    weight_sum = sum(W_weighted_rounded(i, :));
    if abs(weight_sum - 1) < 0.0001
        fprintf('节点 %d: 权重和 = %.4f ✓\n', i, weight_sum);
    else
        fprintf('节点 %d: 权重和 = %.4f ✗ (应为1.0000)\n', i, weight_sum);
    end
end

% 统计信息
fprintf('\n网络统计信息:\n');
fprintf('自环权重范围: [%.2f, %.2f]\n', min(selfloop_weights), max(selfloop_weights));
non_self_weights = W_weighted_rounded(W_weighted_rounded > 0 & ~eye(N));
if ~isempty(non_self_weights)
    fprintf('出边权重范围: [%.4f, %.4f]\n', min(non_self_weights), max(non_self_weights));
else
    fprintf('出边权重范围: 无出边\n');
end
fprintf('双向边比例: %.2f%%\n', 100 * bidirectional_edges / (bidirectional_edges + unidirectional_edges));

% 保存结果
fprintf('\n结果已保存到变量中:\n');
fprintf('W_undirected: 无向邻接矩阵\n');
fprintf('W_directed: 有向邻接矩阵\n');
fprintf('W_weighted: 加权有向邻接矩阵\n');
fprintf('selfloop_weights: 自环权重向量\n');