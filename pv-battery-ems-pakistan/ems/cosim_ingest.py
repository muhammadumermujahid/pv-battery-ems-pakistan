"""Re-cost the EMS days with the Simulink plant loss map (cosim_map.csv from cosim_map.m).
For every 15-min slot the plant loss L(Ppv, Pbat) is interpolated from the map and subtracted from the AC-side power;
the schedules (rules, MILP) are the ones dispatched with the ideal-inverter model; the MILP is not re-optimised.
Two variants: 'pv path' (loss at Pbat = 0 only; the EMS already charges 4 % per battery pass through eta)
and 'full map' (battery stage included; conservative because eta is applied as well)."""
import sys, json, numpy as np, pandas as pd
from scipy.interpolate import LinearNDInterpolator, NearestNDInterpolator
import ems10 as E
from ems10 import *

def load_map(path, idle=True):
    m = pd.read_csv(path)
    if 'SYNTHETIC' in path.upper(): print('*** SYNTHETIC TEST MAP - results are NOT plant results, do not use in the paper ***')
    pts = np.c_[m.Ppv_kW, m.Pbat_kW]; l = m.loss_kW.values.copy()
    if idle:                                                                # remove the measured zero-power offset (about 0.03 kW)
        l0 = float(m[(m.Pbat_set_kW == 0)].sort_values('G_Wm2').loss_kW.iloc[0]); l = np.clip(l - l0, 0, None)
        pts = np.vstack([pts, [0, 0]]); l = np.r_[l, 0.0]
    else:
        l0 = 0.0
    lin, near = LinearNDInterpolator(pts, l), NearestNDInterpolator(pts, l)
    def f(ppv, pb):
        v = lin(ppv, pb); n = near(ppv, pb); return np.where(np.isnan(v), n, v)
    pv0 = m[m.Pbat_set_kW == 0]
    pv0 = pv0.sort_values('Ppv_kW'); lp = np.clip(pv0.loss_kW.values - l0, 0, None)
    g = lambda ppv: np.interp(ppv, pv0.Ppv_kW.values, lp)
    return f, g, m

def total(pv, fixed, sh, ch, dis, Eb, loss):
    r, _ = account('x', pv - loss, fixed, sh, ch, dis, Eb); return r['total'], r['import_kwh'], r['peak_import_kwh']

def main(path='cosim_map.csv', idle=True):
    f_full, f_pv, m = load_map(path, idle); out = {}
    for season in ('summer', 'winter', 'cloudy'):
        set_season_tariff(season)
        pv = pv_profile(season); fixed = fixed_load(S0(season)); L = shiftables(S0(season)); hab = habitual_profile(L)
        runs = {}
        ch, dis, Eb = run_battery(pv, fixed + hab.sum(0), lambda t, e: True); runs['sc'] = (hab, ch, dis, Eb)
        runs['rules'] = rule_schedule(L, pv, fixed)
        sh, ch, dis, Eb, g, o = solve_milp(L, pv, fixed); runs['milp'] = (sh, ch, dis, Eb)
        res = {}
        for variant in ('ideal', 'pv_path', 'full'):
            tot = {}
            for k, (sh, ch, dis, Eb) in runs.items():
                pb = dis - ch
                loss = np.zeros(T) if variant == 'ideal' else (f_pv(pv) if variant == 'pv_path' else f_full(pv, pb))
                tot[k] = total(pv, fixed, sh, ch, dis, Eb, loss)
            b, r, mi = tot['sc'][0], tot['rules'][0], tot['milp'][0]
            res[variant] = dict(sc=b, rules=r, milp=mi, rho=(b - r) / (b - mi), peak_rules=tot['rules'][2], peak_milp=tot['milp'][2])
        out[season] = res
        print(season, {v: (round(x['rho'] * 100, 1), round(x['sc']), round(x['rules']), round(x['milp'])) for v, x in res.items()})
    json.dump(out, open('cosim_results.json' if idle else 'cosim_results_keepidle.json', 'w'), indent=1)
    vd = m[m.Pbat_set_kW != 0]
    print('DC-link voltage over the map: %.1f .. %.1f V (|dev| max %.1f V)' % (m.vdc_min.min(), m.vdc_max.max(), np.abs(m.vdc_mean - 700).max()))

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'cosim_map.csv', idle=not (len(sys.argv) > 2 and sys.argv[2] == 'keepidle'))
