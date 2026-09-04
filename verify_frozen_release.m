function verify_frozen_release(root)
%VERIFY_FROZEN_RELEASE Required invariants for the final governance study.
if nargin<1 || isempty(root), root=fileparts(mfilename('fullpath')); end
r=fullfile(root,'results_frozen'); fig=fullfile(root,'figures_tables'); cal=fullfile(root,'data_calibration','processed');
primary=loadE(r,'primary_policy_comparison_60_scenarios.mat'); assert(primary.Summary.R==60,'Primary R must equal 60.'); assert(numel(primary.Policies)==5,'Primary policy set must contain five policies.'); assert(all(primary.Metrics.UnsafeExecutionRate(:)==0),'Primary guarded safety invariant failed.');
names={'weather_p80_boundary_20_scenarios.mat','wind_gate_ablation_20_scenarios.mat','low_soc_gate_ablation_20_scenarios.mat','low_inertia_sensitivity_20_scenarios.mat','reference_inertia_sensitivity_20_scenarios.mat','high_inertia_sensitivity_20_scenarios.mat','low_plan_change_scale_20_scenarios.mat','high_plan_change_scale_20_scenarios.mat','planning_window_2_steps_20_scenarios.mat','planning_window_3_steps_20_scenarios.mat','planning_window_4_steps_20_scenarios.mat','safety_guard_on_20_scenarios.mat'};
for i=1:numel(names), E=loadE(r,names{i}); assert(E.Summary.R==20,'%s must have R=20.',names{i}); assert(all(E.Metrics.UnsafeExecutionRate(:)==0),'Guarded invariant failed: %s',names{i}); end
on=loadE(r,'safety_guard_on_20_scenarios.mat'); off=loadE(r,'safety_guard_off_20_scenarios.mat'); assert(isequal(on.ScenarioSeeds,off.ScenarioSeeds),'Safety ON/OFF seeds are not paired.'); assert(any(off.Metrics.UnsafeExecutionRate(:)>0),'Guard OFF counterfactual unexpectedly has no unsafe executions.');
fleetNames={'fleet_size_2_60_scenarios.mat','fleet_size_3_60_scenarios.mat','fleet_size_4_60_scenarios.mat'};
fleetSeeds=[];
for i=1:numel(fleetNames)
    E=loadE(r,fleetNames{i});
    assert(E.Summary.R==60,'%s must have R=60.',fleetNames{i});
    assert(numel(E.Policies)==2,'Fleet-size boundary must compare the two fixed-inertia policies.');
    assert(all(E.Metrics.UnsafeExecutionRate(:)==0),'Fleet-size guarded safety invariant failed: %s',fleetNames{i});
    if i==1, fleetSeeds=E.ScenarioSeeds; else, assert(isequal(fleetSeeds,E.ScenarioSeeds),'Fleet-size scenarios are not shared.'); end
end
t=readtable(fullfile(cal,'sao_paulo_gfs_era5_forecast_pairs_20min.csv'));
requiredColumns={'gfs_wind_mps','era5_u10_mps','era5_v10_mps','abs_bias_corrected_speed_error_mps'};
assert(all(ismember(requiredColumns,t.Properties.VariableNames)), 'Same-city GFS/ERA5 calibration columns missing.');
assert(any(strcmpi(string(t.split),'holdout')), 'Weather holdout rows missing.');
expected={'Figure1_Closed_Loop_Governance_Architecture.png','Figure2_Sao_Paulo_Calibration_Evidence.png','Figure3_Representative_Sao_Paulo_Replay.png','Figure4_Primary_Holdout_Policy_Evidence.png','Figure5_Governance_Mechanism_and_Inertia_Evidence.png','Figure6_Boundary_and_Safety_Evidence.png','Figure7_Fleet_and_Input_Heterogeneity_Boundaries.png','Table1_Calibration_and_Experimental_Contract.docx','Table2_Primary_Holdout_Policy_Evidence.docx','Table3_Mechanism_Boundary_and_Safety_Evidence.docx','Table4_Fleet_Size_and_Input_Heterogeneity.docx'};
for i=1:numel(expected), f=fullfile(fig,expected{i}); assert(isfile(f), 'Missing final artifact: %s',expected{i}); assert(dir(f).bytes>1000,'Artifact too small: %s',expected{i}); end
fprintf('Frozen release audit PASSED: 60 primary/fleet, 20 boundary/ablation, shared guard zero unsafe.\n');
end
function E=loadE(r,n),x=load(fullfile(r,n),'Evidence');E=x.Evidence;end
