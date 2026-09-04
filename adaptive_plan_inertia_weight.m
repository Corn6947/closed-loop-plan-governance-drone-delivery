function W3 = adaptive_plan_inertia_weight(windErr, minSoc, forecastWind, cfg)
%ADAPTIVE_PLAN_INERTIA_WEIGHT State-dependent plan-inertia rule used by all policies.
% State variables determine the value of W3; W3 itself remains confined to
% the plan-change cost in the optimization/fallback objective.

    e = max(0, windErr) / cfg.WindErrorScaleMps;
    h = max(0, forecastWind - cfg.HighWindReferenceMps) / ...
        cfg.WindErrorScaleMps;
    s = max(0, (cfg.Ewarn - minSoc) / (cfg.Ewarn - cfg.Esafe));
    inertiaExposure = cfg.InertiaGammaError * e ^ 2 + ...
        cfg.InertiaGammaWind * h ^ 2 + cfg.InertiaGammaSoC * s ^ 2;
    floorValue = cfg.W3MinRatio * cfg.W3base;
    switch lower(string(cfg.W3Form))
        case "linear"
            severity = min(1, inertiaExposure / 4);
            W3 = cfg.W3base - (cfg.W3base - floorValue) * severity;
        case "piecewise"
            if inertiaExposure < 1
                W3 = cfg.W3base;
            elseif inertiaExposure < 3
                W3 = 0.5 * (cfg.W3base + floorValue);
            else
                W3 = floorValue;
            end
        case "step"
            W3 = floorValue;
            if inertiaExposure < 2, W3 = cfg.W3base; end
        otherwise
            W3 = floorValue + ...
                (1 - cfg.W3MinRatio) * cfg.W3base * exp(-inertiaExposure);
    end
    W3 = min(cfg.W3base, max(floorValue, W3));
end
