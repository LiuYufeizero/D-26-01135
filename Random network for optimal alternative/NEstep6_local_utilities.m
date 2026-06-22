clc;
clear;

function v_local = compute_local_coalition_utility(W, C, u_I, coalition)
% 计算局部移情网络中联盟效用
% 输入:
%   W - 移情矩阵 (4x4)
%   C - 维护成本矩阵 (4x4)  
%   u_I - 内在效用向量 (4x1)
%   coalition - 联盟成员索引向量
% 输出:
%   v_local - 联盟效用值

    n = size(W, 1);
    
    % 空联盟效用为0
    if isempty(coalition)
        v_local = 0;
        return;
    end
    
    % 提取联盟成员
    S = coalition;
    k = length(S);
    
    % 步骤1: 修正子联盟内的移情权重
    W_S = zeros(k, k);
    for i = 1:k
        node_i = S(i);
        % 计算原始权重在联盟S内的行和
        row_sum = sum(W(node_i, S));
        % 归一化处理
        for j = 1:k
            node_j = S(j);
            W_S(i, j) = W(node_i, node_j) / row_sum;
        end
    end
    
    % 步骤2: 计算联盟内个体移情效用
    u_S_local = zeros(k, 1);
    for i = 1:k
        node_i = S(i);
        % 内在效用加权和
        utility_sum = 0;
        for j = 1:k
            node_j = S(j);
            utility_sum = utility_sum + W_S(i, j) * u_I(node_j);
        end
        
        % 维护成本总和
        cost_sum = 0;
        for j = 1:k
            node_j = S(j);
            cost_sum = cost_sum + C(node_i, node_j);
        end
        
        u_S_local(i) = utility_sum - cost_sum;
    end
    
    % 步骤3: 计算节省的成本 (与联盟外节点断开连接节省的成本)
    saved_cost = 0;
    for i = 1:k
        node_i = S(i);
        for node_j = 1:n
            if ~ismember(node_j, S) && C(node_i, node_j) > 0
                saved_cost = saved_cost + C(node_i, node_j);
            end
        end
    end
    
    % 步骤4: 计算机会成本 (损失的外部移情效用)
    opportunity_cost = 0;
    for i = 1:k
        node_i = S(i);
        for node_j = 1:n
            if ~ismember(node_j, S) && W(node_i, node_j) > 0
                opportunity_cost = opportunity_cost + W(node_i, node_j) * u_I(node_j);
            end
        end
    end
    
    % 步骤5: 计算总联盟效用
    internal_utility = sum(u_S_local);  % 内部效用总和
    v_local = internal_utility + saved_cost - opportunity_cost;
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

% 计算不同联盟的效用
fprintf('=== 局部移情网络联盟效用计算 ===\n\n');

% 单个决策者联盟
for i = 1:4
    v = compute_local_coalition_utility(W, C, u_I, i);
    fprintf('联盟 {%d} 效用: %.2f\n', i, v);
end

% 双决策者联盟
pairs = nchoosek(1:4, 2);
for i = 1:size(pairs, 1)
    v = compute_local_coalition_utility(W, C, u_I, pairs(i,:));
    fprintf('联盟 {%d,%d} 效用: %.2f\n', pairs(i,1), pairs(i,2), v);
end

% 三决策者联盟
triples = nchoosek(1:4, 3);
for i = 1:size(triples, 1)
    v = compute_local_coalition_utility(W, C, u_I, triples(i,:));
    fprintf('联盟 {%d,%d,%d} 效用: %.2f\n', triples(i,1), triples(i,2), triples(i,3), v);
end

% 大联盟 (所有决策者)
v_grand = compute_local_coalition_utility(W, C, u_I, 1:4);
fprintf('大联盟 {1,2,3,4} 效用: %.2f\n', v_grand);

