#!/usr/bin/env bash
# Reproduce every result and figure. Run from this folder: bash run_all.sh   (about 10-15 min)
set -e
python3 ems10.py        # summer / winter / overcast days -> results.json, data/series.npy
python3 sens.py         # sensitivity study             -> sensitivity.json
python3 annual.py       # monthly-average-day year       -> annual.json
python3 variability.py  # 1,825 real days, 2016-2020     -> variability.json
python3 decomp.py       # 3x3 gap decomposition          -> decomp.json
python3 carry.py        # SOC carried between days       -> carry.json
python3 v2days.py       # rules v2 on real days          -> v2days.json
python3 carry_v2.py     # rules v2 with carried SOC      -> carry_v2.json
python3 gridcharge.py   # grid-charging test             -> gridcharge.json
python3 forecast.py     # day-ahead MILP with PV errors  -> forecast.json
python3 coupled.py      # early efficiency-scaling test  -> coupled.json
python3 cosim_ingest.py cosim_map_all.csv   # re-cost with Simulink loss map
python3 site_base.py; python3 site_levels.py; python3 site_forecast.py; python3 site_nasa.py   # six sites, forecasts, thresholds, NASA POWER check (about 12 min)
python3 make_figures.py; python3 mkfig_data.py; python3 mkfig_plantmap.py
