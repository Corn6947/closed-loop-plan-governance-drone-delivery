function files = generate_submission_figures(outDir, resultDir)
%GENERATE_SUBMISSION_FIGURES Create final figures from frozen experimental runs.
% Every numerical mark comes from results_frozen; no values are
% manually entered.  The figures intentionally report the conditional result:
% event-triggered fixed inertia is the primary governance candidate, whereas
% adaptive inertia is not claimed to dominate the fixed rule.

root = fileparts(mfilename('fullpath'));
if nargin < 1 || isempty(outDir), outDir = fullfile(root,'figures_tables'); end
if nargin < 2 || isempty(resultDir), resultDir = fullfile(root,'results_frozen'); end
if ~exist(outDir,'dir'), mkdir(outDir); end
M = load(fullfile(resultDir,'primary_policy_comparison_60_scenarios.mat'),'Evidence'); E = M.Evidence;
P80 = loadE(resultDir,'weather_p80_boundary_20_scenarios.mat');
Woff = loadE(resultDir,'wind_gate_ablation_20_scenarios.mat');
Loff = loadE(resultDir,'low_soc_gate_ablation_20_scenarios.mat');
H2 = loadE(resultDir,'planning_window_2_steps_20_scenarios.mat');
H3 = loadE(resultDir,'planning_window_3_steps_20_scenarios.mat');
H4 = loadE(resultDir,'planning_window_4_steps_20_scenarios.mat');
Wlow = loadE(resultDir,'low_inertia_sensitivity_20_scenarios.mat');
Wmid = loadE(resultDir,'reference_inertia_sensitivity_20_scenarios.mat');
Whigh = loadE(resultDir,'high_inertia_sensitivity_20_scenarios.mat');
Gon = loadE(resultDir,'safety_guard_on_20_scenarios.mat'); Goff = loadE(resultDir,'safety_guard_off_20_scenarios.mat');
cal = fullfile(root,'data_calibration','processed');
s = style();

files = { ...
 'Figure1_Closed_Loop_Governance_Architecture.png', ...
 'Figure2_Sao_Paulo_Calibration_Evidence.png', ...
 'Figure3_Representative_Sao_Paulo_Replay.png', ...
 'Figure4_Primary_Holdout_Policy_Evidence.png', ...
 'Figure5_Governance_Mechanism_and_Inertia_Evidence.png', ...
 'Figure6_Boundary_and_Safety_Evidence.png', ...
 'Figure7_Fleet_and_Input_Heterogeneity_Boundaries.png'};
fig1(fullfile(outDir,files{1}),s);
fig2(fullfile(outDir,files{2}),cal,E.Config,s);
fig3(fullfile(outDir,files{3}),E,s);
fig4(fullfile(outDir,files{4}),E,s);
fig5(fullfile(outDir,files{5}),E,P80,Woff,Loff,Wlow,Wmid,Whigh,s);
fig6(fullfile(outDir,files{6}),H2,H3,H4,Gon,Goff,s);
fig7(fullfile(outDir,files{7}),resultDir,s);
fprintf('SP-GFS final figures exported to %s\n',outDir);
end

function E=loadE(dir,name), z=load(fullfile(dir,name),'Evidence'); E=z.Evidence; end
function s=style()
s.font='Times New Roman'; s.ink=[.10 .15 .22]; s.navy=[.08 .23 .42]; s.blue=[.13 .40 .72];
s.orange=[.85 .28 .05]; s.green=[.10 .48 .27]; s.gold=[.65 .43 .06]; s.red=[.76 .13 .13]; s.gray=[.35 .39 .45];
s.lightBlue=[.91 .95 .99]; s.lightGold=[1 .97 .88]; s.lightGreen=[.91 .98 .93]; s.lightRed=[1 .93 .93];
s.policy=[s.gray;s.gold;s.orange;s.green;.32 .32 .32]; s.panel=11.5; s.label=9.2; s.note=7.1;
end
function f=newfig(w,h), f=figure('Color','w','Units','centimeters','Position',[1 1 w h],'PaperPositionMode','auto','Renderer','painters','ToolBar','none','MenuBar','none'); end
function finish(f,file)
set(findall(f,'-property','FontName'),'FontName','Times New Roman'); ax=findall(f,'Type','axes');
for k=1:numel(ax), try, ax(k).Toolbar.Visible='off'; catch, end, end
drawnow; temp=[tempname '.png']; exportgraphics(f,temp,'Resolution',320); a=imread(temp); delete(temp);
if size(a,3)==1,a=repmat(a,1,1,3);end; pad=24; b=uint8(255*ones(size(a,1)+2*pad,size(a,2)+2*pad,3)); b(pad+(1:size(a,1)),pad+(1:size(a,2)),:)=a(:,:,1:3); imwrite(b,file); close(f);
end
function styleax(ax,s), set(ax,'FontName',s.font,'FontSize',s.label,'LineWidth',.75,'Box','on','Layer','top'); grid(ax,'on'); ax.GridAlpha=.14; ax.GridColor=[.2 .25 .3]; end
function c=pale(col,a), c=a*col+(1-a)*[1 1 1]; end
function flowbox(ax,p,str,fill,edge,s)
rectangle(ax,'Position',p,'FaceColor',fill,'EdgeColor',edge,'LineWidth',1.55,'Curvature',.02); if iscell(str),str=strjoin(str,newline);end
text(ax,p(1)+p(3)/2,p(2)+p(4)/2,str,'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',6.9,'FontWeight','bold','Color',edge,'Interpreter','tex');
end
function arrow(ax,x1,y1,x2,y2,c), quiver(ax,x1,y1,x2-x1,y2-y1,0,'Color',c,'LineWidth',1.25,'MaxHeadSize',.20); end

function fig1(file,s)
% The physical panel deliberately shows all three operational UAV roles.
% A legend and an explicit return rule make the schematic self-contained.
f=newfig(19,11.8); ax=axes(f,'Position',[.050 .22 .385 .59]); hold(ax,'on'); axis(ax,[-24 24 -20 20]); axis(ax,'equal'); set(ax,'XTick',[],'YTick',[]); grid(ax,'on'); ax.GridAlpha=.10; box(ax,'on');
z=[-13 -6;-5 7;9 -8;11 6;15 -7;-10 12;7 12;-15 -13]; scatter(ax,z(:,1),z(:,2),40,[.72 .75 .78],'filled','MarkerEdgeColor','w');
scatter(ax,-5,7,92,'p','filled','MarkerFaceColor',s.red,'MarkerEdgeColor','w');
h1=plot(ax,[0 9],[0 -8],'--','Color',s.orange,'LineWidth',2); h2=plot(ax,[0 -5],[0 7],'--','Color',s.blue,'LineWidth',2); h3=plot(ax,[0 -13],[0 -6],'--','Color',s.green,'LineWidth',2);
hp=quiver(ax,0,0,6,4,0,'Color',s.navy,'LineWidth',2.7,'MaxHeadSize',.28); h0=scatter(ax,0,0,82,'s','filled','MarkerFaceColor',s.ink,'MarkerEdgeColor','w');
text(ax,-.5,-2.6,'P_k','HorizontalAlignment','center','FontWeight','bold','FontSize',s.label); text(ax,6.4,3.5,'P_{k+1}','Color',s.navy,'FontWeight','bold','FontSize',s.label);
title(ax,'(a) Mobile-platform/UAV physical boundary','FontWeight','bold','FontSize',11.5);
legend(ax,[h1 h2 h3 h0 hp],{'UAV 1: capacity support','UAV 2: priority service','UAV 3: contingency reserve','platform at P_k','next-step relocation'},'Location','southoutside','NumColumns',2,'Box','off','FontSize',6.1);
ax2=axes(f,'Position',[.49 .18 .485 .67]); axis(ax2,[0 1 0 1]); axis(ax2,'off'); hold(ax2,'on');
flowbox(ax2,[.05 .855 .90 .105],{'Public inputs','Sao Paulo orders | GFS/ERA5 wind | energy envelope'},s.lightBlue,s.navy,s);
flowbox(ax2,[.05 .705 .90 .095],{'Calibrated state estimate','orders | SoC | current wind | released plan'},s.lightGold,s.gold,s);
flowbox(ax2,[.05 .545 .90 .105],{'Shared ForcedSafetyTrigger','model-check the released first-slot task'},s.lightRed,s.red,s);
flowbox(ax2,[.035 .315 .435 .135],{'Model-feasible first slot','ordinary access: Always or ET','W_3 sets revision resistance'},s.lightBlue,s.blue,s);
flowbox(ax2,[.530 .315 .435 .135],{'Model-infeasible first slot','mandatory safety replanning','no accepted plan: hold / swap / defer'},s.lightRed,s.red,s);
flowbox(ax2,[.05 .075 .90 .115],{'Model-accepted execution and feedback','service | stability | energy | next state'},s.lightGreen,s.navy,s);
arrow(ax2,.5,.855,.5,.800,s.gray); arrow(ax2,.5,.705,.5,.650,s.gray);
arrow(ax2,.48,.545,.255,.450,s.blue); arrow(ax2,.52,.545,.745,.450,s.red);
text(ax2,.255,.477,'PASS','Color',s.blue,'FontSize',6.0,'FontWeight','bold','HorizontalAlignment','center');
text(ax2,.745,.477,'OVERRIDE','Color',s.red,'FontSize',6.0,'FontWeight','bold','HorizontalAlignment','center');
arrow(ax2,.255,.315,.405,.190,s.blue); arrow(ax2,.745,.315,.595,.190,s.red);
title(ax2,'(b) Closed-loop governance architecture','FontWeight','bold','FontSize',11.5);
annotation(f,'textbox',[.055 .035 .895 .080],'String',{'Reading note. Dashed rays are same-step UAV sorties from P_k; all three return before platform relocation to P_{k+1}.','The governance path separates discretionary planning access from the shared, non-discretionary safety override.'},'EdgeColor',[.78 .80 .83],'BackgroundColor',[.98 .99 1],'FontName',s.font,'FontSize',6.6,'Color',s.gray,'HorizontalAlignment','center','VerticalAlignment','middle','FitBoxToText','off');
finish(f,file);
end

function fig2(file,cal,cfg,s)
profile=readtable(fullfile(cal,'olist_hourly_demand_profile.csv')); geo=readtable(fullfile(cal,'olist_12_zone_geometry.csv')); w=readtable(fullfile(cal,'sao_paulo_gfs_era5_forecast_pairs_20min.csv')); energy=readtable(fullfile(cal,'matrice100_energy_summary.csv'),'TextType','string');
if ismember('split',w.Properties.VariableNames), h=w(strcmpi(string(w.split),'holdout'),:); else, h=w; end
% The processed release already contains the scalar bias-corrected absolute
% speed residual.  Use that audited column rather than recomputing it with a
% potentially different wind-vector convention.
res=h.abs_bias_corrected_speed_error_mps;
f=newfig(19,13.4); tl=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact'); tl.Position=[.10 .09 .83 .84];
ax=nexttile(tl); bar(ax,profile.hour_of_day,profile.relative_intensity_to_hourly_mean,.78,'FaceColor',s.blue,'EdgeColor','none'); yline(ax,1,'--','hourly mean = 1','Color',s.gray,'LabelHorizontalAlignment','left'); xlim(ax,[-.6 23.6]); ylim(ax,[0 2.0]); xlabel(ax,'Hour of day'); ylabel(ax,'Relative arrival intensity'); title(ax,'(a) Public order-time proxy','FontWeight','bold','FontSize',s.panel); styleax(ax,s);
ax=nexttile(tl); scatter(ax,geo.x_km_from_demand_center,geo.y_km_from_demand_center,3200*geo.calibration_probability,geo.calibration_probability,'filled','MarkerEdgeColor','w'); colormap(ax,parula); cb=colorbar(ax); cb.Label.String='Zone sampling probability'; xlabel(ax,'km from demand centre (x)'); ylabel(ax,'km from demand centre (y)'); axis(ax,'equal'); ylim(ax,[-22 15]); grid(ax,'on'); title(ax,'(b) Spatial demand-zone proxy','FontWeight','bold','FontSize',s.panel); styleax(ax,s);
ax=nexttile(tl); p80=cfg.EventWindThresholdCandidatesMps(1); p90=cfg.EmpiricalEventErrorThresholdMps; histogram(ax,res,'BinWidth',.08,'FaceColor',s.navy,'EdgeColor','none','Normalization','probability'); hold(ax,'on'); xline(ax,cfg.LowRiskErrorThresholdMps,'--','Color',s.gray,'LineWidth',1.1); xline(ax,p80,'--','Color',s.gold,'LineWidth',1.2); xline(ax,p90,'--','Color',s.red,'LineWidth',1.2); xlabel(ax,'Bias-corrected |GFS forecast - ERA5 actual| (m/s)'); ylabel(ax,'Holdout probability'); title(ax,'(c) Same-city weather holdout residual','FontWeight','bold','FontSize',s.panel); ylim(ax,[0 .09]); text(ax,.02,.94,sprintf('Bias correction: %.2f m/s\nP50 (grey), P80 (gold), P90 primary (red)\nGFS 06 UTC; 20-min replay',cfg.GFSForecastSpeedBiasForecastMinusActualMps),'Units','normalized','VerticalAlignment','top','FontSize',s.note,'BackgroundColor','w','Margin',2); styleax(ax,s);
ax=nexttile(tl); dates=unique(energy.date); n=numel(dates); holdDates=dates(max(1,floor(.8*n)+1):end); isHold=ismember(energy.date,holdDates); train=energy(~isHold,:); test=energy(isHold,:); p0=median(train.mean_power_w_abs_vi); pred=p0*test.duration_s/3600; actual=test.energy_wh_abs_vi; scatter(ax,actual,pred,28,s.green,'filled','MarkerEdgeColor','w'); hold(ax,'on'); mx=1.08*max([actual;pred]); plot(ax,[0 mx],[0 mx],'--','Color',s.gray,'LineWidth',1.1); mape=mean(abs(pred-actual)./actual)*100; bias=mean(pred-actual); mae=mean(abs(pred-actual)); text(ax,.05,.92,sprintf('External M100 envelope; n = %d\nMAPE = %.1f%% | bias = %+.1f Wh | MAE = %.1f Wh',height(test),mape,bias,mae),'Units','normalized','VerticalAlignment','top','BackgroundColor','w','Margin',3,'FontSize',s.note); xlabel(ax,'Observed mission energy (Wh)'); ylabel(ax,'Constant-power prediction (Wh)'); title(ax,'(d) External M100 energy holdout','FontWeight','bold','FontSize',s.panel); axis(ax,'square'); xlim(ax,[0 mx]); ylim(ax,[0 mx]); styleax(ax,s); annotation(f,'textbox',[.09 .018 .84 .065],'String',{'Reading note. Panels (a-b) calibrate order timing and zone weights; panel (c) freezes the same-city GFS-ERA5 residual gates.','Panel (d) is an external transfer check on a nontarget M100 airframe, not target-aircraft validation.'},'EdgeColor',[.78 .80 .83],'BackgroundColor',[.98 .99 1],'FontName',s.font,'FontSize',6.8,'Color',s.gray,'HorizontalAlignment','center','VerticalAlignment','middle'); finish(f,file);
end

function fig3(file,E,s)
R=E.Representative; T=numel(R.Trigger); t=1:T; f=newfig(19,14.6); tl=tiledlayout(f,3,1,'TileSpacing','compact','Padding','compact'); tl.Position=[.145 .125 .72 .81];
ax=nexttile(tl); yyaxis(ax,'left'); bar(ax,t,R.Arrivals,.72,'FaceColor',[.72 .74 .76],'EdgeColor','none'); hold(ax,'on'); bar(ax,t,R.VIPArrivals,.72,'FaceColor',s.red,'EdgeColor','none'); ylabel(ax,'Arriving orders','Color',s.navy); yyaxis(ax,'right'); p1=plot(ax,t,R.ForecastWind,'--','Color',s.blue,'LineWidth',1.6); p2=plot(ax,t,R.ActualWind,'-o','Color',s.navy,'MarkerFaceColor',s.navy,'MarkerSize',3,'LineWidth',1.1); ylabel(ax,'Wind speed (m/s)','Color',s.orange); xlim(ax,[1 T]); title(ax,'(a) Sao Paulo order-weather replay (one declared illustrative replication)','FontWeight','bold','FontSize',s.panel); styleax(ax,s);
ax=nexttile(tl); yM=1.15*E.Config.W3base; hold(ax,'on'); eventband(ax,t,R.Trigger,.90*yM,.985*yM,s.blue,.30); eventband(ax,t,R.ForcedSafetyTrigger,.79*yM,.87*yM,s.red,.38); plot(ax,t,R.W3,'-s','Color',s.orange,'MarkerFaceColor',s.orange,'MarkerSize',3.1,'LineWidth',1.3); yline(ax,E.Config.W3base,'--','Color',s.gray,'LineWidth',.9); ylim(ax,[0 yM]); xlim(ax,[1 T]); ylabel(ax,'Adaptive inertia W_3(k)'); title(ax,'(b) Ordinary policy access is separate from safety override','FontWeight','bold','FontSize',s.panel); text(ax,.02,.94,{'Blue band: ordinary planning access','Pink band: ForcedSafetyTrigger override','Orange squares: adaptive W_3(k)'},'Units','normalized','VerticalAlignment','top','FontSize',s.note,'BackgroundColor','w','Margin',2); styleax(ax,s);
ax=nexttile(tl); bar(ax,t,R.Energy,.70,'FaceColor',s.navy,'EdgeColor','none'); ylabel(ax,'Executed step energy (Wh)','Color',s.navy); yyaxis(ax,'right'); plot(ax,t,R.Hs,'-o','Color',s.orange,'MarkerFaceColor',s.orange,'MarkerSize',3,'LineWidth',1.2); ylabel(ax,'Plan-change distance H_s','Color',s.orange); xlim(ax,[1 T]); xlabel(ax,'Rolling decision step'); title(ax,'(c) Safe execution and realised organisational response','FontWeight','bold','FontSize',s.panel); text(ax,.02,.92,{'Navy bars: executed flight energy','Orange line: policy plan-change distance H_s'},'Units','normalized','VerticalAlignment','top','FontSize',s.note,'BackgroundColor','w','Margin',2); styleax(ax,s);
annotation(f,'textbox',[.09 .018 .82 .075],'String',{'Reading note. This declared replay illustrates process timing only, not policy ranking; the adaptive curve is not evidence of adaptive-policy superiority.','Blue bands denote ordinary access, pink bands denote the mandatory safety override, and navy bars report energy of successfully executed flights.'},'EdgeColor',[.78 .80 .83],'BackgroundColor',[.98 .99 1],'FontName',s.font,'FontSize',6.7,'Color',s.gray,'HorizontalAlignment','center','VerticalAlignment','middle'); finish(f,file);
end

function fig4(file,E,s)
names={'AlwaysFixed','ETFixed','AlwaysAdaptive','ETAdaptive','AlwaysMyopic'}; f=newfig(20,13.6); tl=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact'); tl.Position=[.13 .10 .80 .83];
dotpanel(nexttile(tl),E,'VIPOnTimeRate',names,'VIP on-time rate (%)','(a) VIP on-time rate',s); dotpanel(nexttile(tl),E,'CompletionRate',names,'Total completion rate (%)','(b) Total completion rate',s); dotpanel(nexttile(tl),E,'EnergyPerOrder',names,'Flight energy per completed order (Wh)','(c) Flight energy per completed order',s); dotpanel(nexttile(tl),E,'PolicyPlanningReleaseRate',names,'Ordinary planning access rate (%)','(d) Ordinary planning access',s); finish(f,file);
end
function dotpanel(ax,E,field,names,xlab,ttl,s)
[m,h]=meanCI(E.Metrics.(field)); y=numel(m):-1:1; hold(ax,'on'); for i=1:numel(m), line(ax,[m(i)-h(i) m(i)+h(i)],[y(i) y(i)],'Color',s.policy(i,:),'LineWidth',1.6); plot(ax,m(i),y(i),'o','MarkerSize',6.5,'MarkerFaceColor',s.policy(i,:),'MarkerEdgeColor',s.ink); end; lo=min(m-h); hi=max(m+h); pd=max(.7,.12*(hi-lo)); xlim(ax,[lo-pd hi+pd]); set(ax,'YTick',1:numel(m),'YTickLabel',fliplr(names),'YLim',[.4 numel(m)+.6]); xlabel(ax,xlab); title(ax,ttl,'FontWeight','bold','FontSize',s.panel); styleax(ax,s); text(ax,.02,.04,'Points: scenario means; whiskers: 95% Student-t CIs. n = 60.','Units','normalized','FontSize',s.note,'Color',s.gray);
end

function fig5(file,E,P80,Woff,Loff,Wlow,Wmid,Whigh,s)
f=newfig(21.0,11.2); tl=tiledlayout(f,1,3,'TileSpacing','compact','Padding','compact'); tl.Position=[.08 .25 .86 .66];
sets={E,P80,Woff,Loff}; labs={'P90','P80','wind gate OFF','low-SoC gate OFF'}; ax=nexttile(tl); [d,h]=arrayfun(@(k)accessCI(sets{k},'CompletionRate'),1:4); errorbar(ax,1:4,d,h,'o','Color',s.green,'MarkerFaceColor',s.green,'LineStyle','none','LineWidth',1.3,'CapSize',4); hold(ax,'on'); yline(ax,0,'Color',s.gray); set(ax,'XTick',1:4,'XTickLabel',labs,'XTickLabelRotation',18); ylim(ax,[-5 13]); ylabel(ax,'ETFixed - AlwaysFixed (pp)'); title(ax,'(a) Completion under access-rule conditions','FontWeight','bold','FontSize',s.panel); text(ax,.02,.04,'Paired t 95% CIs; P90 n = 60, boundaries n = 20.','Units','normalized','FontSize',s.note,'Color',s.gray); styleax(ax,s);
sets={Wlow,Wmid,Whigh}; labs={'low','frozen','high'}; ax=nexttile(tl); [d,h]=arrayfun(@(k)adaptiveCI(sets{k},'VIPOnTimeRate'),1:3); errorbar(ax,1:3,d,h,'o','Color',s.orange,'MarkerFaceColor',s.orange,'LineStyle','none','LineWidth',1.3,'CapSize',4); hold(ax,'on'); yline(ax,0,'Color',s.gray); text(ax,2,.7,'all 20 paired differences = 0','HorizontalAlignment','center','FontSize',6.2,'Color',s.gray); set(ax,'XTick',1:3,'XTickLabel',labs); ylim(ax,[-22 8]); ylabel(ax,'ETAdaptive - ETFixed (VIP pp)'); title(ax,'(b) Adaptive plan-inertia sensitivity','FontWeight','bold','FontSize',s.panel); text(ax,.02,.04,{'No tested range confirms a stable','adaptive advantage; n = 20 per range.'},'Units','normalized','FontSize',s.note,'Color',s.gray); styleax(ax,s);
ax=nexttile(tl); [m,h]=meanCI(E.Metrics.HsPolicy); [v,vh]=meanCI(E.Metrics.VIPOnTimeRate); hold(ax,'on'); mk={'s','d','^','o'}; short={'AF','EF','AA','EA'}; dx=[5 5 5 7]; dy=[1.4 -2.2 -1.4 .7]; for i=1:4, errorbar(ax,m(i),v(i),vh(i),vh(i),h(i),h(i),'LineStyle','none','Marker',mk{i},'MarkerSize',7,'MarkerFaceColor',s.policy(i,:),'MarkerEdgeColor',s.ink,'Color',s.policy(i,:),'LineWidth',1.1); text(ax,m(i)+dx(i),v(i)+dy(i),short{i},'FontWeight','bold','FontSize',6.8,'Color',s.policy(i,:)); end; xlim(ax,[145 285]); ylim(ax,[20 72]); xlabel(ax,'Policy-induced plan-change distance H_{s,policy}'); ylabel(ax,'VIP on-time rate (%)'); title(ax,'(c) Primary service-stability trade-off','FontWeight','bold','FontSize',s.panel); styleax(ax,s); text(ax,.03,.06,sprintf('AlwaysMyopic outside x-axis:\nH_{s,policy} = %.1f; VIP = %.1f%%',m(5),v(5)),'Units','normalized','FontSize',6.2,'Color',s.gray,'BackgroundColor','w','Margin',2);
annotation(f,'textbox',[.08 .025 .86 .11],'String',{'Reading note. Panel (a) reports P90, P80, wind-gate-OFF, and low-SoC-gate-OFF access-rule contrasts. Panel (b) reports independent low (10 vs 10-20), frozen (20 vs 10-50), and high (50 vs 25-50) plan-inertia boundary runs.','Panel (c): AF = AlwaysFixed; EF = ETFixed; AA = AlwaysAdaptive; EA = ETAdaptive. AlwaysMyopic is reported numerically because its plan-change distance lies far outside the four-policy range. Whiskers are Student-t 95% confidence intervals.'},'EdgeColor',[.78 .80 .83],'BackgroundColor',[.98 .99 1],'FontName',s.font,'FontSize',6.1,'Color',s.gray,'HorizontalAlignment','center','VerticalAlignment','middle'); finish(f,file);
end

function fig6(file,H2,H3,H4,Gon,Goff,s)
f=newfig(19.8,9.7); tl=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact'); tl.Position=[.10 .16 .80 .75];
sets={H2,H3,H4}; ax=nexttile(tl); [dc,hc]=arrayfun(@(k)accessCI(sets{k},'CompletionRate'),1:3); [de,he]=arrayfun(@(k)accessCI(sets{k},'EnergyPerOrder'),1:3); yyaxis(ax,'left'); errorbar(ax,(2:4)-.06,dc,hc,'o','Color',s.green,'MarkerFaceColor',s.green,'LineStyle','none','LineWidth',1.3,'CapSize',4); ylabel(ax,'Completion difference (pp)','Color',s.green); ax.YAxis(1).Color=s.green; yyaxis(ax,'right'); errorbar(ax,(2:4)+.06,de,he,'s','Color',s.orange,'MarkerFaceColor',s.orange,'LineStyle','none','LineWidth',1.3,'CapSize',4); ylabel(ax,'Energy difference (Wh)','Color',s.orange); ax.YAxis(2).Color=s.orange; xlabel(ax,'Rolling horizon H'); xlim(ax,[1.7 4.3]); xticks(ax,2:4); title(ax,'(a) Planning-window boundary evidence','FontWeight','bold','FontSize',s.panel); text(ax,.03,.04,'Separate n = 20 sets; no trend line.','Units','normalized','FontSize',s.note,'Color',s.gray); styleax(ax,s);
keys=string({Gon.Policies.Key}); ix=[find(keys=="ETFixed",1) find(keys=="ETAdaptive",1)]; on=mean(Gon.Metrics.UnsafeExecutionRate(ix,:),2); off=mean(Goff.Metrics.UnsafeExecutionRate(ix,:),2); hOn=ciHalf(Gon.Metrics.UnsafeExecutionRate(ix,:)); hOff=ciHalf(Goff.Metrics.UnsafeExecutionRate(ix,:)); ax=nexttile(tl); b=bar(ax,[on off],.68,'grouped'); b(1).FaceColor=s.green;b(2).FaceColor=s.red; hold(ax,'on'); for r=1:2, errorbar(ax,r-.17,on(r),hOn(r),'k.','LineWidth',1,'CapSize',4); errorbar(ax,r+.17,off(r),hOff(r),'k.','LineWidth',1,'CapSize',4); text(ax,r-.17,.18,'0.000','HorizontalAlignment','center','FontSize',6.2,'Color',s.green,'FontWeight','bold'); end; set(ax,'XTickLabel',{'ETFixed','ETAdaptive'}); ylabel(ax,'Infeasible execution (% of arrived orders)'); ylim(ax,[0 max(8,max(off(:)+hOff(:))*1.2)]); title(ax,'(b) Matched-seed safety-guard ablation','FontWeight','bold','FontSize',s.panel); legend(ax,b,{'Shared guard ON','Guard OFF'},'Location','northwest','Box','off','FontSize',7.4); styleax(ax,s); finish(f,file);
end

function fig7(file,resultDir,s)
fleet=readtable(fullfile(resultDir,'exports','fleet_size_boundaries.csv'));
roles=readtable(fullfile(resultDir,'exports','fleet_role_utilisation.csv'));
het=readtable(fullfile(resultDir,'exports','input_heterogeneity_diagnostics.csv'));
% The upper-two/lower-one layout stays readable when the PNG is inserted at
% the manuscript's 6.75-inch width.
f=newfig(19.0,13.4);
ax=axes(f,'Position',[.10 .57 .31 .33]); x=fleet.FleetSize';
yyaxis(ax,'left'); errorbar(ax,x-.04,fleet.CompletionDelta',fleet.CompletionDelta'-fleet.CompletionLower',fleet.CompletionUpper'-fleet.CompletionDelta','o','Color',s.green,'MarkerFaceColor',s.green,'LineStyle','none','LineWidth',1.35,'CapSize',4); ylabel(ax,'Completion difference (pp)','Color',s.green);
yyaxis(ax,'right'); errorbar(ax,x+.04,fleet.PolicyHsDelta',fleet.PolicyHsDelta'-fleet.PolicyHsLower',fleet.PolicyHsUpper'-fleet.PolicyHsDelta','s','Color',s.orange,'MarkerFaceColor',s.orange,'LineStyle','none','LineWidth',1.35,'CapSize',4); ylabel(ax,'Policy-induced H_s difference','Color',s.orange);
xlabel(ax,'Fleet size D'); xlim(ax,[1.7 4.3]); xticks(ax,2:4); title(ax,'(a) Governance effect across fleet sizes','FontWeight','bold','FontSize',10.2); styleax(ax,s);
% A heat map is clearer than the previous stacked bars: it preserves the
% role-by-fleet comparison and shows unavailable UAV roles explicitly.
ax=axes(f,'Position',[.59 .57 .30 .33]); subset=roles(roles.Policy=="ETFixed",:); vals=nan(4,3); for i=1:height(subset), r=subset(i,:); vals(r.DroneIndex,r.FleetSize-1)=r.MeanActions; end
imagesc(ax,2:4,1:4,vals); set(ax,'YDir','reverse'); colormap(ax,parula); cb=colorbar(ax); cb.Label.String='Mean sorties / episode'; caxis(ax,[0 14]); xlabel(ax,'Fleet size D'); xticks(ax,2:4); yticks(ax,1:4); yticklabels(ax,{'UAV 1 capacity','UAV 2 priority','UAV 3 reserve','UAV 4 capacity'}); title(ax,'(b) ETFixed role utilisation','FontWeight','bold','FontSize',10.2); styleax(ax,s); ax.FontSize=8;
for r=1:4, for c=1:3, if isnan(vals(r,c)), text(ax,c+1,r,'n/a','HorizontalAlignment','center','FontSize',7.4,'Color',s.ink,'FontAngle','italic'); else, text(ax,c+1,r,sprintf('%.1f',vals(r,c)),'HorizontalAlignment','center','FontWeight','bold','FontSize',7.8,'Color','w'); end, end, end
% Leave a wider left margin for the subgroup labels at manuscript width.
% The wording preserves the outcome-blind median-split meaning while avoiding
% labels extending beyond the exported PNG boundary.
ax=axes(f,'Position',[.18 .20 .74 .23]); cRows=het(het.Outcome=="Completion",:); y=4:-1:1; labels={'Orders: lower half','Orders: upper half','Wind residual: lower half','Wind residual: upper half'}; hold(ax,'on'); xline(ax,0,'Color',s.gray); for i=1:height(cRows), line(ax,[cRows.T95Lower(i) cRows.T95Upper(i)],[y(i) y(i)],'Color',s.navy,'LineWidth',1.5); plot(ax,cRows.ETFixedMinusAlwaysFixed(i),y(i),'o','MarkerFaceColor',s.navy,'MarkerEdgeColor',s.ink,'MarkerSize',6); end;
set(ax,'YTick',1:4,'YTickLabel',flip(labels),'YLim',[.4 4.6]); xlim(ax,[-1 11]); xlabel(ax,'Completion difference (pp)'); title(ax,'(c) Descriptive input heterogeneity','FontWeight','bold','FontSize',10.2); styleax(ax,s); ax.FontSize=8; annotation(f,'textbox',[.075 .025 .88 .095],'String',{'Reading note. Panel (a) uses a fleet-boundary seed range frozen independently of the primary P90 evaluation and reuses it across D = 2, 3, and 4; no fleet-size trend is estimated.','Panel (b) is a role-by-fleet heat map (n/a = UAV not present). Panel (c) is a result-blind median split of the 60 primary scenarios (n = 30 per stratum), not a confirmatory subgroup test.'},'EdgeColor',[.78 .80 .83],'BackgroundColor',[.98 .99 1],'FontName',s.font,'FontSize',6.8,'Color',s.gray,'HorizontalAlignment','center','VerticalAlignment','middle'); finish(f,file);
end

function eventband(ax,t,flag,y0,y1,col,a)
active=false; first=1; for k=1:numel(flag)+1, q=k<=numel(flag)&&logical(flag(k)); if q&&~active,first=k;active=true;elseif ~q&&active,last=k-1;rectangle(ax,'Position',[t(first)-.45 y0 t(last)-t(first)+.9 y1-y0],'FaceColor',pale(col,a),'EdgeColor',col,'LineWidth',.5);active=false;end,end
end
function [m,h]=meanCI(x),m=mean(x,2)';h=ciHalf(x);end
function h=ciHalf(x), n=size(x,2); h=tinv(.975,n-1)*std(x,0,2)'/sqrt(n); end
function [d,h]=accessCI(E,field), k=string({E.Policies.Key}); a=find(k=="AlwaysFixed",1);e=find(k=="ETFixed",1);x=E.Metrics.(field)(e,:)-E.Metrics.(field)(a,:);d=mean(x);h=tinv(.975,numel(x)-1)*std(x)/sqrt(numel(x));end
function [d,h]=adaptiveCI(E,field), k=string({E.Policies.Key});a=find(k=="ETAdaptive",1);e=find(k=="ETFixed",1);x=E.Metrics.(field)(a,:)-E.Metrics.(field)(e,:);d=mean(x);h=tinv(.975,numel(x)-1)*std(x)/sqrt(numel(x));end
