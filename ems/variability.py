"""Day-to-day variability: run the four strategies on every real day of PVGIS-ERA5 hourly irradiance (Islamabad, 30 deg south,
2016-2020, local time UTC+5), same loads/tariff/peak windows as annual.py (summer load April-October, winter load November-March)."""
import json, datetime as dt, numpy as np
import ems10 as E
from ems10 import *
HOT = {4,5,6,7,8,9,10}
raw = [l.strip().split(',') for l in open('data/pvgis_series_2016_2020_raw.csv') if l[:2] == '20' and ':' in l[:9]]
t0 = dt.datetime(int(raw[0][0][:4]), int(raw[0][0][4:6]), int(raw[0][0][6:8]), int(raw[0][0][9:11]))
G = np.array([float(r[1]) for r in raw]); n = len(G)
hrs = np.arange(n) + 0.5                                              # hour labels hh:30 (UTC), hours since t0 (00:00 UTC of first day)
d0 = dt.date(2016, 1, 2); d1 = dt.date(2020, 12, 30)                  # local days fully covered
out = []; d = d0
while d <= d1:
    start = (dt.datetime(d.year, d.month, d.day) - t0).total_seconds() / 3600 - 5.0   # local midnight in UTC hours since t0
    tc = start + H + DT / 2
    g = np.interp(tc, hrs, G)
    pv = np.minimum(CFG['pv_kwp'] * g / 1000 * CFG['pv_pr'], CFG['inv_kw'])
    ls = 'summer' if d.month in HOT else 'winter'
    set_season_tariff(ls)
    fixed = fixed_load(ls); L = shiftables(ls); hab = habitual_profile(L); z = np.zeros(T)
    s0, _ = account('pv', pv, fixed, hab, z, z, np.zeros(T))
    ch, dis, Eb = run_battery(pv, fixed + hab.sum(0), lambda t, e: True); s1, _ = account('sc', pv, fixed, hab, ch, dis, Eb)
    sh, ch, dis, Eb = rule_schedule(L, pv, fixed); s2, _ = account('rules', pv, fixed, sh, ch, dis, Eb)
    sh, ch, dis, Eb, gap, obj = solve_milp(L, pv, fixed); s3, _ = account('milp', pv, fixed, sh, ch, dis, Eb)
    out.append(dict(date=str(d), month=d.month, pv_kwh=float(pv.sum() * DT), cost=[s['total'] for s in (s0, s1, s2, s3)],
                    peak=[s['peak_import_kwh'] for s in (s0, s1, s2, s3)]))
    d += dt.timedelta(days=1)
json.dump(out, open('variability.json', 'w'))
print(len(out), 'days')
