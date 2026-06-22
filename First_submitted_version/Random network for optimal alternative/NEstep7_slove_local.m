clc; clear; close all;

%% 输入数据：联盟效用值（局部移情网络）
v_local = struct();

% 单人联盟
v_local.S0 = 0;
v_local.S1 = 2.40;
v_local.S2 = -12.20;
v_local.S3 = 13.80;
v_local.S4 = 6.20;

% 两人联盟
v_local.S5 = -12.00;   % {1,2}
v_local.S6 = 24.00;    % {1,3}
v_local.S7 = 8.60;     % {1,4}
v_local.S8 = 28.36;    % {2,3}
v_local.S9 = -6.00;    % {2,4}
v_local.S10 = 22.30;   % {3,4}

% 三人联盟
v_local.S11 = 32.80;   % {1,2,3}
v_local.S12 = -5.80;   % {1,2,4}
v_local.S13 = 37.00;   % {1,3,4}
v_local.S14 = 36.86;   % {2,3,4}

% 大联盟
v_local.N = 45.80;

%% 设置决策变量
% 顺序：x1, x2, x3, x4, d5, d6, d7, d8, d9, d10, d11, d12, d13, d14, 
%       d5_plus, d6_plus, d7_plus, d8_plus, d9_plus, d10_plus, d11_plus, 
%       d12_plus, d13_plus, d14_plus
n_vars = 4 + 10 + 10;  % 4个x，10个d，10个d^+
n = 4;                 % 玩家数量

%% 目标函数：min z = sum(d_S)
f = zeros(n_vars, 1);
for i = (n+1):(n+10)
    f(i) = 1;  % 对应d5到d14
end

%% 等式约束
Aeq = [];
beq = [];

% 1. 大联盟约束：x1 + x2 + x3 + x4 = v(N)
Aeq1 = [1, 1, 1, 1, zeros(1, n_vars-4)];
beq1 = v_local.N;
Aeq = [Aeq; Aeq1];
beq = [beq; beq1];

% 2. 10个联盟约束：∑_{j∈Sm} xj + d_Sm - d_Sm^+ = v(Sm)
% 联盟S5 = {1,2}
Aeq2 = zeros(1, n_vars);
Aeq2([1,2]) = 1;           % x1 + x2
Aeq2(5) = 1;               % d5
Aeq2(15) = -1;             % -d5^+
beq2 = v_local.S5;
Aeq = [Aeq; Aeq2];
beq = [beq; beq2];

% 联盟S6 = {1,3}
Aeq3 = zeros(1, n_vars);
Aeq3([1,3]) = 1;           % x1 + x3
Aeq3(6) = 1;               % d6
Aeq3(16) = -1;             % -d6^+
beq3 = v_local.S6;
Aeq = [Aeq; Aeq3];
beq = [beq; beq3];

% 联盟S7 = {1,4}
Aeq4 = zeros(1, n_vars);
Aeq4([1,4]) = 1;           % x1 + x4
Aeq4(7) = 1;               % d7
Aeq4(17) = -1;             % -d7^+
beq4 = v_local.S7;
Aeq = [Aeq; Aeq4];
beq = [beq; beq4];

% 联盟S8 = {2,3}
Aeq5 = zeros(1, n_vars);
Aeq5([2,3]) = 1;           % x2 + x3
Aeq5(8) = 1;               % d8
Aeq5(18) = -1;             % -d8^+
beq5 = v_local.S8;
Aeq = [Aeq; Aeq5];
beq = [beq; beq5];

% 联盟S9 = {2,4}
Aeq6 = zeros(1, n_vars);
Aeq6([2,4]) = 1;           % x2 + x4
Aeq6(9) = 1;               % d9
Aeq6(19) = -1;             % -d9^+
beq6 = v_local.S9;
Aeq = [Aeq; Aeq6];
beq = [beq; beq6];

% 联盟S10 = {3,4}
Aeq7 = zeros(1, n_vars);
Aeq7([3,4]) = 1;           % x3 + x4
Aeq7(10) = 1;              % d10
Aeq7(20) = -1;             % -d10^+
beq7 = v_local.S10;
Aeq = [Aeq; Aeq7];
beq = [beq; beq7];

% 联盟S11 = {1,2,3}
Aeq8 = zeros(1, n_vars);
Aeq8([1,2,3]) = 1;         % x1 + x2 + x3
Aeq8(11) = 1;              % d11
Aeq8(21) = -1;             % -d11^+
beq8 = v_local.S11;
Aeq = [Aeq; Aeq8];
beq = [beq; beq8];

% 联盟S12 = {1,2,4}
Aeq9 = zeros(1, n_vars);
Aeq9([1,2,4]) = 1;         % x1 + x2 + x4
Aeq9(12) = 1;              % d12
Aeq9(22) = -1;             % -d12^+
beq9 = v_local.S12;
Aeq = [Aeq; Aeq9];
beq = [beq; beq9];

% 联盟S13 = {1,3,4}
Aeq10 = zeros(1, n_vars);
Aeq10([1,3,4]) = 1;        % x1 + x3 + x4
Aeq10(13) = 1;             % d13
Aeq10(23) = -1;            % -d13^+
beq10 = v_local.S13;
Aeq = [Aeq; Aeq10];
beq = [beq; beq10];

% 联盟S14 = {2,3,4}
Aeq11 = zeros(1, n_vars);
Aeq11([2,3,4]) = 1;        % x2 + x3 + x4
Aeq11(14) = 1;             % d14
Aeq11(24) = -1;            % -d14^+
beq11 = v_local.S14;
Aeq = [Aeq; Aeq11];
beq = [beq; beq11];

%% 不等式约束：xj >= v({j})
A = zeros(4, n_vars);
b = zeros(4, 1);

% x1 >= v({1})
A(1,1) = -1;  % 转换为 -x1 <= -v({1}) 形式
b(1) = -v_local.S1;

% x2 >= v({2})
A(2,2) = -1;
b(2) = -v_local.S2;

% x3 >= v({3})
A(3,3) = -1;
b(3) = -v_local.S3;

% x4 >= v({4})
A(4,4) = -1;
b(4) = -v_local.S4;

%% 变量边界
% d_S >= 0, d_S^+ >= 0
lb = zeros(n_vars, 1);
ub = inf(n_vars, 1);

% x_j 无上界，下界由不等式约束已保证
lb(1) = -inf;
lb(2) = -inf;
lb(3) = -inf;
lb(4) = -inf;

%% 求解线性规划
options = optimoptions('linprog', 'Display', 'off');
[x_opt, min_z, exitflag] = linprog(f, A, b, Aeq, beq, lb, ub, options);

%% 输出结果
if exitflag == 1
    fprintf('========== 线性规划求解结果 ==========\n');
    fprintf('最小目标函数值 min z = %.4f\n\n', min_z);
    
    fprintf('最优解 x*：\n');
    for i = 1:n
        fprintf('  x*_%d = %.4f\n', i, x_opt(i));
    end
    
    % 验证：输出各联盟的偏差
    fprintf('\n各联盟偏差 d_S：\n');
    coalition_names = {'S5', 'S6', 'S7', 'S8', 'S9', 'S10', 'S11', 'S12', 'S13', 'S14'};
    for i = 1:10
        fprintf('  %s: d = %.4f, d^+ = %.4f\n', ...
            coalition_names{i}, x_opt(n+i), x_opt(n+10+i));
    end
    
    % 验证大联盟约束
    fprintf('\n验证大联盟约束：\n');
    fprintf('  Σ x*_j = %.4f, v(N) = %.4f\n', sum(x_opt(1:n)), v_local.N);
    
else
    fprintf('求解失败，退出标志：%d\n', exitflag);
end