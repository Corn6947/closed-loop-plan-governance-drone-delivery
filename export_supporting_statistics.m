function Supporting = export_supporting_statistics(root, outDir)
%EXPORT_SUPPORTING_STATISTICS Export prespecified supplementary evidence.
% All rows remain scenario-level paired summaries. They are not merged with
% the 60-scenario primary inference and cannot reselect a preferred policy.

    if nargin < 1 || isempty(root), root = 'results_frozen'; end
    if nargin < 2 || isempty(outDir), outDir = fullfile(root, 'exports'); end
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    rows = table();
    rows = append_access(rows, root, 'Primary P90 (reference)', ...
        'primary_policy_comparison_60_scenarios.mat');
    rows = append_access(rows, root, 'Weather P80 threshold', ...
        'weather_p80_boundary_20_scenarios.mat');
    rows = append_access(rows, root, 'Wind ordinary gate off', ...
        'wind_gate_ablation_20_scenarios.mat');
    rows = append_access(rows, root, 'Low-SoC ordinary gate off', ...
        'low_soc_gate_ablation_20_scenarios.mat');
    rows = append_access(rows, root, 'PlanChangeScale = 5', ...
        'low_plan_change_scale_20_scenarios.mat');
    rows = append_access(rows, root, 'PlanChangeScale = 20', ...
        'high_plan_change_scale_20_scenarios.mat');
    rows = append_access(rows, root, 'Window H = 2', ...
        'planning_window_2_steps_20_scenarios.mat');
    rows = append_access(rows, root, 'Window H = 3', ...
        'planning_window_3_steps_20_scenarios.mat');
    rows = append_access(rows, root, 'Window H = 4', ...
        'planning_window_4_steps_20_scenarios.mat');
    writetable(rows, fullfile(outDir, 'access_mechanism_boundaries.csv'));

    inertia = table();
    inertia = append_inertia(inertia, root, 'Low inertia: fixed 10; adaptive [10,20]', ...
        'low_inertia_sensitivity_20_scenarios.mat');
    inertia = append_inertia(inertia, root, 'Frozen: fixed 20; adaptive [10,50]', ...
        'reference_inertia_sensitivity_20_scenarios.mat');
    inertia = append_inertia(inertia, root, 'High inertia: fixed 50; adaptive [25,50]', ...
        'high_inertia_sensitivity_20_scenarios.mat');
    writetable(inertia, fullfile(outDir, 'inertia_sensitivity.csv'));

    on = loadE(root, 'safety_guard_on_20_scenarios.mat');
    off = loadE(root, 'safety_guard_off_20_scenarios.mat');
    assert(isequal(on.ScenarioSeeds, off.ScenarioSeeds));
    safety = table(); keys = string({on.Policies.Key});
    for p = 1:numel(keys)
        d = off.Metrics.UnsafeExecutionRate(p,:) - on.Metrics.UnsafeExecutionRate(p,:);
        [mu,lo,hi] = tci(d);
        [lat,latlo,lathi] = tci(on.Metrics.PlanningReleaseTimeP95(p,:));
        safety = [safety; table(keys(p), on.Summary.R, ...
            mean(on.Metrics.UnsafeExecutionRate(p,:)), ...
            mean(off.Metrics.UnsafeExecutionRate(p,:)), mu,lo,hi,lat,latlo,lathi, ...
            'VariableNames', {'Policy','Scenarios','GuardOnUnsafePct', ...
            'GuardOffUnsafePct','OffMinusOnUnsafePct','T95Lower','T95Upper', ...
            'GuardOnReleaseP95Seconds','LatencyLower','LatencyUpper'})]; %#ok<AGROW>
    end
    writetable(safety, fullfile(outDir, 'safety_guard_ablation.csv'));

    Supporting = struct('AccessBoundary', rows, 'InertiaSensitivity', inertia, ...
        'SafetyAblation', safety, 'Interpretation', ...
        'Supplementary conditions are prespecified boundary or mechanism evidence; the 60-scenario P90 primary contrast is not reselected.');
    save(fullfile(outDir, 'supporting_analysis.mat'), 'Supporting', '-v7');
end

function rows = append_access(rows, root, condition, file)
    E = loadE(root, file); [a,e] = access(E);
    metrics = {'VIPOnTimeRate','CompletionRate','EnergyPerOrder','HsPolicy', ...
        'PolicyPlanningReleaseRate','ForcedSafetyTriggerRate'};
    row = table(string(condition), E.Summary.R, ...
        'VariableNames', {'Condition','Scenarios'});
    for k = 1:numel(metrics)
        [mu,lo,hi] = tci(E.Metrics.(metrics{k})(e,:) - E.Metrics.(metrics{k})(a,:));
        stem = stem_for(metrics{k});
        row.([stem 'Delta']) = mu; row.([stem 'Lower']) = lo; row.([stem 'Upper']) = hi;
    end
    row.MaxGuardedUnsafePct = max(E.Metrics.UnsafeExecutionRate([a,e],:), [], 'all');
    rows = [rows; row]; %#ok<AGROW>
end

function rows = append_inertia(rows, root, condition, file)
    E = loadE(root, file); keys = string({E.Policies.Key});
    fixed = find(keys == "ETFixed", 1); adaptive = find(keys == "ETAdaptive", 1);
    metrics = {'VIPOnTimeRate','CompletionRate','EnergyPerOrder','HsPolicy'};
    row = table(string(condition), E.Summary.R, ...
        'VariableNames', {'Condition','Scenarios'});
    for k = 1:numel(metrics)
        [mu,lo,hi] = tci(E.Metrics.(metrics{k})(adaptive,:) - E.Metrics.(metrics{k})(fixed,:));
        stem = stem_for(metrics{k});
        row.([stem 'AdaptiveMinusFixed']) = mu;
        row.([stem 'Lower']) = lo; row.([stem 'Upper']) = hi;
    end
    row.MaxGuardedUnsafePct = max(E.Metrics.UnsafeExecutionRate([fixed,adaptive],:), [], 'all');
    rows = [rows; row]; %#ok<AGROW>
end

function E = loadE(root, name)
    S = load(fullfile(root, name), 'Evidence'); E = S.Evidence;
end

function [a,e] = access(E)
    keys = string({E.Policies.Key});
    a = find(keys == "AlwaysFixed", 1); e = find(keys == "ETFixed", 1);
    assert(~isempty(a) && ~isempty(e));
end

function s = stem_for(metric)
    map = struct('VIPOnTimeRate','VIP','CompletionRate','Completion', ...
        'EnergyPerOrder','Energy','HsPolicy','PolicyHs', ...
        'PolicyPlanningReleaseRate','Access', ...
        'ForcedSafetyTriggerRate','ForcedSafety');
    s = map.(metric);
end

function [mu,lo,hi] = tci(x)
    x = x(:); mu = mean(x); n = numel(x);
    hw = tinv(.975,n-1) * std(x,0) / sqrt(n);
    lo = mu-hw; hi = mu+hw;
end
