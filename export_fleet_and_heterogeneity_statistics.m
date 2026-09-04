function Out = export_fleet_and_heterogeneity_statistics(root, outDir)
%EXPORT_FLEET_AND_HETEROGENEITY_STATISTICS Transparent supplementary
% boundary evidence. Fleet results are R=60 matched-date replications. The
% heterogeneity partition is post-primary but outcome-blind: it ranks only
% input covariates (orders or bias-corrected weather residual), breaks ties
% by scenario seed, and never changes the confirmatory primary analysis.
if nargin<1 || isempty(root), root='results_frozen'; end
if nargin<2 || isempty(outDir), outDir=fullfile(root,'exports'); end
if ~exist(outDir,'dir'), mkdir(outDir); end

files={'fleet_size_2_60_scenarios.mat','fleet_size_3_60_scenarios.mat','fleet_size_4_60_scenarios.mat'};
fleet=table(); roleRows=table();
for j=1:numel(files)
    E=loadE(root,files{j}); assert(E.Summary.R==60); assert(all(E.Metrics.UnsafeExecutionRate(:)==0));
    [a,e]=access(E); metrics={'VIPOnTimeRate','CompletionRate','EnergyPerOrder','HsPolicy','PolicyPlanningReleaseRate','ForcedSafetyTriggerRate'};
    row=table(E.Config.D,E.Summary.R,'VariableNames',{'FleetSize','Scenarios'});
    for k=1:numel(metrics)
        [mu,lo,hi]=tci(E.Metrics.(metrics{k})(e,:)-E.Metrics.(metrics{k})(a,:)); st=stem(metrics{k});
        row.([st 'Delta'])=mu; row.([st 'Lower'])=lo; row.([st 'Upper'])=hi;
    end
    row.MaxGuardedUnsafePct=max(E.Metrics.UnsafeExecutionRate(:)); fleet=[fleet;row]; %#ok<AGROW>
    for p=1:numel(E.Policies)
        for d=1:E.Config.D
            x=squeeze(E.RoleActions(p,:,d)); [mu,lo,hi]=tci(x);
            roleRows=[roleRows;table(E.Config.D,string(E.Policies(p).Key),d,mu,lo,hi,...
                'VariableNames',{'FleetSize','Policy','DroneIndex','MeanActions','T95Lower','T95Upper'})]; %#ok<AGROW>
        end
    end
end
writetable(fleet,fullfile(outDir,'fleet_size_boundaries.csv'));
writetable(roleRows,fullfile(outDir,'fleet_role_utilisation.csv'));

E=loadE(root,'primary_policy_comparison_60_scenarios.mat'); [a,e]=access(E); n=E.Summary.R; cov=table(E.ScenarioSeeds(:),'VariableNames',{'ScenarioSeed'});
cfg=E.Config; orderTotal=zeros(n,1); weatherResidual=zeros(n,1); dates=strings(n,1);
for r=1:n
    scen=draw_sao_paulo_order_weather_scenario(cfg,E.ScenarioSeeds(r));
    orderTotal(r)=sum(scen.ReplayObservedPurchaseCount);
    weatherResidual(r)=mean(abs(scen.ForecastWind-scen.ActualWind));
    dates(r)=string(scen.ReplayEpisodeDate);
end
cov.OrderTotal=orderTotal; cov.MeanBiasCorrectedAbsWindResidualMps=weatherResidual; cov.ReplayEpisodeDate=dates;
writetable(cov,fullfile(outDir,'primary_input_covariates.csv'));

het=table(); metrics={'VIPOnTimeRate','CompletionRate','EnergyPerOrder','HsPolicy','PolicyPlanningReleaseRate'};
specs={'OrderTotal',orderTotal;'MeanBiasCorrectedAbsWindResidualMps',weatherResidual};
for z=1:size(specs,1)
    name=specs{z,1}; x=specs{z,2}; [~,ord]=sortrows([x(:),E.ScenarioSeeds(:)],[1 2]); groups={ord(1:n/2),ord(n/2+1:end)}; labels={'Lower half','Upper half'};
    for g=1:2
        idx=groups{g};
        for k=1:numel(metrics)
            delta=E.Metrics.(metrics{k})(e,idx)-E.Metrics.(metrics{k})(a,idx); [mu,lo,hi]=tci(delta); st=stem(metrics{k});
            het=[het;table(string(name),string(labels{g}),numel(idx),mean(x(idx)),min(x(idx)),max(x(idx)),string(st),mu,lo,hi,...
                'VariableNames',{'InputCovariate','InputStratum','Scenarios','CovariateMean','CovariateMin','CovariateMax','Outcome','ETFixedMinusAlwaysFixed','T95Lower','T95Upper'})]; %#ok<AGROW>
        end
    end
end
writetable(het,fullfile(outDir,'input_heterogeneity_diagnostics.csv'));
Out=struct('FleetBoundary',fleet,'FleetRoles',roleRows,'InputCovariates',cov,'Heterogeneity',het,...
    'Interpretation','Fleet boundary uses 60 matched replays. Heterogeneity is a transparent, outcome-blind, post-primary descriptive split and does not alter the primary inference.');
save(fullfile(outDir,'fleet_and_heterogeneity_analysis.mat'),'Out','-v7');
end
function E=loadE(root,name),s=load(fullfile(root,name),'Evidence');E=s.Evidence;end
function [a,e]=access(E),k=string({E.Policies.Key});a=find(k=="AlwaysFixed",1);e=find(k=="ETFixed",1);assert(~isempty(a)&&~isempty(e));end
function [mu,lo,hi]=tci(x),x=x(:);mu=mean(x);hw=tinv(.975,numel(x)-1)*std(x)/sqrt(numel(x));lo=mu-hw;hi=mu+hw;end
function s=stem(metric),m=struct('VIPOnTimeRate','VIP','CompletionRate','Completion','EnergyPerOrder','Energy','HsPolicy','PolicyHs','PolicyPlanningReleaseRate','Access','ForcedSafetyTriggerRate','ForcedSafety');s=m.(metric);end
