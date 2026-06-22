%% 社会福利分配的MATLAB脚本
% 基于论文《考虑维护成本的移情网络决策模型与社会福利分配》


clear all; close all; clc;

%% 1. 参数设置（使用论文5.2节中的例子）
n = 4; % 决策者数量
m = 1; % 方案数量（这里只考虑方案a2）

% 移情矩阵 W (4x4)
W = [0.4, 0.2, 0.4, 0;
     0.1, 0.2, 0.7, 0;
     0.2, 0,   0.2, 0.6;
     0,   0,   0.2, 0.8];

% 维护成本矩阵 C(a2) (4x4)
C = [0,   0.2, 0.2, 0;
     1.4, 0,   1.4, 0;
     0.9, 0,   0,   0.9;
     0,   0,   0.2, 0];

% 内在效用向量 u^I(a2) (4x1)
uI = [10; 0; 0; 20];

% 全局移情网络参数
D = diag(diag(W)); % 对角矩阵
I = eye(n);

%% 2. 计算决策者效用
fprintf('=== 2. 计算决策者效用 ===\n');

% 局部移情网络效用
u_local = zeros(n, 1);
for j = 1:n
    u_local(j) = W(j,j)*uI(j);
    for k = 1:n
        if k ~= j
            u_local(j) = u_local(j) + W(j,k)*uI(k) - C(j,k);
        end
    end
end

fprintf('局部移情网络效用:\n');
disp(u_local');

% 全局移情网络效用
% u_global = (I - W + D)^{-1} * (D*uI - C*ones(n,1))
u_global = (I - W + D) \ (D*uI - C*ones(n,1));

fprintf('全局移情网络效用:\n');
disp(u_global');

% 社会福利
sw_local = sum(u_local);
sw_global = sum(u_global);
fprintf('局部移情网络社会福利: %.4f\n', sw_local);
fprintf('全局移情网络社会福利: %.4f\n', sw_global);

%% 3. 计算所有子联盟的效用
fprintf('\n=== 3. 计算所有子联盟效用 ===\n');

% 生成所有子联盟（不包括空集）
all_subsets = dec2bin(1:(2^n-1)) - '0';
num_subsets = size(all_subsets, 1);

% 存储联盟效用
v_local = zeros(num_subsets, 1);  % 局部移情
v_global = zeros(num_subsets, 1); % 全局移情

% 计算每个联盟的效用
for s = 1:num_subsets
    S = find(all_subsets(s,:)); % 联盟成员
    S_complement = setdiff(1:n, S); % 非联盟成员
    
    % 跳过空集
    if isempty(S)
        continue;
    end
    
    % 提取子联盟的移情权重矩阵
    k = length(S);
    W_S = W(S, S);
    
    % 归一化处理（使每行和为1）
    for i = 1:k
        row_sum = sum(W_S(i, :));
        if row_sum > 0
            W_S(i, :) = W_S(i, :) / row_sum;
        end
    end
    
    % 计算内部效用（子联盟内决策者效用）
    % 对于局部移情网络
    u_S_local = zeros(k, 1);
    for j = 1:k
        idx_j = S(j);
        u_S_local(j) = W_S(j,j)*uI(idx_j);
        for kk = 1:k
            if kk ~= j
                idx_kk = S(kk);
                u_S_local(j) = u_S_local(j) + W_S(j,kk)*uI(idx_kk) - C(idx_j, idx_kk);
            end
        end
    end
    
    % 对于全局移情网络（需要迭代计算）
    % 使用Jacobi迭代法求解子联盟内的全局效用
    u_S_global = zeros(k, 1);
    D_S = diag(diag(W_S));
    C_S = C(S, S);
    uI_S = uI(S);
    
    % 迭代求解
    max_iter = 1000;
    tol = 1e-6;
    for iter = 1:max_iter
        u_S_global_new = (W_S - D_S) * u_S_global + D_S * uI_S - C_S * ones(k,1);
        if norm(u_S_global_new - u_S_global, inf) < tol
            u_S_global = u_S_global_new;
            break;
        end
        u_S_global = u_S_global_new;
    end
    
    % 计算节省的成本（与联盟外成员的连接成本）
    saved_cost_local = 0;
    saved_cost_global = 0;
    for j = 1:k
        idx_j = S(j);
        for kk = 1:length(S_complement)
            idx_k = S_complement(kk);
            saved_cost_local = saved_cost_local + C(idx_j, idx_k);
            saved_cost_global = saved_cost_global + C(idx_j, idx_k);
        end
    end
    
    % 计算机会成本损失（失去的移情效用）
    opp_cost_local = 0;
    opp_cost_global = 0;
    for j = 1:k
        idx_j = S(j);
        for kk = 1:length(S_complement)
            idx_k = S_complement(kk);
            opp_cost_local = opp_cost_local + W(idx_j, idx_k) * uI(idx_k);
            opp_cost_global = opp_cost_global + W(idx_j, idx_k) * u_global(idx_k);
        end
    end
    
    % 计算联盟总效用
    v_local(s) = sum(u_S_local) + saved_cost_local - opp_cost_local;
    v_global(s) = sum(u_S_global) + saved_cost_global - opp_cost_global;
    
    % 单个决策者的联盟效用
    if length(S) == 1
        v_local(s) = u_local(S(1));
        v_global(s) = u_global(S(1));
    end
end

% 大联盟的效用（全部决策者）
full_set = ones(1, n);
full_idx = find(ismember(all_subsets, full_set, 'rows'));
if ~isempty(full_idx)
    v_local(full_idx) = sw_local;
    v_global(full_idx) = sw_global;
end

fprintf('计算完成: 共 %d 个子联盟\n', num_subsets);

%% 4. 构建合作博弈分配问题
fprintf('\n=== 4. 合作博弈分配问题求解 ===\n');

% 使用线性规划(LP2)求解分配方案
% min z = sum(d_S)
% s.t.:
%   (22a) sum(x_j) = v(N)
%   (22b) sum_{j in S} x_j + d_S - d_S^+ = v(S)
%   (22c) x_j >= v({j})
%   (22e) d_S, d_S^+ >= 0

% 对于局部移情网络
fprintf('\n--- 局部移情网络分配 ---\n');
[x_local, z_local] = solve_cooperative_game(n, all_subsets, v_local, sw_local);

fprintf('分配方案 x_local:\n');
disp(x_local');
fprintf('目标函数值 z = %.6f\n', z_local);

% 对于全局移情网络
fprintf('\n--- 全局移情网络分配 ---\n');
[x_global, z_global] = solve_cooperative_game(n, all_subsets, v_global, sw_global);

fprintf('分配方案 x_global:\n');
disp(x_global');
fprintf('目标函数值 z = %.6f\n', z_global);

%% 5. 核心检验
fprintf('\n=== 5. 核心检验 ===\n');

% 检验分配是否在核心中
[in_core_local, violations_local] = check_core(x_local, all_subsets, v_local);
[in_core_global, violations_global] = check_core(x_global, all_subsets, v_global);

fprintf('局部移情网络: ');
if in_core_local
    fprintf('分配在核心中\n');
else
    fprintf('分配不在核心中，有 %d 个联盟约束被违反\n', violations_local);
end

fprintf('全局移情网络: ');
if in_core_global
    fprintf('分配在核心中\n');
else
    fprintf('分配不在核心中，有 %d 个联盟约束被违反\n', violations_global);
end

%% 6. 结果可视化
fprintf('\n=== 6. 结果可视化 ===\n');

figure('Position', [100, 100, 1200, 500]);

% 子图1: 效用比较
subplot(1, 3, 1);
bar_data = [u_local, u_global, x_local, x_global];
bar(bar_data);
xlabel('决策者');
ylabel('效用值');
title('决策者效用与分配');
legend({'局部效用', '全局效用', '局部分配', '全局分配'}, 'Location', 'best');
grid on;

% 子图2: 社会福利分解
subplot(1, 3, 2);
pie([sw_local, sw_global]);
title('社会福利比较');
legend({'局部移情', '全局移情'}, 'Location', 'best');

% 子图3: 分配方案对比
subplot(1, 3, 3);
plot(1:n, x_local, 'b-o', 'LineWidth', 2, 'MarkerSize', 8);
hold on;
plot(1:n, x_global, 'r-s', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('决策者');
ylabel('分配值');
title('分配方案对比');
legend({'局部移情分配', '全局移情分配'}, 'Location', 'best');
grid on;

%% 辅助函数定义

function [x_opt, z_opt] = solve_cooperative_game(n, all_subsets, v, vN)
    % 求解合作博弈分配问题的线性规划
    
    num_subsets = size(all_subsets, 1);
    
    % 决策变量: [x1,...,xn, d1,...,d_m, d1+,...,d_m+]
    % m = num_subsets (不包括空集)
    num_vars = n + 2*num_subsets;
    
    % 目标函数: min sum(d_S)
    f = [zeros(1, n), ones(1, num_subsets), zeros(1, num_subsets)];
    
    % 约束条件
    Aeq = zeros(num_subsets + 1, num_vars);
    beq = zeros(num_subsets + 1, 1);
    
    % 约束(22a): sum(x_j) = v(N)
    Aeq(1, 1:n) = ones(1, n);
    beq(1) = vN;
    
    % 约束(22b): sum_{j in S} x_j + d_S - d_S^+ = v(S)
    for s = 1:num_subsets
        S = find(all_subsets(s,:));
        Aeq(s+1, S) = 1;
        Aeq(s+1, n+s) = 1;           % d_S
        Aeq(s+1, n+num_subsets+s) = -1; % d_S^+
        beq(s+1) = v(s);
    end
    
    % 不等式约束
    % 约束(22c): x_j >= v({j})
    A = zeros(n, num_vars);
    b = zeros(n, 1);
    
    for j = 1:n
        % 找到单个决策者j的联盟索引
        single_subset = zeros(1, n);
        single_subset(j) = 1;
        idx = find(ismember(all_subsets, single_subset, 'rows'));
        
        if ~isempty(idx)
            A(j, j) = -1; % x_j >= v({j}) 等价于 -x_j <= -v({j})
            b(j) = -v(idx);
        end
    end
    
    % 非负约束: d_S, d_S^+ >= 0
    lb = [-inf*ones(1, n), zeros(1, 2*num_subsets)];
    
    % 求解线性规划
    options = optimoptions('linprog', 'Display', 'off');
    [x_opt, z_opt] = linprog(f, A, b, Aeq, beq, lb, [], options);
    
    % 提取分配方案
    if ~isempty(x_opt)
        x_opt = x_opt(1:n);
    else
        x_opt = zeros(n, 1);
    end
end

function [in_core, violations] = check_core(x, all_subsets, v)
    % 检验分配是否在核心中
    
    num_subsets = size(all_subsets, 1);
    violations = 0;
    
    for s = 1:num_subsets
        S = find(all_subsets(s,:));
        if ~isempty(S)
            sum_x_S = sum(x(S));
            if sum_x_S < v(s) - 1e-6  % 考虑数值误差
                violations = violations + 1;
            end
        end
    end
    
    in_core = (violations == 0);
end