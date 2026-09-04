# License Scope

This repository uses a layered licensing scheme because it combines
author-written software, author-generated research materials, and derived
inputs whose upstream terms remain controlling.

## Author-written software

The author-written MATLAB and Python source files in this repository are
licensed under the MIT License in `LICENSE`.

## Author-generated materials

Unless a file states otherwise, the authors license their original
documentation, figures, tables, manifests, frozen simulation outputs, and
other author-generated research materials under the Creative Commons
Attribution 4.0 International license (CC BY 4.0):
https://creativecommons.org/licenses/by/4.0/

When reusing these materials, cite this repository or its archived release and
identify any changes.

## Derived calibration inputs and third-party sources

No blanket repository license is granted over third-party source data or over
rights retained by upstream providers. The files under
`data_calibration/processed/` are released only as derived research inputs for
audit and reproduction, subject to the source-specific terms and attribution
requirements recorded in `DATA_SOURCES.md`,
`data_calibration/PUBLIC_SOURCE_MANIFEST.json`, and the cited source records.

Raw Olist, GFS, ERA5, and DJI Matrice 100 files are not redistributed. Users
who need raw data must reacquire them from the listed public sources and comply
with the providers' current terms. The broader
`data_calibration/source_manifest.json` contains legacy acquisition records
that are not inputs to the final experiment; retaining those records does not
extend any license to the referenced raw files.

## External software

MATLAB, YALMIP, Gurobi, and other third-party dependencies are not included and
remain governed by their own licenses.
