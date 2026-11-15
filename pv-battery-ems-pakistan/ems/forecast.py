"""Day-ahead MILP scheduling with an imperfect PV forecast (deployable variant of the MILP).
The MILP is solved once at 00:00 with a forecast of PV; appliance start times are then fixed.
During the day the battery follows its planned charge/discharge, limited by the real PV surplus
and by its SOC; any mismatch is covered by the grid (no grid charging)."""
import json, numpy as np
import ems10 as E
from ems10 import T, DT, CFG, account, shiftables, fixed_load, pv_profile, set_season_tariff, S0, solve_milp, rule_schedule, habitual_profile, run_battery

def execute(pv, fixed, sh, chp, disp):
    emin = CFG['soc_min'] * CFG['batt_kwh']; emax = CFG['batt_kwh']; eta = CFG['eta']; e = CFG['soc0'] * emax
    ch = np.zeros(T); dis = np.zeros(T); Eb = np.zeros(T)
    for t in range(T):
        load = fixed[t] + sh[:, t].sum(); net = pv[t] - load
        if disp[t] > 1e-9:                                   # planned discharge
            d = min(disp[t], CFG['batt_kw'], (e - emin) * eta / DT); dis[t] = max(d, 0); e -= dis[t] * DT / eta
        elif net > 0:                                        # planned charge or idle: charge from real surplus only
            c = min(net, CFG['batt_kw'], (emax - e) / (eta * DT)); ch[t] = max(c, 0); e += eta * ch[t] * DT
        Eb[t] = e
    return ch, dis, Eb

def run(season, scale=1.0, forecast=None):
    set_season_tariff(season)
    pv = pv_profile(season); fixed = fixed_load(S0(season)); L = shiftables(S0(season))
    pvf = forecast if forecast is not None else pv * scale
    sh, chp, disp, Ep, gap, obj = solve_milp(L, pvf, fixed)
    ch, dis, Eb = execute(pv, fixed, sh, chp, disp)
    r, _ = account('day-ahead MILP', pv, fixed, sh, ch, dis, Eb)
    return r['total'], r['peak_import_kwh']

if __name__ == '__main__':
    R = json.load(open('results.json'))['seasons']; out = {}
    for season in ('summer', 'winter', 'cloudy'):
        sc = R[season]['scenarios']; base, rules, milp = sc[1]['total'], sc[2]['total'], sc[3]['total']
        rows = []
        for f in (0.5, 0.75, 1.0, 1.25, 1.5):
            tot, pk = run(season, f)
            rows.append(dict(scale=f, total=tot, peak=pk, share=(base - tot) / (base - milp)))
        out[season] = dict(base=base, rules=rules, milp=milp, rules_share=(base - rules) / (base - milp), rows=rows)
        if season == 'cloudy':       # persistence: yesterday was the clear summer day
            tot, pk = run(season, forecast=pv_profile('summer'))
            out[season]['persistence'] = dict(total=tot, peak=pk, share=(base - tot) / (base - milp))
        print(season, 'base %.0f rules %.0f milp %.0f' % (base, rules, milp))
        for r in rows: print('  f=%.2f total %.0f peak %.1f share %.0f%%' % (r['scale'], r['total'], r['peak'], 100 * r['share']))
        if 'persistence' in out[season]: print('  persistence', out[season]['persistence'])
    json.dump(out, open('forecast.json', 'w'), indent=1)
