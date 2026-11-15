"""Check of decomp.py with the battery state of charge carried from day to day (no reset to 50 %), 1,825 real days.
Chains: RR (coupled rules), RS (rule appliance schedule, self-consumption battery), HS, HR (habitual loads), MO (joint MILP with carried SOC)."""
import json, datetime as dt, numpy as np
import ems10 as E
from ems10 import *
HOT = {4,5,6,7,8,9,10}
raw = [l.strip().split(',') for l in open('data/pvgis_series_2016_2020_raw.csv') if l[:2] == '20' and ':' in l[:9]]
t0 = dt.datetime(int(raw[0][0][:4]), int(raw[0][0][4:6]), int(raw[0][0][6:8]), int(raw[0][0][9:11]))
G = np.array([float(r[1]) for r in raw]); hrs = np.arange(len(G)) + 0.5
emax = CFG['batt_kwh']; soc = {k: 0.5 for k in ('RR', 'RS', 'HS', 'HR', 'MO')}
cost = {k: [] for k in soc}; meta = []
d = dt.date(2016, 1, 2)
while d <= dt.date(2020, 12, 30):
    start = (dt.datetime(d.year, d.month, d.day) - t0).total_seconds() / 3600 - 5.0
    g = np.interp(start + H + DT / 2, hrs, G); pv = np.minimum(CFG['pv_kwp'] * g / 1000 * CFG['pv_pr'], CFG['inv_kw'])
    ls = 'summer' if d.month in HOT else 'winter'; set_season_tariff(ls)
    fixed = fixed_load(ls); L = shiftables(ls); hab = habitual_profile(L)
    def run(key, fn):
        CFG['soc0'] = soc[key]; sh, ch, dis, Eb = fn(); r, _ = account('x', pv, fixed, sh, ch, dis, Eb)
        soc[key] = float(Eb[-1] / emax) if (ch.sum() + dis.sum()) > 0 else soc[key]; cost[key].append(r['total']); return sh
    shR = run('RR', lambda: rule_schedule(L, pv, fixed))
    run('RS', lambda: (shR,) + run_battery(pv, fixed + shR.sum(0), lambda t, e: True))
    run('HS', lambda: (hab,) + run_battery(pv, fixed + hab.sum(0), lambda t, e: True))
    run('HR', lambda: (hab,) + run_battery(pv, fixed + hab.sum(0), lambda t, e: E.is_peak[t] or e / emax > 0.8))
    run('MO', lambda: solve_milp(L, pv, fixed)[:4])
    meta.append((str(d), ls)); d += dt.timedelta(days=1)
C = {k: np.array(v) for k, v in cost.items()}; s = np.array([m[1] for m in meta])
for nm, m in (('hot', s == 'summer'), ('cool', s == 'winter'), ('all', s != '')):
    mm = {k: C[k][m].mean() for k in C}
    print(nm, {k: round(v, 1) for k, v in mm.items()}, ' capture RR %.1f RS %.1f (vs HS baseline, MILP carried)' % (100 * (mm['HS'] - mm['RR']) / (mm['HS'] - mm['MO']), 100 * (mm['HS'] - mm['RS']) / (mm['HS'] - mm['MO'])))
print('RS < RR on %.0f %% of days; final SOC RR %.2f RS %.2f' % (100 * np.mean(C['RS'] < C['RR']), soc['RR'], soc['RS']))
json.dump({k: v.tolist() for k, v in C.items()}, open('carry.json', 'w'))
