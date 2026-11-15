"""Per real day: rules with the off-peak discharge flag off (v1) and on (v2 variants), for hold-before-peak 0, 2, 3 h."""
import json, datetime as dt, numpy as np
import ems10 as E
from ems10 import *
HOT = {4,5,6,7,8,9,10}
raw = [l.strip().split(',') for l in open('data/pvgis_series_2016_2020_raw.csv') if l[:2] == '20' and ':' in l[:9]]
t0 = dt.datetime(int(raw[0][0][:4]), int(raw[0][0][4:6]), int(raw[0][0][6:8]), int(raw[0][0][9:11]))
G = np.array([float(r[1]) for r in raw]); hrs = np.arange(len(G)) + 0.5
d = dt.date(2016, 1, 2); out = []
while d <= dt.date(2020, 12, 30):
    start = (dt.datetime(d.year, d.month, d.day) - t0).total_seconds() / 3600 - 5.0
    g = np.interp(start + H + DT / 2, hrs, G); pv = np.minimum(CFG['pv_kwp'] * g / 1000 * CFG['pv_pr'], CFG['inv_kw'])
    ls = 'summer' if d.month in HOT else 'winter'; set_season_tariff(ls)
    fixed = fixed_load(ls); L = shiftables(ls); row = dict(date=str(d), season=ls, pv=float(pv.sum() * DT))
    for hold in (0.0, 2.0, 3.0):
        for good in (False, True):
            if not good and hold > 0: continue
            sh, ch, dis, Eb = rule_schedule(L, pv, fixed, good=good, hold_pre=hold); r, _ = account('x', pv, fixed, sh, ch, dis, Eb)
            row[f'g{int(good)}_h{int(hold)}'] = r['total']; row[f'pk_g{int(good)}_h{int(hold)}'] = r['peak_import_kwh']
    out.append(row); d += dt.timedelta(days=1)
json.dump(out, open('v2days.json', 'w')); print(len(out))
