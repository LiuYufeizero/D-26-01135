clc;
clear;

function u_global = compute_global_utility(W, C, u_I)
    % 计算全局移情网络中所有决策者的效用向量
    % 输入:
    %   W - 移情矩阵 (n x n)
    %   C - 维护成本矩阵 (n x n)
    %   u_I - 内在效用向量 (n x 1)
    % 输出:
    %   u_global - 全局效用向量 (n x 1)
    
    n = size(W, 1);
    
    % 构建对角矩阵D
    D = diag(diag(W));
    
    % 计算 (I - W + D) 的逆矩阵
    I = eye(n);
    inv_matrix = inv(I - W + D);
    
    % 计算维护成本向量（每行求和）
    cost_vector = sum(C, 2);
    
    % 计算全局效用: u = (I - W + D)^{-1} * (D * u_I - C * e)
    u_global = inv_matrix * (D * u_I - cost_vector);
end

function v_global = compute_global_coalition_utility(W, C, u_I, coalition, u_global_all)
    % 计算全局移情网络中联盟效用
    % 输入:
    %   W - 原始移情矩阵 (n x n)
    %   C - 原始维护成本矩阵 (n x n)
    %   u_I - 内在效用向量 (n x 1)
    %   coalition - 联盟成员索引向量
    %   u_global_all - 整个大联盟下的全局效用向量 (n x 1)
    % 输出:
    %   v_global - 联盟效用值
    
    n = size(W, 1);
    
    % 空联盟效用为0
    if isempty(coalition)
        v_global = 0;
        return;
    end
    
    % 提取联盟成员
    S = coalition;
    k = length(S);
    
    % 步骤1: 修正子联盟内的移情权重（归一化）
    W_S = zeros(k, k);
    for i = 1:k
        node_i = S(i);
        % 计算原始权重在联盟S内的行和
        row_sum = sum(W(node_i, S));
        if row_sum > 0
            for j = 1:k
                node_j = S(j);
                W_S(i, j) = W(node_i, node_j) / row_sum;
            end
        else
            % 如果行和为0（理论上不会发生，因为至少有一个自环权重）
            W_S(i, i) = 1;  % 只保留自环
        end
    end
    
    % 步骤2: 构建联盟内的维护成本矩阵
    C_S = zeros(k, k);
    for i = 1:k
        node_i = S(i);
        for j = 1:k
            node_j = S(j);
            C_S(i, j) = C(node_i, node_j);
        end
    end
    
    % 步骤3: 提取联盟内的内在效用
    u_I_S = u_I(S);
    
    % 步骤4: 计算联盟内决策者的全局效用
    % 使用修正后的W_S和C_S
    u_S_global = compute_global_utility(W_S, C_S, u_I_S);
    
    % 步骤5: 计算内部效用总和
    internal_utility = sum(u_S_global);
    
    % 步骤6: 计算节省的成本（与联盟外节点断开连接节省的成本）
    saved_cost = 0;
    for i = 1:k
        node_i = S(i);
        for node_j = 1:n
            if ~ismember(node_j, S) && C(node_i, node_j) > 0
                saved_cost = saved_cost + C(node_i, node_j);
            end
        end
    end
    
    % 步骤7: 计算机会成本（损失的外部移情效用）
    % 在全局移情网络中，使用整个大联盟下的外部节点效用
    opportunity_cost = 0;
    for i = 1:k
        node_i = S(i);
        for node_j = 1:n
            if ~ismember(node_j, S) && W(node_i, node_j) > 0
                % 使用整个大联盟下的全局效用
                opportunity_cost = opportunity_cost + W(node_i, node_j) * u_global_all(node_j);
            end
        end
    end
    
    % 步骤8: 计算总联盟效用
    % v(S) = 内部效用总和 + 节省的成本 - 机会成本
    v_global = internal_utility + saved_cost - opportunity_cost;
end

% 测试示例
% 移情矩阵 W (4x4)
W = [0.4, 0.2, 0.4, 0;
     0.1, 0.2, 0.7, 0;
     0.2, 0,   0.2, 0.6;
     0,   0,   0.2, 0.8];

% 维护成本矩阵 C (4x4)
C = [0,   0.2, 0.2, 0;
     1.4, 0,   1.4, 0;
     0.9, 0,   0,   0.9;
     0,   0,   0.2, 0];

% 内在效用向量 u^I
u_I = [10; 0; 20; 10];

% 首先计算整个大联盟的全局效用向量（用于机会成本计算）
u_global_all = compute_global_utility(W, C, u_I);

fprintf('=== 全局移情网络联盟效用计算 ===\n\n');
fprintf('整个大联盟下的全局效用向量:\n');
disp(u_global_all');
fprintf('\n');

% 单个决策者联盟
for i = 1:4
    v = compute_global_coalition_utility(W, C, u_I, i, u_global_all);
    fprintf('联盟 {%d} 效用: %.2f\n', i, v);
end

% 双决策者联盟
pairs = nchoosek(1:4, 2);
for i = 1:size(pairs, 1)
    v = compute_global_coalition_utility(W, C, u_I, pairs(i,:), u_global_all);
    fprintf('联盟 {%d,%d} 效用: %.2f\n', pairs(i,1), pairs(i,2), v);
end

% 三决策者联盟
triples = nchoosek(1:4, 3);
for i = 1:size(triples, 1)
    v = compute_global_coalition_utility(W, C, u_I, triples(i,:), u_global_all);
    fprintf('联盟 {%d,%d,%d} 效用: %.2f\n', triples(i,1), triples(i,2), triples(i,3), v);
end

% 大联盟 (所有决策者)
v_grand_global = compute_global_coalition_utility(W, C, u_I, 1:4, u_global_all);
fprintf('大联盟 {1,2,3,4} 效用: %.2f\n', v_grand_global);
