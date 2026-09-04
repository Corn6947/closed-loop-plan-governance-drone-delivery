function weather = draw_public_weather_path(T, splitName, seed)
%DRAW_PUBLIC_WEATHER_PATH Draw a 20-minute weather path from public data.
% The public inputs are hourly. Each sampled hour is therefore held over
% three decision steps. Forecast and realised directions are retained
% separately; V2 execution code must use the realised values only when
% checking a flight that is about to execute.

    if nargin < 2 || isempty(splitName), splitName = 'calibration'; end
    if nargin >= 3 && ~isempty(seed), rng(seed, 'twister'); end
    if ~isscalar(T) || T < 1 || mod(T, 1) ~= 0
        error('T must be a positive integer.');
    end

    here = fileparts(mfilename('fullpath'));
    csvFile = fullfile(here, '..', 'processed', 'legacy_weather_pairs_fingerprint_only.csv');
    source = readtable(csvFile, 'TextType', 'string');
    source = source(source.split == string(splitName), :);
    nHours = ceil(T / 3);
    if height(source) < nHours
        error('Not enough public weather rows in split %s.', splitName);
    end

    % Choose a contiguous historical block, preserving serial correlation.
    sourceTime = datetime(source.valid_time_utc, ...
        'InputFormat', "yyyy-MM-dd'T'HH:mm", 'TimeZone', 'UTC');
    starts = find([true; hours(diff(sourceTime)) == 1]);
    viable = starts(starts + nHours - 1 <= height(source));
    if isempty(viable), error('No contiguous weather block is available.'); end
    first = viable(randi(numel(viable)));
    block = source(first:first + nHours - 1, :);

    expand3 = @(x) repelem(x(:)', 3);
    weather.ForecastWindMps = expand3(block.forecast_wind_mps);
    weather.ActualWindMps = expand3(block.actual_wind_mps);
    weather.ForecastDirectionRad = deg2rad(expand3(block.forecast_direction_deg));
    weather.ActualDirectionRad = deg2rad(expand3(block.actual_direction_deg));
    weather.ForecastWindMps = weather.ForecastWindMps(1:T);
    weather.ActualWindMps = weather.ActualWindMps(1:T);
    weather.ForecastDirectionRad = weather.ForecastDirectionRad(1:T);
    weather.ActualDirectionRad = weather.ActualDirectionRad(1:T);
    weather.SourceRows = block.valid_time_utc;
    weather.Split = string(splitName);
end
