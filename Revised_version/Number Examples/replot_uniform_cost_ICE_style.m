function outputDir = replot_uniform_cost_ICE_style(sourceDirectory)
%REPLOT_UNIFORM_COST_ICE_STYLE Replot saved results in the supplied ICE style.
% outputDir = replot_uniform_cost_ICE_style;
% No community detection or optimization is repeated.
base=fileparts(mfilename('fullpath'));
if nargin<1 || isempty(sourceDirectory)
    files=dir(fullfile(base,'allocation_figures','*','community_cost_results.mat'));
    assert(~isempty(files),'Run plot_uniform_cost_allocation first.');
    [~,k]=max([files.datenum]); sourceDirectory=files(k).folder;
end
C=load(fullfile(sourceDirectory,'community_cost_results.mat'), ...
    'CommunityModels','resultFile','datasetIndices');
resultFile=C.resultFile;
if ~isfile(resultFile), resultFile=fullfile(base,resultFile); end
S=load(resultFile,'Models','datasetIndices');
[present,order]=ismember(C.datasetIndices,S.datasetIndices);
assert(all(present));
outputDir=fullfile(base,'allocation_figures', ...
    [char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')) '_ICE_style']);
render_uniform_cost_allocation_figures(S.Models(order,:),C.CommunityModels,outputDir);
% Require identical data tables for this appearance-only revision.
for file={'imputation_figure_data.csv','dissatisfaction_figure_data.csv'}
    previous=fullfile(sourceDirectory,file{1});
    if isfile(previous)
        assert(isequaln(readtable(previous),readtable(fullfile(outputDir,file{1}))), ...
            'Source data changed during the style revision.');
    end
end
fprintf('PASS: plotted data match the previous figures.\n');
fprintf('ICE-style figures saved to:\n%s\n',outputDir);
end
