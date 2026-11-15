# Data
- `pvgis_june.csv`, `pvgis_december.csv`, `pvgis_m01..m12.csv`: PVGIS monthly average-day hourly profiles (10 kWp, ERA5), used for the summer, winter and monthly-average-day runs.
- `pvgis_series_2016_2020_raw.csv`: PVGIS-ERA5 hourly series 2016-2020 (local time = UTC+5), used for the 1,825 real days.
- `simulink_inputs_*.csv`: irradiance and power inputs exported for the Simulink plant.
- `series.npy`: dispatch time series written by `ems10.py` (regenerated on every run).

Source: PVGIS, European Commission Joint Research Centre (https://re.jrc.ec.europa.eu/pvg_tools/), ERA5 reanalysis (Copernicus Climate Change Service). Check the PVGIS and Copernicus terms of use before redistributing under another licence; the MIT licence in the repository root covers the code only. The irradiance is reanalysis, not site measurement.

- `sites/*.csv`: PVGIS-ERA5 hourly 2016-2020 for Islamabad, Lahore, Multan, Peshawar, Quetta, Karachi (30 deg south tilt). `sites/nasa_isb_*.json` and `sites/islamabad_nasa.csv`: NASA POWER all-sky GHI for Islamabad (scaled by 1.213 to the PVGIS mean daily PV); NASA POWER data are public domain with acknowledgement (https://power.larc.nasa.gov/).
