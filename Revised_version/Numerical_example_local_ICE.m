%% solve_table3.m
% 表3：局部移情网络下各方案的社会福利
% Table 3: social welfare in local empathetic networks
%
% Revised model:
%   K(a_i)       = W .* C(a_i)
%   u_local(a_i) = W*u_I(a_i) - K(a_i)*ones(n,1)
%   sw_local    = sum(u_local(a_i))
%
% Self-maintenance costs:
%   c_jj(a_i) = 0
%
% One ICE update with u^(0) = u_I gives the exact local utility.
% No dense n-by-n cost matrices are constructed.
%
% MATLAB R2024b
% This script does not write output files.

clear;
clc;

%% 1. 参数设置 / Configuration

% 默认读取本脚本所在目录中的 Empirical Example 文件夹。
% Read datasets from the folder next to this script.
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end

dataDir = fullfile(scriptDir, 'Empirical Example');

datasetFiles = { ...
    'Karate.txt', ...
    'PolBK.gml', ...
    'LastFM.txt', ...
    'Amazon.txt', ...
    'Dblp.txt'};

datasetNames = ["Karate", "PolBK", "LastFM", "Amazon", "Dblp"];

expectedNodes = [34, 105, 7624, 334863, 317080];
expectedEdges = [78, 441, 27806, 925872, 1049866];

numberOfAlternatives = 8;

theta = 0.4;
preferenceSeed = 100;
costSeeds = 123:130;

% 基础成本取值 / Baseline costs: {0,1,2}.
maximumEdgeCost = 5;

% 排名对应效用 / Utilities by preference rank:
% 1 -> 80, 2 -> 75, ..., 8 -> 45.
utilityByRank = 80:-10:10;

assert(isfolder(dataDir), ...
    'Data folder not found: %s', dataDir);

assert(theta > 0 && theta <= 1, ...
    'theta must satisfy 0 < theta <= 1.');

assert(numel(costSeeds) == numberOfAlternatives, ...
    'One maintenance-cost seed is required for each alternative.');

assert(numel(utilityByRank) == numberOfAlternatives, ...
    'One utility value is required for each preference rank.');

%% 2. 结果数组 / Result arrays

numberOfDatasets = numel(datasetFiles);

nodeCount = zeros(numberOfDatasets, 1);
edgeCount = zeros(numberOfDatasets, 1);

welfareValues = nan(numberOfDatasets, numberOfAlternatives);
maximumWelfare = nan(numberOfDatasets, 1);
optimalAlternative = strings(numberOfDatasets, 1);

elapsedSeconds = nan(numberOfDatasets, 1);
verificationErrors = nan(numberOfDatasets, 1);

%% 3. 逐个网络计算 / Evaluate each network

for datasetIndex = 1:numberOfDatasets

    datasetPath = fullfile( ...
        dataDir, datasetFiles{datasetIndex});

    assert(isfile(datasetPath), ...
        'Dataset file not found: %s', datasetPath);

    fprintf('\nProcessing %s ...\n', ...
        char(datasetNames(datasetIndex)));

    % 计时包括：读取、预处理、输入生成、福利计算和数值校验。
    % Timing includes loading, preprocessing, input generation,
    % welfare evaluation and numerical checks.
    % Result printing is excluded.
    startTime = tic;

    %% 3.1 读取无向网络 / Load the undirected network

    [edgeStart, edgeEnd, n] = ...
        loadUndirectedNetwork(datasetPath);

    numberOfUndirectedEdges = numel(edgeStart);

    nodeCount(datasetIndex) = n;
    edgeCount(datasetIndex) = numberOfUndirectedEdges;

    % 检查是否与论文所用数据集一致。
    % Stop if the dataset statistics differ from the manuscript.
    assert(n == expectedNodes(datasetIndex), ...
        '%s: expected %d nodes, but found %d.', ...
        char(datasetNames(datasetIndex)), ...
        expectedNodes(datasetIndex), n);

    assert(numberOfUndirectedEdges == expectedEdges(datasetIndex), ...
        '%s: expected %d undirected edges, but found %d.', ...
        char(datasetNames(datasetIndex)), ...
        expectedEdges(datasetIndex), numberOfUndirectedEdges);

    %% 3.2 将无向边转换为两条有向边 / Create directed edges

    % 保持与原 local_ICE.m 完全相同的边顺序。
    % Preserve the directed-edge order used in local_ICE.m.
    directedStart = [edgeStart; edgeEnd];
    directedEnd   = [edgeEnd; edgeStart];

    numberOfDirectedEdges = numel(directedStart);

    %% 3.3 构造稀疏权重矩阵 / Construct sparse W

    degree = accumarray( ...
        directedStart, ...
        ones(numberOfDirectedEdges, 1), ...
        [n, 1], @sum, 0);

    % w_jk = (1-theta)/degree(j), for non-self directed edges.
    directedWeights = ...
        (1 - theta) ./ degree(directedStart);

    % 非孤立节点的自环权重为 theta。
    % Isolated nodes receive self-weight 1 to preserve row sums.
    selfLoopWeights = theta * ones(n, 1);
    selfLoopWeights(degree == 0) = 1;

    nodeIndices = (1:n)';

    W = sparse( ...
        [directedStart; nodeIndices], ...
        [directedEnd; nodeIndices], ...
        [directedWeights; selfLoopWeights], ...
        n, n);

    rowSums = full(sum(W, 2));
    maximumRowError = max(abs(rowSums - 1));

    assert(maximumRowError <= 1e-12, ...
        '%s: W is not row-stochastic. Maximum error = %.3e.', ...
        char(datasetNames(datasetIndex)), maximumRowError);

    %% 3.4 生成偏好和内在效用 / Generate intrinsic utilities

    intrinsicUtility = generateIntrinsicUtilities( ...
        n, numberOfAlternatives, preferenceSeed, utilityByRank);

    % omega_local = W' * ones(n,1).
    localEmpatheticCentrality = full(sum(W, 1)).';

    % 每个节点的加权成本上界。
    % Upper bound on each node's total weighted maintenance cost.
    costUpperBound = ...
        maximumEdgeCost * (1 - selfLoopWeights);

    %% 3.5 加权成本下的一次局部更新 / One-step local evaluation

    socialWelfare = zeros(1, numberOfAlternatives);
    largestVerificationError = 0;

    for alternativeIndex = 1:numberOfAlternatives

        % 保留原来的随机种子和 uint8 生成方式。
        % Preserve the original random seed and uint8 generation.
        rng(costSeeds(alternativeIndex), 'twister');

        % 只为现有非自环有向边生成基础成本。
        % Generate baseline costs on existing non-self directed edges.
        directedMaintenanceCost = randi( ...
            [0, maximumEdgeCost], ...
            numberOfDirectedEdges, 1, 'uint8');

        % 核心修改 / Core change:
        % effective cost on edge (j,k) = w_jk * c_jk(a_i).
        weightedDirectedCost = ...
            directedWeights .* double(directedMaintenanceCost);

        % outgoingMaintenanceCost(j) = sum_k w_jk*c_jk(a_i).
        outgoingMaintenanceCost = accumarray( ...
            directedStart, ...
            weightedDirectedCost, ...
            [n, 1], @sum, 0);

        % 初始效用 / Initial utility: u^(0) = u_I.
        uInitial = double( ...
            intrinsicUtility(:, alternativeIndex));

        % 一次更新即得到精确局部效用。
        % One update gives the exact local utility.
        uLocal = W * uInitial - outgoingMaintenanceCost;

        socialWelfare(alternativeIndex) = sum(uLocal);

        % 等价公式校验 / Equivalent-formula check:
        % sw = omega_local' * u_I - sum_jk(w_jk*c_jk).
        welfareCheck = ...
            localEmpatheticCentrality.' * uInitial ...
            - sum(weightedDirectedCost);

        currentError = abs( ...
            socialWelfare(alternativeIndex) - welfareCheck);

        largestVerificationError = max( ...
            largestVerificationError, currentError);

        verificationTolerance = ...
            1e-10 * max(1, abs(welfareCheck));

        assert(currentError <= verificationTolerance, ...
            '%s, a_%d: inconsistent welfare calculations.', ...
            char(datasetNames(datasetIndex)), alternativeIndex);

        % theta=0.4 且基础成本不超过2时，节点总成本不超过1.2。
        % For theta=0.4 and baseline costs <=2, total node cost <=1.2.
        assert( ...
            all(outgoingMaintenanceCost >= -1e-12) && ...
            all(outgoingMaintenanceCost <= costUpperBound + 1e-10), ...
            '%s, a_%d: weighted costs are outside valid bounds.', ...
            char(datasetNames(datasetIndex)), alternativeIndex);
    end

    welfareValues(datasetIndex, :) = socialWelfare;
    verificationErrors(datasetIndex) = largestVerificationError;

    %% 3.6 选择最优方案 / Select the optimal alternative

    maximumWelfare(datasetIndex) = max(socialWelfare);

    tieTolerance = ...
        1e-10 * max(1, abs(maximumWelfare(datasetIndex)));

    % 使用完整精度判断最优方案，不使用已舍入的表格数值。
    % Determine maximizers before rounding the displayed values.
    optimalSet = find( ...
        abs(socialWelfare - maximumWelfare(datasetIndex)) ...
        <= tieTolerance);

    optimalAlternative(datasetIndex) = ...
        strjoin("a_" + string(optimalSet), ", ");

    elapsedSeconds(datasetIndex) = toc(startTime);

    if numel(optimalSet) > 1
        warning('%s: multiple maximizers within tolerance: %s.', ...
            char(datasetNames(datasetIndex)), ...
            char(optimalAlternative(datasetIndex)));
    end

    fprintf('Nodes: %d; undirected edges: %d\n', ...
        n, numberOfUndirectedEdges);

    fprintf('Local social welfare:\n');
    fprintf(' %.6f', socialWelfare);

    fprintf('\nOptimal alternative(s): %s\n', ...
        char(optimalAlternative(datasetIndex)));

    fprintf('Maximum welfare: %.6f\n', ...
        maximumWelfare(datasetIndex));

    fprintf('Runtime: %.6f s\n', ...
        elapsedSeconds(datasetIndex));

    fprintf('Maximum verification error: %.3e\n', ...
        largestVerificationError);

    % 清理大型中间数组，仅保留汇总结果。
    % Release large intermediate arrays; retain the result arrays.
    clear W intrinsicUtility localEmpatheticCentrality
    clear edgeStart edgeEnd directedStart directedEnd
    clear directedWeights selfLoopWeights degree nodeIndices rowSums
    clear directedMaintenanceCost weightedDirectedCost
    clear outgoingMaintenanceCost costUpperBound uInitial uLocal
end

%% 4. 创建表3和完整汇总表 / Build result tables

welfareVariableNames = cellstr( ...
    "SW_a" + string(1:numberOfAlternatives));

welfareTable = array2table( ...
    welfareValues, 'VariableNames', welfareVariableNames);

datasetTable = table( ...
    datasetNames(:), 'VariableNames', {'Dataset'});

runtimeTable = table( ...
    elapsedSeconds, 'VariableNames', {'Runtime_s'});

% 与论文表3对应：数据集、8个福利值、运行时间。
% Manuscript Table 3: dataset, eight welfare values, runtime.
table3 = [datasetTable, welfareTable, runtimeTable];

networkTable = table( ...
    nodeCount, edgeCount, ...
    'VariableNames', {'Nodes', 'UndirectedEdges'});

selectionTable = table( ...
    optimalAlternative, maximumWelfare, verificationErrors, ...
    'VariableNames', { ...
        'OptimalAlternative', ...
        'MaximumWelfare', ...
        'VerificationError'});

summaryTable = [ ...
    datasetTable, networkTable, welfareTable, ...
    selectionTable, runtimeTable];

%% 5. 固定小数格式输出表3 / Print Table 3

fprintf('\nTable 3: local social welfare\n');

fprintf('%-9s', 'Dataset');
for i = 1:numberOfAlternatives
    fprintf(' %14s', sprintf('a_%d', i));
end
fprintf(' %13s\n', 'Runtime (s)');

for d = 1:numberOfDatasets
    fprintf('%-9s', char(datasetNames(d)));
    fprintf(' %14.2f', welfareValues(d, :));
    fprintf(' %13.6f\n', elapsedSeconds(d));
end

fprintf('\nOptimal alternatives:\n');
disp([datasetTable, selectionTable]);

%% 6. 输出 LaTeX 表格行 / Print LaTeX rows

% 自动加粗最优值；如果存在并列最优，则全部加粗。
% Bold all maximizers, including any ties within tolerance.
fprintf('\nLaTeX rows for Table 3:\n');

for d = 1:numberOfDatasets

    fprintf('%s', char(datasetNames(d)));

    best = max(welfareValues(d, :));
    tieTol = 1e-10 * max(1, abs(best));

    for i = 1:numberOfAlternatives
        if abs(welfareValues(d, i) - best) <= tieTol
            fprintf(' & \\textbf{%.2f}', welfareValues(d, i));
        else
            fprintf(' & %.2f', welfareValues(d, i));
        end
    end

    fprintf(' & %.6f \\\\\n', elapsedSeconds(d));
end

%% Local functions / 辅助函数

function [edgeStart, edgeEnd, numberOfNodes] = ...
        loadUndirectedNetwork(filePath)
% Read TXT edge lists or the supplied GML network.
% Preserve the node remapping and edge ordering in local_ICE.m.

    [~, ~, extension] = fileparts(filePath);

    switch lower(extension)

        case '.txt'

            fileID = fopen(filePath, 'r');

            if fileID < 0
                error('Cannot open data file: %s', filePath);
            end

            cleanupObject = onCleanup(@() fclose(fileID));

            % 空白分隔；忽略以 # 开始的注释。
            % For Karate.txt, parsing stops before the trailing
            % nonnumeric CSV node-metadata section.
            parsedData = textscan( ...
                fileID, '%f%f', ...
                'CollectOutput', true, ...
                'CommentStyle', '#');

            rawEdges = parsedData{1};

            if isempty(rawEdges) || size(rawEdges, 2) ~= 2
                error('No valid two-column edge list found in %s.', ...
                    filePath);
            end

            rawStart = rawEdges(:, 1);
            rawEnd = rawEdges(:, 2);
            explicitNodeIDs = [];

            clear cleanupObject

        case '.gml'

            gmlText = fileread(filePath);

            nodeTokens = regexp( ...
                gmlText, ...
                '(?m)^\s*id\s+(-?\d+)\s*$', ...
                'tokens');

            sourceTokens = regexp( ...
                gmlText, ...
                '(?m)^\s*source\s+(-?\d+)\s*$', ...
                'tokens');

            targetTokens = regexp( ...
                gmlText, ...
                '(?m)^\s*target\s+(-?\d+)\s*$', ...
                'tokens');

            explicitNodeIDs = tokenCellsToNumbers(nodeTokens);
            rawStart = tokenCellsToNumbers(sourceTokens);
            rawEnd = tokenCellsToNumbers(targetTokens);

            if numel(rawStart) ~= numel(rawEnd)
                error('Unmatched source and target entries in %s.', ...
                    filePath);
            end

        otherwise
            error('Unsupported network format: %s', extension);
    end

    rawStart = rawStart(:);
    rawEnd = rawEnd(:);
    explicitNodeIDs = explicitNodeIDs(:);

    validEdges = ...
        isfinite(rawStart) ...
        & isfinite(rawEnd) ...
        & rawStart == fix(rawStart) ...
        & rawEnd == fix(rawEnd);

    rawStart = rawStart(validEdges);
    rawEnd = rawEnd(validEdges);

    % 将原始节点编号按升序映射到 1,...,n。
    % Remap sorted original node IDs to 1,...,n.
    allNodeIDs = unique( ...
        [explicitNodeIDs; rawStart; rawEnd], 'sorted');

    numberOfNodes = numel(allNodeIDs);

    if numberOfNodes == 0
        error('No valid nodes found in %s.', filePath);
    end

    [startFound, mappedStart] = ismember(rawStart, allNodeIDs);
    [endFound, mappedEnd] = ismember(rawEnd, allNodeIDs);

    if ~all(startFound) || ~all(endFound)
        error('Some node identifiers could not be remapped.');
    end

    % 先保留节点，再移除原数据中的自环。
    % Identify nodes before removing original self-loops.
    nonSelfEdges = mappedStart ~= mappedEnd;

    mappedStart = mappedStart(nonSelfEdges);
    mappedEnd = mappedEnd(nonSelfEdges);

    % 规范化无向边端点，并移除重复边及反向重复边。
    % Canonicalize endpoints and remove duplicate undirected edges.
    edgePairs = sort([mappedStart(:), mappedEnd(:)], 2);
    edgePairs = unique(edgePairs, 'rows');

    edgeStart = edgePairs(:, 1);
    edgeEnd = edgePairs(:, 2);
end

function intrinsicUtility = generateIntrinsicUtilities( ...
        numberOfNodes, numberOfAlternatives, randomSeed, utilityByRank)
% Preserve the preference-generation procedure in local_ICE.m.
%
% Example ranking:
%   a3 > a4 > a8 > a2 > a5 > a7 > a1 > a6
% Corresponding intrinsic utilities in alternative order:
%   [50, 65, 80, 75, 60, 45, 55, 70]

    rng(randomSeed, 'twister');

    % 保留 single 类型，避免改变原随机实例。
    % Preserve single precision to reproduce the original instances.
    randomValues = rand( ...
        numberOfNodes, numberOfAlternatives, 'single');

    [~, preferenceOrder] = sort(randomValues, 2, 'descend');

    clear randomValues

    intrinsicUtility = zeros( ...
        numberOfNodes, numberOfAlternatives, 'single');

    nodeIndices = (1:numberOfNodes)';

    for rankIndex = 1:numberOfAlternatives

        linearIndices = sub2ind( ...
            [numberOfNodes, numberOfAlternatives], ...
            nodeIndices, ...
            double(preferenceOrder(:, rankIndex)));

        intrinsicUtility(linearIndices) = ...
            single(utilityByRank(rankIndex));
    end
end

function values = tokenCellsToNumbers(tokenCells)
% Convert regexp tokens to a numeric column vector.

    if isempty(tokenCells)
        values = zeros(0, 1);
        return;
    end

    values = cellfun( ...
        @(token) str2double(token{1}), tokenCells(:));
end