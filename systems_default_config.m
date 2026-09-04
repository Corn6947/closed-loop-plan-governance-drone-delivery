function cfg = systems_default_config()
%SYSTEMS_DEFAULT_CONFIG Authoritative configuration for the submission evidence pipeline.
% Distances are in km, speeds in m/s, powers in W, times in s (unless the
% field name explicitly states hours), and battery energies in Wh.

    % V2 is a separate, empirically informed experiment definition.  The
    % frozen V1 result package remains a historical concept demonstration.
    cfg.SchemaVersion = 'systems-sao-paulo-gfs-governance-v1';
    cfg.T = 27;
    cfg.H = 3;
    cfg.C = 12;
    cfg.D = 3;
    cfg.R = 60;
    cfg.Clearance = 12;
    cfg.ErrorSigma = NaN; % Legacy field: V2 replays empirical wind blocks.
    cfg.SeedBase = 20260802;
    cfg.Depot = [0, 0]; % Demand-centre coordinate reference, not a real depot.

    cfg.UsePublicCalibration = true;
    cfg.CalibrationPackageVersion = 'sao-paulo-gfs-era5-joint-replay-v1';
    cfg.PublicCalibration.WindBiasMps = NaN; % Superseded by the GFS pairing below.
    cfg.PublicCalibration.WindErrorBlockHours = 3;
    cfg.PublicCalibration.Source = 'data_calibration/processed public-calibration-release-v1';
    cfg.InputSplit = 'holdout'; % Final evaluation only after rule freeze.
    cfg.UseSaoPauloJointReplay = true;
    cfg.GFSForecastSpeedBiasForecastMinusActualMps = 0.4883457117;
    cfg.BaseOrdersPer20Min = 2.2; % Capacity-matched scenario scale, not observed rate.
    cfg.VIPScenarioShare = 0.10; % Management scenario; no compatible public VIP label.
    cfg.VIPScenarioSeedOffset = 410000;
    cfg.EmpiricalEventErrorThresholdMps = 1.4793821485; % Development P90, bias-corrected GFS residual.
    cfg.EventThresholdSelection = ['Development-set 90th percentile of ', ...
        'bias-corrected absolute wind-speed residual; fixed before holdout use.'];
    cfg.ForcedSafetyEnabled = true;
    cfg.SafetyGuardVersion = 'first-slot-actual-state-v1';
    cfg.RequireZeroUnsafeExecution = true;

    cfg.StepSeconds = 20 * 60;
    cfg.StepHours = cfg.StepSeconds / 3600;
    cfg.TruckStepDistanceKm = 3.8;

    % Reduced-form flight physics. The airspeed conversion is explicit so
    % that no m/s wind quantity is ever subtracted from a km/h speed.
    cfg.DroneAirspeedKmh = 62;
    cfg.DroneAirspeedMps = cfg.DroneAirspeedKmh / 3.6;
    cfg.MinGroundSpeedMps = 2.5;
    cfg.BaseCruisePowerW = 230; % Retained only for backward-compatible V1 calls.
    cfg.UseMissionEquivalentPower = true;
    cfg.MissionEquivalentPowerW = 407.723375;
    cfg.EnergyTransferP10W = 317.948435;
    cfg.EnergyTransferP90W = 472.060722;
    cfg.EnergyModelContract = ['Public DJI M100 full-mission-equivalent ', ...
        'power envelope; target-aircraft transfer and role multipliers ', ...
        'remain explicit scenario uncertainty.'];
    % Fleet-role contract. For D=3, the first two UAVs are capacity and
    % priority roles and UAV 3 is a contingency reserve. Fleet-size boundary
    % analyses use D=2 (capacity + priority) and D=4 (the same three roles
    % plus one additional capacity UAV); only the designated reserve UAV is
    % subject to reserve eligibility.
    cfg.RolePowerMultiplier = [1.05, 0.90, 1.40];
    cfg.ReserveDroneIndex = 3;
    cfg.AdditionalCapacityPowerMultiplier = 1.05;

    cfg.Emax = 1000;
    cfg.Ewarn = 480;
    cfg.Esafe = 200;
    % The order due date is soft: overdue jobs remain eligible and accrue
    % tardiness.  A common 12-step hard queue limit is applied only after
    % that soft due date and is identical for every policy and planner path.
    cfg.MaxLateSteps = 12;

    % Plan-inertia mechanism. W3 may be state-dependent, but may only
    % multiply the plan-change distance D(pi_k,pi_{k-1}); it must never
    % alter physical risk, energy feasibility, or reserve eligibility.
    % Fixed and adaptive inertia are tuned independently on the development
    % split.  Keeping these parameters separate prevents an adaptive-rule
    % change from silently changing the fixed-inertia comparator.
    cfg.FixedW3 = 20;
    cfg.W3base = 50;
    cfg.W3MinRatio = 0.10;
    cfg.W3Form = 'exponential';
    cfg.InertiaGammaError = 1.5;
    cfg.InertiaGammaWind = 1.2;
    cfg.InertiaGammaSoC = 4.5;
    % Development-data anchors: absolute residual P90 and realised wind P90.
    % These scale only the management W3 response, never physical safety.
    cfg.WindErrorScaleMps = 1.4793821485;
    cfg.HighWindReferenceMps = 4.984564;
    cfg.EventWindThresholdMps = cfg.EmpiricalEventErrorThresholdMps;
    cfg.EnableWindTrigger = true;
    cfg.EnableLowSoCTrigger = true;
    % P80/P90 are prespecified responsiveness-boundary conditions.  P90 is
    % the primary conservative operating point above; both are reported on
    % holdout rather than selecting the better outcome after evaluation.
    cfg.EventWindThresholdCandidatesMps = [1.1629470278, 1.4793821485];
    cfg.ReserveWindThresholdMps = 11;
    cfg.BacklogPressureThreshold = 12;
    % Development-set medians of bias-corrected absolute residual and
    % forecast wind.  The retention floor applies only inside this joint
    % low-risk region; it must not overwrite an error-responsive W3 under
    % an observed forecast miss.
    cfg.LowRiskErrorThresholdMps = 0.6295345489;
    cfg.LowRiskForecastWindMps = 2.984645;
    cfg.LowRiskW3FloorRatio = 0.90;
    cfg.VIPW3CapRatio = 0.20;
    cfg.BacklogW3CapRatio = 0.40;
    cfg.RetainPlanThresholdRatio = 0.65;

    % Assignment utility and schedule-change accounting.
    cfg.PriorityBenefit = 650;
    cfg.DeadlineBenefit = 75;
    cfg.AgeBenefit = 30;
    cfg.DistancePenalty = 14;
    cfg.RiskDistancePenalty = 12;
    cfg.EnergyPenaltyPerWh = 2.5;
    cfg.ReservePenalty = 90;
    cfg.PlanChangeScale = 10;
    cfg.ServiceWeightScale = 1.0;
    cfg.OrderExpiryEnabled = true;
    cfg.OrderExpiryAfterSteps = cfg.MaxLateSteps;
    cfg.PrimaryEndpoint = 'VIPOnTimeRate';
    cfg.PrimaryAlpha = 0.05;
    cfg.PowerTarget = 0.80;
    % Frozen inferential family: stratified VIP/standard tardiness remains
    % diagnostic only and is intentionally excluded from Holm adjustment.
    cfg.SecondaryHolmFamily = {'CompletionRate','MeanTardiness', ...
        'EnergyPerOrder','Nervousness','PlanningReleaseRate', ...
        'PlanningTime'};
    cfg.MatchedTriggerAudit = false;

    % Time-bounded MILP settings and incumbent tolerances.
    cfg.UseMILPPlanner = true;
    cfg.MILPTimeLimit = 1.5;
    cfg.MILPMIPGap = 0.005;
    cfg.GurobiThreads = 1;
    cfg.GurobiSeed = 20260728;
    cfg.MaxCandidateOrders = 18;
    cfg.FeasibilityTolerance = 1e-6;
    cfg.IntegerTolerance = 1e-5;
end
