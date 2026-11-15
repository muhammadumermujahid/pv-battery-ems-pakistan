# Adding the 15 kWh battery to `grid_inv_test` (build guide)

Goal: show that a battery on the 700 V DC link can move +/-5 kW while the existing DC-link PI keeps ~700 V and the grid current stays clean. The 24 h dispatch stays in Python; Simulink only shows the converter-level behaviour.
Block names below are those of Simscape Electrical > Specialized Power Systems (R2023a). If a name differs slightly in your install, search the library browser for it.

**Before you start:** File > Save As `grid_inv_test_battery.slx` and work on that copy. Keep the powergui on Discrete, Ts = 5e-6.

## 1. Parameters (put in the model workspace or a script)
| Name | Value | Why |
|---|---|---|
| Vbat | 400 V | nominal battery voltage |
| Ah | 37.5 Ah | 15 kWh / 400 V |
| Lb | **10 mH** (Rb = 0.02 ohm) | at 2 mH the ripple would be 17 A pk-pk against a 12.5 A average; at 10 mH it is about 3.4 A |
| fsw | 5 kHz | same as the PV boost |
| Pmax | 5 kW | 12.5 A at 400 V |
| Ts_ctl | 5e-5 s | control sample time (40 samples per PWM period) |
| Kp, Ki | 19 V/A, 3600 | about 300 Hz current-loop bandwidth: Kp = Lb x 2 pi x 300, integral zero at 1/10 of that |

## 2. Power circuit
1. Add **Battery** (Electrical Sources). Type Lithium-Ion, Nominal voltage 400, Rated capacity 37.5 Ah, Initial SOC 50 %. Leave other fields default.
2. Add **Series RLC Branch** named `Lb`, type RL, R = 0.02, L = 10e-3.
3. Add **Current Measurement** named `i_bat` in series between battery (+) and `Lb`. Check the arrow: positive current must flow **out of** the battery towards the bridge (discharge = +).
4. Add **Universal Bridge** named `HB`: Number of arms **1**, Power electronic device IGBT/Diodes, Snubber resistance 1e5, Ron 1e-3, Forward voltage 1 V (as your boost IGBT).
5. Connections: `Lb` right side -> bridge **A** (midpoint). Bridge **DC+** -> the existing 700 V DC-link positive node; bridge **DC-** and battery (-) -> the DC-link negative node.
6. Add two **Voltage Measurement** blocks: `V_bat` across the battery and `V_dc` across the DC link (you may reuse your existing DC-link measurement).

## 3. Control (all Simulink blocks, sample time Ts_ctl)
Signal flow:
`P_ref` -> Gain (1/Vbat) -> **I_ref**
`I_ref - i_bat` -> **Discrete PI** (Kp = 19, Ki = 3600, Ts = 5e-5) -> **vL\*** (the voltage you want across the inductor)
`Du = (V_bat - vL*) / V_dc` -> Saturation [0.05, 0.95] -> `m = 2*Du - 1` -> **PWM Generator (2-Level)**, 1 arm, carrier 5 kHz, internal generation, sample time 5e-6 -> bridge gate input `g`.

Notes:
- Du is the duty of the **upper** switch (it connects the midpoint to DC+). At 5 kW steady state, Du = 1 - Vbat/Vdc = 0.43 at the start of discharge and the PI trims it.
- Add a Divide block with `V_dc` (not a constant) so the controller stays correct if the DC link moves slightly.
- If the battery current moves the wrong way when you step P_ref, flip the sign of `i_bat` (or the current-measurement direction), not the PI.
- P_ref: a **Step** or Repeating Sequence: 0 W until 0.4 s, +5000 W (discharge) from 0.4 s, -5000 W (charge) from 0.8 s.

## 4. Simulation settings for the test
- **Irradiance 300 W/m2 (not 1000).** At 1000 W/m2 the PV gives 9.7 kW and a +5 kW discharge would push the inverter past its roughly 9.8 kW current limit (the DC-link PI limit is +/-20 A), so the DC link would rise. At 300 W/m2 the PV gives about 2.9 kW, so grid power should be about 7.9 kW during discharge and about -2.1 kW (import) during charge.
- Stop time 1.0 s (your model's current value) is enough; the paper currently says 1.2 s, so set one of them to match.
- Add To Workspace blocks (Structure With Time) for: `p_bat` (V_bat x i_bat), `v_dc`, `i_bat`, grid phase currents, grid power.
- The SOC will hardly move in 1 s (5 kW for 0.4 s is under 1 Wh). That is expected; the 24 h SOC comes from the Python model.

## 5. What to measure and send back
| Quantity | Window | Expected |
|---|---|---|
| DC-link voltage mean and min/max | 0.3-0.4 s, 0.5-0.7 s, 0.9-1.0 s | about 700 V, deviation of a few volts at the steps |
| Battery power | same windows | 0, +5 kW, -5 kW |
| Grid active power | same windows | PV, PV + about 5 kW, PV - about 5 kW |
| Battery converter efficiency | 0.5-0.7 s and 0.9-1.0 s | about 97-98 % (P_dc_link / P_bat) |
| Grid-current THD (2nd-50th) | each window | about 2-3 % as before |
| DC-link settling time after each step | - | tens of ms |

Please send: screenshots of the scope (DC-link voltage, battery current, grid power) and these numbers. I will add a "Battery stage" subsection to the paper, a new row in Table II, a battery-converter figure and the updated Fig. 1/5 descriptions.

## 6. Common problems
- **DC link blows up or inverter current saturates:** irradiance too high, or sign of battery current reversed.
- **Battery current oscillates:** lower Kp to 10 and Ki to 2000.
- **Algebraic loop warning:** put a Unit Delay (Ts_ctl) on `i_bat` before the error sum.
- **Powergui complains about the sample time:** every sample time must be a multiple of 5e-6.
