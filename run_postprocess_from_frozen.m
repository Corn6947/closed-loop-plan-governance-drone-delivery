function run_postprocess_from_frozen()
%RUN_POSTPROCESS_FROM_FROZEN Rebuild statistics and figures without rerunning MILPs.
root = fileparts(mfilename('fullpath'));
old = pwd;
cleanup = onCleanup(@() cd(old)); %#ok<NASGU>
cd(root);
addpath(root);
addpath(fullfile(root, 'data_calibration', 'matlab'));

resultDir = fullfile(root, 'results_frozen');
exportDir = fullfile(resultDir, 'exports');
figureDir = fullfile(root, 'figures_tables');

export_primary_statistics( ...
    fullfile(resultDir, 'primary_policy_comparison_60_scenarios.mat'), exportDir);
export_supporting_statistics(resultDir, exportDir);
export_fleet_and_heterogeneity_statistics(resultDir, exportDir);
generate_submission_figures(figureDir, resultDir);
verify_frozen_release(root);
fprintf('Frozen-result post-processing completed.\n');
end
