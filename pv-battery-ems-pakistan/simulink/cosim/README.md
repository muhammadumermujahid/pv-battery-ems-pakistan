# Co-simulation (EMS day <-> Simulink plant)
1. In MATLAB, open the folder with grid_inv_test_battery.slx, copy cosim_map.m there, run `cosim_map` (about 30 runs of 0.6 s).
   The irradiance source must read G_Wm2 and the battery Pref step must use Pbat_W (the script tries to set both).
2. It writes cosim_map.csv. Put it in ems/ (as cosim_map_all.csv) and run `python3 cosim_ingest.py cosim_map.csv`.
3. The output compares rho with the ideal inverter, the PV-path loss only, and the full map (battery stage included).
cosim_map_SYNTHETIC_TEST.csv only tests the code; do not quote it.
