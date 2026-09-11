%% global_ICE_with_figures.m
% 全局移情网络：加权维护成本、ICE/FI-ICE、分网络绘图
% Global empathetic networks: weighted costs, ICE/FI-ICE and figures
%
% B = W-D
% R(:,i) = D*uI(a_i) - (W.*C(a_i))*ones(n,1)
% U^(t+1) = B*U^t + R
%
% Two separate figures per network:
%   1. Iterative welfare and reference welfare.
%   2. Welfare gaps and elimination thresholds.
%
% MATLAB R2024b

clear;
clc;

%% 1. 路径与参数 / Paths and parameters

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end

dataDir = fullfile(scriptDir,'Empirical Example');

assert(isfolder(dataDir), ...
    'Data folder not found: %s',dataDir);

datasetFiles = { ...
    'Karate.txt','PolBK.gml','LastFM.txt','Amazon.txt','Dblp.txt'};

datasetNames = ["Karate","PolBK","LastFM","Amazon","DBLP"];

expectedNodes = [34,105,7624,334863,317080];
expectedEdges = [78,441,27806,925872,1049866];

% 保留你当前脚本中的参数。
% Preserve the parameters in your currently saved script.
utilityByRank = 80:-10:10;
maximumEdgeCost = 5;       % Baseline costs: 0,1,...,5.
theta = 0.4;
alpha = min(utilityByRank); % Currently alpha = 1.

% 如需恢复之前的参数，改为：
% To restore the earlier parameter setting:
% utilityByRank = 80:-5:45;
% maximumEdgeCost = 2;
% alpha = min(utilityByRank);

preferenceSeed = 100;
costSeeds = 123:130;

maxICEIterations = 500;
relativeGuard = 1e-10;

% 独立参考迭代的精度参数，不是 ICE 剔除阈值。
% Accuracy target for the independent reference iteration.
referenceTolerance = 1e-4;
maxReferenceIterations = 2000;

%% 2. 绘图与导出设置 / Figure settings

showFigures = true;

% 默认仅显示图窗，不保存文件。
% Set true to export PNG, PDF and EPS.
saveFigures = false;

assert(showFigures || saveFigures, ...
    'Enable figure display or export.');

outputDir = '';

if saveFigures
    % 每次新建时间戳文件夹，不覆盖已有结果。
    % Create a new timestamped folder for each run.
    outputDir = fullfile( ...
        dataDir,'global_ICE_figures', ...
        char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));

    assert(~isfolder(outputDir), ...
        'Output folder already exists; rerun.');

    mkdir(outputDir);
end

m = numel(utilityByRank);
N = numel(datasetFiles);

assert(theta > 0 && theta <= 1 && numel(costSeeds) == m);

assert(m >= 1 && m <= 8, ...
    'The figure styles support one to eight alternatives.');

assert(maxICEIterations >= 1 && ...
       maxICEIterations == fix(maxICEIterations));

assert(referenceTolerance > 0 && relativeGuard >= 0);

assert(maximumEdgeCost >= 0 && maximumEdgeCost <= 255 && ...
       maximumEdgeCost == fix(maximumEdgeCost));

%% 3. 结果数组 / Result arrays

candidateText = strings(N,1);
method = strings(N,1);
iterations = zeros(N,1);

iceSeconds = zeros(N,1);
referenceSeconds = zeros(N,1);

referenceWelfare = nan(N,m);
referenceError = nan(N,m);

iceResults = cell(N,1);
iceHistories = cell(N,1);
figureHandles = gobjects(N,2);

%% 4. 逐个网络求解 / Process each network

for d = 1:N

    fprintf('\nProcessing %s ...\n',char(datasetNames(d)));

    filePath = fullfile(dataDir,datasetFiles{d});

    assert(isfile(filePath), ...
        'Dataset not found: %s',filePath);

    %% 4.1 读取网络 / Load network

    [edgeStart,edgeEnd,n] = loadUndirectedNetwork(filePath);

    assert(n == expectedNodes(d) && ...
           numel(edgeStart) == expectedEdges(d), ...
        'Unexpected network size for %s.',char(datasetNames(d)));

    %% 4.2 构造稀疏矩阵 B = W-D

    % 保留原来的边排序，保证随机成本可复现。
    % Preserve the original directed-edge ordering.
    src = [edgeStart;edgeEnd];
    dst = [edgeEnd;edgeStart];

    E = numel(src);

    degree = accumarray( ...
        src,ones(E,1),[n,1],@sum,0);

    weights = (1-theta)./degree(src);

    selfWeights = theta*ones(n,1);
    selfWeights(degree == 0) = 1;

    B = sparse(src,dst,weights,n,n);

    assert(max(abs(full(sum(B,2))+selfWeights-1)) <= 1e-12, ...
        'W is not row-stochastic.');

    wMin = min(selfWeights);
    q = 1-wMin;

    %% 4.3 内在效用与加权成本 / Utilities and weighted costs

    UI = generateIntrinsicUtilities( ...
        n,m,preferenceSeed,utilityByRank);

    costs = zeros(n,m);

    for i = 1:m

        rng(costSeeds(i),'twister');

        baseline = randi( ...
            [0,maximumEdgeCost],E,1,'uint8');

        % costs(j,i) = sum_k w_jk*c_jk(a_i).
        costs(:,i) = accumarray( ...
            src,weights.*double(baseline),[n,1],@sum,0);
    end

    assert( ...
        all(costs >= -1e-12,'all') && ...
        all(costs <= maximumEdgeCost*(1-selfWeights)+1e-10,'all'), ...
        'Weighted costs are outside valid bounds.');

    % 常数项与 Delta 均使用加权成本。
    % Weighted costs enter both R and Delta.
    R = selfWeights.*double(UI)-costs;

    delta = max( ...
        abs(selfWeights.*(double(UI)-alpha)-costs),[],1);

    clear UI costs baseline edgeStart edgeEnd
    clear src dst degree weights selfWeights

    %% 4.4 ICE / FI-ICE

    timer = tic;

    [result,H] = runGlobalICE( ...
        B,R,delta,alpha,wMin,maxICEIterations,relativeGuard);

    iceSeconds(d) = toc(timer);

    %% 4.5 独立参考计算 / Independent reference calculation

    % 参考计算和绘图不计入 ICESeconds。
    % Reference calculation and plotting are excluded from ICESeconds.
    timer = tic;

    [refSW,refErr,refIterations,refOK] = ...
        convergeReference( ...
            B,R,alpha,q,referenceTolerance,maxReferenceIterations);

    referenceSeconds(d) = toc(timer);

    assert(refOK, ...
        'Reference accuracy target not reached for %s.', ...
        char(datasetNames(d)));

    %% 4.6 核验 / Verification

    guard = relativeGuard*max(1,max(abs(refSW)));

    for h = 1:numel(H.iteration)

        recorded = isfinite(H.welfare(h,:));

        bound = ...
            n*q^H.iteration(h)/wMin*delta(recorded);

        assert(all( ...
            abs(H.welfare(h,recorded)-refSW(recorded)) ...
            <= bound+refErr(recorded)+guard), ...
            'Welfare-error check failed.');
    end

    [~,best] = max(refSW);
    other = setdiff(1:m,best);

    % Only identify a unique reference winner if its interval separates.
    if isempty(other) || ...
            refSW(best)-refErr(best) > ...
            max(refSW(other)+refErr(other))+guard

        assert(ismember(best,result.candidateSet), ...
            'ICE removed the reference winner.');
    end

    %% 4.7 保存到工作区并绘图 / Store results and plot

    candidateText(d) = formatAlternativeSet(result.candidateSet);
    method(d) = result.method;
    iterations(d) = result.iterations;

    referenceWelfare(d,:) = refSW;
    referenceError(d,:) = refErr;

    iceResults{d} = result;
    iceHistories{d} = H;

    figureHandles(d,:) = plotNetworkFigures( ...
        datasetNames(d),H,refSW,showFigures,outputDir);

    fprintf('Candidates: %s; %s iterations: %d\n', ...
        char(candidateText(d)),char(method(d)),iterations(d));

    fprintf('Reference welfare:');
    fprintf(' %.6f',refSW);
    fprintf('\n');

    clear B R result H
end

%% 5. 汇总 / Summary

summaryTable = table( ...
    datasetNames(:),candidateText,method,iterations, ...
    iceSeconds,referenceSeconds, ...
    'VariableNames',{ ...
        'Dataset','Candidates','Method','Iterations', ...
        'ICESeconds','ReferenceSeconds'});

referenceTable = [ ...
    table(datasetNames(:),'VariableNames',{'Dataset'}), ...
    array2table(referenceWelfare, ...
        'VariableNames',cellstr("SW_a"+string(1:m)))];

disp(summaryTable);
disp(referenceTable);

if saveFigures
    fprintf('Figures saved to:\n%s\n',outputDir);
end

%% Local functions / 辅助函数

function [result,history] = runGlobalICE( ...
        B,R,delta,alpha,wMin,maxIterations,relativeGuard)

    [n,m] = size(R);
    assert(wMin > 0 && wMin <= 1);

    q = 1-wMin;
    U = alpha*ones(n,m);
    active = true(1,m);

    % Fixed maximum over all original alternatives.
    maxDelta = max(delta);

    welfare = nan(maxIterations+1,m);
    gaps = nan(maxIterations+1,m);
    thresholds = nan(maxIterations+1,1);
    usedThresholds = nan(maxIterations+1,1);
    activeHistory = false(maxIterations+1,m);
    eliminationIteration = nan(1,m);

    welfare(1,:) = n*alpha;
    gaps(1,:) = 0;

    thresholds(1) = 2*n/wMin*maxDelta;

    usedThresholds(1) = thresholds(1) ...
        + relativeGuard*max([1,abs(n*alpha),thresholds(1)]);

    activeHistory(1,:) = active;
    lastIteration = 0;

    for t = 1:maxIterations

        if nnz(active) <= 1
            break;
        end

        ids = find(active);

        % 只更新未剔除方案 / Update active alternatives only.
        U(:,ids) = B*U(:,ids)+R(:,ids);

        sw = sum(U(:,ids),1);

        assert(all(isfinite(sw)), ...
            'Non-finite iterative welfare.');

        gap = max(sw)-sw;

        % 理论剔除阈值 / Theoretical elimination threshold.
        tau = 2*n*q^t/wMin*maxDelta;

        numericalGuard = ...
            relativeGuard*max([1,abs(sw),tau]);

        % 实际判据为严格大于，避免强行打破并列。
        % Strict comparison preserves unresolved ties.
        removed = ids(gap > tau+numericalGuard);

        active(removed) = false;
        eliminationIteration(removed) = t;

        welfare(t+1,ids) = sw;
        gaps(t+1,ids) = gap;

        thresholds(t+1) = tau;
        usedThresholds(t+1) = tau+numericalGuard;

        activeHistory(t+1,:) = active;
        lastIteration = t;
    end

    rows = 1:(lastIteration+1);

    history.iteration = (0:lastIteration)';
    history.welfare = welfare(rows,:);
    history.gap = gaps(rows,:);
    history.threshold = thresholds(rows);
    history.usedThreshold = usedThresholds(rows);
    history.active = activeHistory(rows,:);
    history.candidateCount = sum(history.active,2);
    history.eliminationIteration = eliminationIteration;

    result.candidateSet = find(active);
    result.iterations = lastIteration;

    result.candidateWelfare = ...
        welfare(lastIteration+1,active);

    result.candidateErrorBound = ...
        n*q^lastIteration/wMin*delta(active);

    result.terminatedWithSingleton = nnz(active) == 1;

    if result.terminatedWithSingleton
        result.method = "ICE";
    else
        % Remaining candidates are not necessarily exact ties.
        result.method = "FI-ICE";
    end
end

function [sw,errorBound,iterations,converged] = ...
        convergeReference(B,R,alpha,q,tolerance,maxIterations)

    [n,m] = size(R);

    U = alpha*ones(n,m);
    iterations = 0;

    for t = 1:maxIterations

        updated = B*U+R;
        difference = max(abs(updated-U),[],1);

        U = updated;
        iterations = t;

        posteriorBound = n*q/(1-q)*difference;

        if all(posteriorBound <= tolerance)
            break;
        end
    end

    residual = B*U+R-U;
    errorBound = n/(1-q)*max(abs(residual),[],1);
    sw = sum(U,1);

    converged = ...
        all(isfinite(sw)) && all(errorBound <= tolerance);
end

function [edgeStart,edgeEnd,n] = loadUndirectedNetwork(filePath)

    [~,~,extension] = fileparts(filePath);

    switch lower(extension)

        case '.txt'

            rawData = readmatrix(filePath,'FileType','text');

            assert(~isempty(rawData) && size(rawData,2) >= 2, ...
                'Invalid edge list: %s',filePath);

            rawStart = rawData(:,1);
            rawEnd = rawData(:,2);
            explicitNodeIDs = [];

        case '.gml'

            txt = fileread(filePath);

            nodeTokens = regexp( ...
                txt,'(?m)^\s*id\s+(-?\d+)\s*$','tokens');

            sourceTokens = regexp( ...
                txt,'(?m)^\s*source\s+(-?\d+)\s*$','tokens');

            targetTokens = regexp( ...
                txt,'(?m)^\s*target\s+(-?\d+)\s*$','tokens');

            explicitNodeIDs = tokenCellsToNumbers(nodeTokens);
            rawStart = tokenCellsToNumbers(sourceTokens);
            rawEnd = tokenCellsToNumbers(targetTokens);

            assert(numel(rawStart) == numel(rawEnd), ...
                'Unmatched GML endpoints.');

        otherwise
            error('Unsupported file format: %s',extension);
    end

    rawStart = rawStart(:);
    rawEnd = rawEnd(:);

    valid = ...
        isfinite(rawStart) & isfinite(rawEnd) & ...
        rawStart == fix(rawStart) & rawEnd == fix(rawEnd);

    rawStart = rawStart(valid);
    rawEnd = rawEnd(valid);

    allIDs = unique( ...
        [explicitNodeIDs(:);rawStart;rawEnd],'sorted');

    n = numel(allIDs);
    assert(n > 0,'No valid nodes found.');

    [~,mappedStart] = ismember(rawStart,allIDs);
    [~,mappedEnd] = ismember(rawEnd,allIDs);

    nonSelf = mappedStart ~= mappedEnd;

    pairs = sort( ...
        [mappedStart(nonSelf),mappedEnd(nonSelf)],2);

    pairs = unique(pairs,'rows');

    edgeStart = pairs(:,1);
    edgeEnd = pairs(:,2);
end

function values = tokenCellsToNumbers(tokens)

    if isempty(tokens)
        values = zeros(0,1);
    else
        values = cellfun(@(x) str2double(x{1}),tokens(:));
    end
end

function UI = generateIntrinsicUtilities(n,m,seed,utilityByRank)

    rng(seed,'twister');

    randomValues = rand(n,m,'single');
    [~,order] = sort(randomValues,2,'descend');

    clear randomValues

    UI = zeros(n,m,'uint8');

    for rank = 1:m
        ids = sub2ind([n,m],(1:n)',order(:,rank));
        UI(ids) = uint8(utilityByRank(rank));
    end
end

function text = formatAlternativeSet(indices)

    text = "{" ...
        + strjoin("a_"+string(indices(:).'),", ") ...
        + "}";
end

function figures = plotNetworkFigures( ...
        name,H,refSW,showFigures,outputDir)
% 绘图风格与 global_ICE.m 保持一致。
% Match the plotting style of global_ICE.m.
%
% Figure 1: iterative welfare and reference welfare.
% Figure 2: welfare gaps and the theoretical elimination threshold.

    t = H.iteration(:);
    T = t(end);
    m = numel(refSW);

    % 原配色与标记 / Original colors and markers.
    colors = lines(m);
    markers = {'o','s','^','d','v','>','<','p'};

    assert(m <= numel(markers), ...
        'Too many alternatives for the marker list.');

    visibility = 'off';
    if showFigures
        visibility = 'on';
    end

    figures = gobjects(1,2);

    for kind = 1:2

        if kind == 1
            Y = H.welfare;
            firstIteration = 0;

            windowName = sprintf( ...
                '%s: iterative social welfare',char(name));

            yLabel = '$sw^{\left(t\right)}\left(a_i\right)$';

            fileTag = 'global_ICE_iterative_value';

        else
            Y = H.gap;
            firstIteration = min(1,T);

            windowName = sprintf( ...
                '%s: ICE elimination threshold',char(name));

            yLabel = [ ...
                '$\widehat{sw}^{\left(t\right)}-' ...
                'sw^{\left(t\right)}\left(a_i\right)$'];

            fileTag = 'global_ICE_elimination_threshold';
        end

        %% 创建独立图窗 / Create a separate figure

        f = figure( ...
            'Color','white', ...
            'Visible',visibility, ...
            'Name',windowName, ...
            'NumberTitle','off', ...
            'Units','centimeters', ...
            'Position',[2 2 14 10], ...
            'PaperPositionMode','auto');

        figures(kind) = f;

        ax = axes(f);
        hold(ax,'on');

        %% 绘制各方案曲线 / Plot alternative trajectories

        for i = 1:m

            idx = find( ...
                t >= firstIteration & isfinite(Y(:,i)));

            if isempty(idx)
                continue;
            end

            if kind == 1
                % 参考福利线与迭代曲线在同一剔除时刻结束。
                % Reference segments end at the elimination iteration.
                plot( ...
                    ax,t(idx),refSW(i)*ones(size(idx)), ...
                    ':', ...
                    'Color',colors(i,:), ...
                    'LineWidth',0.8, ...
                    'HandleVisibility','off');
            end

            % 剔除后的历史值为 NaN，不继续延长曲线。
            % NaN entries prevent extending eliminated trajectories.
            plot( ...
                ax,t(idx),Y(idx,i), ...
                [markers{i},'-'], ...
                'Color',colors(i,:), ...
                'LineWidth',1.0, ...
                'MarkerSize',6, ...
                'DisplayName',sprintf('$a_{%d}$',i));
        end

        %% 黑色虚线：理论剔除阈值 / Theoretical threshold

        if kind == 2

            idx = find( ...
                t >= firstIteration & isfinite(H.threshold));

            plot( ...
                ax,t(idx),H.threshold(idx), ...
                'k--', ...
                'LineWidth',1.3, ...
                'DisplayName','$Threshold$');
        end

        %% 图例和坐标轴 / Legend and axes

        legend( ...
            ax,'Location','best','Interpreter','latex');

        xlabel(ax,'$t$','Interpreter','latex');
        ylabel(ax,yLabel,'Interpreter','latex');

        % 沿用原脚本的整数迭代刻度。
        % Preserve the original integer iteration ticks.
        if T <= 30
            tickValues = firstIteration:T;
        else
            tickValues = unique(round(linspace( ...
                firstIteration,T,11)));
        end

        set(ax,'XTick',tickValues);

        % 兼容零次或一次迭代的特殊情况。
        % Handle zero/one-iteration cases safely.
        xlim(ax,[firstIteration,max(firstIteration+1,T)]);

        set( ...
            ax, ...
            'FontName','Times New Roman', ...
            'FontSize',10, ...
            'LineWidth',0.75, ...
            'TickDir','in', ...
            'Box','on');

        %% Adjust only the elimination-threshold figure.
        % 仅调整阈值图；福利迭代图保持不变。
        if kind == 2

            % Vertical headroom above the largest welfare gap.
            % 最大福利差距上方预留 15% 空间。
            zoomPadding = 1.15;

            gapValues = H.gap(t >= firstIteration,:);
            gapValues = gapValues(isfinite(gapValues));

            if isempty(gapValues) || max(gapValues) <= 0
                yUpper = 1;
            else
                yUpper = zoomPadding * max(gapValues);
            end

            % Preserve the original full-range limits.
            % 保留原始纵轴范围，便于恢复。
            drawnow;
            setappdata(ax,'FullRangeYLim',ylim(ax));

            % When saving is enabled, also export a full-range version.
            % 开启保存时，额外导出未截取纵轴的完整范围图。
            if ~isempty(outputDir)
                assert(isfolder(outputDir), ...
                    'Output folder not found: %s',outputDir);

                tag = regexprep(char(name),'[^A-Za-z0-9_-]','_');
                fullStem = fullfile(outputDir, ...
                    sprintf('%s_%s_full_range',tag,fileTag));

                exportgraphics(f,[fullStem '.pdf'], ...
                    'ContentType','vector', ...
                    'BackgroundColor','white');

                exportgraphics(f,[fullStem '.png'], ...
                    'Resolution',600, ...
                    'BackgroundColor','white');

                print(f,[fullStem '.eps'], ...
                    '-depsc','-painters','-r600');
            end

            % Keep all finite welfare-gap values within the visible range.
            % 所有福利差距值均保留在可视范围内。
            ylim(ax,[0,yUpper]);

            % Move the legend outside so it cannot hide elimination points.
            % 图例移到右侧图外，并适当加宽图窗。
            figPosition = get(f,'Position');
            figPosition(3) = max(figPosition(3),18);
            set(f,'Position',figPosition);

            legend(ax,'Location','eastoutside', ...
                'Interpreter','latex');

            % Explicitly disclose any visually clipped early thresholds.
            % 若早期阈值超出显示范围，添加说明。
            thresholdValues = H.threshold(t >= firstIteration);
            % if any(thresholdValues > yUpper)
            %     title('FontName','Times New Roman', ...
            %         'FontSize',9, ...
            %         'FontWeight','normal', ...
            %         'Interpreter','none');
            % end

            % fprintf('%s: threshold-plot y-range = [0, %.6g].\n', ...
            %     char(name),yUpper);
        end

        grid(ax,'off');
        hold(ax,'off');

        drawnow;

        %% 可选导出 / Optional export

        if ~isempty(outputDir)

            assert(isfolder(outputDir), ...
                'Output folder not found: %s',outputDir);

            datasetTag = regexprep( ...
                char(name),'[^A-Za-z0-9_-]','_');

            stem = fullfile( ...
                outputDir,sprintf('%s_%s',datasetTag,fileTag));

            % 矢量 PDF / Vector PDF.
            exportgraphics( ...
                f,[stem '.pdf'], ...
                'ContentType','vector', ...
                'BackgroundColor','white');

            % 600 dpi PNG.
            exportgraphics( ...
                f,[stem '.png'], ...
                'Resolution',600, ...
                'BackgroundColor','white');

            % EPS for LaTeX.
            print( ...
                f,[stem '.eps'], ...
                '-depsc','-painters','-r600');
        end
    end
end