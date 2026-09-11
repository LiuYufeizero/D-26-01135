%% Table 2: ICE with empathy-weighted maintenance costs
% 不写入文件 / No files are written.
% 每行对应一个DM，每列对应一个方案。
% Rows: DMs; columns: alternatives.
clc;clear;

useWeightedCosts = true;  % false: old unweighted-cost model
alpha = 5;
maxIter = 1000;           % Safety cap, not a fixed stopping iteration
tol = 1e-10;

%% 1. 图2输入 / Inputs from Figure 2
W = [0.3, 0.7, 0.0;
     0.0, 0.3, 0.7;
     0.1, 0.0, 0.9];

UI = [10,  5;
      10,  5;
       5, 10];           % Columns: a1, a2

n = size(W, 1);
m = size(UI, 2);

assert(n == 3 && m == 2, ...
    'This table format requires 3 DMs and 2 alternatives.');
assert(all(W(:) >= 0) && all(diag(W) > 0));
assert(max(abs(sum(W, 2) - 1)) < tol);

% 基准成本 / BASELINE costs, not already weighted
C = zeros(n, n, m);

C(:, :, 1) = [0, 2, 0;
              0, 0, 2;
              1, 0, 0];

C(:, :, 2) = [0, 1, 0;
              0, 0, 1;
              2, 0, 0];

D = diag(diag(W));
B = W - D;
wMin = min(diag(W));
q = 1 - wMin;

costVector = zeros(n, m);
K = zeros(n, n, m);

for i = 1:m
    assert(all(diag(C(:, :, i)) == 0));

    if useWeightedCosts
        K(:, :, i) = W .* C(:, :, i);
    else
        K(:, :, i) = C(:, :, i);
    end

    costVector(:, i) = sum(K(:, :, i), 2);
end

%% 2. 常数项与淘汰阈值 / Constant term and threshold
% U(t+1) = B*U(t) + rhs
rhs = D * UI - costVector;

Delta = max(abs( ...
    D * (UI - alpha * ones(n, m)) - costVector), [], 1);

% Maximum Delta is taken over the ORIGINAL alternative set.
threshold0 = (2 * n / wMin) * max(Delta);

fprintf('Weighted costs: %d\n', useWeightedCosts);
fprintf('Delta(a1) = %.6f, Delta(a2) = %.6f\n', ...
    Delta(1), Delta(2));
fprintf('Threshold(t) = %.6f * %.6f^t\n', threshold0, q);

%% 3. ICE同步迭代 / Synchronous Jacobi updates
U = alpha * ones(n, m);
active = true(1, m);
eliminatedAt = nan(1, m);

% History index h corresponds to iteration t = h - 1.
Uhist = nan(n, m, maxIter + 1);
SWhist = nan(m, maxIter + 1);
GapHist = nan(m, maxIter + 1);
ThresholdHist = nan(1, maxIter + 1);

Uhist(:, :, 1) = U;
SWhist(:, 1) = sum(U, 1).';
GapHist(:, 1) = 0;
ThresholdHist(1) = threshold0;
tStop = 0;

for t = 1:maxIter
    if nnz(active) <= 1
        break
    end

    idx = find(active);

    % All DMs use the previous iteration's utilities.
    % 必须同步更新，不能在同一轮使用已更新的邻居效用。
    Uold = U;
    U(:, idx) = B * Uold(:, idx) + rhs(:, idx);

    sw = sum(U(:, idx), 1);
    gaps = max(sw) - sw;
    threshold = threshold0 * q^t;

    % Record this iteration BEFORE eliminating candidates.
    Uhist(:, idx, t + 1) = U(:, idx);
    SWhist(idx, t + 1) = sw.';
    GapHist(idx, t + 1) = gaps.';
    ThresholdHist(t + 1) = threshold;
    tStop = t;

    % Strict inequality; use unrounded values.
    removed = idx(gaps > threshold);
    active(removed) = false;
    eliminatedAt(removed) = t;
end

% Remove unused history columns.
keep = 1:(tStop + 1);
Uhist = Uhist(:, :, keep);
SWhist = SWhist(:, keep);
GapHist = GapHist(:, keep);
ThresholdHist = ThresholdHist(keep);
iterations = 0:tStop;

if nnz(active) == 1
    fprintf('\nICE stopped at t = %d; selected alternative: a%d\n', ...
        tStop, find(active));
else
    warning(['Iteration limit reached; ', ...
        'the remaining candidates are unresolved.']);
    disp(find(active));
end

%% 4. 直接解核验 / Direct solution for verification only
% The exact solution is NOT used in ICE elimination.
Uexact = (eye(n) - B) \ rhs;
SWexact = sum(Uexact, 1);

assert(norm((eye(n) - B) * Uexact - rhs, inf) < tol);

% Verify the theoretical welfare error bound at every recorded step.
for h = 1:numel(iterations)
    t = iterations(h);
    valid = ~isnan(SWhist(:, h)).';

    errors = abs(SWexact(valid) - SWhist(valid, h).');
    errorBounds = (n / wMin) * q^t * Delta(valid);

    assert(all(errors <= errorBounds + tol), ...
        'Welfare error bound failed.');
end

fprintf('Exact welfare: a1 = %.8f, a2 = %.8f\n', ...
    SWexact(1), SWexact(2));

if nnz(active) == 1
    assert(SWexact(active) >= max(SWexact) - tol);
end

%% 5. 按表2结构组织结果 / Format results as Table 2
Ncols = numel(iterations);
displayCells = cell(7, Ncols);

for h = 1:Ncols
    for j = 1:n
        displayCells{j, h} = sprintf('%.4f, %.4f', ...
            Uhist(j, 1, h), Uhist(j, 2, h));
    end

    displayCells{4, h} = sprintf('%.4f, %.4f', ...
        SWhist(1, h), SWhist(2, h));

    displayCells{5, h} = sprintf('%.4f', GapHist(1, h));
    displayCells{6, h} = sprintf('%.4f', GapHist(2, h));
    displayCells{7, h} = sprintf('%.4f', ThresholdHist(h));
end

% Initial gaps equal zero; show dashes as in the manuscript.
displayCells{5, 1} = '-';
displayCells{6, 1} = '-';

columnNames = arrayfun(@(t) sprintf('t%d', t), iterations, ...
    'UniformOutput', false);

rowNames = {'u1_a1_a2', 'u2_a1_a2', 'u3_a1_a2', ...
            'sw_a1_a2', 'gap_a1', 'gap_a2', 'threshold'};

Table2 = cell2table(displayCells, ...
    'VariableNames', columnNames, ...
    'RowNames', rowNames);

disp(Table2);

%% 6. 输出LaTeX表格行 / Print copyable LaTeX rows
bs = char(92);

latexLabels = { ...
    '$u_1^{(t)}(a_1),u_1^{(t)}(a_2)$', ...
    '$u_2^{(t)}(a_1),u_2^{(t)}(a_2)$', ...
    '$u_3^{(t)}(a_1),u_3^{(t)}(a_2)$', ...
    '$sw^{(t)}(a_1),sw^{(t)}(a_2)$', ...
    ['$' bs 'widehat{sw}^{(t)}-sw^{(t)}(a_1)$'], ...
    ['$' bs 'widehat{sw}^{(t)}-sw^{(t)}(a_2)$'], ...
    ['$' sprintf('%.6g', threshold0) ...
        '(' sprintf('%.6g', q) ')^t$']};

fprintf('\nLaTeX rows:\n');

timeEntries = arrayfun(@num2str, iterations, ...
    'UniformOutput', false);

fprintf('%s\n', ...
    ['$t=$ & ' strjoin(timeEntries, ' & ') ' ' bs bs]);

for r = 1:7
    fprintf('%s\n', [latexLabels{r} ' & ' ...
        strjoin(displayCells(r, :), ' & ') ' ' bs bs]);
end