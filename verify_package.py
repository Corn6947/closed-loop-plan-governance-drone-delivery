"""Static verification for the Systems submission reproducibility package."""
from __future__ import annotations

import csv
import hashlib
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
errors: list[str] = []
warnings: list[str] = []
EXCLUDE_DIRS = {".git", "__pycache__"}


def is_excluded(path: Path) -> bool:
    return any(part in EXCLUDE_DIRS for part in path.relative_to(ROOT).parts)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


manifest_path = ROOT / "PACKAGE_MANIFEST.json"
if not manifest_path.is_file():
    errors.append("PACKAGE_MANIFEST.json is missing")
else:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for item in manifest.get("files", []):
        path = ROOT / item["path"]
        if not path.is_file():
            errors.append(f"missing: {item['path']}")
        elif path.stat().st_size != item["bytes"]:
            errors.append(f"size mismatch: {item['path']}")
        elif sha256(path) != item["sha256"]:
            errors.append(f"hash mismatch: {item['path']}")

required = [
    "run_final_experiment_suite.m",
    "run_governance_evidence_suite.m",
    "run_verify_frozen_release.m",
    "run_postprocess_from_frozen.m",
    "results_frozen/primary_policy_comparison_60_scenarios.mat",
    "data_calibration/processed/sao_paulo_gfs_era5_forecast_pairs_20min.csv",
    "figures_tables/Figure7_Fleet_and_Input_Heterogeneity_Boundaries.png",
    "figures_tables/Table4_Fleet_Size_and_Input_Heterogeneity.docx",
    "figures_tables/ARTIFACT_MANIFEST.json",
]
for relative in required:
    if not (ROOT / relative).is_file():
        errors.append(f"required file missing: {relative}")

for relative, expected_rows in [
    ("data_calibration/processed/sao_paulo_gfs_era5_forecast_pairs_20min.csv", 19035),
    ("data_calibration/processed/sao_paulo_order_weather_20min.csv", 19035),
    ("data_calibration/processed/sao_paulo_joint_episode_catalog.csv", 705),
]:
    path = ROOT / relative
    if not path.is_file():
        continue
    with path.open("r", newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames and "order_ids" in reader.fieldnames:
            errors.append(f"pseudonymous identifier column remains: {relative}")
        count = sum(1 for _ in reader)
    if count != expected_rows:
        errors.append(f"unexpected row count {count} != {expected_rows}: {relative}")

artifact_manifest_path = ROOT / "figures_tables" / "ARTIFACT_MANIFEST.json"
if artifact_manifest_path.is_file():
    artifact_manifest = json.loads(artifact_manifest_path.read_text(encoding="utf-8"))
    for item in artifact_manifest.get("Artifacts", []):
        path = ROOT / item["Path"]
        if not path.is_file():
            errors.append(f"artifact manifest target missing: {item['Path']}")
        elif path.stat().st_size != item["Bytes"]:
            errors.append(f"artifact size mismatch: {item['Path']}")
        elif sha256(path) != item["SHA256"]:
            errors.append(f"artifact hash mismatch: {item['Path']}")

legacy_name_pattern = re.compile(r"(?i)(^|[_-])(q2|v2|v3|spgfs)([_-]|$)")
for path in ROOT.rglob("*"):
    if not path.is_file() or is_excluded(path):
        continue
    relative = path.relative_to(ROOT).as_posix()
    if relative.startswith("provenance/"):
        continue
    if legacy_name_pattern.search(path.name):
        errors.append(f"legacy internal label remains in public filename: {relative}")

matlab_function_pattern = re.compile(
    r"^\s*function(?:\s+\[[^\]]+\]|\s+\w+)\s*=\s*(\w+)\s*\(|^\s*function\s+(\w+)\s*\("
)
for path in ROOT.rglob("*.m"):
    if is_excluded(path):
        continue
    first_line = path.read_text(encoding="utf-8-sig").splitlines()[0]
    match = matlab_function_pattern.search(first_line)
    if match:
        declared = match.group(1) or match.group(2)
        if declared != path.stem:
            errors.append(
                f"MATLAB function/filename mismatch: {path.relative_to(ROOT).as_posix()} declares {declared}"
            )

if any(path.is_dir() and path.name.lower() == "raw" for path in ROOT.rglob("*")):
    errors.append("a raw-data directory is present")

credential_pattern = re.compile(
    r"(?i)(api[_-]?key|access[_-]?token|secret[_-]?key|password)\s*[:=]\s*['\"][^'\"]+"
)
for path in ROOT.rglob("*"):
    if not path.is_file() or is_excluded(path) or path.suffix.lower() not in {".m", ".py", ".md", ".json", ".txt", ".csv"}:
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    if credential_pattern.search(text):
        errors.append(f"possible credential assignment: {path.relative_to(ROOT).as_posix()}")

pre_redaction = ROOT / "provenance" / "Figure_Table_Artifact_Manifest_pre_public_redaction.json"
if pre_redaction.is_file():
    warnings.append("pre-redaction manifest is provenance-only; use the public artifact/package manifests")

if errors:
    print("PACKAGE VERIFICATION: FAIL")
    for item in errors:
        print(f"ERROR: {item}")
    sys.exit(1)

print("PACKAGE VERIFICATION: PASS")
for item in warnings:
    print(f"WARNING: {item}")
