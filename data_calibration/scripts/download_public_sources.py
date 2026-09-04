"""Download the frozen public inputs used by the public-data calibration pack.

The script deliberately downloads only the source files needed for the
calibration claims.  It writes a manifest with URLs, licences, hashes and
download timestamps so that the supplement can be audited and reproduced.
"""

from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "raw"

SOURCES = [
    {
        "id": "weather_actual_era5_open_meteo_2024",
        "file": "weather_actual_era5_open_meteo_2024.json",
        "url": (
            "https://archive-api.open-meteo.com/v1/archive?latitude=40.4406"
            "&longitude=-79.9959&start_date=2024-01-01&end_date=2024-12-31"
            "&hourly=wind_speed_10m,wind_direction_10m&wind_speed_unit=ms"
            "&timezone=UTC"
        ),
        "licence": "Open-Meteo non-commercial attribution licence; underlying ERA5/ERA5-Land attribution applies.",
        "purpose": "Hourly reanalysis proxy for realised 10 m wind at the Pittsburgh reference point.",
    },
    {
        "id": "weather_forecast_gfs_open_meteo_2024",
        "file": "weather_forecast_gfs_open_meteo_2024.json",
        "url": (
            "https://historical-forecast-api.open-meteo.com/v1/forecast?latitude=40.4406"
            "&longitude=-79.9959&start_date=2024-01-01&end_date=2024-12-31"
            "&hourly=wind_speed_10m,wind_direction_10m&wind_speed_unit=ms"
            "&timezone=UTC&models=gfs_seamless"
        ),
        "licence": "Open-Meteo non-commercial attribution licence; forecast provenance is NOAA NCEP GFS.",
        "purpose": "Archived near-term GFS forecast proxy, paired to the realised-wind proxy by valid hour.",
    },
    {
        "id": "cmu_package_delivery_flights_zip",
        "file": "cmu_package_delivery_flights.zip",
        "url": "https://ndownloader.figshare.com/files/26385070",
        "licence": "CC BY 4.0.",
        "purpose": "Public DJI Matrice 100 package-delivery telemetry for external energy-model validation.",
    },
    {
        "id": "cmu_package_delivery_parameters",
        "file": "cmu_package_delivery_parameters.csv",
        "url": "https://ndownloader.figshare.com/files/26385034",
        "licence": "CC BY 4.0.",
        "purpose": "Flight-level operating-condition metadata for the public telemetry set.",
    },
    {
        "id": "cmu_package_delivery_readme",
        "file": "cmu_package_delivery_README.txt",
        "url": "https://ndownloader.figshare.com/files/26405786",
        "licence": "CC BY 4.0.",
        "purpose": "Variable definitions and data-collection protocol for the public telemetry set.",
    },
    {
        "id": "amazon_last_mile_route_data",
        "file": "amazon_last_mile_route_data.json",
        "url": "https://amazon-last-mile-challenges.s3.amazonaws.com/almrrc2021/almrrc2021-data-training/model_build_inputs/route_data.json",
        "licence": "CC BY-NC 4.0.",
        "purpose": "Real last-mile route, stop and route-start structure used only as an operational-load proxy.",
    },
    {
        "id": "olist_orders",
        "file": "olist_orders_dataset.csv",
        "url": "https://raw.githubusercontent.com/spdrio/Brazilian-E-Commerce-Public-Dataset-by-Olist/master/files/olist_orders_dataset.csv",
        "licence": "Public Olist dataset terms; GitHub mirror is used only to retrieve the original public data.",
        "purpose": "Actual order-purchase timestamps for calibrating temporal demand intensity; not a drone-delivery outcome dataset.",
    },
    {
        "id": "olist_customers",
        "file": "olist_customers_dataset.csv",
        "url": "https://raw.githubusercontent.com/spdrio/Brazilian-E-Commerce-Public-Dataset-by-Olist/master/files/olist_customers_dataset.csv",
        "licence": "Public Olist dataset terms; GitHub mirror is used only to retrieve the original public data.",
        "purpose": "Customer zip-prefix labels for calibrating relative spatial demand concentration.",
    },
    {
        "id": "olist_geolocation",
        "file": "olist_geolocation_dataset.csv",
        "url": "https://huggingface.co/datasets/miminmoons/olist-ecommerce-for-delivery-and-review-prediction/resolve/main/data/olist_geolocation_dataset.csv?download=true",
        "licence": "MIT mirror of the public Olist dataset; used only to retrieve the original public geolocation table.",
        "purpose": "Public zip-prefix coordinate records used only after robust aggregation to calibrate abstract demand-zone geometry.",
    },
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def download(url: str, target: Path) -> None:
    request = Request(url, headers={"User-Agent": "Systems-V2-public-calibration/1.0"})
    with urlopen(request, timeout=180) as response, target.open("wb") as handle:
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            handle.write(chunk)


def main() -> None:
    RAW.mkdir(parents=True, exist_ok=True)
    manifest = []
    for source in SOURCES:
        target = RAW / source["file"]
        if not target.exists() or target.stat().st_size == 0:
            print(f"Downloading {source['id']} ...")
            download(source["url"], target)
        item = dict(source)
        item.update(
            {
                "local_file": str(target.relative_to(ROOT)).replace("\\", "/"),
                "bytes": target.stat().st_size,
                "sha256": sha256(target),
                "downloaded_utc": datetime.now(timezone.utc).isoformat(),
            }
        )
        manifest.append(item)
        print(f"Ready: {target.name} ({item['bytes']:,} bytes)")

    (ROOT / "source_manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
