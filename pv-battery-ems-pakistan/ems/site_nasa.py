"""Independent-dataset check: NASA POWER (CERES/MERRA-2) hourly all-sky GHI for Islamabad, 2016-2020, scaled by one factor so that the mean daily PV of
2016-2018 equals the PVGIS-ERA5 value (GHI -> 30 deg tilt). Same rules/MILP, same threshold (25 kWh). -> site_nasa.json"""
import json, numpy as np
from sitelib import *
rows = []
for y in range(2016, 2021):
    p = json.load(open(f'data/sites/nasa_isb_{y}.json'))['properties']['parameter']['ALLSKY_SFC_SW_DWN']
    for k, v in p.items(): rows.append((k, max(v, 0.0)))
def write(scale):
    with open('data/sites/islamabad_nasa.csv', 'w') as f:
        f.write('header\ntime,G(i)\n')
        for k, v in rows: f.write(f'{k[:8]}:{k[8:10]}30,{v*scale:.2f}\n')
write(1.0); a = load_days('islamabad_nasa'); b = load_days('islamabad')
tr = [i for i, (d, _) in enumerate(a) if d.year <= 2018]
ma = np.mean([a[i][1].sum() * DT for i in tr]); mb = np.mean([b[i][1].sum() * DT for i in tr]); sc = mb / ma; print('scale', round(sc, 3), 'mean PVGIS', round(mb, 1))
write(sc); a = load_days('islamabad_nasa')
pa = np.array([x[1].sum() * DT for x in a]); pb = np.array([x[1].sum() * DT for x in b]); print('corr daily PV NASA vs PVGIS', round(float(np.corrcoef(pa, pb)[0, 1]), 3), 'mean', pa.mean().round(1), pb.mean().round(1))
res = []
for d, pv in a:
    ls, fixed, L = setup(d); hab = habitual_profile(L)
    ch, dis, Eb = run_battery(pv, fixed + hab.sum(0), lambda t, e: True); s1, _ = account('sc', pv, fixed, hab, ch, dis, Eb)
    sh, ch, dis, Eb = rule_schedule(L, pv, fixed); r1, _ = account('r', pv, fixed, sh, ch, dis, Eb)
    sh, ch, dis, Eb = rule_schedule(L, pv, fixed, good=True); r2, _ = account('r', pv, fixed, sh, ch, dis, Eb)
    sh, ch, dis, Eb, gap, obj = solve_milp(L, pv, fixed); m, _ = account('m', pv, fixed, sh, ch, dis, Eb)
    res.append(dict(date=str(d), pv=float(pv.sum() * DT), sc=s1['total'], v1=r1['total'], v2all=r2['total'], mi=m['total'], pk1=r1['peak_import_kwh'], pk2=r2['peak_import_kwh']))
R = {k: np.array([r[k] for r in res]) for k in res[0] if k != 'date'}; yrs = np.array([int(r['date'][:4]) for r in res]); te = yrs >= 2019
pers = np.concatenate([[R['pv'][0]], R['pv'][:-1]]); out = {}
for name, fc in (('persistence', pers), ('perfect', R['pv'])):
    v2 = np.where(fc >= 25.0, R['v2all'], R['v1']); out[name] = dict(all=float((R['sc'] - v2).sum() / (R['sc'] - R['mi']).sum() * 100), test=float((R['sc'] - v2)[te].sum() / (R['sc'] - R['mi'])[te].sum() * 100))
out['v1'] = dict(all=float((R['sc'] - R['v1']).sum() / (R['sc'] - R['mi']).sum() * 100), test=float((R['sc'] - R['v1'])[te].sum() / (R['sc'] - R['mi'])[te].sum() * 100))
out['scale'] = float(sc); out['corr'] = float(np.corrcoef(pa, pb)[0, 1]); print(out); json.dump(out, open('site_nasa.json', 'w'), indent=1)
