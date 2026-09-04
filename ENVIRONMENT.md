# Computational Environment

The frozen release records:

- MATLAB 24.2 / R2024b
- YALMIP 20230622
- Gurobi 10.0.1
- Windows 10 build 22631.6199
- Gurobi threads: 1
- Gurobi random seed: 20260728
- Per-MILP time limit: 0.5 seconds in the final suite
- MIP gap: 0.005
- Python 3.10 or later for package checks and table generation
- `python-docx>=1.1,<2` for Word table generation

The optimization stack is not redistributed. Install MATLAB, YALMIP, and Gurobi separately and configure a valid local Gurobi license. Do not add license files or entitlement keys to this package.

The order-level GLMM exporter uses `fitglme`, which requires MATLAB's Statistics and Machine Learning Toolbox. Frozen CSV outputs are supplied for users who do not have that toolbox.
