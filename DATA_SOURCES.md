# Data Sources and Redistribution Boundaries

## Final empirical inputs

`data_calibration/PUBLIC_SOURCE_MANIFEST.json` is the authoritative source list for the reported final experiment. The older `source_manifest.json` is retained as a broader acquisition audit and contains legacy Pittsburgh and Amazon entries that are not inputs to the final governance experiment; they must not be cited as part of the final input contract.

### Demand timing and spatial proxy

- Source: Brazilian E-Commerce Public Dataset by Olist.
- Role: Sao Paulo purchase-time profile and calibration-only abstract spatial demand zones.
- Public retrieval records are listed in `data_calibration/source_manifest.json`.
- Raw order and customer tables are not redistributed. The package includes only derived profiles and replay counts. Raw pseudonymous order identifiers have been removed.

### Forecast wind

- Source: NCEP GFS 0.25 Degree Global Forecast Grids Historical Archive, dataset d084001.
- DOI: `10.5065/D65D8PWK`.
- Role: archived 06 UTC forecasts for the Sao Paulo reference grid point.
- Selection and integrity details: `data_calibration/sao_paulo_gfs_source_manifest.json`.

### Realised-wind proxy

- Source: ERA5 10 m wind retrieved through the Open-Meteo historical archive interface.
- Role: realised-wind proxy paired by valid time with GFS and Sao Paulo order days.
- Provenance: `data_calibration/joint_replay_source_manifest.json`.

### Energy envelope

- Source: *In-flight positional and energy use data set of a DJI Matrice 100 quadcopter for small package delivery*.
- Article DOI: `10.1038/s41597-021-00930-x`.
- Data DOI: `10.1184/R1/12683453`.
- License reported by the source: CC BY 4.0.
- Role: external engineering transfer envelope, not same-city or target-aircraft telemetry.

## Included derived data

The package includes the processed inputs required to reproduce the experiments. `sao_paulo_gfs_era5_forecast_pairs_20min.csv` and `sao_paulo_order_weather_20min.csv` were copied into the public package after removing the `order_ids` column. No row used by the simulation was removed, and the simulation does not reference that column.

`legacy_weather_pairs_fingerprint_only.csv` is retained only because the frozen fingerprint code records an earlier calibration interface. It is not used to draw the final same-city scenarios.

## Raw-to-processed code status

The package contains the available Olist, weather-proxy, energy-processing, and validation utilities. The exact one-off collector that assembled the final 3,525 archived GFS point responses and paired them with the ERA5/Olist replay was not preserved as a standalone script. The final processed table, source selection contract, raw-collection integrity counts, validation report, hashes, and experiment-facing scenario loader are preserved. This limitation affects raw acquisition reproducibility, not reproduction of the reported simulation from the released processed inputs.

## License caution

Third-party source terms remain controlling. No license in this repository grants rights over third-party raw data or proprietary software. Review the source terms before reacquiring or redistributing any raw file.
