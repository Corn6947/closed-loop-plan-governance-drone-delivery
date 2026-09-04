"""Validate the public-data public calibration pack without rewriting it."""

from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def row_count(path):
    with path.open(encoding="utf-8") as handle:
        return sum(1 for _ in csv.reader(handle)) - 1


def main():
    manifest = json.loads((ROOT / "source_manifest.json").read_text(encoding="utf-8"))
    hash_checks = []
    for source in manifest:
        path = ROOT / source["local_file"]
        hash_checks.append(
            {
                "id": source["id"],
                "exists": path.exists(),
                "sha256_matches_manifest": path.exists() and sha256(path) == source["sha256"],
            }
        )
    params = json.loads(
        (ROOT / "processed" / "public_calibration_parameters.json").read_text(encoding="utf-8")
    )
    weather_rows = row_count(ROOT / "processed" / "legacy_weather_pairs_fingerprint_only.csv")
    order_rows = row_count(ROOT / "processed" / "olist_order_events.csv")
    spatial_zone_rows = row_count(ROOT / "processed" / "olist_12_zone_geometry.csv")
    energy_rows = row_count(ROOT / "processed" / "matrice100_energy_summary.csv")
    geometry = params["demand"].get("spatial_geometry", {})
    checks = {
        "all_source_hashes_match": all(item["sha256_matches_manifest"] for item in hash_checks),
        "weather_pair_count_matches": weather_rows == params["weather"]["pair_count"],
        "order_count_matches": order_rows == params["demand"]["source_order_count"],
        "spatial_zone_count_matches": spatial_zone_rows == geometry.get("zone_count") == 12,
        "spatial_fit_is_calibration_only": geometry.get("zone_fit_split") == "calibration only; fixed before development and holdout evaluation",
        "spatial_coordinate_match_is_high": geometry.get("calibration_order_coordinate_match_rate", 0) >= 0.95,
        "spatial_holdout_is_nonempty": geometry.get("holdout_orders_with_coordinates", 0) > 0,
        "spatial_holdout_tvd_is_bounded": 0 <= geometry.get("zone_holdout_total_variation_distance", -1) <= 1,
        "flight_count_matches": energy_rows == params["energy"]["flight_count"],
        "weather_holdout_is_nonempty": params["weather"]["holdout_pairs"] > 0,
        "energy_holdout_is_nonempty": params["energy"]["holdout_flight_count"] > 0,
        "unidentified_parameters_are_disclosed": set(params["not_calibrated"]) == {
            "vip_share", "W3_and_Hs", "platform_movement", "target_aircraft_transfer"
        },
    }
    result = {
        "validation_status": "pass" if all(checks.values()) else "fail",
        "checks": checks,
        "source_hash_checks": hash_checks,
    }
    output = ROOT / "reports" / "校准包验证结果.json"
    output.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(result, indent=2, ensure_ascii=False))
    if result["validation_status"] != "pass":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
