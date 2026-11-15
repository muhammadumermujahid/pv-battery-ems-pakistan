"""Per site and day: cost of PV+battery, rules v1 and the perfect-foresight MILP (independent of any forecast). -> site_base.json"""
import json, sys
from sitelib import *
out = {}
for site in SITES:
    rows = []
    for d, pv in load_days(site):
        ls, fixed, L = setup(d); hab = habitual_profile(L); z = np.zeros(T)
        ch, dis, Eb = run_battery(pv, fixed + hab.sum(0), lambda t, e: True); sc, _ = account('sc', pv, fixed, hab, ch, dis, Eb)
        sh, ch, dis, Eb = rule_schedule(L, pv, fixed); r1, _ = account('r1', pv, fixed, sh, ch, dis, Eb)
        sh, ch, dis, Eb, gap, obj = solve_milp(L, pv, fixed); mi, _ = account('m', pv, fixed, sh, ch, dis, Eb)
        rows.append(dict(date=str(d), pv=float(pv.sum() * DT), sc=sc['total'], v1=r1['total'], milp=mi['total'], pk_v1=r1['peak_import_kwh']))
    out[site] = rows; print(site, len(rows), flush=True)
    json.dump(out, open('site_base.json', 'w'))
