function run_verify_frozen_release()
%RUN_VERIFY_FROZEN_RELEASE Verify the supplied frozen evidence package.
root = fileparts(mfilename('fullpath'));
old = pwd;
cleanup = onCleanup(@() cd(old)); %#ok<NASGU>
cd(root);
addpath(root);
addpath(fullfile(root, 'data_calibration', 'matlab'));
verify_frozen_release(root);
end
