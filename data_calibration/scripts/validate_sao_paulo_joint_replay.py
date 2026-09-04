"""Validate the Sao Paulo same-city order/weather replay package."""

from __future__ import annotations

import csv
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
STEP_FILE = ROOT / "processed" / "sao_paulo_order_weather_20min.csv"
CATALOG_FILE = ROOT / "processed" / "sao_paulo_joint_episode_catalog.csv"
SOURCE_MANIFEST = ROOT / "joint_replay_source_manifest.json"
OUT_FILE = ROOT / "reports" / "sao_paulo_joint_replay_integrity.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> None:
    required = [STEP_FILE, CATALOG_FILE, SOURCE_MANIFEST]
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise FileNotFoundError(f"Missing package files: {missing}")

    by_episode: dict[str, list[dict[str, str]]] = defaultdict(list)
    split_rows = Counter()
    with STEP_FILE.open("r", encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            by_episode[row["episode_date"]].append(row)
            split_rows[row["split"]] += 1

    with CATALOG_FILE.open("r", encoding="utf-8", newline="") as handle:
        catalog = {row["episode_date"]: row for row in csv.DictReader(handle)}

    errors: list[str] = []
    for episode_date, rows in by_episode.items():
        rows.sort(key=lambda row: int(row["step"]))
        steps = [int(row["step"]) for row in rows]
        if steps != list(range(1, 28)):
            errors.append(f"{episode_date}: expected steps 1..27")
        if episode_date not in catalog:
            errors.append(f"{episode_date}: absent from catalogue")
            continue
        observed = sum(int(row["observed_purchase_count"]) for row in rows)
        expected = int(catalog[episode_date]["observed_purchase_count"])
        if observed != expected:
            errors.append(f"{episode_date}: order total {observed} != {expected}")
        shares = sum(float(row["within_episode_arrival_share"]) for row in rows)
        target = 1.0 if expected > 0 else 0.0
        # Shares are exported to eight decimal places, so accumulated CSV
        # rounding can reach several 1e-8 over 27 steps.
        if abs(shares - target) > 1e-6:
            errors.append(f"{episode_date}: arrival shares sum to {shares}")
        for row in rows:
            if not row["actual_wind_mps"] or not row["actual_wind_direction_deg"]:
                errors.append(f"{episode_date} step {row['step']}: missing weather")

    if set(catalog) != set(by_episode):
        errors.append("Episode keys differ between step file and catalogue")

    manifest = json.loads(SOURCE_MANIFEST.read_text(encoding="utf-8"))
    model_is_explicit = "models=era5" in manifest["url"]
    if not model_is_explicit:
        errors.append("Source URL does not explicitly request ERA5")

    report = {
        "status": "pass" if not errors else "fail",
        "checks": {
            "episode_count": len(by_episode),
            "rows": sum(split_rows.values()),
            "rows_by_split": dict(split_rows),
            "steps_per_episode": 27,
            "all_episode_steps_complete": not any("expected steps" in e for e in errors),
            "catalog_totals_match": not any("order total" in e for e in errors),
            "arrival_shares_valid": not any("arrival shares" in e for e in errors),
            "weather_complete": not any("missing weather" in e for e in errors),
            "explicit_era5_model_request": model_is_explicit,
        },
        "sha256": {
            "step_file": sha256(STEP_FILE),
            "catalog_file": sha256(CATALOG_FILE),
            "source_manifest": sha256(SOURCE_MANIFEST),
        },
        "errors": errors,
    }
    OUT_FILE.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    if errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
