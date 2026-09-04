function distance = plan_change_distance(newPlan, oldPlan)
%PLAN_CHANGE_DISTANCE Canonical one-hot plan-change distance.
% A task replacement counts as one removal plus one insertion, matching the
% one-hot distance used by the MILP objective.  Empty-to-task and
% task-to-empty changes each count as one.

    if ~isequal(size(newPlan), size(oldPlan))
        error('plan_change_distance:SizeMismatch', ...
            'newPlan and oldPlan must have identical dimensions.');
    end
    changed = newPlan ~= oldPlan;
    distance = sum(double(newPlan(changed) ~= 0)) + ...
        sum(double(oldPlan(changed) ~= 0));
end
