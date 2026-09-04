# Reproducibility Protocol

## A. Static integrity check

```bash
python verify_package.py
```

Expected result: `PACKAGE VERIFICATION: PASS`.

## B. Audit frozen results

Start MATLAB in the package root and run:

```matlab
run_verify_frozen_release
```

This checks the 60-replication primary and fleet conditions, 20-replication boundary and ablation conditions, paired guard seeds, zero unsafe execution under the shared guard, calibration columns, and final figures/tables.

## C. Regenerate statistics and figures from frozen results

```matlab
run_postprocess_from_frozen
```

Then regenerate the Word tables and manifests:

```bash
python create_submission_tables.py
python build_artifact_manifest.py
python build_public_package_manifest.py
python verify_package.py
```

The order-level GLMM step requires the Statistics and Machine Learning Toolbox. If unavailable, retain the supplied frozen GLMM CSV and disclose that only aggregate post-processing was rerun.

## D. Full experimental rerun

Use a fresh copy because the command overwrites `results_frozen`:

```matlab
run_final_experiment_suite('run')
```

The final suite uses fixed seed bases declared in `run_final_experiment_suite.m`. Common random numbers are shared across policy comparisons. Runtime can vary with hardware and solver configuration; numerical results should be interpreted against the scenario-level outputs and declared solver tolerances.
