%% ICE算法 - 寻找社会最优方案
% 基于"考虑维护成本的移情网络决策模型与社会福利分配"文档实现
% 全局移情网络中社会福利最大化的迭代候选消除算法

%% 初始化参数
clear;
clc;
close all;

% 决策者数量和方案数量
n = 12; % 决策者数量
m = 8;  % 方案数量

% 初始化存储数组
max_iterations = 1000; % 防止无限循环
sw_per_iteration = nan(m, max_iterations+1); % 使用NaN初始化，淘汰后不再记录
THRESHOLD = zeros(1, max_iterations);
DIFF = nan(m, max_iterations); % 使用NaN初始化

% 移情矩阵W (n×n)，行和为1
W = [    0.2700,    0.7300,        0,         0 ,        0,         0,         0,         0,         0,         0 ,        0 ,        0;
         0.5200,    0.2500,    0.0500,    0.0300,    0.0700,         0,    0.0100,    0.0500,         0,    0.0100,         0 ,   0.0100;
         0.4600,         0,    0.3100,    0.0100,    0.1100,    0.0500,    0.0100,    0.0100,    0.0400,         0,         0 ,        0;
         0,    0.3800,    0.0600,    0.4400,         0,         0,         0,         0,         0,         0,    0.1200,         0;
         0,    0.3200,    0.1400 ,        0,    0.5400,         0,         0,         0,         0,         0,         0,         0;
         0,         0,         0,         0,    0.6400,    0.3600,         0,         0,         0,         0,         0,         0;
         0,    0.3000,    0.1000,         0,         0,         0,    0.4400,         0,    0.1600,         0,         0,         0;
         0,    0.5600,    0.0500,         0,         0,         0,         0,    0.3900,         0,         0,         0,         0;
         0,         0,         0,         0,         0,         0,    0.4900,         0,    0.4100,         0,         0,    0.1000;
         0,    0.2000,    0.0200,         0,         0,         0,         0,         0,         0,    0.4400,    0.3400,         0;
         0,         0,         0,    0.1500,         0,        0,         0 ,        0,         0 ,   0.3300 ,   0.5200 ,        0;
         0,    0.3400,         0 ,        0,         0,         0,         0,         0,    0.5200 ,        0,         0 ,   0.1400];



% W = [0.42,  0.12,	0.13,	0.12,	0.09,	0,	    0,	    0, 	    0.12,	0,      0,	    0;
%      0.14,	0.53,	0.15,	0,	    0,	    0,	    0.08,   0, 	    0,	    0,      0.1,    0;
%      0.01,  0.04,	0.46,	0.05,	0.1,	0.03,	0.06,	0.11,	0.06,	0.07,	0.01,	0;
%      0.25,	0,  	0.18,	0.41,	0,	    0,	    0,	    0,	    0,	    0,	    0,	    0.16;
%      0.07,	0,	    0.06,	0,	    0.46,	0.09,	0,	    0.14,	0,	    0,	    0,	    0.18;
%      0,	    0,  	0.32,	0,	    0.42,	0.26,	0,	    0,	    0,	    0,	    0,	    0;
%      0, 	0.22,	0.24,	0,	    0,   	0,	    0.28,	0,  	0,	    0.26,	0,	    0;
%      0,	    0,	    0.71,	0,	    0.08,	0,	    0,	    0.21,	0,	    0,	    0,	    0;
%      0.57,	0,	    0.19,	0,	    0,	    0,	    0,	    0,	    0.24,	0,	    0,	    0;
%      0, 	0,	    0.15,	0,	    0,	    0,	    0.43,	0,	    0,	    0.42,	0,	    0;
%      0,	    0.09,	0.77,	0,	    0,	    0,	    0,	    0,	    0,	    0,	    0.14,	0;
%      0,	    0,	    0,	    0.32,	0.36,	0,	    0,	    0,	    0,	    0,	    0,	0.32];

% 验证移情矩阵行和是否为1
for j = 1:n
    if abs(sum(W(j,:)) - 1) > 1e-10
        error('移情矩阵第%d行和不为1', j);
    end
end

% 内在效用矩阵 uI (n×m)
% 决策者对方案的内在偏好效用
uI = [90-40, 90-20, 90-70, 90-30, 90-60, 90-10, 90-50, 90-80;   % 决策者1
      90-20, 90-70, 90-60, 90-30, 90-40, 90-80, 90-10, 90-50;   % 决策者2
      90-60, 90-20, 90-40, 90-10, 90-80, 90-70, 90-50, 90-30;   % 决策者3
      90-50, 90-10, 90-70, 90-30, 90-80, 90-40, 90-20, 90-20;   % 决策者4
      90-70, 90-20, 90-10, 90-80, 90-30, 90-50, 90-40, 90-60;   % 决策者5
      90-50, 90-60, 90-10, 90-30, 90-70, 90-20, 90-80, 90-40;   % 决策者6
      90-50, 90-20, 90-40, 90-70, 90-30, 90-60, 90-10, 90-80;   % 决策者7
      90-50, 90-10, 90-60, 90-80, 90-30, 90-40, 90-70, 90-20;   % 决策者8
      90-70, 90-80, 90-30, 90-50, 90-60, 90-20, 90-10, 90-40;   % 决策者9
      90-10, 90-30, 90-70, 90-50, 90-60, 90-40, 90-20, 90-80;   % 决策者10
      90-50, 90-80, 90-60, 90-30, 90-40, 90-70, 90-20, 90-10;   % 决策者11
      90-10, 90-30, 90-40, 90-60, 90-50, 90-80, 90-70, 90-20];  % 决策者12

% 维护成本矩阵 C (每个方案一个n×n矩阵)
C = cell(1, m);
C{1} = [
0,4,0,0,0,0,0,0,0,0,0,0 ;
2,0,2,3,4,0,3,5,0,4,0,3 ;
2,0,0,2,4,3,1,2,4,0,0,0 ;
0,1,1,0,0,0,0,0,0,0,3,0 ;
0,3,4,0,0,0,0,0,0,0,0,0 ;
0,0,0,0,5,0,0,0,0,0,0,0 ;
0,4,4,0,0,0,0,0,4,0,0,0 ;
0,2,2,0,0,0,0,0,0,0,0,0 ;
0,0,0,0,0,0,2,0,0,0,0,2 ;
0,4,1,0,0,0,0,0,0,0,3,0 ;
0,0,0,3,0,0,0,0,0,3,0,0 ;
0,3,0,0,0,0,0,0,2,0,0,0];

C{2} = [
0,1,0,0,0,0,0,0,0,0,0,0 ;
4,0,3,3,2,0,2,4,0,2,0,2 ;
4,0,0,3,1,2,5,3,1,0,0,0 ;
0,1,4,0,0,0,0,0,0,0,4,0 ;
0,5,4,0,0,0,0,0,0,0,0,0 ;
0,0,0,0,2,0,0,0,0,0,0,0 ;
0,3,3,0,0,0,0,0,1,0,0,0 ;
0,3,3,0,0,0,0,0,0,0,0,0 ;
0,0,0,0,0,0,5,0,0,0,0,5 ;
0,5,2,0,0,0,0,0,0,0,1,0 ;
0,0,0,2,0,0,0,0,0,4,0,0 ;
0,1,0,0,0,0,0,0,5,0,0,0];

C{3} = [
0,3,0,0,0,0,0,0,0,0,0,0;
1,0,4,1,1,0,4,3,0,3,0,3;
3,0,0,2,1,5,1,5,3,0,0,0;
0,3,5,0,0,0,0,0,0,0,1,0;
0,2,5,0,0,0,0,0,0,0,0,0;
0,0,0,0,5,0,0,0,0,0,0,0;
0,5,2,0,0,0,0,0,3,0,0,0;
0,2,5,0,0,0,0,0,0,0,0,0;
0,0,0,0,0,0,2,0,0,0,0,2;
0,1,4,0,0,0,0,0,0,0,1,0;
0,0,0,1,0,0,0,0,0,5,0,0;
0,1,0,0,0,0,0,0,1,0,0,0];

C{4} = [
0,1,0,0,0,0,0,0,0,0,0,0 ;
1,0,1,1,4,0,2,3,0,1,0,3 ;
3,0,0,5,5,2,5,1,1,0,0,0 ;
0,3,3,0,0,0,0,0,0,0,3,0 ;
0,4,4,0,0,0,0,0,0,0,0,0 ;
0,0,0,0,2,0,0,0,0,0,0,0 ;
0,4,5,0,0,0,0,0,4,0,0,0 ;
0,4,3,0,0,0,0,0,0,0,0,0 ;
0,0,0,0,0,0,1,0,0,0,0,5 ;
0,5,4,0,0,0,0,0,0,0,4,0 ;
0,0,0,3,0,0,0,0,0,1,0,0 ;
0,5,0,0,0,0,0,0,2,0,0,0];

C{5} = [
0,3,0,0,0,0,0,0,0,0,0,0 ;
1,0,1,4,3,0,1,3,0,4,0,4 ;
3,0,0,5,1,1,1,4,1,0,0,0 ;
0,3,5,0,0,0,0,0,0,0,1,0 ;
0,4,2,0,0,0,0,0,0,0,0,0 ;
0,0,0,0,5,0,0,0,0,0,0,0 ;
0,1,1,0,0,0,0,0,4,0,0,0 ;
0,2,3,0,0,0,0,0,0,0,0,0 ;
0,0,0,0,0,0,2,0,0,0,0,4 ;
0,2,5,0,0,0,0,0,0,0,4,0 ;
0,0,0,2,0,0,0,0,0,4,0,0 ;
0,5,0,0,0,0,0,0,2,0,0,0
];

C{6} = [
0,5,0,0,0,0,0,0,0,0,0,0 ;
2,0,1,1,2,0,4,4,0,4,0,2 ;
1,0,0,2,1,4,2,2,3,0,0,0 ;
0,4,5,0,0,0,0,0,0,0,1,0 ;
0,4,5,0,0,0,0,0,0,0,0,0 ;
0,0,0,0,3,0,0,0,0,0,0,0 ;
0,3,4,0,0,0,0,0,5,0,0,0 ;
0,1,5,0,0,0,0,0,0,0,0,0 ;
0,0,0,0,0,0,3,0,0,0,0,4 ;
0,2,1,0,0,0,0,0,0,0,1,0 ;
0,0,0,1,0,0,0,0,0,4,0,0 ;
0,3,0,0,0,0,0,0,5,0,0,0
];

C{7} = [
0,3,0,0,0,0,0,0,0,0,0,0 ;
2,0,4,1,5,0,3,5,0,1,0,1 ;
1,0,0,4,1,1,3,2,1,0,0,0 ;
0,5,2,0,0,0,0,0,0,0,5,0 ;
0,3,2,0,0,0,0,0,0,0,0,0 ;
0,0,0,0,4,0,0,0,0,0,0,0 ;
0,3,1,0,0,0,0,0,3,0,0,0 ;
0,4,1,0,0,0,0,0,0,0,0,0 ;
0,0,0,0,0,0,2,0,0,0,0,2 ;
0,5,1,0,0,0,0,0,0,0,2,0 ;
0,0,0,5,0,0,0,0,0,3,0,0 ;
0,4,0,0,0,0,0,0,2,0,0,0
];

C{8} = [
0,1,0,0,0,0,0,0,0,0,0,0 ;
2,0,3,1,3,0,5,2,0,1,0,5 ;
4,0,0,4,1,5,1,3,2,0,0,0 ;
0,2,4,0,0,0,0,0,0,0,5,0 ;
0,4,5,0,0,0,0,0,0,0,0,0 ;
0,0,0,0,3,0,0,0,0,0,0,0 ;
0,4,4,0,0,0,0,0,1,0,0,0 ;
0,1,3,0,0,0,0,0,0,0,0,0 ;
0,0,0,0,0,0,5,0,0,0,0,5 ;
0,4,2,0,0,0,0,0,0,0,5,0 ;
0,0,0,5,0,0,0,0,0,3,0,0 ;
0,5,0,0,0,0,0,0,1,0,0,0    
];

% 效用边界参数
c = 10;   % 内在效用下界
d = 80;   % 内在效用上界

% 方案集合
A = 1:m; % 方案编号

%% ICE算法主循环
fprintf('开始ICE算法执行...\n');
fprintf('决策者数量: %d, 方案数量: %d\n', n, m);

% 初始化候选方案集
A_prime = A;
fprintf('初始候选方案集: ');
disp(A_prime);

% 计算最小自环权重
w_tilde = min(diag(W));
fprintf('最小自环权重 w_tilde = %.6f\n', w_tilde);

% 初始化迭代效用矩阵
u_prev = zeros(n, m);
for i = 1:m
    u_prev(:, i) = c * ones(n, 1);
end

% 记录哪些方案在每个迭代中仍然存活
active_schemes = true(m, max_iterations+1); % 记录每个方案在每个迭代是否存活
for i = 1:m
    active_schemes(i, 1) = true; % 初始时所有方案都存活
end

% 计算初始社会福利(t=0)
for i = 1:m
    sw_per_iteration(i, 1) = n * c;  % t=0时的社会福利
end

t = 0;
converged = false;

% 主迭代循环
while length(A_prime) > 1 && t < max_iterations
    t = t + 1;
    fprintf('\n=== 第 %d 次迭代 ===\n', t);
    
    % 初始化当前迭代的社会福利数组
    sw_t = zeros(1, m);
    u_current = zeros(n, m);
    
    %% 计算每个候选方案的迭代效用和社会福利
    for idx = 1:length(A_prime)
        a_i = A_prime(idx);  % 当前候选方案的原始编号
        sw_current = 0;
        
        fprintf('计算方案 a%d 的效用...\n', a_i);
        
        for j = 1:n
            % 内在效用部分
            intrinsic_part = W(j,j) * uI(j, a_i);
            
            % 移情效用部分：∑_{k≠j} w_jk * u_k^{(t-1)}(a_i)
            empathetic_part = 0;
            for k = 1:n
                if k ~= j
                    empathetic_part = empathetic_part + W(j,k) * u_prev(k, a_i);
                end
            end
            
            % 维护成本部分：∑_{k≠j} c_jk(a_i)
            cost_part = 0;
            for k = 1:n
                if k ~= j
                    cost_part = cost_part + C{a_i}(j,k);
                end
            end
            
            % 更新当前效用
            u_current(j, a_i) = intrinsic_part + empathetic_part - cost_part;
            sw_current = sw_current + u_current(j, a_i);
            
            fprintf('  决策者 d%d: 内在%.6f + 移情%.6f - 成本%.6f = 总效用%.6f\n', ...
                j, intrinsic_part, empathetic_part, cost_part, u_current(j, a_i));
        end
        
        sw_t(a_i) = sw_current;
        fprintf('方案 a%d 的社会福利: %.6f\n', a_i, sw_current);
        
        % 记录社会福利（使用方案原始编号作为索引）
        sw_per_iteration(a_i, t+1) = sw_current;
    end
    
    %% 确定最大社会福利和淘汰阈值
    sw_values = sw_t(A_prime);
    if isempty(sw_values)
        break;
    end
    sw_hat = max(sw_values);
    threshold = 2 * n * (d - c) * (1 - w_tilde)^t;
    THRESHOLD(t) = threshold;
    
    fprintf('最大社会福利: %.6f\n', sw_hat);
    fprintf('淘汰阈值: %.6f\n', threshold);
    
    %% 淘汰被支配的方案
    to_remove = [];
    for idx = 1:length(A_prime)
        a_i = A_prime(idx);
        diff = sw_hat - sw_t(a_i);
        
        % 记录差值（使用方案原始编号作为索引）
        DIFF(a_i, t) = diff;
        
        fprintf('方案 a%d 与最大社会福利差值: %.6f', a_i, diff);
        
        if diff >= threshold
            to_remove = [to_remove, idx];
            fprintf(' → 淘汰\n');
            
            % 标记该方案在淘汰后的迭代中不再存活
            active_schemes(a_i, t+1:end) = false;
            
            % 将被淘汰方案在淘汰后的社会福利和差值设置为NaN
            sw_per_iteration(a_i, t+1:end) = NaN;
            if t < max_iterations
                DIFF(a_i, t+1:end) = NaN;
            end
        else
            fprintf(' → 保留\n');
            % 标记该方案在当前迭代仍然存活
            active_schemes(a_i, t+1) = true;
        end
    end
    
    % 更新候选方案集
    if ~isempty(to_remove)
        A_prime(to_remove) = [];
        fprintf('淘汰后候选方案集: ');
        disp(A_prime);
    else
        fprintf('本轮无方案被淘汰\n');
    end
    
    % 更新迭代效用
    u_prev = u_current;
    
    % 检查收敛条件
    if length(A_prime) == 1
        fprintf('找到社会最优方案!\n');
        converged = true;
        break;
    end
end

%% 输出最终结果
if converged
    a_opt = A_prime(1);
    fprintf('\n======= ICE算法执行完成 =======\n');
    fprintf('社会最优方案: a%d\n', a_opt);
    fprintf('总迭代次数: %d\n', t);
    fprintf('最终社会福利: %.6f\n', sw_t(a_opt));
    
    % 显示各决策者在最优方案下的最终效用
    fprintf('\n各决策者在最优方案 a%d 下的效用:\n', a_opt);
    for j = 1:n
        fprintf('  决策者 d%d: %.6f\n', j, u_current(j, a_opt));
    end
else
    fprintf('算法未收敛到唯一解，剩余候选方案: ');
    disp(A_prime);
end

%% 算法性能分析
fprintf('\n======= 算法性能分析 =======\n');
fprintf('收敛速度因子 (1-w_tilde): %.6f\n', 1-w_tilde);
fprintf('理论最大误差上界: %.6f\n', n*(d-c)*(1-w_tilde)^t);

%% 可视化部分
% 只取实际迭代次数的数据
actual_iterations = t;
TT = 0:actual_iterations;
colors = lines(m+1);
markers = {'o', 's', 'p', 'h', 'd', '^', 'v', '>', '<'};

% 计算真实社会福利
e = ones(n, 1);
I = eye(n);
D = diag(diag(W));
A_mat = I - W + D;
Ainv = inv(A_mat);
omega_global = e' * Ainv * D;

sw_true = zeros(1, m);
C_global = cell(1, m);
for i = 1:m
    C_global{i} = Ainv * C{i};
    sw_true(i) = omega_global * uI(:, i) - e'*C_global{i}*e;
end

% 可视化 估计社会福利随迭代变化

% 子图1：估计社会福利随迭代的变化
figure(1);
for a_idx = 1:m
    % 只绘制存活方案的数据点
    % 找到该方案存活的最后一个迭代
    last_active_iter = find(active_schemes(a_idx, 1:actual_iterations+1), 1, 'last');
    
    if ~isempty(last_active_iter)
        % 只绘制到该方案存活的最后一个迭代
        plot_data = sw_per_iteration(a_idx, 1:last_active_iter);
        plot_x = 0:(last_active_iter-1);
        
        if last_active_iter > 1
            plot(plot_x, plot_data, ...
                 [markers{a_idx} '-'], ...
                 'Color', colors(a_idx, :), ...
                 'LineWidth', 1.5, ...
                 'MarkerSize', 8, ...
                 'DisplayName', sprintf('Alternative $a_{%d}$', a_idx));
            hold on;
            
            % % 在淘汰点添加标记（如果被淘汰）
            % if last_active_iter <= actual_iterations && ~active_schemes(a_idx, actual_iterations+1)
            %     plot(plot_x(end), plot_data(end), 'x', ...
            %          'Color', colors(a_idx, :), ...
            %          'MarkerSize', 10, ...
            %          'LineWidth', 2, ...
            %          'HandleVisibility', 'off');
            % end
        end
    end
end

% 添加真实值参考线
for a_idx = 1:m
    plot([0, actual_iterations], [sw_true(a_idx), sw_true(a_idx)], ':', ...
         'Color', colors(a_idx, :), ...
         'LineWidth', 1.5, ...
         'HandleVisibility', 'off');
end

legend('Location', 'best', 'Interpreter', 'latex');
xlabel('$t$', 'Interpreter', 'latex');
ylabel('$s{w^{\left( t \right)}}\left( {{a_i}} \right)$', 'Interpreter', 'latex');
% grid on;
set(gca, 'XTick', 0:1:actual_iterations);
xlim([0, actual_iterations]);

set(gcf, 'PaperPositionMode', 'auto');

% print('-depsc', 'ICE_iterative_value.eps');

% 子图2：社会福利差异vs消除阈值
figure(2);
for a_idx = 1:m
    % 只绘制存活方案的差异数据
    % 找到该方案在DIFF中有数据的最后一个迭代
    valid_diff_indices = find(~isnan(DIFF(a_idx, 1:actual_iterations)));
    
    if ~isempty(valid_diff_indices)
        plot(valid_diff_indices, DIFF(a_idx, valid_diff_indices), ...
             [markers{a_idx} '-'], ...
             'Color', colors(a_idx, :), ...
             'LineWidth', 1.5, ...
             'MarkerSize', 8, ...
             'DisplayName', sprintf('Alternative $a_{%d}$', a_idx));
        hold on;
        
        % % 在淘汰点添加标记
        % if max(valid_diff_indices) < actual_iterations
        %     plot(valid_diff_indices(end), DIFF(a_idx, valid_diff_indices(end)), 'x', ...
        %          'Color', colors(a_idx, :), ...
        %          'MarkerSize', 10, ...
        %          'LineWidth', 2, ...
        %          'HandleVisibility', 'off');
        % end
    end
end

plot(1:actual_iterations, THRESHOLD(1:actual_iterations), 'k--', ...
     'LineWidth', 2, ...
     'DisplayName', '$2n\left( {d - c} \right)\left( {1 - \tilde w} \right)^t$');

legend('Location', 'best', 'Interpreter', 'latex');
xlabel('$t$', 'Interpreter', 'latex');
ylabel('${\widehat {sw}^{\left( t \right)}} - s{w^{\left( t \right)}}\left( {{a_i}} \right)$', 'Interpreter', 'latex');
% grid on;
set(gca, 'XTick', 1:actual_iterations);
xlim([1, actual_iterations]);

set(gcf, 'PaperPositionMode', 'auto');

% print('-depsc', 'ICE_elimination_threshold.eps');