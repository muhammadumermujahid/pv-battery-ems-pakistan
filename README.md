# PV–battery home under a Pakistani time-of-use tariff: converter model and energy management

Code, model scripts and result files for the article

> M. U. Mujahid, *Rule-based versus optimal energy management of a photovoltaic–battery home under a Pakistani time-of-use tariff: from converter dynamics to household cost*, submitted to *Applied Energy* (2026).

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.24261362.svg)](https://doi.org/10.5281/zenodo.24261362)

Archived release (cite this): M. U. Mujahid, *PV–battery home under a Pakistani time-of-use tariff: converter model and energy management (code and data)*, version 1.0.0, Zenodo, 2026. https://doi.org/10.5281/zenodo.24261362

The study has two layers:
- **Plant:** a switched Simulink / Simscape Electrical model of a 10 kWp PV array, a boost converter with perturb-and-observe tracking, a 700 V DC link, a 400 V battery stage and a PLL-based grid inverter. The reference step is 1 µs, and the scripts switch it automatically.
- **Energy management:** a Python model in 15-minute steps of a home with a 15 kWh / 5 kW battery and four shiftable appliances under the IESCO A-1 two-tier tariff with net billing. It compares rule-based control (v1 and v2) with a perfect-foresight MILP.

## Contents
| Folder | What it holds |
|---|---|
| `ems/` | Python energy-management code (rules v1/v2, MILP with HiGHS via SciPy), every experiment, and the result files (`*.json`) quoted in the paper |
| `ems/data/` | PVGIS-ERA5 and NASA POWER inputs (see `ems/data/README.md` for sources and terms) |
| `ems/cosim_map_all.csv` | 34-point loss map measured on the Simulink plant (1 µs, corrected battery controller); earlier maps are kept as `*_5us.csv` and `*_1us_asbuilt.csv` |
| `simulink/matlab/` | MATLAB scripts that build, modify and measure the plant. The scripts behind the published plant results are `fine_reruns.m`, `finestep_test.m`, `bias_test.m`, `battery_fix.m`, `damper_test.m` and `model_dump.m`. |
| `simulink/results/` | Console outputs of every MATLAB run (plain text), `model_dump.txt` (every block, parameter and connection of the model) and figure data (`fine_figdata/`) |
| `simulink/pv_exact.py`, `simulink/avg_tracker.py` | Exact array curve from the Simscape parameters, and an averaged model of the input stage running the model's own tracker code |
| `figures_src/` | Figure scripts, SVG sources, vector PDFs and the PNGs used in the paper |

## Run the energy-management model
```
pip install -r requirements.txt
cd ems
bash run_all.sh        # about 10-15 minutes; regenerates every .json and the figures in ems/figures/
```
`python3 ems10.py` alone reproduces the three-day results (`results.json`). Tested with Python 3.13 and SciPy (HiGHS). The site data files are included, so no download is needed.

## Run the plant model
You need MATLAB R2023a or later with Simulink and Simscape Electrical (Specialized Power Systems). Put `grid_inv_test_battery.slx` in a folder, open MATLAB there and run a script, for example `fine_reruns` (about 4.5 h at 1 µs). Every script:
- sets the model step, the tracker window and the test conditions in memory;
- writes its console to a `.txt` file;
- closes the model **without saving**.

**Battery controller.** The model as first built limited the `Saturation2` block in front of the battery-duty divider to ±0.5, which turned the battery current loop into a bang-bang controller. The published battery results use limits of 100–1000 V, and `battery_fix.m` applies this correction in memory. The paper documents both versions.

## Licences
- **Code** (`*.py`, `*.m`, `*.sh`): MIT, see `LICENSE`.
- **Data, results and figures produced in this work:** CC BY 4.0, see `LICENSE-DATA`.
- **Third-party input data:**
  - PVGIS / ERA5: European Commission JRC and Copernicus Climate Change Service.
  - NASA POWER: public, with acknowledgement.
  - These stay under their own terms; see `ems/data/README.md`.

## Privacy
The appliance ratings and run times come from a private household in Islamabad. Only the values used in the model are included; the household is not identified.
