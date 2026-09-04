function ReleaseAnalysis = export_primary_statistics(inputFile, outDir)
%EXPORT_PRIMARY_STATISTICS Export frozen main-analysis statistics.
% Scenario-level paired contrasts remain the primary inference.  This
% function adds paired bootstrap intervals and a prespecified order-level
% logistic mixed-effects sensitivity analysis with scenario random effects.

    if nargin < 1 || isempty(inputFile)
        inputFile = fullfile('results_frozen', ...
            'primary_policy_comparison_60_scenarios.mat');
    end
    if nargin < 2 || isempty(outDir)
        outDir = fullfile('results_frozen', 'exports');
    end
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    S = load(inputFile, 'Evidence');
    E = S.Evidence;
    assert(isfield(E, 'OrderOutcomes'), ...
        'export_primary_statistics:MissingOrderOutcomes', ...
        'Use the primary order-audit rerun as input.');
    assert(all(E.Metrics.UnsafeExecutionRate(:) == 0), ...
        'export_primary_statistics:SafetyInvariant', ...
        'Unsafe execution is non-zero in the proposed main evidence.');

    policyKeys = string({E.Policies.Key});
    primaryMetrics = {'VIPOnTimeRate','CompletionRate','EnergyPerOrder', ...
        'HsPolicy','HsSafety','PolicyPlanningReleaseRate', ...
        'ForcedSafetyTriggerRate','PlanningTime','UnsafeExecutionRate'};
    summaryRows = table();
    for p = 1:numel(policyKeys)
        for m = 1:numel(primaryMetrics)
            x = E.Metrics.(primaryMetrics{m})(p, :);
            [mu, lo, hi] = mean_t_ci(x);
            summaryRows = [summaryRows; table(policyKeys(p), ...
                string(primaryMetrics{m}), mu, lo, hi, std(x, 0), ...
                numel(x), 'VariableNames', {'Policy','Outcome','Mean', ...
                'T95Lower','T95Upper','SD','Scenarios'})]; %#ok<AGROW>
        end
    end
    writetable(summaryRows, fullfile(outDir, 'primary_policy_summary.csv'));

    pairs = { ...
        'ETFixed','AlwaysFixed','ETFixed minus AlwaysFixed'; ...
        'ETAdaptive','AlwaysAdaptive','ETAdaptive minus AlwaysAdaptive'; ...
        'ETAdaptive','ETFixed','ETAdaptive minus ETFixed'};
    contrastMetrics = {'VIPOnTimeRate','CompletionRate','EnergyPerOrder', ...
        'HsPolicy','HsSafety','PolicyPlanningReleaseRate', ...
        'ForcedSafetyTriggerRate','PlanningTime'};
    contrastRows = table();
    rng(20261002, 'twister');
    for j = 1:size(pairs, 1)
        a = find(policyKeys == pairs{j,1}, 1);
        b = find(policyKeys == pairs{j,2}, 1);
        assert(~isempty(a) && ~isempty(b));
        for m = 1:numel(contrastMetrics)
            d = E.Metrics.(contrastMetrics{m})(a, :) - ...
                E.Metrics.(contrastMetrics{m})(b, :);
            [mu, tlo, thi] = mean_t_ci(d);
            [blo, bhi] = paired_bootstrap_ci(d, 10000);
            contrastRows = [contrastRows; table(string(pairs{j,3}), ...
                string(contrastMetrics{m}), mu, tlo, thi, blo, bhi, ...
                numel(d), 'VariableNames', {'Contrast','Outcome', ...
                'MeanDifference','T95Lower','T95Upper', ...
                'Bootstrap95Lower','Bootstrap95Upper','Scenarios'})]; %#ok<AGROW>
        end
    end
    writetable(contrastRows, fullfile(outDir, 'primary_paired_contrasts.csv'));

    orderTable = build_order_table(E, policyKeys);
    glmmRows = table();
    for j = 1:size(pairs, 1)
        pairTable = orderTable(orderTable.Policy == pairs{j,1} | ...
            orderTable.Policy == pairs{j,2}, :);
        pairTable.IsTreatment = categorical(pairTable.Policy == pairs{j,1});
        pairTable.VIP = categorical(pairTable.VIP);
        pairTable.Scenario = categorical(pairTable.Scenario);
        mdl = fitglme(pairTable, ...
            'OnTime ~ 1 + IsTreatment*VIP + (1|Scenario)', ...
            'Distribution', 'Binomial', 'Link', 'logit', ...
            'FitMethod', 'Laplace');
        [estimate, se] = vip_treatment_effect(mdl);
        z = 1.95996398454005;
        lo = estimate - z * se;
        hi = estimate + z * se;
        glmmRows = [glmmRows; table(string(pairs{j,3}), estimate, se, ...
            lo, hi, exp(estimate), exp(lo), exp(hi), height(pairTable), ...
            numel(unique(pairTable.Scenario)), ...
            'VariableNames', {'Contrast','VIPLogOddsDifference','SE', ...
            'LogOdds95Lower','LogOdds95Upper','VIPOddsRatio', ...
            'OddsRatio95Lower','OddsRatio95Upper','Orders','Scenarios'})]; %#ok<AGROW>
    end
    writetable(glmmRows, fullfile(outDir, 'order_level_glmm_diagnostic.csv'));
    writetable(orderTable, fullfile(outDir, 'holdout_order_outcomes.csv'));

    ReleaseAnalysis = struct();
    ReleaseAnalysis.InputFile = inputFile;
    ReleaseAnalysis.PolicySummary = summaryRows;
    ReleaseAnalysis.PairedContrasts = contrastRows;
    ReleaseAnalysis.OrderLevelGLMM = glmmRows;
    ReleaseAnalysis.UnsafeExecutionInvariant = true;
    ReleaseAnalysis.PrimaryInference = ['Scenario-level paired t and ', ...
        'paired bootstrap intervals; GLMM is an order-level sensitivity analysis.'];
    save(fullfile(outDir, 'primary_release_analysis.mat'), ...
        'ReleaseAnalysis', '-v7');
end

function T = build_order_table(E, policyKeys)
    policy = strings(0,1); scenario = zeros(0,1); vip = zeros(0,1);
    onTime = zeros(0,1); served = zeros(0,1); expired = zeros(0,1);
    tardiness = zeros(0,1); arrival = zeros(0,1); deadline = zeros(0,1);
    for p = 1:numel(policyKeys)
        for r = 1:E.Config.R
            x = E.OrderOutcomes{p,r};
            n = numel(x.OnTime);
            policy = [policy; repmat(policyKeys(p), n, 1)]; %#ok<AGROW>
            scenario = [scenario; repmat(r, n, 1)]; %#ok<AGROW>
            vip = [vip; x.VIP(:)]; %#ok<AGROW>
            onTime = [onTime; x.OnTime(:)]; %#ok<AGROW>
            served = [served; x.Served(:)]; %#ok<AGROW>
            expired = [expired; x.Expired(:)]; %#ok<AGROW>
            tardiness = [tardiness; x.TardinessSteps(:)]; %#ok<AGROW>
            arrival = [arrival; x.ArrivalStep(:)]; %#ok<AGROW>
            deadline = [deadline; x.DeadlineStep(:)]; %#ok<AGROW>
        end
    end
    T = table(policy, scenario, vip, onTime, served, expired, tardiness, ...
        arrival, deadline, 'VariableNames', {'Policy','Scenario','VIP', ...
        'OnTime','Served','Expired','TardinessSteps','ArrivalStep', ...
        'DeadlineStep'});
end

function [estimate, se] = vip_treatment_effect(mdl)
    names = string(mdl.CoefficientNames);
    beta = fixedEffects(mdl);
    covb = mdl.CoefficientCovariance;
    % With categorical 0/1 predictors, the VIP treatment effect is the
    % treatment main effect plus its interaction with VIP.  This derives the
    % pairwise treatment contrast at VIP=1 without interpreting standard
    % customer effects as the primary endpoint.
    c = zeros(numel(beta), 1);
    treatment = contains(names, 'IsTreatment') & ~contains(names, ':');
    interaction = contains(names, 'IsTreatment') & contains(names, ':');
    assert(sum(treatment) == 1 && sum(interaction) == 1, ...
        'export_primary_statistics:UnexpectedCoefficientNames');
    c(treatment | interaction) = 1;
    estimate = c' * beta;
    se = sqrt(c' * covb * c);
end

function [mu, lo, hi] = mean_t_ci(x)
    x = x(:); n = numel(x); mu = mean(x);
    if n < 2, lo = mu; hi = mu; return; end
    hw = tinv(0.975, n - 1) * std(x, 0) / sqrt(n);
    lo = mu - hw; hi = mu + hw;
end

function [lo, hi] = paired_bootstrap_ci(d, B)
    d = d(:); n = numel(d);
    draw = randi(n, n, B);
    bootMeans = mean(d(draw), 1);
    lo = prctile(bootMeans, 2.5);
    hi = prctile(bootMeans, 97.5);
end
