"""Per site and day: cost of the rules when off-peak discharge is allowed down to a state-of-charge floor (0.2 = rules v2 always on,
'none' = rules v1). Any forecast / threshold rule then only selects one column per day. -> site_levels.json"""
import json
from sitelib import *
FLOORS = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
out = {}
for site in SITES:
    rows = []
    for d, pv in load_days(site):
        ls, fixed, L = setup(d); r = dict(cost=[], peak=[])
        for fl in FLOORS:
            sh, ch, dis, Eb = rule_schedule(L, pv, fixed, floor=fl); a, _ = account('x', pv, fixed, sh, ch, dis, Eb)
            r['cost'].append(a['total']); r['peak'].append(a['peak_import_kwh'])
        rows.append(r)
    out[site] = rows; print(site, flush=True)
json.dump(out, open('site_levels.json', 'w'))
