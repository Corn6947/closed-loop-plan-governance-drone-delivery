function Fingerprint = build_release_fingerprint(cfg, policies)
%BUILD_RELEASE_FINGERPRINT Immutable provenance for formal Evidence releases.
% Only files capable of changing scenario generation, policy semantics,
% optimization, execution, metrics, or scenario-level confidence summaries
% enter CodeHash.  Figure/table/pipeline files are deliberately excluded and
% are tracked by the artifact manifest instead.

    Fingerprint.ConfigHash = sha256_text(jsonencode(orderfields(cfg)));
    Fingerprint.PolicyHash = sha256_text(jsonencode(policies));
    sourceFiles = { ...
        'systems_default_config.m', 'systems_policy_catalog.m', ...
        'run_governance_evidence_suite.m', 'adaptive_plan_inertia_weight.m', ...
        'plan_change_distance.m', 'relocate_mobile_platform.m', ...
        'evaluate_flight_physics.m', 'evaluate_order_status.m', ...
        'mean_student_t_ci.m', 'build_release_fingerprint.m'};
    payload = '';
    for i = 1:numel(sourceFiles)
        assert(exist(sourceFiles{i}, 'file') == 2, ...
            'Missing source file for fingerprint: %s', sourceFiles{i});
        payload = [payload, sourceFiles{i}, char(10), ...
            fileread(sourceFiles{i}), char(10)]; %#ok<AGROW>
    end
    Fingerprint.CodeHash = sha256_text(payload);
    Fingerprint.SourceFiles = sourceFiles;
    calibrationFiles = {};
    if isfield(cfg, 'UsePublicCalibration') && cfg.UsePublicCalibration
        calibrationRoot = fullfile('data_calibration');
        calibrationFiles = { ...
            fullfile(calibrationRoot, 'matlab', 'draw_public_arrivals.m'), ...
            fullfile(calibrationRoot, 'matlab', 'draw_public_weather_path.m'), ...
            fullfile(calibrationRoot, 'matlab', 'load_public_spatial_zones.m'), ...
            fullfile(calibrationRoot, 'processed', 'legacy_weather_pairs_fingerprint_only.csv'), ...
            fullfile(calibrationRoot, 'processed', 'olist_hourly_demand_profile.csv'), ...
            fullfile(calibrationRoot, 'processed', 'olist_12_zone_geometry.csv')};
    end
    calibrationPayload = '';
    for i = 1:numel(calibrationFiles)
        assert(exist(calibrationFiles{i}, 'file') == 2, ...
            'Missing calibrated input for fingerprint: %s', calibrationFiles{i});
        calibrationPayload = [calibrationPayload, calibrationFiles{i}, char(10), ...
            fileread(calibrationFiles{i}), char(10)]; %#ok<AGROW>
    end
    Fingerprint.CalibrationFiles = calibrationFiles;
    Fingerprint.CalibrationHash = sha256_text(calibrationPayload);
    Fingerprint.SchemaVersion = cfg.SchemaVersion;
    env = struct();
    env.MATLABVersion = version;
    env.MATLABRelease = version('-release');
    env.Computer = computer;
    env.GurobiMEX = which('gurobi');
    env.YALMIPOptimize = which('optimize');
    env.GurobiHome = getenv('GUROBI_HOME');
    env.GurobiLicenseFileSet = ~isempty(getenv('GRB_LICENSE_FILE'));
    env.GurobiThreads = cfg.GurobiThreads;
    env.GurobiSeed = cfg.GurobiSeed;
    Fingerprint.Environment = env;
    Fingerprint.EnvironmentHash = sha256_text(jsonencode(orderfields(env)));
end

function digest = sha256_text(textValue)
    bytes = uint8(unicode2native(textValue, 'UTF-8'));
    engine = java.security.MessageDigest.getInstance('SHA-256');
    engine.update(bytes);
    raw = typecast(engine.digest(), 'uint8');
    digest = lower(reshape(dec2hex(raw, 2).', 1, []));
end
