function render_uniform_cost_allocation_figures(Models,CommunityModels,outputDir)
%RENDER_UNIFORM_COST_ALLOCATION_FIGURES Inherit the supplied ICE figure style.
% Separate Local/Global figures; Times New Roman 10 pt, inward ticks, box on,
% no grid, lines palette, solid curves and hollow o/s/^/d/v markers.
% Data and normalization are unchanged. Every source point remains in the
% plotted line; only marker placement is thinned to avoid a dense marker band.
% Figures: 14 x 10 cm; outside legends use 18 x 10 cm, as in the ICE script.
% No dissatisfaction value is drawn beyond the imputation cutoff.
if ~isfolder(outputDir), mkdir(outputDir); end
N=size(Models,1);
colors=lines(8);
markers={'o','s','^','d','v','>','<','p'};
types=["Local","Global"];
cutoffs=zeros(N,2); names=strings(1,N);
for d=1:N
    names(d)=Models{d,1}.Dataset;
    for t=1:2
        cutoffs(d,t)=Models{d,t}.CriticalC(Models{d,t}.Winner);
    end
end
finiteCutoffs=cutoffs(isfinite(cutoffs) & cutoffs>=0);
cMax=max([10;5*ceil(finiteCutoffs(:)/5)]);
cGrid=linspace(0,cMax,601)';
sourceRows=cell(2*N,1);

for t=1:2
    [fig,ax]=newFigure(types(t)+": imputation surplus");
    allR=[];
    for d=1:N
        M=Models{d,t}; a=M.Winner; star=cutoffs(d,t);
        c=unique([cGrid;star(isfinite(star) & star>=0)]);
        r=(M.Surplus0(a)+c*M.SurplusSlope)/M.NodeCount;
        idx=markerIndices(c,d,N,star);
        plot(ax,c,r,[markers{M.DatasetIndex},'-'], ...
            'Color',colors(M.DatasetIndex,:),'LineWidth',1.0, ...
            'MarkerSize',6,'MarkerFaceColor','none','MarkerIndices',idx, ...
            'DisplayName',latexName(names(d)));
        allR=[allR;r]; %#ok<AGROW>
        sourceRows{(t-1)*N+d}=table(repmat(M.Dataset,numel(c),1), ...
            repmat(M.NetworkType,numel(c),1),c,r, ...
            'VariableNames',{'Dataset','NetworkType','c','SurplusPerNode'});
    end
    plot(ax,[0,cMax],[0,0],'k--','LineWidth',1.3,'DisplayName','$R(c)=0$');
    xlabel(ax,'$c$','Interpreter','latex');
    ylabel(ax,'$R(c)/n$','Interpreter','latex');
    xlim(ax,[0,cMax]); set(ax,'XTick',0:5:cMax);
    span=max(1,max(allR)-min(allR));
    ylim(ax,[min(allR)-.05*span,max(allR)+.08*span]);
    legend(ax,'Location','best','Interpreter','latex','FontSize',10);
    exportFigure(fig,ax,outputDir,char(types(t)+"_c_vs_imputation"));
end
writetable(vertcat(sourceRows{:}),fullfile(outputDir,'imputation_figure_data.csv'));
if isempty(CommunityModels), return; end

sourceRows=cell(2*N,1);
for t=1:2
    [fig,ax]=newFigure(types(t)+": minimum community dissatisfaction");
    zMax=0; lastCost=0;
    for d=1:N
        M=Models{d,t}; C=CommunityModels{d,t}; star=C.CriticalC;
        knots=-C.Gap0(C.GapSlope<0)./C.GapSlope(C.GapSlope<0);
        knots=knots(knots>=0 & knots<=star);
        onset=C.DissatisfactionOnset;
        c=unique([cGrid(cGrid<star);star;knots;onset(isfinite(onset)&onset>=0)]);
        R=C.Surplus0+c*C.SurplusSlope;
        H=sum(max(C.Gap0+C.GapSlope*c',0),1)';
        z=max(H-R,0);
        plottedZ=z/C.NodeCount;
        plottedZ(plottedZ<1e-9)=0;
        idx=markerIndices(c,d,N,star,6);
        plot(ax,c,plottedZ,[markers{M.DatasetIndex},'-'], ...
            'Color',colors(M.DatasetIndex,:),'LineWidth',1.0, ...
            'MarkerSize',6,'MarkerFaceColor','none','MarkerIndices',idx, ...
            'DisplayName',latexName(names(d)));
        zMax=max(zMax,max(plottedZ)); lastCost=max(lastCost,max(c));
        sourceRows{(t-1)*N+d}=table(repmat(M.Dataset,numel(c),1), ...
            repmat(M.NetworkType,numel(c),1),c,R,H,z,z/C.NodeCount, ...
            'VariableNames',{'Dataset','NetworkType','c','Surplus','RequiredSurplus','z','zPerNode'});
        assert(all(diff(z)>=-10*C.Tolerance));
    end
    xlabel(ax,'$c$','Interpreter','latex');
    ylabel(ax,'$z(c)/n$','Interpreter','latex');
    % Same threshold-plot convention: retain all values and 15% headroom.
    yUpper=1.15*zMax; if yUpper<=0, yUpper=1; end
    ylim(ax,[0,yUpper]);
    xUpper=5*ceil(lastCost/5); if xUpper<=0, xUpper=1; end
    xlim(ax,[0,xUpper]);
    if xUpper<=15, set(ax,'XTick',0:2:xUpper); else, set(ax,'XTick',0:5:xUpper); end
    outsideLegend(fig,ax);
    exportFigure(fig,ax,outputDir,char(types(t)+"_c_vs_dissatisfaction"));
end
writetable(vertcat(sourceRows{:}),fullfile(outputDir,'dissatisfaction_figure_data.csv'));

% Companion regime diagrams use the same typography and axes.
stateColors=[colors(1,:);colors(2,:);.85 .85 .85];
for t=1:2
    [fig,ax]=newFigure(types(t)+": allocation regimes");
    for d=1:N
        C=CommunityModels{d,t}; star=C.CriticalC; onset=C.DissatisfactionOnset;
        if ~isfinite(onset), onset=star; end
        ends=[0,onset,star,cMax];
        for state=1:3
            if ends(state+1)>ends(state)
                rectangle(ax,'Position',[ends(state),d-.3,ends(state+1)-ends(state),.6], ...
                    'FaceColor',stateColors(state,:),'EdgeColor','none');
            end
        end
        
    end
    stateNames={'$z=0$','$z>0$','$\mathrm{Empty}$'};
    for state=1:3
        plot(ax,NaN,NaN,'s','Color',stateColors(state,:), ...
            'MarkerFaceColor',stateColors(state,:),'MarkerSize',6, ...
            'DisplayName',stateNames{state});
    end
    set(ax,'YTick',1:N,'YTickLabel',names,'YDir','reverse');
    xlabel(ax,'$c$','Interpreter','latex');
    xlim(ax,[0,cMax]); ylim(ax,[.4,N+.6]); set(ax,'XTick',0:5:cMax);
    outsideLegend(fig,ax);
    exportFigure(fig,ax,outputDir,char(types(t)+"_c_vs_allocation_regimes"));
end
end

function label=latexName(name)
label=['$\mathrm{' char(name) '}$'];
end

function idx=markerIndices(c,seriesIndex,numberOfSeries,critical,numberOfMarkers)
% Stagger symbols to distinguish coincident baselines.
% No source rows are removed and no coordinates are jittered.
if nargin<5, numberOfMarkers=18; end
step=(c(end)-c(1))/numberOfMarkers;
if step<=0, idx=1; return; end
targets=(c(1):step:c(end))'+step*(seriesIndex-1)/numberOfSeries;
targets=targets(targets<=c(end));
targets=[targets;critical(isfinite(critical)&critical>=c(1)&critical<=c(end))];
idx=zeros(size(targets));
for k=1:numel(targets), [~,idx(k)]=min(abs(c-targets(k))); end
idx=unique(idx);
end

function [fig,ax]=newFigure(windowName)
fig=figure('Color','white','Visible','off','Name',windowName, ...
    'NumberTitle','off','Units','centimeters','Position',[2 2 14 10], ...
    'PaperPositionMode','auto','Renderer','painters');
ax=axes(fig); hold(ax,'on');
set(ax,'FontName','Times New Roman','FontSize',10,'LineWidth',.75, ...
    'TickDir','in','Box','on');
grid(ax,'off');
end

function outsideLegend(fig,ax)
position=get(fig,'Position'); position(3)=18; set(fig,'Position',position);
legend(ax,'Location','eastoutside','Interpreter','latex','FontSize',10);
end

function exportFigure(fig,ax,out,name)
grid(ax,'off'); hold(ax,'off'); drawnow;
stem=fullfile(out,name);
% Preserve the full physical canvas so LaTeX glyphs are not tightly cropped.
fig.Units='centimeters'; dimensions=fig.Position(3:4);
fig.PaperUnits='centimeters'; fig.PaperSize=dimensions;
fig.PaperPosition=[0,0,dimensions];
print(fig,[stem '.pdf'],'-dpdf','-painters');
print(fig,[stem '.png'],'-dpng','-r600');
print(fig,[stem '.eps'],'-depsc','-painters','-r600');
print(fig,[stem '.svg'],'-dsvg');
savefig(fig,[stem '.fig']);
% Separate figures each have one panel; panel alignment is not applicable.
close(fig);
end
