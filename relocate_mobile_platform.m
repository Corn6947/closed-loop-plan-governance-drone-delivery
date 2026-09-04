function [truckPosition, distanceKm] = relocate_mobile_platform(truckPosition, targetPoints, maxDistanceKm)
%RELOCATE_MOBILE_PLATFORM Shared mobile-platform relocation rule.
% The platform moves toward the centroid of active task targets, capped by
% maxDistanceKm.  This rule is used by execution and all diagnostic tests.

    if nargin < 3 || isempty(maxDistanceKm)
        maxDistanceKm = 3.8;
    end
    if isempty(targetPoints)
        distanceKm = 0;
        return;
    end
    target = mean(targetPoints, 1);
    delta = target - truckPosition;
    distanceKm = min(maxDistanceKm, norm(delta));
    if distanceKm > 0
        truckPosition = truckPosition + distanceKm * delta / norm(delta);
    end
end
