function scen = draw_public_arrivals(T, C, baseOrdersPer20Min, startHour, seed)
%DRAW_PUBLIC_ARRIVALS Draw standard-order arrivals from the Olist shape.
% baseOrdersPer20Min is intentionally NOT calibrated here: the Olist data
% identify the intraday shape, while fleet/capacity matching is an explicit
% V2 scenario decision. VIP labels are deliberately left at zero. Customer
% zones are sampled without replacement from the public calibrated geometry.

    if nargin < 4 || isempty(startHour), startHour = randi([0, 23]); end
    if nargin >= 5 && ~isempty(seed), rng(seed, 'twister'); end
    if ~isscalar(T) || ~isscalar(C) || T < 1 || C < 1
        error('T and C must be positive scalars.');
    end
    if ~isscalar(baseOrdersPer20Min) || baseOrdersPer20Min < 0
        error('baseOrdersPer20Min must be nonnegative.');
    end

    here = fileparts(mfilename('fullpath'));
    csvFile = fullfile(here, '..', 'processed', 'olist_hourly_demand_profile.csv');
    profile = readtable(csvFile);
    rel = zeros(1, 24);
    rel(profile.hour_of_day + 1) = profile.relative_intensity_to_hourly_mean;

    spatial = load_public_spatial_zones();
    if C ~= numel(spatial.Probability)
        error('Public spatial geometry has %d zones, so C must equal %d.', ...
            numel(spatial.Probability), numel(spatial.Probability));
    end

    scen.ArrivalPriority = zeros(C, T); % 1=standard, 2=VIP in the main model
    scen.Coord = spatial.CoordKm;
    scen.SpatialZoneId = spatial.ZoneId;
    scen.SpatialProbability = spatial.Probability;
    scen.SpatialGeometryContract = spatial.Contract;
    scen.UncalibratedVIP = true;
    scen.DemandShapeSource = 'Olist Sao Paulo hourly public-order profile';
    scen.BaseOrdersPer20Min = baseOrdersPer20Min;
    for t = 1:T
        hour = mod(startHour + floor((t - 1) / 3), 24);
        lambda = baseOrdersPer20Min * rel(hour + 1);
        n = min(C, local_poisson(lambda));
        if n > 0
            selected = local_weighted_without_replacement(spatial.Probability(:), n);
            scen.ArrivalPriority(selected, t) = 1;
        end
    end
end

function selected = local_weighted_without_replacement(probability, n)
    % Efraimidis--Spirakis keys; all probabilities have been checked positive.
    keys = rand(numel(probability), 1) .^ (1 ./ probability);
    [~, order] = sort(keys, 'descend');
    selected = order(1:n)';
end

function n = local_poisson(lambda)
    if lambda == 0, n = 0; return; end
    threshold = exp(-lambda);
    product = 1;
    n = -1;
    while product > threshold
        n = n + 1;
        product = product * rand;
    end
end
