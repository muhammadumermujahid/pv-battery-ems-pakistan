"""Where do the rules lose to the MILP?  3 x 3 design: appliance schedule {habitual, rules, MILP} x battery policy {self-consumption, rules, optimal}.
'optimal' battery = MILP with the appliance schedule fixed. Run on the summer, winter and overcast days and on 1,825 real days (2016-2020)."""
import json, datetime as dt, numpy as np
import ems10 as E
from ems10 import *

def cells(pv, ls, season_key=None):
    set_season_tariff(season_key or ls)
    fixed = fixed_load(S0(ls)); L = shiftables(S0(ls)); hab = habitual_profile(L)
    emax = CFG['batt_kwh']
    shR, chR, disR, ER = rule_schedule(L, pv, fixed)
    shM, chM, disM, EM, gap, obj = solve_milp(L, pv, fixed)
    out = {}
    for an, sh in (('H', hab), ('R', shR), ('M', shM)):
        load = fixed + sh.sum(0)
        for bn in ('S', 'R', 'O'):
            if bn == 'S':   ch, dis, Eb = run_battery(pv, load, lambda t, e: True)
            elif bn == 'R': ch, dis, Eb = run_battery(pv, load, lambda t, e: E.is_peak[t] or e / emax > 0.8)
            else:
                _, ch, dis, Eb, g, o = solve_milp([], pv, load)
            r, _ = account('x', pv, fixed, sh, ch, dis, Eb); out[an + bn] = r['total']
    # consistency: coupled rules and joint MILP
    rr, _ = account('x', pv, fixed, shR, chR, disR, ER); rm, _ = account('x', pv, fixed, shM, chM, disM, EM)
    out['_rules'] = rr['total']; out['_milp'] = rm['total']
    return out

def decomp(c):
    R, M = c['RR'], c['MO']; gap = R - M
    app = 0.5 * ((c['RR'] - c['MR']) + (c['RO'] - c['MO']))      # value of MILP appliance schedule (both orders averaged)
    bat = 0.5 * ((c['MR'] - c['MO']) + (c['RR'] - c['RO']))      # value of optimal battery dispatch (both orders averaged)
    return dict(gap=gap, appliance=app, battery=bat)

if __name__ == '__main__':
    res = {}
    for season in ('summer', 'winter', 'cloudy'):
        set_season_tariff(season); pv = pv_profile(season)
        c = cells(pv, season, season); res[season] = c
        print(season, {k: round(v, 1) for k, v in c.items()}, {k: round(v, 1) for k, v in decomp(c).items()})
    # real days
    HOT = {4,5,6,7,8,9,10}
    raw = [l.strip().split(',') for l in open('data/pvgis_series_2016_2020_raw.csv') if l[:2] == '20' and ':' in l[:9]]
    t0 = dt.datetime(int(raw[0][0][:4]), int(raw[0][0][4:6]), int(raw[0][0][6:8]), int(raw[0][0][9:11]))
    G = np.array([float(r[1]) for r in raw]); hrs = np.arange(len(G)) + 0.5
    d = dt.date(2016, 1, 2); tot = {}; n = {'summer': 0, 'winter': 0}; days = []
    while d <= dt.date(2020, 12, 30):
        start = (dt.datetime(d.year, d.month, d.day) - t0).total_seconds() / 3600 - 5.0
        g = np.interp(start + H + DT / 2, hrs, G); pv = np.minimum(CFG['pv_kwp'] * g / 1000 * CFG['pv_pr'], CFG['inv_kw'])
        ls = 'summer' if d.month in HOT else 'winter'
        c = cells(pv, ls); days.append(dict(date=str(d), season=ls, pv_kwh=float(pv.sum() * DT), **c))
        d += dt.timedelta(days=1)
    res['real_days'] = days
    json.dump(res, open('decomp.json', 'w'))
    print(len(days), 'real days done')
