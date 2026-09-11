function [Thresholds,CommunityModels,outputDir] = plot_uniform_cost_allocation(resultFile,datasetIndices,outputDir)
%PLOT_UNIFORM_COST_ALLOCATION c 与分配集、社区最小不满意度的关系图。
% [Thresholds,CommunityModels,out] = plot_uniform_cost_allocation;
% 首次运行用种子1:20计算Louvain，后续从带原始数据校验的缓存读取。
% 需要先运行 run_uniform_cost_sweep，或显式给出其 MAT 结果路径。
% 输出三类图：分配集余量、最小社区不满意度、分配状态区间。
% 按 ICE 脚本格式，Local/Global 分别导出独立图窗。
% 不满意度只在分配集非空时定义；没有外推到空集区域。
base=fileparts(mfilename('fullpath'));
if nargin<1 || isempty(resultFile)
    files=dir(fullfile(base,'results','*','uniform_cost_results.mat'));
    assert(~isempty(files),'Run run_uniform_cost_sweep first.');
    [~,which]=max([files.datenum]);
    resultFile=fullfile(files(which).folder,files(which).name);
end
S=load(resultFile,'Models','settings','datasetIndices');
if nargin<2 || isempty(datasetIndices), datasetIndices=S.datasetIndices; end
validateattributes(datasetIndices,{'numeric'},{'vector','integer','>=',1,'<=',5});
assert(numel(unique(datasetIndices))==numel(datasetIndices));
[present,where]=ismember(datasetIndices,S.datasetIndices);
assert(all(present),'The saved results do not contain all requested networks.');
Models=S.Models(where,:); clear S.Models
if nargin<3 || isempty(outputDir)
    outputDir=fullfile(base,'allocation_figures',char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
end
if ~isfolder(outputDir), mkdir(outputDir); end
render_uniform_cost_allocation_figures(Models,{},outputDir);
Partitions=uniform_cost_partitions(datasetIndices);
CommunityModels=cell(numel(datasetIndices),2);
rows=cell(numel(datasetIndices)*2,1);
names={'Karate.txt','PolBK.gml','LastFM.txt','Amazon.txt','Dblp.txt'};
oldRng=rng; restore=onCleanup(@()rng(oldRng));
for d=1:numel(datasetIndices)
    k=datasetIndices(d); M=Models{d,1}; P=Partitions{d}; n=M.NodeCount;
    path=fullfile(fileparts(base),'Empirical Example',names{k});
    [s,e,nodeIDs]=loadNetwork(path);
    assert(isequal(nodeIDs,M.NodeIDs) && isequal(nodeIDs,P.NodeIDs));
    src=[s;e]; dst=[e;s]; degree=accumarray(src,1,[n,1]);
    B=sparse(src,dst,(1-S.settings.Theta)./degree(src),n,n);
    UI=generateIntrinsicUtilities(n,S.settings.UtilityByRank,S.settings.PreferenceSeed);
    for t=1:2
        M=Models{d,t};
        assert(isfinite(M.Winner),'Supply a uniquely selected alternative before allocation.');
        C=uniform_cost_community_model(B,UI(:,M.Winner),P.Labels,M);
        C.Modularity=P.Modularity; C.BestLouvainSeed=P.BestSeed;
        CommunityModels{d,t}=C;
        rows{(d-1)*2+t}=table(M.Dataset,M.NetworkType,M.Winner,n,C.CommunityCount, ...
            C.Modularity,C.BestLouvainSeed,C.DissatisfactionOnset,C.CriticalC, ...
            C.DissatisfactionAtZero,C.DissatisfactionAtCutoff, ...
            C.DissatisfactionAtCutoff/n, ...
            'VariableNames',{'Dataset','NetworkType','OptimalAlternative','Nodes', ...
            'Communities','Modularity','LouvainSeed','DissatisfactionOnset', ...
            'ImputationCutoff','zAtZero','zAtCutoff','zPerNodeAtCutoff'});
        fprintf('%s %s: z starts at c=%.8g; imputation cutoff c=%.8g; z(c*)/n=%.8g\n', ...
            M.Dataset,M.NetworkType,C.DissatisfactionOnset,C.CriticalC,C.DissatisfactionAtCutoff/n);
    end
end
Thresholds=vertcat(rows{:});
writetable(Thresholds,fullfile(outputDir,'allocation_thresholds.csv'));
save(fullfile(outputDir,'community_cost_results.mat'),'CommunityModels','Thresholds', ...
    'datasetIndices','resultFile');
render_uniform_cost_allocation_figures(Models,CommunityModels,outputDir);
disp(Thresholds(:,{'Dataset','NetworkType','DissatisfactionOnset','ImputationCutoff'}));
fprintf('Figures and source data saved to:\n%s\n',outputDir);
end
function UI=generateIntrinsicUtilities(n,utilityByRank,seed)
% Exactly the same random generation as the current weighted-cost code.
m=numel(utilityByRank);
rng(seed,'twister');
randomValues=rand(n,m,'single');
[~,order]=sort(randomValues,2,'descend');
UI=zeros(n,m,'single');
for r=1:m
    idx=sub2ind([n,m],(1:n)',double(order(:,r)));
    UI(idx)=single(utilityByRank(r));
end
end

function [edgeStart,edgeEnd,nodeIDs]=loadNetwork(path)
assert(isfile(path),'Dataset not found: %s',path);
[~,~,ext]=fileparts(path);
explicitIDs=[];
if strcmpi(ext,'.gml')
    txt=fileread(path);
    f=@(tag) cellfun(@(x) str2double(x{1}), ...
        regexp(txt,['(?m)^\s*' tag '\s+(-?\d+)\s*$'],'tokens'));
    explicitIDs=f('id');
    s=f('source'); e=f('target');
    assert(numel(s)==numel(e),'Unmatched GML endpoints.');
else
    raw=readmatrix(path,'FileType','text');
    assert(~isempty(raw) && size(raw,2)>=2,'Invalid edge list.');
    s=raw(:,1); e=raw(:,2);
end
s=s(:); e=e(:);
valid=isfinite(s)&isfinite(e)&s==fix(s)&e==fix(e);
s=s(valid); e=e(valid);
nodeIDs=unique([explicitIDs(:);s;e],'sorted');
assert(~isempty(nodeIDs));
[~,s]=ismember(s,nodeIDs); [~,e]=ismember(e,nodeIDs);
keep=s~=e;
pairs=unique(sort([s(keep),e(keep)],2),'rows');
edgeStart=pairs(:,1); edgeEnd=pairs(:,2);
end


