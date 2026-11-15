# Simulink test scripts (Items 1-4)
Run them in the Command Window with `grid_inv_test_battery` open (MATLAB R2023a, Simscape Electrical Specialized Power Systems). Each script restores the model afterwards.
- `item1_battery.m`  SOC (10-95 %), reference ramp and feed-forward on/off at 300 W/m^2. Results: `../results/item1_battery.csv`.
  The `settle_ms` column is **not valid** (the 5 kHz current ripple keeps the 5 % band from being met); do not use it.
  The open-circuit-voltage and resistance curve is an assumed generic NMC pack scaled to 400 V at 50 % SOC.
- `inspect_model.m`, `inspect_wiring.m`  read-only dumps of block parameters and wiring.

- `item2_weakgrid.m`  SCR 20/10/5/3/2 (X/R 7; plus X/R 2) x PLL gain scale. Results: `../results/item2_weakgrid_console_and_csv.txt`. The `stable` column is **not valid** (baseline switching ripple exceeds its 20 % d-axis threshold); use THD, DC-link deviation and divergence instead.
- `item2b_*`  spectrum / sequence diagnostics of the weak-grid distortion (`../results/item2b_diagnostics_console.txt`).
- `item2c_retune.m`  decoupling and PI-gain variants. `item2d_bandwidth.m`  gains scaled with L_f+L_g (Table X of the paper).
Scripts 2, 2b-2d were pasted into the MATLAB Command Window (R2023a); the exact text is in the project chat history and reproduced in the .m files here.

## Item 3 - P&O tracker (dynamic irradiance)
- `mppt_10ms_averaged.m`: corrected tracker for the MATLAB Function block `MPPT Function` (10 ms averaged, dD = 0.003). Requires the Cin branch set to `BranchType = RC` with `Resistance = 8` (the original Cin was a pure capacitor, so its 1 ohm ESR was inert).
- The original tracker is called every 5 us with dD = 1e-4 and excites the 190 Hz boost-inductor / input-capacitor resonance at partial irradiance.
- Console results for all diagnostics and the ramp tests: `../results/item3_tracker_console.txt`. The ramp/steady-state script was pasted inline in the chat session (see paper Sec. IV-F for the definitions).
- Item 1 (battery) and Tables II and IV were repeated with the corrected tracker: `../results/item1_battery_v2_console.txt`, `../results/headline_rerun_v2_console.txt`. Item 2 (weak grid) is still the original-tracker run and is provisional until repeated.
- Item 3b (partial shading): `item3b_build_shaded_array.m` builds the two-section array with bypass diodes (model not saved by the script); the test script computes the true two-section P-V curve from the single-diode parameters (diode drop 0.8 V assumed) and compares it with the tracker. Results: `../results/item3b_shading_console.txt`. Result: P&O stays on the local peak at B = 300 and 100 W/m2 (61 % and 19 % of the global maximum).
- Item 4 (voltage dips): a Three-Phase Fault block (`Fault_PCC`, GroundFault off, SwitchTimes [10 11] = inactive) is wired to the source terminals; the source impedance is set to SCR = 100 for the test and restored afterwards. `mppt_dclink_override.m` adds a DC-link override (third input from `Vdc_meas`). Results with and without the override: `../results/item4_ride_through_console.txt`. Balanced dips only; no compliance claim.

## Master rerun (corrected tracker)
- `master_rerun.m` reruns Table IX (weak grid, midday), Table X (gains), the measured-power feed-forward variant, the midday no-feed-forward case, the 34-point loss map and the figure-data export. Console output: `../results/master_rerun_console.txt`. Section C printed both result lines but then failed while concatenating the result table (a harmless table-building error); the printed numbers are complete.
- The loss map is also in `../../ems/cosim_map_all.csv`; `ems/cosim_ingest.py` and `mkfig_plantmap.py` were rerun on it.
- Not repeated with the corrected tracker: PLL-gain scaling, decoupling-only, halved/doubled-gain and X/R = 2 weak-grid variants (`item2_weakgrid.m`, `item2c_retune.m`); Fig. 5, Fig. 6 and the battery-stage figure (figdata files from section F not yet used).
