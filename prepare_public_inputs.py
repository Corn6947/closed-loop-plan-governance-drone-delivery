"""Remove raw pseudonymous order identifiers from public derived inputs."""
from __future__ import annotations

import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parent
PROCESSED = ROOT / "data_calibration" / "processed"
FILES = [
    PROCESSED / "sao_paulo_gfs_era5_forecast_pairs_20min.csv",
    PROCESSED / "sao_paulo_order_weather_20min.csv",
]


def remove_identifier(path: Path) -> None:
    with path.open("r", newline="", encoding="utf-8-sig") as source:
        reader = csv.DictReader(source)
        if reader.fieldnames is None or "order_ids" not in reader.fieldnames:
            return
        fields = [field for field in reader.fieldnames if field != "order_ids"]
        rows = list(reader)
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", newline="", encoding="utf-8") as target:
        writer = csv.DictWriter(target, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    temporary.replace(path)


for file_path in FILES:
    remove_identifier(file_path)
print("Public-input identifier check completed.")
