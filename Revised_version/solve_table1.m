%% Recalculate Table 1 with empathy-weighted maintenance costs
% 基准成本 / Baseline cost: C(j,k,i)
% 有效成本 / Effective cost: K = W .* C
% 行 j 为付费者 / Row j identifies the payer.

clc;clear;
%% 1. 可调整设置 / Configurable conventions
intrinsicMode = 'net';       % 'net' or 'gross'
secondCostMode = 'rank';     % 'rank' or 'alternative'

% net:
%   sum(uI) - sum(K(:))
% gross:
%   sum(uI)
%
% rank:
%   [0.9, 0.2, 1.4] correspond to best, second, worst.
% alternative:
%   [0.9, 0.2, 1.4] correspond to a1, a2, a3,
%   regardless of each payer's preference ranking.

assert(any(strcmp(intrinsicMode, {'net', 'gross'})), ...
    'intrinsicMode must be net or gross.');
assert(any(strcmp(secondCostMode, {'rank', 'alternative'})), ...
    'secondCostMode must be rank or alternative.');

%% 2. 网络与偏好 / Network and preferences
W = [0.4, 0.2, 0.4, 0.0;
     0.1, 0.2, 0.7, 0.0;
     0.2, 0.0, 0.2, 0.6;
     0.0, 0.0, 0.2, 0.8];

% rankPos(j,i): DM j's rank of alternative ai.
% 1 = best, 2 = second, 3 = worst.
% Columns: a1, a2, a3.
rankPos = [1, 2, 3;          % d1: a1 > a2 > a3
           1, 3, 2;          % d2: a1 > a3 > a2
           2, 1, 3;          % d3: a2 > a1 > a3
           3, 2, 1];         % d4: a3 > a2 > a1

utilityByRank = [20, 10, 0];
UI = utilityByRank(rankPos); % Rows: DMs; columns: alternatives

n = size(W, 1);
m = size(UI, 2);
tol = 1e-10;

assert(all(W(:) >= 0), 'Weights must be nonnegative.');
assert(all(diag(W) > 0), 'Self-weights must be positive.');
assert(max(abs(sum(W, 2) - 1)) < tol, ...
    'Each row of W must sum to one.');

D = diag(diag(W));
A = eye(n) - W + D;

% Only existing non-self edges incur maintenance costs.
edgeMask = W > 0;
edgeMask(1:n+1:end) = false;

%% 3. 三种成本情形 / Three cost scenarios
positiveByRank = [6, 4, 2];
secondPattern  = [4, 2, 6];

basePositive = positiveByRank(rankPos);

if strcmp(secondCostMode, 'rank')
    baseSecond = secondPattern(rankPos);
else
    baseSecond = repmat(secondPattern, n, 1);
end

% baseCost(j,i,s): baseline cost on each outgoing non-self edge
% of payer j, for alternative i, in scenario s.
%
% s = 1: No costs
% s = 2: Positively related costs
% s = 3: Second cost pattern
baseCost = cat(3, zeros(n, m), basePositive, baseSecond);

assert(all(baseCost(:) >= 0), 'Costs must be nonnegative.');

%% 4. 计算效用与福利 / Compute utilities and welfare
% Each scenario contributes three columns: Intrinsic, Local, Global.
R = zeros(m, 9);

% Detailed outputs retained in the MATLAB workspace.
C_all = zeros(n, n, m, 3);
directCost = zeros(n, m, 3);
U_local = zeros(n, m, 3);
U_global = zeros(n, m, 3);

for s = 1:3
    for i = 1:m
        % Same payer-specific baseline cost on all retained outgoing edges.
        C = repmat(baseCost(:, i, s), 1, n) .* edgeMask;

        % Apply empathy weights exactly once.
        K = W .* C;
        b = sum(K, 2);

        % Local: uL = W*uI - K*e
        uL = W * UI(:, i) - b;

        % Global: (I-W+D)*uG = D*uI - K*e
        % Solve directly; do not form an explicit inverse.
        rhs = D * UI(:, i) - b;
        uG = A \ rhs;

        % Check the global utility equation.
        assert(norm(A * uG - rhs, inf) <= ...
            tol * (1 + norm(rhs, inf)), ...
            'Global utility equation residual is too large.');

        intrinsicWelfare = sum(UI(:, i));
        if strcmp(intrinsicMode, 'net')
            intrinsicWelfare = intrinsicWelfare - sum(b);
        end

        cols = 3 * (s - 1) + (1:3);
        R(i, cols) = [intrinsicWelfare, sum(uL), sum(uG)];

        C_all(:, :, i, s) = C;
        directCost(:, i, s) = b;
        U_local(:, i, s) = uL;
        U_global(:, i, s) = uG;
    end
end

%% 5. 表1及各列最优方案 / Table 1 and column-wise maximizers
alternatives = {'a1'; 'a2'; 'a3'};
columnNames = {'No_I', 'No_L', 'No_G', ...
               'Pos_I', 'Pos_L', 'Pos_G', ...
               'Other_I', 'Other_L', 'Other_G'};

% Preserve full precision in Table1 and R.
Table1 = array2table(R, ...
    'VariableNames', columnNames, ...
    'RowNames', alternatives);

fprintf('\nIntrinsic mode: %s; second-cost mode: %s\n', ...
    intrinsicMode, secondCostMode);

% Print two decimal places without rounding stored results.
fprintf('%-4s', 'Alt');
for col = 1:9
    fprintf(' %10s', columnNames{col});
end
fprintf('\n');

for i = 1:m
    fprintf('%-4s', alternatives{i});
    fprintf(' %10.2f', R(i, :));
    fprintf('\n');
end

% Determine maxima using unrounded values; retain ties.
winnerMask = abs(bsxfun(@minus, R, max(R, [], 1))) <= 1e-9;

fprintf('\nMaximizing alternatives:\n');
for col = 1:9
    idx = find(winnerMask(:, col));
    fprintf('%-10s: %s\n', columnNames{col}, ...
        strjoin(alternatives(idx), ', '));
end

%% 6. 输出可复制的LaTeX表格行 / Print copyable LaTeX rows
% Maximum values in each column are automatically bolded.
slash = char(92);

fprintf('\nLaTeX rows:\n');
for i = 1:m
    lineText = ['$a_' num2str(i) '$'];

    for col = 1:9
        valueText = sprintf('%.2f', R(i, col));

        if winnerMask(i, col)
            valueText = [slash 'textbf{' valueText '}'];
        end

        lineText = [lineText ' & ' valueText];
    end

    fprintf('%s\n', [lineText ' ' slash slash]);
end