"""Build reproducible public-data calibration artifacts from the downloaded data.

This is intentionally conservative: it calibrates only observed quantities.
It never turns public proxies into claims about a particular company, aircraft,
or organisational plan-change cost.
"""

from __future__ import annotations

import csv
import json
import math
import statistics
import zipfile
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "raw"
PROCESSED = ROOT / "processed"
REPORTS = ROOT / "reports"
MATLAB = ROOT / "matlab"


def mean(values):
    return sum(values) / len(values) if values else float("nan")


def percentile(values, pct):
    if not values:
        return float("nan")
    data = sorted(values)
    position = (len(data) - 1) * pct / 100.0
    lower, upper = math.floor(position), math.ceil(position)
    if lower == upper:
        return data[lower]
    return data[lower] + (data[upper] - data[lower]) * (position - lower)


def stdev(values):
    return statistics.stdev(values) if len(values) >= 2 else float("nan")


def weighted_mean(values, weights):
    total_weight = sum(weights)
    return sum(value * weight for value, weight in zip(values, weights)) / total_weight if total_weight else float("nan")


def haversine_km(lat1, lon1, lat2, lon2):
    radius_km = 6371.0088
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi, dlambda = math.radians(lat2 - lat1), math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * radius_km * math.asin(math.sqrt(a))


def project_km(lat, lon, reference_lat, reference_lon):
    """Local equirectangular projection for a city-scale abstract zone map."""
    y = (lat - reference_lat) * 110.574
    x = (lon - reference_lon) * 111.320 * math.cos(math.radians(reference_lat))
    return x, y


def nearest_centroid(point, centroids):
    return min(range(len(centroids)), key=lambda index: (point[0] - centroids[index][0]) ** 2 + (point[1] - centroids[index][1]) ** 2)


def deterministic_weighted_kmeans(points, weights, k, seed=20260802, max_iter=200):
    """Dependency-free weighted k-means with a deterministic farthest-point seed."""
    if len(points) < k:
        raise RuntimeError(f"Need at least {k} spatial points, found {len(points)}")
    first = max(range(len(points)), key=lambda index: (weights[index], -index))
    selected = [first]
    while len(selected) < k:
        candidate = max(
            (index for index in range(len(points)) if index not in selected),
            key=lambda index: (
                min((points[index][0] - points[j][0]) ** 2 + (points[index][1] - points[j][1]) ** 2 for j in selected),
                weights[index],
                -index,
            ),
        )
        selected.append(candidate)
    centroids = [points[index] for index in selected]
    assignments = None
    for _ in range(max_iter):
        updated_assignments = [nearest_centroid(point, centroids) for point in points]
        new_centroids = []
        for cluster in range(k):
            members = [index for index, assigned in enumerate(updated_assignments) if assigned == cluster]
            if not members:
                # The farthest point from its assigned centroid repairs an empty cluster deterministically.
                candidate = max(
                    range(len(points)),
                    key=lambda index: (points[index][0] - centroids[updated_assignments[index]][0]) ** 2
                    + (points[index][1] - centroids[updated_assignments[index]][1]) ** 2,
                )
                new_centroids.append(points[candidate])
                continue
            cluster_weights = [weights[index] for index in members]
            new_centroids.append(
                (
                    weighted_mean([points[index][0] for index in members], cluster_weights),
                    weighted_mean([points[index][1] for index in members], cluster_weights),
                )
            )
        if assignments == updated_assignments:
            break
        assignments, centroids = updated_assignments, new_centroids
    return centroids, assignments


def safe_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return float("nan")


def write_csv(path, fields, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def xy(speed, direction_degrees):
    # Both sources use the same direction convention.  We need a consistent
    # vector representation for error magnitudes; the sign convention cancels.
    angle = math.radians(direction_degrees)
    return speed * math.sin(angle), speed * math.cos(angle)


def assign_weather_split(timestamp):
    if timestamp < "2024-09-01":
        return "calibration"
    if timestamp < "2024-11-01":
        return "development"
    return "holdout"


def calibrate_weather():
    actual = json.loads((RAW / "weather_actual_era5_open_meteo_2024.json").read_text(encoding="utf-8"))
    forecast = json.loads((RAW / "weather_forecast_gfs_open_meteo_2024.json").read_text(encoding="utf-8"))
    actual_h, forecast_h = actual["hourly"], forecast["hourly"]
    lookup = {
        time: (speed, direction)
        for time, speed, direction in zip(
            actual_h["time"], actual_h["wind_speed_10m"], actual_h["wind_direction_10m"]
        )
    }
    rows = []
    for time, fcst_speed, fcst_direction in zip(
        forecast_h["time"], forecast_h["wind_speed_10m"], forecast_h["wind_direction_10m"]
    ):
        if time not in lookup:
            continue
        actual_speed, actual_direction = lookup[time]
        fu, fv = xy(fcst_speed, fcst_direction)
        au, av = xy(actual_speed, actual_direction)
        rows.append(
            {
                "valid_time_utc": time,
                "split": assign_weather_split(time),
                "forecast_wind_mps": round(fcst_speed, 5),
                "forecast_direction_deg": round(fcst_direction, 5),
                "actual_wind_mps": round(actual_speed, 5),
                "actual_direction_deg": round(actual_direction, 5),
                "speed_error_mps": round(actual_speed - fcst_speed, 5),
                "u_error_mps": round(au - fu, 5),
                "v_error_mps": round(av - fv, 5),
                "vector_error_mps": round(math.hypot(au - fu, av - fv), 5),
            }
        )
    if len(rows) < 8000:
        raise RuntimeError(f"Expected a full year of hourly wind pairs, got {len(rows)}")
    write_csv(PROCESSED / "legacy_weather_pairs_fingerprint_only.csv", list(rows[0]), rows)

    train = [r for r in rows if r["split"] == "calibration"]
    holdout = [r for r in rows if r["split"] == "holdout"]
    train_bias = mean([r["speed_error_mps"] for r in train])
    residuals = [r["speed_error_mps"] - train_bias for r in train]
    holdout_residuals = [r["speed_error_mps"] - train_bias for r in holdout]
    holdout_vector = [r["vector_error_mps"] for r in holdout]
    autocorr_num = sum(
        residuals[i] * residuals[i - 1] for i in range(1, len(residuals))
    )
    autocorr_den = sum(value * value for value in residuals)
    return {
        "reference_location": "Pittsburgh reference point (40.4406, -79.9959); 10 m wind only",
        "forecast_source": "Open-Meteo historical GFS seamless archive",
        "actual_source": "Open-Meteo historical archive (ERA5/ERA5-Land proxy)",
        "forecast_lead_time_contract": "The seamless archive does not identify a fixed issue time or lead time; it is a near-term forecast proxy only, not a lead-specific 20/40/60-minute skill calibration.",
        "pair_count": len(rows),
        "calibration_pairs": len(train),
        "development_pairs": len([r for r in rows if r["split"] == "development"]),
        "holdout_pairs": len(holdout),
        "mean_speed_bias_mps": train_bias,
        "legacy_error_sigma_mps": stdev(residuals),
        "speed_error_p05_mps": percentile(residuals, 5),
        "speed_error_p50_mps": percentile(residuals, 50),
        "speed_error_p95_mps": percentile(residuals, 95),
        "vector_error_p95_mps": percentile([r["vector_error_mps"] for r in train], 95),
        "lag1_speed_residual_autocorrelation": autocorr_num / autocorr_den if autocorr_den else float("nan"),
        "recommended_resampling": "sample contiguous hourly forecast-error blocks; interpolate or hold at the 20-minute decision step",
        "recommended_block_hours": 3,
        "holdout_speed_mae_mps": mean([abs(value) for value in holdout_residuals]),
        "holdout_speed_rmse_mps": math.sqrt(mean([value * value for value in holdout_residuals])),
        "holdout_vector_error_p95_mps": percentile(holdout_vector, 95),
    }


def route_stop_count(route):
    stops = route.get("stops", {})
    return sum(1 for stop in stops.values() if str(stop.get("type", "")).lower() != "station")


def calibrate_amazon_load():
    route_data = json.loads((RAW / "amazon_last_mile_route_data.json").read_text(encoding="utf-8"))
    rows = []
    for route_id, route in route_data.items():
        stops = route_stop_count(route)
        departure = route.get("departure_time_utc", "")
        date = route.get("date_YYYY_MM_DD", "")
        try:
            departure_hour = int(str(departure).split(":")[0])
        except (ValueError, IndexError):
            departure_hour = ""
        rows.append(
            {
                "route_id": route_id,
                "route_date": date,
                "departure_time_utc": departure,
                "departure_hour_utc": departure_hour,
                "station_code": route.get("station_code", ""),
                "route_score": route.get("route_score", ""),
                "customer_stop_count": stops,
            }
        )
    write_csv(PROCESSED / "amazon_route_load_summary.csv", list(rows[0]), rows)
    stop_counts = [row["customer_stop_count"] for row in rows]
    return {
        "route_count": len(rows),
        "mean_customer_stops_per_route": mean(stop_counts),
        "median_customer_stops_per_route": percentile(stop_counts, 50),
        "p10_customer_stops_per_route": percentile(stop_counts, 10),
        "p90_customer_stops_per_route": percentile(stop_counts, 90),
        "use_in_v2": "operational-load and stop-count proxy only; never a dynamic-arrival or exact-geometry calibration source",
    }


def chronological_order_split(timestamps):
    unique_dates = sorted({timestamp[:10] for timestamp in timestamps if timestamp})
    n = len(unique_dates)
    first = unique_dates[max(0, math.ceil(n * 0.70) - 1)]
    second = unique_dates[max(0, math.ceil(n * 0.85) - 1)]
    return first, second


def calibrate_demand():
    customers = {}
    with (RAW / "olist_customers_dataset.csv").open(encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            customers[row["customer_id"]] = {
                "zip_prefix": row["customer_zip_code_prefix"],
                "city": row["customer_city"],
            }

    # Olist deliberately exposes coordinates at postal-code-prefix level and
    # can contain many points per prefix.  A component-wise median prevents
    # repeated source rows from acting as individual customers or addresses.
    geo_values = defaultdict(list)
    with (RAW / "olist_geolocation_dataset.csv").open(encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            zip_prefix = row.get("geolocation_zip_code_prefix", "")
            latitude = safe_float(row.get("geolocation_lat"))
            longitude = safe_float(row.get("geolocation_lng"))
            if zip_prefix and math.isfinite(latitude) and math.isfinite(longitude):
                geo_values[zip_prefix].append((latitude, longitude))
    geo_by_zip = {
        zip_prefix: (percentile([item[0] for item in values], 50), percentile([item[1] for item in values], 50))
        for zip_prefix, values in geo_values.items()
    }

    orders = []
    with (RAW / "olist_orders_dataset.csv").open(encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            timestamp = row.get("order_purchase_timestamp", "")
            customer = customers.get(row["customer_id"])
            # A single city is essential for a meaningful hotspot distribution.
            # It remains a demand proxy only; Pittsburgh weather and CMU flights
            # are deliberately reported as separate public sources.
            if not timestamp or not customer or customer["city"] != "sao paulo":
                continue
            orders.append(
                {
                    "order_id": row["order_id"],
                    "purchase_timestamp": timestamp,
                    "customer_zip_prefix": customer["zip_prefix"],
                    "status": row.get("order_status", ""),
                }
            )
    cut_calibration, cut_development = chronological_order_split(
        [row["purchase_timestamp"] for row in orders]
    )
    for row in orders:
        date = row["purchase_timestamp"][:10]
        if date <= cut_calibration:
            row["split"] = "calibration"
        elif date <= cut_development:
            row["split"] = "development"
        else:
            row["split"] = "holdout"
        parsed = datetime.strptime(row["purchase_timestamp"], "%Y-%m-%d %H:%M:%S")
        row["hour_of_day"] = parsed.hour
        row["weekday"] = parsed.weekday()
    write_csv(PROCESSED / "olist_order_events.csv", list(orders[0]), orders)

    train = [row for row in orders if row["split"] == "calibration"]
    holdout = [row for row in orders if row["split"] == "holdout"]
    hour_counts = Counter(row["hour_of_day"] for row in train)
    total_train = len(train)
    profile_rows = []
    for hour in range(24):
        count = hour_counts[hour]
        profile_rows.append(
            {
                "hour_of_day": hour,
                "calibration_order_count": count,
                "calibration_share": count / total_train,
                "relative_intensity_to_hourly_mean": count / (total_train / 24),
            }
        )
    write_csv(PROCESSED / "olist_hourly_demand_profile.csv", list(profile_rows[0]), profile_rows)

    train_zips = Counter(row["customer_zip_prefix"] for row in train if row["customer_zip_prefix"])
    holdout_zips = Counter(row["customer_zip_prefix"] for row in holdout if row["customer_zip_prefix"])
    zone_rows = []
    for rank, (zone, count) in enumerate(train_zips.most_common(50), start=1):
        zone_rows.append(
            {
                "rank": rank,
                "zip_prefix_proxy_zone": zone,
                "calibration_orders": count,
                "calibration_share": count / total_train,
                "holdout_orders": holdout_zips[zone],
                "holdout_share": holdout_zips[zone] / len(holdout) if holdout else float("nan"),
            }
        )
    write_csv(PROCESSED / "olist_spatial_hotspot_profile.csv", list(zone_rows[0]), zone_rows)
    train_distribution = [hour_counts[hour] / total_train for hour in range(24)]
    holdout_counts = Counter(row["hour_of_day"] for row in holdout)
    holdout_distribution = [holdout_counts[hour] / len(holdout) for hour in range(24)]
    tv_distance = 0.5 * sum(abs(a - b) for a, b in zip(train_distribution, holdout_distribution))
    top12_share = sum(count for _, count in train_zips.most_common(12)) / total_train

    # Geometry is fitted only on the calibration partition.  The resulting
    # twelve zones are abstract customer-demand zones, not reconstructed
    # addresses, warehouses, roads, aerial corridors, or flight paths.
    train_zip_counts = Counter(row["customer_zip_prefix"] for row in train)
    holdout_zip_counts = Counter(row["customer_zip_prefix"] for row in holdout)
    spatial_rows = []
    for zip_prefix, count in sorted(train_zip_counts.items()):
        if zip_prefix not in geo_by_zip:
            continue
        latitude, longitude = geo_by_zip[zip_prefix]
        spatial_rows.append(
            {
                "zip_prefix": zip_prefix,
                "latitude": latitude,
                "longitude": longitude,
                "calibration_orders": count,
                "holdout_orders": holdout_zip_counts[zip_prefix],
            }
        )
    if len(spatial_rows) < 12:
        raise RuntimeError("Too few geographically matched Olist prefixes for 12-zone calibration")
    matched_calibration_orders = sum(row["calibration_orders"] for row in spatial_rows)
    reference_lat = weighted_mean(
        [row["latitude"] for row in spatial_rows], [row["calibration_orders"] for row in spatial_rows]
    )
    reference_lon = weighted_mean(
        [row["longitude"] for row in spatial_rows], [row["calibration_orders"] for row in spatial_rows]
    )
    points = [project_km(row["latitude"], row["longitude"], reference_lat, reference_lon) for row in spatial_rows]
    weights = [row["calibration_orders"] for row in spatial_rows]
    centroids, assignments = deterministic_weighted_kmeans(points, weights, 12)
    for row, point, zone in zip(spatial_rows, points, assignments):
        row["x_km_from_demand_center"] = point[0]
        row["y_km_from_demand_center"] = point[1]
        row["zone_index"] = zone

    cluster_rows = []
    total_holdout_matched = sum(
        row["holdout_orders"] for row in spatial_rows
    )
    for zone in range(12):
        members = [row for row in spatial_rows if row["zone_index"] == zone]
        zone_weight = sum(row["calibration_orders"] for row in members)
        holdout_weight = sum(row["holdout_orders"] for row in members)
        if zone_weight == 0:
            raise RuntimeError(f"Empty spatial zone {zone + 1}")
        x_km, y_km = centroids[zone]
        zone_lat = reference_lat + y_km / 110.574
        zone_lon = reference_lon + x_km / (111.320 * math.cos(math.radians(reference_lat)))
        cluster_rows.append(
            {
                "zone_id": f"Z{zone + 1:02d}",
                "calibration_zip_prefix_count": len(members),
                "calibration_order_count": zone_weight,
                "calibration_probability": zone_weight / matched_calibration_orders,
                "holdout_order_count": holdout_weight,
                "holdout_probability": holdout_weight / total_holdout_matched if total_holdout_matched else float("nan"),
                "center_latitude": zone_lat,
                "center_longitude": zone_lon,
                "x_km_from_demand_center": x_km,
                "y_km_from_demand_center": y_km,
                "center_distance_from_demand_center_km": math.hypot(x_km, y_km),
            }
        )
    cluster_rows.sort(key=lambda row: row["zone_id"])
    write_csv(PROCESSED / "olist_12_zone_geometry.csv", list(cluster_rows[0]), cluster_rows)
    zip_audit_rows = []
    for row in sorted(spatial_rows, key=lambda item: item["zip_prefix"]):
        zone = cluster_rows[row["zone_index"]]
        zip_audit_rows.append(
            {
                "zip_prefix": row["zip_prefix"],
                "calibration_order_count": row["calibration_orders"],
                "holdout_order_count": row["holdout_orders"],
                "zone_id": zone["zone_id"],
                "x_km_from_demand_center": row["x_km_from_demand_center"],
                "y_km_from_demand_center": row["y_km_from_demand_center"],
            }
        )
    write_csv(PROCESSED / "olist_zip_prefix_zone_audit.csv", list(zip_audit_rows[0]), zip_audit_rows)
    distances = [math.hypot(row["x_km_from_demand_center"], row["y_km_from_demand_center"]) for row in spatial_rows]
    weighted_distance_values = [
        distance for distance, weight in zip(distances, weights) for _ in range(weight)
    ]
    holdout_zone_tvd = 0.5 * sum(
        abs(row["calibration_probability"] - row["holdout_probability"])
        for row in cluster_rows
    )
    return {
        "reference_demand_area": "Sao Paulo city subset of the Olist public dataset",
        "arrival_time_contract": "Purchase timestamps are demand-timing proxies, not observed release times to a last-mile drone operation.",
        "source_order_count": len(orders),
        "calibration_order_count": len(train),
        "development_order_count": len([row for row in orders if row["split"] == "development"]),
        "holdout_order_count": len(holdout),
        "calibration_end_date": cut_calibration,
        "development_end_date": cut_development,
        "holdout_hour_profile_total_variation_distance": tv_distance,
        "top_12_zip_prefix_share": top12_share,
        "spatial_geometry": {
            "reference_geometry": "Demand-weighted geographic centre of matched Sao Paulo Olist postal-code-prefix records; it is a coordinate normalisation reference, not a warehouse or platform location.",
            "postal_prefix_records_with_coordinates": len(spatial_rows),
            "calibration_orders_with_coordinates": matched_calibration_orders,
            "calibration_order_coordinate_match_rate": matched_calibration_orders / len(train),
            "holdout_orders_with_coordinates": total_holdout_matched,
            "holdout_order_coordinate_match_rate": total_holdout_matched / len(holdout) if holdout else float("nan"),
            "zone_count": 12,
            "zone_fit_split": "calibration only; fixed before development and holdout evaluation",
            "zone_holdout_total_variation_distance": holdout_zone_tvd,
            "customer_distance_from_demand_center_p10_km": percentile(weighted_distance_values, 10),
            "customer_distance_from_demand_center_p50_km": percentile(weighted_distance_values, 50),
            "customer_distance_from_demand_center_p90_km": percentile(weighted_distance_values, 90),
            "use_in_v2": "Replace random scen.Coord with the 12 fixed abstract zone centres in olist_12_zone_geometry.csv. Sample arrivals across these zones using calibration_probability. The scenario's platform start location, road motion and aerial route remain engineering assumptions.",
        },
        "use_in_v2": "hour-of-day arrival shape plus a twelve-zone relative spatial distribution within the reference demand area; absolute demand scale and VIP labels remain scenario parameters",
    }


def find_field(row, candidates):
    lower = {key.lower(): key for key in row}
    for candidate in candidates:
        if candidate in lower:
            return lower[candidate]
    return None


def calibrate_energy():
    parameters = {}
    with (RAW / "cmu_package_delivery_parameters.csv").open(encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            parameters[str(row["flight"])] = row

    summaries = []
    with zipfile.ZipFile(RAW / "cmu_package_delivery_flights.zip") as archive:
        for entry in sorted(
            (item for item in archive.infolist() if item.filename.endswith(".csv")),
            key=lambda item: int(Path(item.filename).stem),
        ):
            flight_id = Path(entry.filename).stem
            rows = list(csv.DictReader(line.decode("utf-8") for line in archive.open(entry)))
            if len(rows) < 2:
                continue
            times = [safe_float(row.get("time")) for row in rows]
            voltages = [safe_float(row.get("battery_voltage")) for row in rows]
            currents = [safe_float(row.get("battery_current")) for row in rows]
            winds = [safe_float(row.get("wind_speed")) for row in rows]
            powers = [abs(voltage * current) for voltage, current in zip(voltages, currents)]
            energy_wh = 0.0
            for index in range(1, len(rows)):
                dt = times[index] - times[index - 1]
                if not math.isfinite(dt) or dt <= 0 or dt > 5:
                    continue
                p0 = abs(voltages[index - 1] * currents[index - 1])
                p1 = abs(voltages[index] * currents[index])
                if math.isfinite(p0) and math.isfinite(p1):
                    energy_wh += (p0 + p1) * 0.5 * dt / 3600.0
            duration = max(times) - min(times)
            if not math.isfinite(duration) or duration <= 0:
                continue
            param = parameters.get(flight_id, {})
            central_start = math.floor(len(powers) * 0.20)
            central_end = math.ceil(len(powers) * 0.80)
            central_powers = [
                value for value in powers[central_start:central_end] if math.isfinite(value)
            ]
            summaries.append(
                {
                    "flight": int(flight_id),
                    "date": param.get("date", ""),
                    "route": param.get("route", ""),
                    "commanded_speed_mps": safe_float(param.get("speed")),
                    "payload_g": safe_float(param.get("payload")),
                    "cruise_altitude_m": safe_float(param.get("altitude")),
                    "duration_s": duration,
                    "energy_wh_abs_vi": energy_wh,
                    "mean_power_w_abs_vi": energy_wh * 3600.0 / duration,
                    "central_segment_power_w": mean(central_powers),
                    "mean_wind_mps": mean([value for value in winds if math.isfinite(value)]),
                    "p95_wind_mps": percentile([value for value in winds if math.isfinite(value)], 95),
                }
            )
    summaries.sort(key=lambda row: (row["date"], row["flight"]))
    write_csv(PROCESSED / "matrice100_energy_summary.csv", list(summaries[0]), summaries)
    unique_dates = sorted({row["date"] for row in summaries if row["date"]})
    holdout_dates = set(unique_dates[max(1, math.floor(len(unique_dates) * 0.80)):])
    train = [row for row in summaries if row["date"] not in holdout_dates]
    holdout = [row for row in summaries if row["date"] in holdout_dates]
    train_power = [row["mean_power_w_abs_vi"] for row in train]
    central_train_power = [row["central_segment_power_w"] for row in train]
    constant_mission_power = percentile(train_power, 50)
    constant_cruise_candidate = percentile(central_train_power, 50)
    energy_errors = [
        constant_mission_power * row["duration_s"] / 3600.0 - row["energy_wh_abs_vi"] for row in holdout
    ]
    relative_errors = [
        abs(error) / row["energy_wh_abs_vi"]
        for error, row in zip(energy_errors, holdout)
        if row["energy_wh_abs_vi"] > 0
    ]
    return {
        "aircraft": "DJI Matrice 100; public package-delivery telemetry; non-identical-aircraft external validation",
        "flight_count": len(summaries),
        "calibration_flight_count": len(train),
        "holdout_flight_count": len(holdout),
        "constant_mission_power_median_w": constant_mission_power,
        "central_segment_cruise_power_candidate_w": constant_cruise_candidate,
        "power_p10_w": percentile(train_power, 10),
        "power_p90_w": percentile(train_power, 90),
        "holdout_energy_mae_wh": mean([abs(error) for error in energy_errors]),
        "holdout_energy_rmse_wh": math.sqrt(mean([error * error for error in energy_errors])),
        "holdout_energy_mape": mean(relative_errors),
        "use_in_v2": "Use the full-mission power only as an external energy envelope. The central-segment power is a cruise-power candidate only after V2 adds explicit launch/recovery energy; retain aircraft-transfer uncertainty in all comparisons.",
    }


def round_floats(value):
    if isinstance(value, float):
        return round(value, 6) if math.isfinite(value) else None
    if isinstance(value, dict):
        return {key: round_floats(item) for key, item in value.items()}
    if isinstance(value, list):
        return [round_floats(item) for item in value]
    return value


def write_matlab_override(calibration):
    weather = calibration["weather"]
    energy = calibration["energy"]
    text = f"""function cfg = public_calibration_override(cfg)
%PUBLIC_CALIBRATION_OVERRIDE Public-data calibration suggestion.
% Generated by scripts/build_public_calibration.py. This is NOT a claim of
% target-aircraft field validation. Run it only in a new V2 release.

    % Do not set BaseCruisePowerW here. The public data identify full-mission
    % and central-segment power separately, while the frozen V1 physics has
    % no launch/recovery energy term. A V2 flight-physics update is required.
    cfg.ErrorSigma = {weather['legacy_error_sigma_mps']:.6f};
    cfg.PublicCalibration.WindBiasMps = {weather['mean_speed_bias_mps']:.6f};
    cfg.PublicCalibration.WindErrorBlockHours = {weather['recommended_block_hours']};
    cfg.PublicCalibration.EnergyTransferP10W = {energy['power_p10_w']:.6f};
    cfg.PublicCalibration.EnergyTransferP90W = {energy['power_p90_w']:.6f};
    cfg.PublicCalibration.FullMissionPowerEnvelopeMedianW = {energy['constant_mission_power_median_w']:.6f};
    cfg.PublicCalibration.CruisePowerCandidateW = {energy['central_segment_cruise_power_candidate_w']:.6f};
    cfg.PublicCalibration.Note = ['Use empirical wind-error block resampling ', ...
        'from processed/legacy_weather_pairs_fingerprint_only.csv rather than Gaussian ', ...
        'noise in the final V2 scenario generator.'];
end
"""
    (MATLAB / "public_calibration_override.m").write_text(text, encoding="utf-8")


def write_matlab_spatial_loader(calibration):
    geometry = calibration["demand"]["spatial_geometry"]
    text = f"""function spatial = load_public_spatial_zones()
%LOAD_PUBLIC_SPATIAL_ZONES Load the fixed abstract public demand zones.
% Generated by scripts/build_public_calibration.py. The 12 centres were fit
% on Olist calibration data only. They are not customer addresses, a depot,
% truck positions, roads or authorised aerial corridors.

    here = fileparts(mfilename('fullpath'));
    sourceFile = fullfile(here, '..', 'processed', 'olist_12_zone_geometry.csv');
    zones = readtable(sourceFile, 'TextType', 'string');
    zones = sortrows(zones, 'zone_id');
    if height(zones) ~= {geometry['zone_count']}
        error('Expected {geometry['zone_count']} public spatial zones, found %d.', height(zones));
    end
    if any(zones.calibration_probability <= 0) || abs(sum(zones.calibration_probability) - 1) > 1e-10
        error('Spatial-zone probabilities must be positive and sum to one.');
    end

    spatial.ZoneId = zones.zone_id;
    spatial.CoordKm = [zones.x_km_from_demand_center, zones.y_km_from_demand_center];
    spatial.Probability = zones.calibration_probability';
    spatial.DemandCentreKm = [0, 0];
    spatial.FitSplit = 'calibration';
    spatial.HoldoutTVD = {geometry['zone_holdout_total_variation_distance']:.6f};
    spatial.Contract = ['Use CoordKm only as abstract demand-zone geometry. ', ...
        'Set the V2 platform start explicitly; [0,0] is only the demand-centre reference.'];
end
"""
    (MATLAB / "load_public_spatial_zones.m").write_text(text, encoding="utf-8")


def write_report(calibration):
    weather, demand, energy, amazon = (
        calibration["weather"], calibration["demand"], calibration["energy"], calibration["amazon_load"]
    )
    report = f"""# 公开多源数据标定报告

生成日期：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  
校准包版本：`public-calibration-v1`

## 可主张的证据边界

本包是 **empirically informed simulation** 的输入标定证据，不是目标企业、目标城市或目标无人机的现场运营验证。所有策略必须在同一标定输入和同一安全约束下比较。VIP 标签、计划惯性成本 `W3/Hs`、绝对需求规模和目标机型修正均未被伪装为经验估计。

## 1. 风况与预报误差

- 地点：{weather['reference_location']}。
- 配对数：{weather['pair_count']} 个小时；校准/开发/留出分别为 {weather['calibration_pairs']}/{weather['development_pairs']}/{weather['holdout_pairs']}。
- 校准期风速偏差（实际减预报）：{weather['mean_speed_bias_mps']:.3f} m/s。
- 去偏后的传统标量误差标准差：{weather['legacy_error_sigma_mps']:.3f} m/s；这仅作为旧 `ErrorSigma` 的可比性参数，最终 V2 应采用连续 {weather['recommended_block_hours']} 小时的经验误差块重采样。
- 留出集风速 MAE/RMSE：{weather['holdout_speed_mae_mps']:.3f}/{weather['holdout_speed_rmse_mps']:.3f} m/s。

## 2. 订单到达与空间代理

- Olist 参考需求区域：{demand['reference_demand_area']}。公开订单事件：{demand['source_order_count']} 条；按时间切分为校准 {demand['calibration_order_count']}、开发 {demand['development_order_count']}、留出 {demand['holdout_order_count']}。
- 由校准期小时到达分布预测留出期小时分布的总变差距离：{demand['holdout_hour_profile_total_variation_distance']:.3f}。
- 前 12 个 ZIP 前缀代理区占校准订单的 {demand['top_12_zip_prefix_share']:.2%}。它支持相对空间集中度，不支持目标城市的真实坐标重建。
- Amazon 历史路线：{amazon['route_count']} 条；每路线客户站点数中位数 {amazon['median_customer_stops_per_route']:.1f}，P10/P90 为 {amazon['p10_customer_stops_per_route']:.1f}/{amazon['p90_customer_stops_per_route']:.1f}。仅用于工作负荷与站点规模外部锚定。

## 3. 飞行能耗外部验证

- 数据：公开 DJI Matrice 100 小件配送遥测，{energy['flight_count']} 次飞行；按日期留出 {energy['holdout_flight_count']} 次飞行。
- 校准期全任务等效中位功率：{energy['constant_mission_power_median_w']:.1f} W；中央飞行段巡航功率候选值：{energy['central_segment_cruise_power_candidate_w']:.1f} W；P10/P90：{energy['power_p10_w']:.1f}/{energy['power_p90_w']:.1f} W。
- 常数功率简化模型在留出飞行上的能耗 MAE/RMSE：{energy['holdout_energy_mae_wh']:.2f}/{energy['holdout_energy_rmse_wh']:.2f} Wh；MAPE：{energy['holdout_energy_mape']:.2%}。
- 这不是你目标机型的实测验证。更重要的是，冻结 V1 物理模型没有起降/回收能耗项，故不得把全任务 407.7 W 自动写进 `BaseCruisePowerW`；V2 必须先增加阶段能耗后，才可使用中央飞行段候选功率与全任务包络。

## 4. 导入 V2 的规则

1. 用 `processed/legacy_weather_pairs_fingerprint_only.csv` 连续重放预报—实况误差块；不再以人为设定的 σ=1/3/5 作为主分析。该档案未标识固定提前期，故表述为近实时预报代理，而非 20/40/60 分钟误差标定。
2. 用 `processed/olist_hourly_demand_profile.csv` 作为需求时间形状代理；购买时间不是最后一公里任务释放时间，绝对需求强度另行按系统容量设定，并做边界分析。
3. 用 `matlab/public_calibration_override.m` 仅作为 公开标定配置的起点；不得改写或混入既有冻结发布包。
4. `W3`、`Hs`、VIP 比例与平台移动速度仍须标注为管理/工程情景参数。
5. 发布时提交 `source_manifest.json`、全部脚本、处理 CSV、随机种子和本报告。

## 不可声称的事项

- 未标定真实企业的订单空间坐标、VIP 比例、人工调度成本或计划改动成本；
- 未验证目标无人机、城市低空风场或目标平台的实际性能；
- 未证明商业部署收益、节能收益或安全认证。
"""
    (REPORTS / "public_calibration_report.md").write_text(report, encoding="utf-8")


def main():
    for folder in (PROCESSED, REPORTS, MATLAB):
        folder.mkdir(parents=True, exist_ok=True)
    calibration = {
        "package_version": "public-calibration-release-v1",
        "method": "Route B: public multi-source, empirically informed simulation",
        "weather": calibrate_weather(),
        "demand": calibrate_demand(),
        "energy": calibrate_energy(),
        "amazon_load": calibrate_amazon_load(),
        "not_calibrated": {
            "vip_share": "No public source in this package supplies a compatible VIP/SLA label.",
            "W3_and_Hs": "Governance preference/structural plan-change measure; requires plan-version and operator-workload logs for empirical estimation.",
            "platform_movement": "Engineering scenario parameter until platform or traffic trajectory data are introduced.",
            "target_aircraft_transfer": "No target-aircraft telemetry; public DJI M100 data provide an external envelope only.",
        },
    }
    calibration = round_floats(calibration)
    (PROCESSED / "public_calibration_parameters.json").write_text(
        json.dumps(calibration, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    write_matlab_override(calibration)
    write_matlab_spatial_loader(calibration)
    write_report(calibration)
    print(json.dumps(calibration, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
