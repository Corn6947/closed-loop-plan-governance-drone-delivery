function [eligible, expireNow] = evaluate_order_status(R, t, cfg)
%EVALUATE_ORDER_STATUS Shared late-order eligibility and expiry rule.
% An order remains eligible after its promised deadline while tardiness
% accrues.  It is explicitly expired only after MaxLateSteps beyond that
% deadline; this same status is used by MILP, fallback and idle filling.

    eligible = false(1, R.N);
    expireNow = false(1, R.N);
    if R.N == 0
        return;
    end

    ids = 1:R.N;
    active = ~R.Served(ids) & ~R.Expired(ids) & R.Arrival(ids) <= t;
    if ~cfg.OrderExpiryEnabled
        eligible = active;
        return;
    end
    lateLimit = R.Deadline(ids) + cfg.OrderExpiryAfterSteps;
    expireNow = active & (t > lateLimit);
    eligible = active & ~expireNow & (t <= lateLimit);
end
