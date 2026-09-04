function [mu, halfWidth] = mean_student_t_ci(x, confidence)
%MEAN_STUDENT_T_CI Mean and two-sided Student-t confidence-interval half-width.

    if nargin < 2 || isempty(confidence), confidence = 0.95; end
    x = x(:);
    x = x(isfinite(x));
    n = numel(x);
    if n == 0
        mu = NaN;
        halfWidth = NaN;
        return;
    end
    mu = mean(x);
    if n == 1 || std(x, 0) == 0
        halfWidth = 0;
        return;
    end
    alpha = 1 - confidence;
    halfWidth = tinv(1 - alpha / 2, n - 1) * std(x, 0) / sqrt(n);
end
