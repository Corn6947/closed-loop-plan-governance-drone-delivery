# Reproducibility Package

## Study

**Closed-Loop Plan Governance for Dynamic Drone Delivery Supported by a Mobile Platform: Separating Planning Access, Plan Inertia, and a Shared Safety Guard**

This package supports audit and reproduction of the computational evidence reported in the manuscript. It contains the author-written simulation and post-processing code, public derived calibration inputs, frozen scenario-level results, random seeds, final figures and tables, and machine-readable manifests.

The study is an **empirically informed simulation**, not a field deployment or an enterprise operating-log analysis. The Sao Paulo demand and weather inputs are same-city public proxies. The DJI Matrice 100 energy evidence is an external engineering transfer envelope from a different location.

## Start here

1. Read `CLAIM_BOUNDARIES.md` and `DATA_SOURCES.md`.
2. Run `python verify_package.py` to check package integrity, identifiers, required files, and SHA-256 hashes.
3. In MATLAB, run `run_verify_frozen_release` to check the frozen experimental invariants.
4. To regenerate CSV statistics and the seven figures from the frozen MAT files, run `run_postprocess_from_frozen`.
5. Run `python create_submission_tables.py` to regenerate the Word tables.
6. Run `python build_artifact_manifest.py`, followed by `python build_public_package_manifest.py`, after regenerating any artifact.

Full simulation reruns require MATLAB, YALMIP, and Gurobi and can be started with:

```matlab
run_final_experiment_suite('run')
```

This command overwrites files under `results_frozen`. Use a fresh copy of the package for a full rerun. The frozen results supplied here can be checked without a Gurobi license.

## Package layout

- Root `*.m`: simulation, policy, statistical-export, figure-generation, and verification code.
- `results_frozen/`: frozen results, exported statistics, protocol, and seeds.
- `data_calibration/processed/`: public derived calibration inputs. Raw pseudonymous order identifiers have been removed.
- `data_calibration/matlab/`: calibration interfaces used by the simulation.
- `data_calibration/scripts/`: available public-data download, processing, and validation utilities.
- `figures_tables/`: seven final PNG figures, manuscript tables, and the artifact manifest.
- `provenance/`: the pre-public-redaction internal artifact manifest retained for audit only.

All public-package directories use stable English names. The package must be run from its root directory.

## Reproducibility levels

- **Integrity check:** verifies package contents and hashes; no MATLAB required.
- **Frozen-result audit:** checks sample sizes, common seeds, guard invariants, inputs, figures, and tables.
- **Post-processing reproduction:** regenerates statistics, figures, and tables from frozen results.
- **Full computational rerun:** regenerates the stochastic scenarios and optimization results with the declared software environment.

## Important limitations

- Raw Olist, GFS, ERA5, and Matrice 100 files are not redistributed. Reacquire them from the sources listed in `DATA_SOURCES.md` and observe their terms.
- The final processed GFS-ERA5 replay is included and sufficient for experiment reruns. The exact one-off raw GFS pairing collector used during calibration is not preserved as a standalone script; this is disclosed in `DATA_SOURCES.md` and is a remaining provenance limitation.
- Frozen MAT metadata may retain the source filenames used at the time of the original run. Public-package filenames and executable references have been normalized; the historical mapping is recorded in `provenance/FILE_RENAMING_MAP.csv`.
- Licensing is deliberately layered: author-written MATLAB and Python code is under the MIT License; author-generated documentation, figures, tables, manifests, and frozen simulation outputs are under CC BY 4.0; derived calibration inputs remain subject to the source-specific boundaries in `LICENSE_SCOPE.md` and `DATA_SOURCES.md`.

## Release status

Version 1.0.0 was frozen for public release on 4 September 2026. The confirmed release creators are Wenjie Huang and Jiang Zhou. Repository and archive identifiers are recorded in this README and `CITATION.cff` after the corresponding public records are created. Any later change to authorship or release contents requires a new version rather than silent alteration of the archived files.

- GitHub repository: https://github.com/Corn6947/closed-loop-plan-governance-drone-delivery
- Version 1.0.0 release: https://github.com/Corn6947/closed-loop-plan-governance-drone-delivery/releases/tag/v1.0.0
- Zenodo archive: to be inserted after DOI reservation and publication
