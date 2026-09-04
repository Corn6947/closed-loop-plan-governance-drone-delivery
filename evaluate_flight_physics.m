function flight = evaluate_flight_physics(distanceKm, routeUnit, windSpeedMps, ...
    windDirectionRad, droneIndex, cfg)
%EVALUATE_FLIGHT_PHYSICS Reduced-form, unit-consistent round-trip flight model.
% The drone maintains a fixed airspeed and crabs to hold the intended
% ground track. Wind direction is the direction of air motion in radians.

    flight = struct('Feasible', false, 'GroundSpeedOutMps', NaN, ...
        'GroundSpeedReturnMps', NaN, 'TimeOutSeconds', Inf, ...
        'TimeReturnSeconds', Inf, 'TotalTimeSeconds', Inf, ...
        'EnergyWh', Inf, 'PowerW', NaN, 'Reason', 'invalid-input');

    if nargin < 6 || isempty(cfg), cfg = systems_default_config(); end
    if ~isscalar(distanceKm) || ~isfinite(distanceKm) || distanceKm < 0
        return;
    end
    routeUnit = routeUnit(:)';
    if numel(routeUnit) ~= 2 || any(~isfinite(routeUnit))
        return;
    end
    nrm = norm(routeUnit);
    if distanceKm == 0
        flight.Feasible = true;
        flight.GroundSpeedOutMps = cfg.DroneAirspeedMps;
        flight.GroundSpeedReturnMps = cfg.DroneAirspeedMps;
        flight.TimeOutSeconds = 0;
        flight.TimeReturnSeconds = 0;
        flight.TotalTimeSeconds = 0;
        flight.EnergyWh = 0;
        flight.Reason = 'ok';
        return;
    elseif nrm <= eps
        return;
    end
    routeUnit = routeUnit / nrm;

    if ~isscalar(windSpeedMps) || ~isfinite(windSpeedMps) || windSpeedMps < 0 ...
            || ~isscalar(windDirectionRad) || ~isfinite(windDirectionRad) ...
            || droneIndex < 1 || droneIndex > numel(cfg.RolePowerMultiplier)
        return;
    end

    windVector = windSpeedMps * [cos(windDirectionRad), sin(windDirectionRad)];
    along = dot(windVector, routeUnit);
    crossVector = windVector - along * routeUnit;
    crossSquared = dot(crossVector, crossVector);
    airspeedSquared = cfg.DroneAirspeedMps ^ 2;
    if crossSquared >= airspeedSquared
        flight.Reason = 'crosswind-exceeds-track-hold-capability';
        return;
    end

    trackComponent = sqrt(max(0, airspeedSquared - crossSquared));
    vOut = along + trackComponent;
    vReturn = -along + trackComponent;
    flight.GroundSpeedOutMps = vOut;
    flight.GroundSpeedReturnMps = vReturn;
    if vOut < cfg.MinGroundSpeedMps || vReturn < cfg.MinGroundSpeedMps
        flight.Reason = 'ground-speed-below-safety-minimum';
        return;
    end

    distanceM = distanceKm * 1000;
    tOut = distanceM / vOut;
    tReturn = distanceM / vReturn;
    totalSeconds = tOut + tReturn;
    if isfield(cfg, 'UseMissionEquivalentPower') && ...
            cfg.UseMissionEquivalentPower
        basePowerW = cfg.MissionEquivalentPowerW;
    else
        basePowerW = cfg.BaseCruisePowerW;
    end
    powerW = basePowerW * cfg.RolePowerMultiplier(droneIndex);
    energyWh = powerW * totalSeconds / 3600;

    flight.Feasible = isfinite(totalSeconds) && isfinite(energyWh);
    flight.TimeOutSeconds = tOut;
    flight.TimeReturnSeconds = tReturn;
    flight.TotalTimeSeconds = totalSeconds;
    flight.EnergyWh = energyWh;
    flight.PowerW = powerW;
    if flight.Feasible, flight.Reason = 'ok'; end
end
