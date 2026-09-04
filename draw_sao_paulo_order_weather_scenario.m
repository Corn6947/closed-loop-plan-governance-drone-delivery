function scen = draw_sao_paulo_order_weather_scenario(cfg, seed)
%DRAW_SAO_PAULO_ORDER_WEATHER_SCENARIO Draw one audited same-city replay.
% Each scenario uses one 27-step Sao Paulo day from the final GFS--ERA5
% pairing. Purchase counts are replayed at their observed 20-minute times;
% calibrated demand-zone probabilities provide the spatial proxy because the
% public Olist event table is not a drone-delivery location log.

    assert(cfg.C == 12, 'The audited replay currently uses 12 demand zones.');
    root = fileparts(mfilename('fullpath'));
    dataFile = fullfile(root, 'data_calibration', 'processed', ...
        'sao_paulo_gfs_era5_forecast_pairs_20min.csv');
    assert(exist(dataFile, 'file') == 2, ...
        'Missing audited Sao Paulo GFS--ERA5 pairing: %s', dataFile);

    persistent raw cachedFile
    if isempty(raw) || ~strcmp(cachedFile, dataFile)
        raw = readtable(dataFile, 'TextType', 'string');
        cachedFile = dataFile;
    end
    splitRows = raw(strcmpi(raw.split, string(cfg.InputSplit)), :);
    dates = unique(splitRows.episode_date, 'stable');
    keep = false(size(dates));
    for j = 1:numel(dates)
        episode = splitRows(splitRows.episode_date == dates(j), :);
        keep(j) = height(episode) == cfg.T && ...
            all(episode.step(:) == (1:cfg.T)') && ...
            sum(episode.observed_purchase_count) > 0 && ...
            max(episode.observed_purchase_count) <= cfg.C;
    end
    dates = dates(keep);
    assert(numel(dates) >= cfg.R, ...
        'Only %d direct-replay episodes available for R=%d.', numel(dates), cfg.R);

    % Coprime affine map: sequential common-random seeds select distinct
    % historical days and remain deterministic across reruns.
    idx = mod(7919 * double(seed) + 104729, numel(dates)) + 1;
    selectedDate = dates(idx);
    rows = sortrows(splitRows(splitRows.episode_date == selectedDate, :), 'step');
    assert(all(isfinite(rows.gfs_wind_mps)) && all(isfinite(rows.actual_wind_mps)));

    ensure_calibration_path(root);
    spatial = load_public_spatial_zones();
    rng(seed, 'twister');
    arrivals = zeros(cfg.C, cfg.T);
    for t = 1:cfg.T
        n = rows.observed_purchase_count(t);
        if n > 0
            selected = weighted_without_replacement(spatial.Probability(:), n);
            arrivals(selected, t) = 1;
        end
    end

    bias = cfg.GFSForecastSpeedBiasForecastMinusActualMps;
    scen = struct();
    scen.Coord = spatial.CoordKm;
    scen.SpatialZoneId = spatial.ZoneId;
    scen.SpatialProbability = spatial.Probability;
    scen.SpatialGeometryContract = spatial.Contract;
    scen.ArrivalPriority = arrivals;
    scen.ForecastWind = max(0, rows.gfs_wind_mps(:)' - bias);
    scen.ActualWind = rows.actual_wind_mps(:)';
    scen.ForecastWindDirectionRad = deg2rad(rows.gfs_wind_direction_deg(:)');
    scen.ActualWindDirectionRad = deg2rad(rows.actual_wind_direction_deg(:)');
    scen.WindDirectionRad = scen.ActualWindDirectionRad;
    scen.WeatherSourceRows = rows.utc_time;
    scen.WeatherSplit = string(cfg.InputSplit);
    scen.ReplayEpisodeDate = char(selectedDate);
    scen.ReplayObservedPurchaseCount = rows.observed_purchase_count(:)';
    scen.ReplayForecastLeadHours = rows.forecast_lead_hours(:)';
    scen.ScenarioSeed = seed;
    scen.InputContract = ['Direct same-city Olist purchase-time proxy and ', ...
        'archived 06Z GFS forecast/ERA5 realised-wind replay. Purchase ', ...
        'counts are not delivery releases; zone locations and VIP labels ', ...
        'remain predeclared scenario layers.'];
end

function ensure_calibration_path(root)
    calibrationPath = fullfile(root, 'data_calibration', 'matlab');
    assert(exist(fullfile(calibrationPath, 'load_public_spatial_zones.m'), 'file') == 2, ...
        'Missing spatial calibration interface at %s.', calibrationPath);
    if ~contains(path, calibrationPath), addpath(calibrationPath); end
end

function selected = weighted_without_replacement(probability, n)
    assert(n <= numel(probability));
    keys = rand(numel(probability), 1) .^ (1 ./ probability);
    [~, order] = sort(keys, 'descend');
    selected = order(1:n)';
end
