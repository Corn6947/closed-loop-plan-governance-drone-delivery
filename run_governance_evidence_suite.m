function Evidence = run_governance_evidence_suite(varargin)
%RUN_GOVERNANCE_EVIDENCE_SUITE Common-random, time-bounded governance evidence experiment.
%
% Backward-compatible positional interface:
%   Evidence = run_governance_evidence_suite(R, sigma, outFile, seedBase, ...
%       policySet, cfgOverride)
%
% policySet:
%   factorial5      - 2x2 plan-access/inertia design plus Myopic baseline
%   factorial4      - the four 2x2 factorial cells only
%   core2           - ET-Fixed and Proposed ET-adaptive only

    clc;
    close all;
    cfg = systems_default_config();
    if nargin >= 1 && ~isempty(varargin{1}), cfg.R = varargin{1}; end
    if nargin >= 2 && ~isempty(varargin{2}), cfg.ErrorSigma = varargin{2}; end
    outFile = 'results_working/governance_evidence_data.mat';
    if nargin >= 3 && ~isempty(varargin{3}), outFile = varargin{3}; end
    if nargin >= 4 && ~isempty(varargin{4}), cfg.SeedBase = varargin{4}; end
    policySet = 'factorial5';
    if nargin >= 5 && ~isempty(varargin{5}), policySet = varargin{5}; end
    if nargin >= 6 && ~isempty(varargin{6})
        cfg = apply_config_override(cfg, varargin{6});
    end
    cfg = normalise_fleet_role_contract(cfg);
    cfg.StepHours = cfg.StepSeconds / 3600;

    outDir = fileparts(outFile);
    if ~isempty(outDir) && ~exist(outDir, 'dir'), mkdir(outDir); end

    policies = systems_policy_catalog(policySet, cfg);
    P = numel(policies);
    metricNames = {'CompletionRate', 'VIPOnTimeRate', 'MeanTardiness', ...
        'VIPMeanTardiness', 'StandardMeanTardiness', 'ExpiredRate', ...
        'EnergyPerOrder', 'RiskAbortRate', 'UnsafeExecutionRate', ...
        'Nervousness', 'HsPolicy', 'HsSafety', ...
        'ReplanRate', 'PlanningReleaseRate', 'PolicyPlanningReleaseRate', ...
        'ForcedSafetyTriggerRate', 'SafetyFallbackRate', ...
        'MILPCallRate', ...
        'EmptyInstanceRate', 'PlanningTime', 'SolverTime', 'YalmipTime', ...
        'MILPModelBuildTime', 'MILPOptimizeWallTime', ...
        'MILPExtractionTime', 'MILPFallbackTime', ...
        'MeanPlanningTimePerRelease', 'MeanSolverTimePerMILP', ...
        'MeanYalmipTimePerMILP', 'PlanningReleaseTimeP50', ...
        'PlanningReleaseTimeP95', 'PlanningReleaseTimeMax', ...
        'MILPCallTimeP50', 'MILPCallTimeP95', 'MILPCallTimeMax', ...
        'SolverTimeP50', 'SolverTimeP95', 'SolverTimeMax', ...
        'MinimumSoC', 'EpisodeMinimumSoC', ...
        'TerminalMinimumSoC', 'FleetTotalSwaps', 'MILPFallbackRate', ...
        'MILPTimeLimitRate', 'MILPAcceptedIncumbentRate', ...
        'MaxConstraintViolation'};
    M = struct();
    for f = 1:numel(metricNames)
        M.(metricNames{f}) = zeros(P, cfg.R);
    end
    RoleActions = zeros(P, cfg.R, cfg.D);
    SwapCounts = zeros(P, cfg.R, cfg.D);
    Diagnostics = cell(P, cfg.R);
    % Keep order-level outcomes separate from the scenario-level primary
    % analysis.  They provide an auditable secondary mixed-effects check
    % without changing any decision, policy, or aggregate metric.
    OrderOutcomes = cell(P, cfg.R);
    TriggerSchedules = false(P, cfg.R, cfg.T + cfg.Clearance);
    % Store ET-adaptive traces during the run so the published illustrative
    % replay can be selected by an auditable typicality rule after all
    % scenario-level outcomes are known.  The previous first-replication
    % convention could produce a visually uninformative late horizon.
    Representative = [];
    representativePolicy = find(strcmp({policies.Key}, 'ETAdaptive'), 1);
    RepresentativeTraces = cell(1, cfg.R);

    if cfg.UsePublicCalibration
        inputDescription = sprintf('%s replay (%s split)', ...
            cfg.CalibrationPackageVersion, cfg.InputSplit);
    else
        inputDescription = sprintf('legacy sigma=%.1f m/s', cfg.ErrorSigma);
    end
    fprintf(['governance evidence suite: %d paired common-random scenarios, ', ...
        'inputs=%s, policy set=%s\n'], cfg.R, inputDescription, policySet);
    for r = 1:cfg.R
        scen = build_scenario(cfg, cfg.SeedBase + r, cfg.ErrorSigma);
        matchedSchedule = [];
        for p = 1:P
            activePolicy = policies(p);
            if cfg.MatchedTriggerAudit
                assert(P == 2 && strcmp(policies(1).Key, 'ETFixed') && ...
                    strcmp(policies(2).Key, 'ETAdaptive'), ...
                    ['MatchedTriggerAudit requires the two-policy ', ...
                    'ET-Fixed/ET-Adaptive catalogue.']);
                if p == 2
                    activePolicy.LockedTriggerSchedule = matchedSchedule;
                end
            end
            [out, trace] = simulate_architecture(cfg, scen, activePolicy);
            if cfg.MatchedTriggerAudit && p == 1
                matchedSchedule = trace.TriggerAll;
            end
            for f = 1:numel(metricNames)
                M.(metricNames{f})(p, r) = out.(metricNames{f});
            end
            RoleActions(p, r, :) = out.RoleActions;
            SwapCounts(p, r, :) = out.SwapCounts;
            Diagnostics{p, r} = out.Diagnostics;
            OrderOutcomes{p, r} = out.OrderOutcomes;
            TriggerSchedules(p, r, :) = trace.TriggerAll;
            if ~isempty(representativePolicy) && p == representativePolicy
                RepresentativeTraces{r} = trace;
            end
        end
        if mod(r, 5) == 0 || r == cfg.R
            fprintf('  completed %d/%d scenarios\n', r, cfg.R);
        end
    end

    Summary = summarise_metrics(M, policies, cfg.R);
    if ~isempty(representativePolicy)
        representativeIndex = choose_representative_index(M, RepresentativeTraces, representativePolicy);
        Representative = RepresentativeTraces{representativeIndex};
    else
        representativeIndex = NaN;
    end
    Evidence = struct();
    Evidence.Config = cfg;
    Evidence.Policies = policies;
    Evidence.PolicySet = char(policySet);
    Evidence.Metrics = M;
    Evidence.Summary = Summary;
    Evidence.RoleActions = RoleActions;
    Evidence.SwapCounts = SwapCounts;
    Evidence.Diagnostics = Diagnostics;
    Evidence.OrderOutcomes = OrderOutcomes;
    Evidence.TriggerSchedules = TriggerSchedules;
    Evidence.Representative = Representative;
    Evidence.RepresentativeIndex = representativeIndex;
    Evidence.RepresentativeSelectionRule = ['ET-adaptive scenario nearest the ', ...
        'median standardized VIP/completion/policy-Hs vector, subject to ', ...
        'at least one executed sortie in each half of the decision horizon.'];
    Evidence.ScenarioSeeds = cfg.SeedBase + (1:cfg.R);
    Evidence.Metadata = collect_metadata(cfg, policies);
    save(outFile, 'Evidence', '-v7');

    disp_summary(Summary, policies);
    fprintf('Saved: %s\n', outFile);
end

function idx = choose_representative_index(M, traces, policyIndex)
    vip = M.VIPOnTimeRate(policyIndex, :);
    completion = M.CompletionRate(policyIndex, :);
    hs = M.HsPolicy(policyIndex, :);
    z = [standardize_for_selection(vip); standardize_for_selection(completion); ...
        standardize_for_selection(hs)];
    distance = sum(abs(z), 1);
    coverage = false(1, numel(traces));
    for r = 1:numel(traces)
        tr = traces{r};
        if isempty(tr), continue; end
        mid = floor(numel(tr.Energy) / 2);
        coverage(r) = any(tr.Energy(1:mid) > 0) && any(tr.Energy(mid+1:end) > 0);
    end
    eligible = find(coverage);
    if isempty(eligible), eligible = 1:numel(traces); end
    [~, local] = min(distance(eligible));
    idx = eligible(local);
end

function z = standardize_for_selection(x)
    centre = median(x);
    scale = mad(x, 1);
    if scale < eps, scale = max(1, iqr(x)); end
    z = (x - centre) / scale;
end

function cfg = apply_config_override(cfg, override)
    if ~isstruct(override)
        error('run_governance_evidence_suite:InvalidOverride', ...
            'cfgOverride must be a struct.');
    end
    names = fieldnames(override);
    for i = 1:numel(names)
        cfg.(names{i}) = override.(names{i});
    end
    if isfield(override, 'DroneAirspeedKmh') && ...
            ~isfield(override, 'DroneAirspeedMps')
        cfg.DroneAirspeedMps = cfg.DroneAirspeedKmh / 3.6;
    elseif isfield(override, 'DroneAirspeedMps') && ...
            ~isfield(override, 'DroneAirspeedKmh')
        cfg.DroneAirspeedKmh = 3.6 * cfg.DroneAirspeedMps;
    end
end

function cfg = normalise_fleet_role_contract(cfg)
%NORMALISE_FLEET_ROLE_CONTRACT Make D=2/3/4 robustness runs semantically
% explicit rather than relying on a three-UAV hard-coded role order.
    validateattributes(cfg.D, {'numeric'}, {'scalar','integer','>=',2,'<=',4});
    if ~isfield(cfg, 'AdditionalCapacityPowerMultiplier')
        cfg.AdditionalCapacityPowerMultiplier = cfg.RolePowerMultiplier(1);
    end
    base = cfg.RolePowerMultiplier(:)';
    if numel(base) < 2
        error('run_governance_evidence_suite:FleetRoleContract', ...
            'At least capacity and priority power multipliers are required.');
    end
    if cfg.D == 2
        cfg.RolePowerMultiplier = base(1:2);
        cfg.ReserveDroneIndex = 0;
    else
        if numel(base) < 3
            base(3) = cfg.AdditionalCapacityPowerMultiplier;
        end
        cfg.RolePowerMultiplier = base(1:3);
        if cfg.D > 3
            cfg.RolePowerMultiplier = [cfg.RolePowerMultiplier, ...
                repmat(cfg.AdditionalCapacityPowerMultiplier, 1, cfg.D-3)];
        end
        cfg.ReserveDroneIndex = 3;
    end
end

function roleOrder = fleet_role_order(cfg)
% Priority first, then capacity, then the designated reserve and any extra
% capacity UAVs. This preserves the original D=3 ordering exactly.
    roleOrder = [2, 1];
    if cfg.ReserveDroneIndex > 0
        roleOrder = [roleOrder, cfg.ReserveDroneIndex]; %#ok<AGROW>
    end
    extra = setdiff(1:cfg.D, roleOrder, 'stable');
    roleOrder = [roleOrder, extra];
end

function tf = is_reserve_drone(d, cfg)
    tf = cfg.ReserveDroneIndex > 0 && d == cfg.ReserveDroneIndex;
end

function scen = build_scenario(cfg, seed, sigma)
    %#ok<INUSD> sigma is retained only for the backward-compatible call shape.
    if isfield(cfg, 'UsePublicCalibration') && cfg.UsePublicCalibration
        if ~(isfield(cfg, 'UseSaoPauloJointReplay') && cfg.UseSaoPauloJointReplay)
            ensure_public_calibration_path();
        end
        if isfield(cfg, 'UseSaoPauloJointReplay') && cfg.UseSaoPauloJointReplay
            scen = draw_sao_paulo_order_weather_scenario(cfg, seed);
            weather = [];
        else
            startHour = mod(seed, 24);
            demand = draw_public_arrivals(cfg.T, cfg.C, ...
                cfg.BaseOrdersPer20Min, startHour, seed);
            weather = draw_public_weather_path(cfg.T, cfg.InputSplit, ...
                seed + 100000);
            scen = demand;
            % Planning receives a bias-corrected forecast. Execution uses the
            % corresponding realised wind, preserving each public error block.
            windBias = 0;
            if isfield(cfg, 'PublicCalibration') && ...
                    isfield(cfg.PublicCalibration, 'WindBiasMps') && ...
                    isfinite(cfg.PublicCalibration.WindBiasMps)
                windBias = cfg.PublicCalibration.WindBiasMps;
            end
            scen.ForecastWind = max(0, weather.ForecastWindMps + windBias);
            scen.ActualWind = weather.ActualWindMps;
            scen.ForecastWindDirectionRad = weather.ForecastDirectionRad;
            scen.ActualWindDirectionRad = weather.ActualDirectionRad;
            scen.WindDirectionRad = scen.ActualWindDirectionRad; % Legacy trace field.
            scen.WeatherSourceRows = weather.SourceRows;
            scen.WeatherSplit = weather.Split;
        end
        scen.ScenarioSeed = seed;

        % Public Olist records do not supply a compatible VIP/SLA label.
        % This predeclared management scenario overlays the same arrivals for
        % every policy; it is deliberately not reported as a calibrated rate.
        rng(seed + cfg.VIPScenarioSeedOffset, 'twister');
        arrivals = find(scen.ArrivalPriority > 0);
        isVIP = rand(size(arrivals)) < cfg.VIPScenarioShare;
        if ~isempty(arrivals) && ~any(isVIP) && cfg.VIPScenarioShare > 0
            isVIP(randi(numel(arrivals))) = true;
        end
        scen.ArrivalPriority(arrivals(isVIP)) = 2;
        if isempty(weather)
            scen.InputContract = [scen.InputContract, ' VIP share and ', ...
                'platform motion remain predeclared scenarios.'];
        else
            scen.InputContract = ['Public Olist temporal/spatial proxy plus ', ...
                'public weather replay; VIP share and platform motion are ', ...
                'predeclared scenarios, not empirically estimated inputs.'];
        end
        return;
    end

    % Historical synthetic generator retained only to load legacy V1 calls.
    rng(seed, 'twister');
    scen.Coord = 6 + 8 * rand(cfg.C, 2);
    scen.ForecastWind = zeros(1, cfg.T);
    scen.ActualWind = zeros(1, cfg.T);
    scen.ForecastWindDirectionRad = zeros(1, cfg.T);
    scen.ActualWindDirectionRad = zeros(1, cfg.T);
    scen.WindDirectionRad = zeros(1, cfg.T);
    scen.ArrivalPriority = zeros(cfg.C, cfg.T);
    direction = 2 * pi * rand;
    for t = 1:cfg.T
        base = 5 + 1.1 * sin(t / 2);
        scen.ForecastWind(t) = max(0, base + 0.35 * randn);
        scen.ActualWind(t) = max(0, base + sigma * randn);
        direction = mod(direction + 0.28 * randn, 2 * pi);
        scen.ForecastWindDirectionRad(t) = direction;
        scen.ActualWindDirectionRad(t) = direction;
        scen.WindDirectionRad(t) = direction;
        nArr = 2 + double(rand < 0.35);
        nodes = randperm(cfg.C, min(nArr, cfg.C));
        scen.ArrivalPriority(nodes, t) = 1 + (rand(size(nodes)) < 0.10);
    end
end

function ensure_public_calibration_path()
    here = fileparts(mfilename('fullpath'));
    calibrationPath = fullfile(here, 'data_calibration', 'matlab');
    if ~exist(fullfile(calibrationPath, 'draw_public_arrivals.m'), 'file')
        error('run_governance_evidence_suite:CalibrationMissing', ...
            'Missing V2 calibration interface at %s.', calibrationPath);
    end
    if ~contains(path, calibrationPath)
        addpath(calibrationPath);
    end
end

function [out, trace] = simulate_architecture(cfg, scen, policy)
    maxReq = cfg.C * cfg.T;
    R.Node = zeros(1, maxReq);
    R.Priority = zeros(1, maxReq);
    R.Arrival = zeros(1, maxReq);
    R.Deadline = zeros(1, maxReq);
    R.Served = false(1, maxReq);
    R.Expired = false(1, maxReq);
    R.ServeTime = nan(1, maxReq);
    R.N = 0;

    State.SoC = cfg.Emax * ones(1, cfg.D);
    State.Truck = cfg.Depot;
    State.Swaps = zeros(1, cfg.D);
    State.RoleActions = zeros(1, cfg.D);
    Plan = zeros(cfg.D, cfg.H);
    planAge = cfg.H;

    totalEnergy = 0;
    totalHs = 0;
    totalPolicyHs = 0;
    totalSafetyHs = 0;
    totalPlanningTime = 0;
    totalSolverTime = 0;
    totalYalmipTime = 0;
    replanCount = 0;
    policyReplanCount = 0;
    forcedSafetyCount = 0;
    safetyFallbacks = 0;
    unsafeExecutions = 0;
    riskAborts = 0;
    milpCalls = 0;
    milpFallbacks = 0;
    timeLimitedReturns = 0;
    acceptedIncumbents = 0;
    maxConstraintViolation = 0;
    episodeMinimumSoC = min(State.SoC);
    diagnostics = empty_diagnostics();
    trace = init_trace(cfg, scen);
    lastW3 = cfg.W3base;

    for t = 1:(cfg.T + cfg.Clearance)
        [R, newVIP] = add_arrivals(R, scen, t, cfg);
        R = expire_orders(R, t, cfg);
        windIdx = min(t, cfg.T);
        windErr = abs(scen.ActualWind(windIdx) - scen.ForecastWind(windIdx));
        minSoc = min(State.SoC);
        activeBacklog = sum(~R.Served(1:R.N) & ~R.Expired(1:R.N) & ...
            R.Arrival(1:R.N) <= t);
        servicePressure = newVIP || ...
            activeBacklog >= cfg.BacklogPressureThreshold;
        oldPlan = Plan;
        [forcedPre, forcedReasonPre] = forced_safety_trigger( ...
            State, R, Plan, scen, t, cfg);

        if isfield(policy, 'LockedTriggerSchedule') && ...
                ~isempty(policy.LockedTriggerSchedule)
            assert(numel(policy.LockedTriggerSchedule) == ...
                cfg.T + cfg.Clearance, ...
                'Locked trigger schedule has the wrong horizon length.');
            trigger = logical(policy.LockedTriggerSchedule(t));
            reason = 9 * double(trigger);
        elseif strcmp(policy.TriggerMode, 'always')
            trigger = true;
            reason = 1;
        else
            [trigger, reason] = ordinary_policy_trigger(t, planAge, newVIP, ...
                windErr, minSoc, cfg, policy);
        end

        if policy.Adaptive
            W3 = compute_adaptive_plan_inertia(windErr, minSoc, ...
                scen.ForecastWind(windIdx), cfg);
            % Retain the published plan only in the empirically defined
            % joint low-risk region.  The former condition used only the
            % absence of service pressure and high SoC, which could erase
            % the intended W3 response exactly when forecast error was high.
            lowRiskState = ~servicePressure && minSoc > cfg.Ewarn && ...
                windErr <= cfg.LowRiskErrorThresholdMps && ...
                scen.ForecastWind(windIdx) <= cfg.LowRiskForecastWindMps;
            if lowRiskState
                W3 = max(W3, cfg.LowRiskW3FloorRatio * cfg.W3base);
            end
            if newVIP
                W3 = min(W3, cfg.VIPW3CapRatio * cfg.W3base);
            elseif activeBacklog >= cfg.BacklogPressureThreshold
                W3 = min(W3, cfg.BacklogW3CapRatio * cfg.W3base);
            end
        else
            W3 = policy.FixedW3;
        end
        if ~trigger && ~forcedPre && t > 1, W3 = lastW3; end

        planningOpen = trigger || forcedPre;
        if planningOpen
            if trigger && ~forcedPre
                diagnostics.Ntrigger = diagnostics.Ntrigger + 1;
                policyReplanCount = policyReplanCount + 1;
            end
            if forcedPre
                forcedSafetyCount = forcedSafetyCount + 1;
                diagnostics.NforcedSafety = diagnostics.NforcedSafety + 1;
                diagnostics.ForcedSafetyReasonCounts = ...
                    diagnostics.ForcedSafetyReasonCounts + ...
                    sum(forcedReasonPre(:) == (1:4), 1)';
            end
            ticPlan = tic;
            [Plan, hs, planMeta] = build_plan(R, State, Plan, ...
                scen, t, W3, cfg);
            elapsed = toc(ticPlan);
            planMeta.EndToEndTime = elapsed;
            totalPlanningTime = totalPlanningTime + elapsed;
            totalSolverTime = totalSolverTime + planMeta.SolverTime;
            totalYalmipTime = totalYalmipTime + planMeta.YalmipTime;
            replanCount = replanCount + 1;
            planAge = 0;
            milpCalls = milpCalls + planMeta.MILPCall;
            milpFallbacks = milpFallbacks + planMeta.Fallback;
            timeLimitedReturns = timeLimitedReturns + planMeta.TimeLimited;
            acceptedIncumbents = acceptedIncumbents + ...
                planMeta.AcceptedIncumbent;
            diagnostics.Nempty = diagnostics.Nempty + planMeta.EmptyModel;
            diagnostics.Nmodel = diagnostics.Nmodel + planMeta.MILPCall;
            diagnostics.Noptimize = diagnostics.Noptimize + planMeta.MILPCall;
            diagnostics.Ntimelimit = diagnostics.Ntimelimit + planMeta.TimeLimited;
            if planMeta.MILPCall
                if planMeta.TimeLimited
                    % Counted above; status classes are mutually exclusive.
                elseif planMeta.StatusCode == 0
                    diagnostics.Nnormal = diagnostics.Nnormal + 1;
                elseif ismember(planMeta.StatusCode, [1, 2, 12, 15])
                    diagnostics.Ninfeasible = diagnostics.Ninfeasible + 1;
                else
                    diagnostics.Nerror = diagnostics.Nerror + 1;
                end
            end
            diagnostics.Nincumbent = diagnostics.Nincumbent + ...
                (planMeta.MILPCall * planMeta.HasIncumbent);
            diagnostics.Naccepted = diagnostics.Naccepted + ...
                planMeta.AcceptedIncumbent;
            diagnostics.Nrejected = diagnostics.Nrejected + ...
                (planMeta.MILPCall * planMeta.HasIncumbent * ...
                (1 - planMeta.AcceptedIncumbent));
            diagnostics.Nfallback = diagnostics.Nfallback + planMeta.Fallback;
            if forcedPre
                diagnostics.SafetyReleaseTimeSeconds(end + 1) = elapsed;
            else
                diagnostics.PlanningReleaseTimeSeconds(end + 1) = elapsed;
            end
            if planMeta.MILPCall
                diagnostics.ModelBuildTimeSeconds(end + 1) = ...
                    planMeta.ModelBuildTime;
                diagnostics.OptimizeWallTimeSeconds(end + 1) = ...
                    planMeta.OptimizeWallTime;
                diagnostics.SolverTimeSeconds(end + 1) = ...
                    planMeta.SolverTime;
                diagnostics.YalmipTimeSeconds(end + 1) = ...
                    planMeta.YalmipTime;
                diagnostics.ExtractionTimeSeconds(end + 1) = ...
                    planMeta.ExtractionTime;
                diagnostics.FallbackTimeSeconds(end + 1) = ...
                    planMeta.FallbackTime;
                diagnostics.MILPCallTimeSeconds(end + 1) = ...
                    planMeta.ModelBuildTime + planMeta.OptimizeWallTime + ...
                    planMeta.ExtractionTime + planMeta.FallbackTime;
            end
            if isfinite(planMeta.MaxViolation)
                maxConstraintViolation = max(maxConstraintViolation, ...
                    planMeta.MaxViolation);
            end
        else
            [Plan, hs] = fill_idle_slots(R, State, Plan, scen, t, cfg);
            planAge = planAge + 1;
            planMeta = empty_plan_meta();
        end

        [Plan, effectiveHs, forcedPost, forcedReasonPost, safetyFallback] = ...
            enforce_safe_first_slot(R, State, Plan, oldPlan, scen, t, cfg);
        if forcedPost && ~forcedPre
            forcedSafetyCount = forcedSafetyCount + 1;
            diagnostics.NforcedSafety = diagnostics.NforcedSafety + 1;
            diagnostics.ForcedSafetyReasonCounts = ...
                diagnostics.ForcedSafetyReasonCounts + ...
                sum(forcedReasonPost(:) == (1:4), 1)';
            replanCount = replanCount + 1;
            diagnostics.NsafetyFallback = diagnostics.NsafetyFallback + 1;
        end
        if forcedPre || forcedPost
            totalSafetyHs = totalSafetyHs + effectiveHs;
            if forcedPre && planMeta.Fallback
                safetyFallbacks = safetyFallbacks + 1;
                diagnostics.NsafetyFallback = diagnostics.NsafetyFallback + 1;
            end
        else
            totalPolicyHs = totalPolicyHs + effectiveHs;
        end
        if safetyFallback
            safetyFallbacks = safetyFallbacks + 1;
            if ~forcedPost
                diagnostics.NsafetyFallback = diagnostics.NsafetyFallback + 1;
            end
        end
        totalHs = totalPolicyHs + totalSafetyHs;
        hs = effectiveHs;
        if forcedPre || forcedPost, planAge = 0; end

        [State, R, energy, aborts, servedIds, swapEvents] = ...
            execute_step(State, R, Plan(:, 1), scen, t, cfg);
        episodeMinimumSoC = min(episodeMinimumSoC, min(State.SoC));
        totalEnergy = totalEnergy + energy;
        riskAborts = riskAborts + aborts;
        unsafeExecutions = unsafeExecutions + aborts;
        if isfield(cfg, 'RequireZeroUnsafeExecution') && ...
                cfg.RequireZeroUnsafeExecution && aborts > 0
            error('run_governance_evidence_suite:UnsafeExecution', ...
                'Safety guard invariant failed at decision step %d.', t);
        end
        Plan = [Plan(:, 2:end), zeros(cfg.D, 1)];

        trace.TriggerAll(t) = trigger;
        trace.TriggerReasonAll(t) = reason;
        if t <= cfg.T
            trace.Trigger(t) = trigger;
            trace.TriggerReason(t) = reason;
            trace.W3(t) = W3;
            trace.Hs(t) = hs;
            trace.SoC(:, t) = State.SoC';
            trace.Truck(t, :) = State.Truck;
            trace.Energy(t) = energy;
            trace.SwapEvent(:, t) = swapEvents(:);
            trace.RiskAbort(t) = aborts;
            trace.ForcedSafetyTrigger(t) = forcedPre || forcedPost;
            trace.ForcedSafetyReason(t) = max([forcedReasonPre(:); forcedReasonPost(:)]);
            trace.SafetyFallback(t) = safetyFallback || (forcedPre && planMeta.Fallback);
            trace.HsPolicy(t) = totalPolicyHs;
            trace.HsSafety(t) = totalSafetyHs;
            trace.Plan(:, t) = servedIds(:);
            trace.MILPStatusCode(t) = planMeta.StatusCode;
            trace.MILPFallback(t) = planMeta.Fallback;
            trace.MILPTimeLimited(t) = planMeta.TimeLimited;
            trace.MILPAccepted(t) = planMeta.AcceptedIncumbent;
            trace.MILPEmpty(t) = planMeta.EmptyModel;
            trace.MILPMaxViolation(t) = planMeta.MaxViolation;
            trace.MILPStatusText{t} = planMeta.StatusText;
            for d = 1:cfg.D
                if servedIds(d) > 0
                    trace.TaskNode(d, t) = R.Node(servedIds(d));
                    trace.TaskPriority(d, t) = R.Priority(servedIds(d));
                end
            end
            trace.Arrivals(t) = sum(scen.ArrivalPriority(:, t) > 0);
            trace.VIPArrivals(t) = sum(scen.ArrivalPriority(:, t) == 2);
        end
        lastW3 = W3;
    end

    out = evaluate_episode(R, State, totalEnergy, totalHs, totalPolicyHs, ...
        totalSafetyHs, replanCount, policyReplanCount, forcedSafetyCount, ...
        safetyFallbacks, unsafeExecutions, totalPlanningTime, totalSolverTime, ...
        totalYalmipTime, riskAborts, milpCalls, milpFallbacks, ...
        timeLimitedReturns, acceptedIncumbents, maxConstraintViolation, ...
        diagnostics, episodeMinimumSoC, cfg);
end

function trace = init_trace(cfg, scen)
    trace.ForecastWind = scen.ForecastWind;
    trace.ActualWind = scen.ActualWind;
    trace.WindDirectionRad = scen.WindDirectionRad;
    trace.Trigger = false(1, cfg.T);
    trace.TriggerReason = zeros(1, cfg.T);
    trace.TriggerAll = false(1, cfg.T + cfg.Clearance);
    trace.TriggerReasonAll = zeros(1, cfg.T + cfg.Clearance);
    trace.W3 = zeros(1, cfg.T);
    trace.Hs = zeros(1, cfg.T);
    trace.SoC = zeros(cfg.D, cfg.T);
    trace.Truck = zeros(cfg.T, 2);
    trace.Energy = zeros(1, cfg.T);
    trace.SwapEvent = zeros(cfg.D, cfg.T);
    trace.RiskAbort = zeros(1, cfg.T);
    trace.ForcedSafetyTrigger = false(1, cfg.T);
    trace.ForcedSafetyReason = zeros(1, cfg.T);
    trace.SafetyFallback = false(1, cfg.T);
    trace.HsPolicy = zeros(1, cfg.T);
    trace.HsSafety = zeros(1, cfg.T);
    trace.Plan = zeros(cfg.D, cfg.T);
    trace.TaskNode = zeros(cfg.D, cfg.T);
    trace.TaskPriority = zeros(cfg.D, cfg.T);
    trace.Arrivals = zeros(1, cfg.T);
    trace.VIPArrivals = zeros(1, cfg.T);
    trace.Coord = scen.Coord;
    trace.MILPStatusCode = nan(1, cfg.T);
    trace.MILPFallback = zeros(1, cfg.T);
    trace.MILPTimeLimited = zeros(1, cfg.T);
    trace.MILPAccepted = zeros(1, cfg.T);
    trace.MILPEmpty = zeros(1, cfg.T);
    trace.MILPMaxViolation = nan(1, cfg.T);
    trace.MILPStatusText = repmat({''}, 1, cfg.T);
end

function [R, newVIP] = add_arrivals(R, scen, t, cfg)
    if t > cfg.T, newVIP = false; return; end
    nodes = find(scen.ArrivalPriority(:, t) > 0);
    newVIP = false;
    for q = 1:numel(nodes)
        R.N = R.N + 1;
        id = R.N;
        p = scen.ArrivalPriority(nodes(q), t);
        R.Node(id) = nodes(q);
        R.Priority(id) = p;
        R.Arrival(id) = t;
        R.Deadline(id) = t + 6 - 4 * (p == 2);
        if p == 2, newVIP = true; end
    end
end

function R = expire_orders(R, t, cfg)
    if ~cfg.OrderExpiryEnabled || R.N == 0
        return;
    end
    [~, expired] = evaluate_order_status(R, t, cfg);
    R.Expired(1:R.N) = R.Expired(1:R.N) | expired;
end

function [trigger, reason] = ordinary_policy_trigger(t, planAge, newVIP, windErr, ...
    minSoc, cfg, policy)
    if t == 1, trigger = true; reason = 1; return; end
    if newVIP, trigger = true; reason = 2; return; end
    if cfg.EnableWindTrigger && windErr >= policy.WindThresholdMps
        trigger = true; reason = 3; return;
    end
    if cfg.EnableLowSoCTrigger && minSoc <= cfg.Ewarn
        trigger = true; reason = 4; return;
    end
    if planAge >= cfg.H - 1, trigger = true; reason = 5; return; end
    trigger = false;
    reason = 0;
end

function [forced, reasonCodes] = forced_safety_trigger(State, R, Plan, ...
        scen, t, cfg)
%FORCED_SAFETY_TRIGGER Preflight validation of the published first slot.
% This guard is policy-invariant.  It does not use W3, a policy threshold,
% or a solver status; a first-slot task either remains executable under the
% current state and realised wind, or access to safe replanning is opened.
    reasonCodes = zeros(cfg.D, 1);
    if ~isfield(cfg, 'ForcedSafetyEnabled') || ~cfg.ForcedSafetyEnabled
        forced = false;
        return;
    end
    for d = 1:cfg.D
        id = Plan(d, 1);
        if id <= 0, continue; end
        [safe, reasonCode] = actual_task_feasible(id, d, R, State, ...
            scen, t, cfg);
        if ~safe, reasonCodes(d) = reasonCode; end
    end
    forced = any(reasonCodes > 0);
end

function [safe, reasonCode, flight, needsSwap] = actual_task_feasible( ...
        id, d, R, State, scen, t, cfg)
% Reason codes: 1 invalid/stale task, 2 flight envelope, 3 time limit,
% 4 post-swap energy reserve.  A conditional swap is an explicit safe
% preparation action, not a reason to permit an unsafe task.
    safe = false;
    reasonCode = 0;
    flight = struct('Feasible', false, 'TotalTimeSeconds', Inf, ...
        'EnergyWh', Inf, 'Reason', 'invalid-task');
    needsSwap = false;
    if id < 1 || id > R.N || R.Served(id) || R.Expired(id) || ...
            R.Arrival(id) > t
        reasonCode = 1;
        return;
    end
    node = R.Node(id);
    delta = scen.Coord(node, :) - State.Truck;
    distanceKm = norm(delta);
    if distanceKm <= eps, route = [1, 0]; else, route = delta / distanceKm; end
    windIdx = min(t, cfg.T);
    direction = scen.WindDirectionRad(windIdx);
    if isfield(scen, 'ActualWindDirectionRad')
        direction = scen.ActualWindDirectionRad(windIdx);
    end
    flight = evaluate_flight_physics(distanceKm, route, ...
        scen.ActualWind(windIdx), direction, d, cfg);
    if ~flight.Feasible
        reasonCode = 2;
        return;
    end
    if flight.TotalTimeSeconds > cfg.StepSeconds
        reasonCode = 3;
        return;
    end
    availableEnergy = State.SoC(d);
    needsSwap = availableEnergy <= cfg.Ewarn;
    if needsSwap, availableEnergy = cfg.Emax; end
    if availableEnergy - flight.EnergyWh < cfg.Esafe
        reasonCode = 4;
        return;
    end
    safe = true;
end

function [Plan, hs, fallback] = build_safety_fallback(R, State, oldPlan, ...
        scen, t, cfg)
%BUILD_SAFETY_FALLBACK Deterministic hold/swap/defer policy.
% Only currently safe tasks may be placed in the first slot. Future slots
% are held empty so the next decision step obtains a fresh safety check.
    Plan = zeros(cfg.D, cfg.H);
    [eligible, ~] = evaluate_order_status(R, t, cfg);
    pending = find(eligible);
    roleOrder = fleet_role_order(cfg);
    for ii = 1:numel(roleOrder)
        d = roleOrder(ii);
        if isempty(pending), break; end
        score = -inf(size(pending));
        for q = 1:numel(pending)
            id = pending(q);
            [safe, ~, flight] = actual_task_feasible(id, d, R, State, ...
                scen, t, cfg);
            if safe
                age = t - R.Arrival(id);
                score(q) = 1000 * R.Priority(id) + 50 * age - ...
                    cfg.DistancePenalty * flight.TotalTimeSeconds / 60;
            end
        end
        [best, index] = max(score);
        if isfinite(best)
            Plan(d, 1) = pending(index);
            pending(index) = [];
        end
    end
    hs = cfg.PlanChangeScale * plan_change_distance(Plan, oldPlan);
    fallback = true;
end

function [Plan, hs, forcedNow, reasonCodes, fallback] = ...
        enforce_safe_first_slot(R, State, Plan, oldPlan, scen, t, cfg)
% Final invariant check after either ordinary planning or idle-slot filling.
% If a forecast-feasible candidate is not executable under realised inputs,
% replace it with the deterministic safe fallback before execution.
    [forcedNow, reasonCodes] = forced_safety_trigger(State, R, Plan, ...
        scen, t, cfg);
    fallback = false;
    if forcedNow
        [Plan, hs, fallback] = build_safety_fallback(R, State, oldPlan, ...
            scen, t, cfg);
    else
        hs = cfg.PlanChangeScale * plan_change_distance(Plan, oldPlan);
    end
end

function W3 = compute_adaptive_plan_inertia(windErr, minSoc, forecastWind, cfg)
    W3 = adaptive_plan_inertia_weight(windErr, minSoc, forecastWind, cfg);
end

function [Plan, localHs] = fill_idle_slots(R, State, Plan, scen, t, cfg)
    oldPlan = Plan;
    assigned = Plan(Plan > 0)';
    [eligible, ~] = evaluate_order_status(R, t, cfg);
    pending = find(eligible);
    pending = setdiff(pending, assigned, 'stable');
    roleOrder = fleet_role_order(cfg);
    for h = 1:size(Plan, 2)
        for oo = 1:numel(roleOrder)
            d = roleOrder(oo);
            if Plan(d, h) ~= 0 || isempty(pending), continue; end
            age = t - R.Arrival(pending);
            dist = arrayfun(@(id) ...
                norm(scen.Coord(R.Node(id), :) - State.Truck), pending);
            score = cfg.ServiceWeightScale * ...
                (cfg.PriorityBenefit * R.Priority(pending) + ...
                cfg.AgeBenefit * age) - cfg.DistancePenalty * dist;
            for q = 1:numel(pending)
                if ~forecast_task_feasible(pending(q), d, h, R, ...
                        State, scen, t, cfg)
                    score(q) = -inf;
                end
            end
            if is_reserve_drone(d, cfg)
                keep = arrayfun(@(id) ...
                    reserve_needed(id, h, R, scen, t, cfg), pending);
                score(~keep) = -inf;
            end
            [v, b] = max(score);
            if isfinite(v)
                Plan(d, h) = pending(b);
                pending(b) = [];
            end
        end
    end
    localHs = cfg.PlanChangeScale * plan_change_distance(Plan, oldPlan);
end

function [Plan, hs, meta] = build_plan(R, State, oldPlan, scen, t, W3, cfg)
    meta = empty_plan_meta();
    if cfg.UseMILPPlanner
        [Plan, hs, solved, meta] = build_plan_assignment_milp( ...
            R, State, oldPlan, scen, t, W3, cfg);
        meta.MILPCall = double(~meta.EmptyModel);
        if solved, return; end
        meta.Fallback = 1;
    end
    ticFallback = tic;
    [Plan, hs] = build_plan_fallback(R, State, oldPlan, scen, t, W3, cfg);
    meta.FallbackTime = toc(ticFallback);
end

function meta = empty_plan_meta()
    meta = struct('MILPCall', 0, 'EmptyModel', 0, 'Fallback', 0, ...
        'TimeLimited', 0, ...
        'AcceptedIncumbent', 0, 'HasIncumbent', 0, ...
        'MaxViolation', NaN, 'RejectedIncumbentViolation', NaN, ...
        'IntegerDeviation', NaN, ...
        'SolverTime', 0, 'YalmipTime', 0, ...
        'ModelBuildTime', 0, 'OptimizeWallTime', 0, ...
        'ExtractionTime', 0, 'FallbackTime', 0, ...
        'EndToEndTime', 0, 'StatusCode', NaN, 'StatusText', '');
end

function [Plan, hs] = build_plan_fallback(R, State, oldPlan, ...
    scen, t, W3, cfg)
    Plan = zeros(cfg.D, cfg.H);
    used = false(1, R.N);
    [eligible, ~] = evaluate_order_status(R, t, cfg);
    pending = find(eligible);
    roleOrder = fleet_role_order(cfg);
    for h = 1:cfg.H
        for oo = 1:numel(roleOrder)
            d = roleOrder(oo);
            candidates = pending(~used(pending));
            if Plan(d, h) > 0 || isempty(candidates), continue; end
            score = -inf(size(candidates));
            for z = 1:numel(candidates)
                id = candidates(z);
                if ~forecast_task_feasible(id, d, h, R, State, ...
                        scen, t, cfg), continue; end
                node = R.Node(id);
                dist = norm(scen.Coord(node, :) - State.Truck);
                slack = R.Deadline(id) - (t + h - 1);
                windIdx = min(t + h - 1, cfg.T);
                riskDistancePenalty = cfg.DistancePenalty + ...
                    cfg.RiskDistancePenalty * ...
                    max(0, scen.ForecastWind(windIdx) - ...
                    cfg.HighWindReferenceMps);
                flight = forecast_flight(id, d, h, R, State, scen, t, cfg);
                oldId = oldPlan(d, min(h, size(oldPlan, 2)));
                planChange = plan_change_distance(id, oldId);
                score(z) = cfg.ServiceWeightScale * ...
                    (cfg.PriorityBenefit * R.Priority(id) + ...
                    cfg.DeadlineBenefit * max(0, 3 - slack) + ...
                    cfg.AgeBenefit * (t - R.Arrival(id))) - ...
                    riskDistancePenalty * dist - ...
                    cfg.EnergyPenaltyPerWh * flight.EnergyWh - ...
                    cfg.PlanChangeScale * W3 * planChange;
                if is_reserve_drone(d, cfg)
                    reserveNeed = reserve_needed(id, h, R, scen, t, cfg);
                    if ~reserveNeed
                        score(z) = -inf;
                    else
                        score(z) = score(z) - cfg.ReservePenalty;
                    end
                end
            end
            [best, b] = max(score);
            if isfinite(best)
                Plan(d, h) = candidates(b);
                used(candidates(b)) = true;
            end
        end
    end
    hs = cfg.PlanChangeScale * plan_change_distance(Plan, oldPlan);
end

function [Plan, hs, solved, meta] = build_plan_assignment_milp( ...
    R, State, oldPlan, scen, t, W3, cfg)
    Plan = zeros(cfg.D, cfg.H);
    hs = 0;
    solved = false;
    meta = empty_plan_meta();

    [eligible, ~] = evaluate_order_status(R, t, cfg);
    pending = find(eligible);
    announced = unique(oldPlan(oldPlan > 0));
    announced = intersect(announced, pending, 'stable');
    room = max(0, cfg.MaxCandidateOrders - numel(announced));
    if numel(pending) > numel(announced) + room
        age = t - R.Arrival(pending);
        rank = 1000 * R.Priority(pending) + 100 * age;
        [~, ord] = sort(rank, 'descend');
        top = pending(ord(1:room));
        pending = unique([announced(:); top(:)]', 'stable');
    end
    nQ = numel(pending);
    if nQ == 0
        solved = true;
        meta.EmptyModel = 1;
        meta.MaxViolation = 0;
        meta.IntegerDeviation = 0;
        meta.StatusCode = 0;
        meta.StatusText = 'empty planning queue: no MILP call';
        return;
    end

    ticModelBuild = tic;
    x = binvar(nQ, cfg.D, cfg.H, 'full');
    z = sdpvar(nQ, cfg.D, cfg.H, 'full');
    old = zeros(nQ, cfg.D, cfg.H);
    for q = 1:nQ
        for d = 1:cfg.D
            for h = 1:cfg.H
                old(q, d, h) = double(oldPlan(d, h) == pending(q));
            end
        end
    end
    C = [z(:) >= 0, z(:) >= x(:) - old(:), z(:) >= old(:) - x(:)];
    for d = 1:cfg.D
        for h = 1:cfg.H
            C = [C, sum(x(:, d, h)) <= 1]; %#ok<AGROW>
        end
    end
    for q = 1:nQ
        C = [C, sum(x(q, :, :), 'all') <= 1]; %#ok<AGROW>
    end

    benefit = zeros(nQ, cfg.D, cfg.H);
    eligibility = false(nQ, cfg.D, cfg.H);
    for q = 1:nQ
        id = pending(q);
        age = t - R.Arrival(id);
        node = R.Node(id);
        dist = norm(scen.Coord(node, :) - State.Truck);
        for d = 1:cfg.D
            for h = 1:cfg.H
                eligible = forecast_task_feasible(id, d, h, R, ...
                    State, scen, t, cfg);
                if is_reserve_drone(d, cfg)
                    eligible = eligible && ...
                        reserve_needed(id, h, R, scen, t, cfg);
                end
                eligibility(q, d, h) = eligible;
                if ~eligible
                    C = [C, x(q, d, h) == 0]; %#ok<AGROW>
                    continue;
                end
                slack = R.Deadline(id) - (t + h - 1);
                windIdx = min(t + h - 1, cfg.T);
                riskDistancePenalty = cfg.DistancePenalty + ...
                    cfg.RiskDistancePenalty * ...
                    max(0, scen.ForecastWind(windIdx) - ...
                    cfg.HighWindReferenceMps);
                flight = forecast_flight(id, d, h, R, State, scen, t, cfg);
                benefit(q, d, h) = cfg.ServiceWeightScale * ...
                    (cfg.PriorityBenefit * R.Priority(id) + ...
                    cfg.DeadlineBenefit * max(0, 3 - slack) + ...
                    cfg.AgeBenefit * age) - ...
                    riskDistancePenalty * dist - ...
                    cfg.EnergyPenaltyPerWh * flight.EnergyWh;
                if is_reserve_drone(d, cfg)
                    benefit(q, d, h) = benefit(q, d, h) - ...
                        cfg.ReservePenalty;
                end
            end
        end
    end
    objective = -sum(benefit(:) .* x(:)) + ...
        cfg.PlanChangeScale * W3 * sum(z(:));

    try
        ops = sdpsettings('verbose', 0, 'solver', 'gurobi', ...
            'gurobi.TimeLimit', cfg.MILPTimeLimit, ...
            'gurobi.MIPGap', cfg.MILPMIPGap, ...
            'gurobi.Threads', cfg.GurobiThreads, ...
            'gurobi.Seed', cfg.GurobiSeed);
        meta.ModelBuildTime = toc(ticModelBuild);
        ticOptimize = tic;
        sol = optimize(C, objective, ops);
        meta.OptimizeWallTime = toc(ticOptimize);
        meta.StatusCode = sol.problem;
        meta.StatusText = sol.info;
        if isfield(sol, 'solvertime') && isfinite(sol.solvertime)
            meta.SolverTime = sol.solvertime;
        end
        if isfield(sol, 'yalmiptime') && isfinite(sol.yalmiptime)
            meta.YalmipTime = sol.yalmiptime;
        end
        infoLower = lower(string(sol.info));
        meta.TimeLimited = double(contains(infoLower, 'time limit') || ...
            contains(infoLower, 'time limit reached'));
    catch ME
        if meta.ModelBuildTime == 0
            meta.ModelBuildTime = toc(ticModelBuild);
        end
        meta.StatusCode = -999;
        meta.StatusText = ME.message;
        return;
    end

    ticExtract = tic;
    xv = value(x);
    zv = value(z);
    [accepted, validation] = validate_milp_incumbent( ...
        xv, zv, C, eligibility, cfg);
    meta.HasIncumbent = validation.HasIncumbent;
    % Keep rejected-incumbent residuals as diagnostics, but do not report
    % them as a violation of an accepted/executed plan.  A time-limited
    % candidate that fails the acceptance check is discarded and fallback
    % constructs the plan that is actually executed.
    meta.RejectedIncumbentViolation = validation.MaxViolation;
    if accepted
        meta.MaxViolation = validation.MaxViolation;
    else
        meta.MaxViolation = 0;
    end
    meta.IntegerDeviation = validation.IntegerDeviation;
    admissibleStatus = meta.StatusCode == 0 || meta.TimeLimited == 1;
    if ~(accepted && admissibleStatus)
        meta.ExtractionTime = toc(ticExtract);
        return;
    end

    rounded = round(xv);
    for q = 1:nQ
        for d = 1:cfg.D
            for h = 1:cfg.H
                if rounded(q, d, h) == 1
                    Plan(d, h) = pending(q);
                end
            end
        end
    end
    hs = cfg.PlanChangeScale * plan_change_distance(Plan, oldPlan);
    solved = true;
    meta.AcceptedIncumbent = 1;
    meta.ExtractionTime = toc(ticExtract);
end

function [accepted, result] = validate_milp_incumbent( ...
    xv, zv, constraints, eligibility, cfg)
    result = struct('HasIncumbent', 0, 'MaxViolation', Inf, ...
        'IntegerDeviation', Inf);
    accepted = false;
    if isempty(xv) || isempty(zv) || any(~isfinite(xv(:))) || ...
            any(~isfinite(zv(:)))
        return;
    end
    result.HasIncumbent = 1;
    integerDeviation = max(abs(xv(:) - round(xv(:))));
    rounded = round(xv);
    structuralViolation = 0;
    for d = 1:size(rounded, 2)
        for h = 1:size(rounded, 3)
            structuralViolation = max(structuralViolation, ...
                sum(rounded(:, d, h)) - 1);
        end
    end
    for q = 1:size(rounded, 1)
        structuralViolation = max(structuralViolation, ...
            sum(rounded(q, :, :), 'all') - 1);
    end
    ineligibleAssignments = rounded(~eligibility);
    if ~isempty(ineligibleAssignments)
        structuralViolation = max(structuralViolation, ...
            max(ineligibleAssignments(:)));
    end
    try
        primalResidual = check(constraints);
        constraintViolation = max([0; -primalResidual(:)]);
    catch
        constraintViolation = Inf;
    end
    result.IntegerDeviation = integerDeviation;
    result.MaxViolation = max([0, structuralViolation, ...
        constraintViolation, max(0, -min(zv(:)))]);
    accepted = integerDeviation <= cfg.IntegerTolerance && ...
        result.MaxViolation <= cfg.FeasibilityTolerance;
end

function tf = reserve_needed(id, h, R, scen, t, cfg)
    windIdx = min(t + h - 1, cfg.T);
    tf = R.Priority(id) == 2 || (t - R.Arrival(id) >= 2) || ...
        (scen.ForecastWind(windIdx) >= cfg.ReserveWindThresholdMps);
end

function flight = forecast_flight(id, d, h, R, State, scen, t, cfg)
    node = R.Node(id);
    delta = scen.Coord(node, :) - State.Truck;
    distanceKm = norm(delta);
    if distanceKm <= eps, route = [1, 0]; else, route = delta / distanceKm; end
    windIdx = min(t + h - 1, cfg.T);
    direction = scen.WindDirectionRad(windIdx);
    if isfield(scen, 'ForecastWindDirectionRad')
        direction = scen.ForecastWindDirectionRad(windIdx);
    end
    flight = evaluate_flight_physics(distanceKm, route, ...
        scen.ForecastWind(windIdx), direction, d, cfg);
end

function tf = forecast_task_feasible(id, d, h, R, State, scen, t, cfg)
    flight = forecast_flight(id, d, h, R, State, scen, t, cfg);
    availableEnergy = State.SoC(d);
    if availableEnergy <= cfg.Ewarn, availableEnergy = cfg.Emax; end
    tf = flight.Feasible && flight.TotalTimeSeconds <= cfg.StepSeconds && ...
        availableEnergy - flight.EnergyWh >= cfg.Esafe;
end

function [State, R, energy, aborts, servedIds, swapEvents] = execute_step( ...
    State, R, tasks, scen, t, cfg)
    servedIds = zeros(cfg.D, 1);
    energy = 0;
    aborts = 0;
    swapEvents = zeros(1, cfg.D);
    valid = tasks(tasks > 0 & tasks <= R.N);
    valid = valid(~R.Served(valid));
    % Frozen order: UAV execution uses the platform location that was
    % visible to planning. The platform then relocates once for the next
    % decision step, using the same shared relocation function.

    for d = 1:cfg.D
        id = tasks(d);
        if id == 0 || id > R.N || R.Served(id), continue; end
        node = R.Node(id);
        delta = scen.Coord(node, :) - State.Truck;
        distanceKm = norm(delta);
        if distanceKm <= eps, route = [1, 0]; else, route = delta / distanceKm; end
        windIdx = min(t, cfg.T);
        direction = scen.WindDirectionRad(windIdx);
        if isfield(scen, 'ActualWindDirectionRad')
            direction = scen.ActualWindDirectionRad(windIdx);
        end
        flight = evaluate_flight_physics(distanceKm, route, ...
            scen.ActualWind(windIdx), direction, d, cfg);
        if State.SoC(d) <= cfg.Ewarn
            State.SoC(d) = cfg.Emax;
            State.Swaps(d) = State.Swaps(d) + 1;
            swapEvents(d) = 1;
        end
        % One execution tick is 20 minutes. Flights that violate the time
        % or explicit energy reserve are rejected and logged as risk aborts.
        if ~flight.Feasible || ...
                flight.TotalTimeSeconds > cfg.StepSeconds || ...
                State.SoC(d) - flight.EnergyWh < cfg.Esafe
            aborts = aborts + 1;
            continue;
        end
        State.SoC(d) = State.SoC(d) - flight.EnergyWh;
        energy = energy + flight.EnergyWh;
        State.RoleActions(d) = State.RoleActions(d) + 1;
        R.Served(id) = true;
        R.ServeTime(id) = t;
        servedIds(d) = id;
    end
    relocationIds = valid;
    if isempty(relocationIds)
        [eligible, ~] = evaluate_order_status(R, t, cfg);
        relocationIds = find(eligible);
    end
    if ~isempty(relocationIds)
        targets = scen.Coord(R.Node(relocationIds), :);
        [State.Truck, ~] = relocate_mobile_platform(State.Truck, ...
            targets, cfg.TruckStepDistanceKm);
    end
end

function out = evaluate_episode(R, State, totalEnergy, totalHs, ...
    totalPolicyHs, totalSafetyHs, replanCount, policyReplanCount, ...
    forcedSafetyCount, safetyFallbacks, unsafeExecutions, totalPlanningTime, ...
    totalSolverTime, totalYalmipTime, riskAborts, milpCalls, milpFallbacks, ...
    timeLimitedReturns, acceptedIncumbents, maxConstraintViolation, ...
    diagnostics, episodeMinimumSoC, cfg)
    ids = 1:R.N;
    served = R.Served(ids);
    vip = R.Priority(ids) == 2;
    standard = ~vip;
    expired = R.Expired(ids);
    tardy = zeros(size(ids));
    tardy(served) = max(0, ...
        R.ServeTime(ids(served)) - R.Deadline(ids(served)));
    tardy(~served) = max(0, cfg.T + cfg.Clearance + 1 - ...
        R.Deadline(ids(~served)));
    completed = sum(served);
    vipN = max(1, sum(vip));

    out.CompletionRate = completed / max(1, R.N) * 100;
    out.VIPOnTimeRate = sum(served & vip & tardy == 0) / vipN * 100;
    out.MeanTardiness = mean(tardy);
    vipTardy = tardy(vip);
    standardTardy = tardy(standard);
    if isempty(vipTardy), out.VIPMeanTardiness = 0;
    else, out.VIPMeanTardiness = mean(vipTardy); end
    if isempty(standardTardy), out.StandardMeanTardiness = 0;
    else, out.StandardMeanTardiness = mean(standardTardy); end
    out.ExpiredRate = sum(expired) / max(1, R.N) * 100;
    out.EnergyPerOrder = totalEnergy / max(1, completed);
    out.RiskAbortRate = riskAborts / max(1, R.N) * 100;
    out.UnsafeExecutionRate = unsafeExecutions / max(1, R.N) * 100;
    out.Nervousness = totalHs;
    out.HsPolicy = totalPolicyHs;
    out.HsSafety = totalSafetyHs;
    decisionCount = cfg.T + cfg.Clearance;
    out.PlanningReleaseRate = replanCount / decisionCount * 100;
    out.ReplanRate = out.PlanningReleaseRate;
    out.PolicyPlanningReleaseRate = policyReplanCount / decisionCount * 100;
    out.ForcedSafetyTriggerRate = forcedSafetyCount / decisionCount * 100;
    out.SafetyFallbackRate = safetyFallbacks / decisionCount * 100;
    out.MILPCallRate = 100 * milpCalls / decisionCount;
    out.EmptyInstanceRate = 100 * diagnostics.Nempty / decisionCount;
    out.PlanningTime = totalPlanningTime;
    out.SolverTime = totalSolverTime;
    out.YalmipTime = totalYalmipTime;
    out.MILPModelBuildTime = sum(diagnostics.ModelBuildTimeSeconds);
    out.MILPOptimizeWallTime = sum(diagnostics.OptimizeWallTimeSeconds);
    out.MILPExtractionTime = sum(diagnostics.ExtractionTimeSeconds);
    out.MILPFallbackTime = sum(diagnostics.FallbackTimeSeconds);
    out.MeanPlanningTimePerRelease = totalPlanningTime / ...
        max(1, replanCount);
    out.MeanSolverTimePerMILP = totalSolverTime / max(1, milpCalls);
    out.MeanYalmipTimePerMILP = totalYalmipTime / max(1, milpCalls);
    out.PlanningReleaseTimeP50 = safe_percentile( ...
        diagnostics.PlanningReleaseTimeSeconds, 50);
    out.PlanningReleaseTimeP95 = safe_percentile( ...
        diagnostics.PlanningReleaseTimeSeconds, 95);
    out.PlanningReleaseTimeMax = safe_max( ...
        diagnostics.PlanningReleaseTimeSeconds);
    out.MILPCallTimeP50 = safe_percentile( ...
        diagnostics.MILPCallTimeSeconds, 50);
    out.MILPCallTimeP95 = safe_percentile( ...
        diagnostics.MILPCallTimeSeconds, 95);
    out.MILPCallTimeMax = safe_max(diagnostics.MILPCallTimeSeconds);
    out.SolverTimeP50 = safe_percentile( ...
        diagnostics.SolverTimeSeconds, 50);
    out.SolverTimeP95 = safe_percentile( ...
        diagnostics.SolverTimeSeconds, 95);
    out.SolverTimeMax = safe_max(diagnostics.SolverTimeSeconds);
    out.TerminalMinimumSoC = min(State.SoC);
    out.EpisodeMinimumSoC = episodeMinimumSoC;
    out.MinimumSoC = episodeMinimumSoC;
    out.FleetTotalSwaps = sum(State.Swaps);
    out.MILPFallbackRate = 100 * milpFallbacks / max(1, milpCalls);
    out.MILPTimeLimitRate = 100 * timeLimitedReturns / max(1, milpCalls);
    out.MILPAcceptedIncumbentRate = ...
        100 * acceptedIncumbents / max(1, milpCalls);
    out.MaxConstraintViolation = maxConstraintViolation;
    out.RoleActions = State.RoleActions;
    out.SwapCounts = State.Swaps;
    out.Diagnostics = diagnostics;
    % Per-order records are a derived audit artifact: they do not enter the
    % policy optimisation or any episode-level metric.  OnTime is defined
    % for all orders, while VIP remains an explicit management label.
    out.OrderOutcomes = struct( ...
        'Priority', R.Priority(ids), ...
        'VIP', double(vip), ...
        'ArrivalStep', R.Arrival(ids), ...
        'DeadlineStep', R.Deadline(ids), ...
        'Served', double(served), ...
        'OnTime', double(served & tardy == 0), ...
        'TardinessSteps', tardy, ...
        'Expired', double(expired));
end

function v = safe_percentile(x, p)
    x = x(isfinite(x));
    if isempty(x), v = 0; return; end
    v = prctile(x, p);
end

function v = safe_max(x)
    x = x(isfinite(x));
    if isempty(x), v = 0; else, v = max(x); end
end

function diagnostics = empty_diagnostics()
    diagnostics = struct('Ntrigger', 0, 'Nempty', 0, 'Nmodel', 0, ...
        'Noptimize', 0, 'Nnormal', 0, 'Ntimelimit', 0, ...
        'Ninfeasible', 0, 'Nerror', 0, 'Nincumbent', 0, ...
        'Naccepted', 0, 'Nrejected', 0, 'Nfallback', 0, ...
        'NforcedSafety', 0, 'NsafetyFallback', 0, ...
        'ForcedSafetyReasonCounts', zeros(4, 1), ...
        'PlanningReleaseTimeSeconds', [], ...
        'SafetyReleaseTimeSeconds', [], ...
        'ModelBuildTimeSeconds', [], ...
        'OptimizeWallTimeSeconds', [], ...
        'SolverTimeSeconds', [], ...
        'YalmipTimeSeconds', [], ...
        'ExtractionTimeSeconds', [], ...
        'FallbackTimeSeconds', [], ...
        'MILPCallTimeSeconds', []);
end

function Summary = summarise_metrics(M, policies, R)
    names = fieldnames(M);
    Summary.R = R;
    Summary.CIType = 'two-sided Student-t 95% confidence interval';
    for q = 1:numel(names)
        x = M.(names{q});
        Summary.(names{q}).Mean = zeros(size(x, 1), 1);
        Summary.(names{q}).SD = zeros(size(x, 1), 1);
        Summary.(names{q}).CI = zeros(size(x, 1), 1);
        for p = 1:size(x, 1)
            [mu, hw] = mean_student_t_ci(x(p, :));
            Summary.(names{q}).Mean(p) = mu;
            Summary.(names{q}).SD(p) = std(x(p, :), 0);
            Summary.(names{q}).CI(p) = hw;
        end
    end
    Summary.Names = {policies.Name};
end

function metadata = collect_metadata(cfg, policies)
    metadata.Timestamp = char(datetime('now', ...
        'Format', 'yyyy-MM-dd HH:mm:ss Z'));
    metadata.MATLABVersion = version;
    metadata.MATLABRelease = version('-release');
    metadata.Computer = computer;
    metadata.ProcessorIdentifier = getenv('PROCESSOR_IDENTIFIER');
    metadata.NumberOfProcessors = getenv('NUMBER_OF_PROCESSORS');
    metadata.PhysicalMemoryGB = physical_memory_gb();
    [status, osText] = system('ver');
    if status == 0, metadata.OSVersion = strtrim(osText);
    else, metadata.OSVersion = 'unavailable'; end
    metadata.GurobiThreads = cfg.GurobiThreads;
    metadata.GurobiSeed = cfg.GurobiSeed;
    metadata.SolverCapSecondsPerReplan = cfg.MILPTimeLimit;
    metadata.MIPGap = cfg.MILPMIPGap;
    metadata.PhysicsModel = ['constant airspeed with wind-vector ground-', ...
        'track projection; cruise power times round-trip flight time'];
    metadata.UnitConvention = ['distance km converted to m for flight time; ', ...
        'speed and wind m/s; energy W*s/3600 = Wh'];
    metadata.PlanInertiaSemantics = ...
        'W3 multiplies only plan-change distance; physical-risk and reserve rules are independent.';
    metadata.SafetyGuardSemantics = ['Before execution, all policies share ', ...
        'a realised-state first-slot check; unsafe commitments open forced ', ...
        'safe replanning and, if needed, deterministic hold/swap/defer fallback.'];
    metadata.InputSemantics = ['V2 uses public temporal/spatial demand and ', ...
        'weather replay inputs; VIP share and platform motion remain ', ...
        'predeclared scenarios.'];
    metadata.Fingerprint = build_release_fingerprint(cfg, policies);
    try
        metadata.YALMIPVersion = yalmip('version');
    catch
        metadata.YALMIPVersion = 'unavailable';
    end
    [status, text] = system('gurobi_cl --version');
    if status == 0
        metadata.GurobiVersion = strtrim(text);
    else
        metadata.GurobiVersion = 'gurobi_cl version unavailable';
    end
    metadata.GurobiLicenseProvenance = ...
        'local license file; entitlement key is intentionally not recorded';
end

function memoryGB = physical_memory_gb()
    memoryGB = NaN;
    try
        command = ['powershell -NoProfile -Command "', ...
            '(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory"'];
        [status, text] = system(command);
        bytes = str2double(strtrim(text));
        if status == 0 && isfinite(bytes) && bytes > 0
            memoryGB = bytes / 1024^3;
        end
    catch
        % Hardware metadata is audit information only; no simulation result
        % depends on whether an operating-system query is available.
    end
end

function disp_summary(S, policies)
    fprintf('\nMean results (Student-t 95%% CI half-width in parentheses)\n');
    for p = 1:numel(policies)
        fprintf(['%s | VIP %.1f (%.1f) | completion %.1f | ', ...
            'energy/order %.1f | Hs %.1f | replan %.1f%% | ', ...
            'fallback %.1f%% | time-limit %.1f%%\n'], ...
            policies(p).Key, S.VIPOnTimeRate.Mean(p), ...
            S.VIPOnTimeRate.CI(p), S.CompletionRate.Mean(p), ...
            S.EnergyPerOrder.Mean(p), S.Nervousness.Mean(p), ...
            S.ReplanRate.Mean(p), S.MILPFallbackRate.Mean(p), ...
            S.MILPTimeLimitRate.Mean(p));
    end
end
