"""Annual simulation: twelve PVGIS-ERA5 average days (Islamabad, 30 deg, south), each run with the four strategies and weighted by days in the month."""
import json, os, subprocess, numpy as np
import ems10 as E
from ems10 import *
DAYS = [31,28,31,30,31,30,31,31,30,31,30,31]
HOT = {4,5,6,7,8,9,10}                      # months with AC and fan loads (assumption)
def fetch(m):
    f = f'data/pvgis_m{m:02d}.csv'
    if not os.path.exists(f):
        url = f'https://re.jrc.ec.europa.eu/api/v5_3/DRcalc?lat=33.684&lon=73.048&month={m}&angle=30&aspect=0&global=1&outputformat=csv&usehorizon=1&raddatabase=PVGIS-ERA5'
        txt = subprocess.run(['curl','-s','-m','60',url],capture_output=True,text=True).stdout
        rows = []
        for l in txt.splitlines():
            p = l.split()
            if len(p) == 4 and ':' in p[0]:
                hh, mm = p[0].split(':'); rows.append((int(hh)+int(mm)/60, p[1], p[2], p[3]))
        assert len(rows) == 24, (m, len(rows), txt[:200])
        with open(f,'w') as o:
            o.write(f'# PVGIS-ERA5 DRcalc, Islamabad lat 33.684 lon 73.048, month {m}, slope 30 deg, azimuth 0 (south), average-day hourly values, time in UTC\nutc_hour,G_i,Gb_i,Gd_i\n')
            for r in rows: o.write(','.join(map(str, r)) + '\n')
    return f
res = []
for m in range(1, 13):
    E.PVGIS[f'm{m}'] = fetch(m)
    ls = 'summer' if m in HOT else 'winter'
    set_season_tariff(ls)
    pv = pv_profile(f'm{m}'); fixed = fixed_load(ls); L = shiftables(ls)
    hab = habitual_profile(L); z = np.zeros(T)
    s0, _ = account('pv', pv, fixed, hab, z, z, np.zeros(T))
    ch, dis, Eb = run_battery(pv, fixed + hab.sum(0), lambda t, e: True)
    s1, _ = account('selfc', pv, fixed, hab, ch, dis, Eb)
    sh, ch, dis, Eb = rule_schedule(L, pv, fixed)
    s2, _ = account('rules', pv, fixed, sh, ch, dis, Eb)
    sh4, ch4, dis4, E4 = rule_schedule(L, pv, fixed, good=bool(pv.sum()*DT >= CFG['v2_thr'])); s4, _ = account('rules2', pv, fixed, sh4, ch4, dis4, E4)
    sh3, ch3, dis3, E3, gap, obj = solve_milp(L, pv, fixed)
    s3, _ = account('milp', pv, fixed, sh3, ch3, dis3, E3)
    row = dict(month=m, load=ls, pv_kwh=float(pv.sum()*DT), days=DAYS[m-1], pk=[s['peak_import_kwh'] for s in (s0,s1,s2,s3)], cost=[s['total'] for s in (s0,s1,s2,s3)], cost2=s4['total'], pk2=s4['peak_import_kwh'])
    res.append(row); print(m, ls, round(row['pv_kwh'],1), [round(c) for c in row['cost']], [round(x,1) for x in row['pk']])
tot = np.array([[r['cost'][i]*r['days'] for i in range(4)] for r in res]).sum(0)
pk = np.array([[r['pk'][i]*r['days'] for i in range(4)] for r in res]).sum(0)
base, rules, milp = tot[1], tot[2], tot[3]
tot2 = sum(r['cost2']*r['days'] for r in res); pk2 = sum(r['pk2']*r['days'] for r in res)
out = dict(rho2=float((base-tot2)/(base-milp)), annual_rules2=float(tot2), peak_import_rules2=float(pk2), months=res, annual=tot.tolist(), annual_peak_import=pk.tolist(), rho=float((base-rules)/(base-milp)),
           saving_rules=float(base-rules), saving_milp=float(base-milp), pv_year=float(sum(r['pv_kwh']*r['days'] for r in res)))
json.dump(out, open('annual.json','w'), indent=1); print({k:v for k,v in out.items() if k!='months'})
