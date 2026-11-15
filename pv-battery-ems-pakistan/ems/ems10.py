"""10 kW smart-home EMS: baseline vs rule-based vs MILP benchmark.
Every number in the paper comes from results.json written by this script."""
import json, math, numpy as np
from scipy.optimize import milp, LinearConstraint, Bounds
from scipy.sparse import lil_matrix

DT = 0.25; T = 96                      # 15-minute slots
H = np.arange(T) * DT                  # slot start hour

CFG = dict(
    v2_thr=25.0,                                   # rules v2: off-peak battery discharge allowed when forecast daily PV >= v2_thr kWh
    pv_kwp=10.0, inv_kw=10.0, pv_pr=0.78, use_pvgis=True,   # pv_pr: performance ratio = 0.86 (PVGIS 14 % system losses) x 0.91 (thermal derating, assumed)
    batt_kwh=15.0, batt_kw=5.0, eta=0.96, soc_min=0.20, soc0=0.50,
    tariff_off=34.53, tariff_peak=46.85,   # PKR/kWh, IESCO A-1 ToU, S.R.O. 279(I)/2026 (Feb 2026), accessed 13 Nov 2026
    peak=dict(summer=(19.0, 23.0), winter=(18.0, 22.0)),   # ToU peak: 19:00-23:00 summer (Apr-Oct), 18:00-22:00 winter (Nov-Mar); secondary sources (mepco-online.com.pk, Daily Pakistan 21 Aug 2025), not a primary NEPRA notification
    export_price=10.5,                                      # PKR/kWh  (NEPRA net billing ~Rs10-11, Dawn/ARY, accessed 13 Nov 2026)
    degr=7.7,                                               # PKR per kWh discharged = 627000 PKR / (6000 cycles x 0.9 DoD x 15 kWh), Solar Citizen price + Deye datasheet
    pv_day_kwh=dict(summer=46.0, winter=26.0, cloudy=15.0),   # 'cloudy' = summer loads and tariff with heavy overcast (about one third of the clear-day PV energy)
    daylight=dict(summer=(5.5, 19.0), winter=(7.0, 17.5)),
)
tariff = np.zeros(T); is_peak = np.zeros(T, bool)
def S0(season): return 'summer' if season == 'cloudy' else season   # the cloudy day uses summer loads, tariff and daylight
def set_season_tariff(season):
    season = S0(season)
    a, b = CFG['peak'][season] if isinstance(CFG['peak'], dict) else CFG['peak']
    tariff[:] = np.where((H >= a) & (H < b), CFG['tariff_peak'], CFG['tariff_off'])
    is_peak[:] = tariff > CFG['tariff_off']
set_season_tariff('summer')

import os
PVGIS = {'summer': 'data/pvgis_june.csv', 'cloudy': 'data/pvgis_june.csv', 'winter': 'data/pvgis_december.csv'}
def pvgis_profile(season):
    """Average-day PV power from PVGIS-ERA5 irradiance on the tilted plane (UTC+5 local time), P = kWp * G/1000 * PR, clipped at the inverter rating."""
    f = PVGIS.get(season)
    if not CFG.get('use_pvgis', True) or f is None or not os.path.exists(f): return None
    rows = [l.strip().split(',') for l in open(f) if l[0] not in '#u' and l.strip()]
    hr = (np.array([float(r[0]) for r in rows]) + 5.0) % 24; G = np.array([float(r[1]) for r in rows])
    o = np.argsort(hr); hr, G = hr[o], G[o]
    t = H + DT / 2
    g = np.interp(t, np.r_[hr - 24, hr, hr + 24], np.r_[G, G, G])
    p = np.minimum(CFG['pv_kwp'] * g / 1000 * CFG['pv_pr'], CFG['inv_kw'])
    if season == 'cloudy': p *= CFG['pv_day_kwh']['cloudy'] / (p.sum() * DT)
    return p

def pv_profile(season):
    q = pvgis_profile(season)
    if q is not None: return q
    a, b = CFG['daylight'][S0(season)]
    x = np.clip((H + DT/2 - a) / (b - a), 0, 1)
    p = np.sin(np.pi * x) ** 2.6
    p[(H < a) | (H >= b)] = 0
    # one passing cloud, 14:00-15:00 in summer, 11:00-12:00 in winter
    if season != 'cloudy':
        c0 = 14.0 if season == 'summer' else 11.0
        p[(H >= c0) & (H < c0 + 1)] *= 0.55
    p *= CFG['pv_day_kwh'][season] / (p.sum() * DT)
    return np.minimum(p, CFG['inv_kw'])

def win(*iv):
    m = np.zeros(T, bool)
    for a, b in iv: m |= (H >= a) & (H < b)
    return m

def fixed_load(season):
    """Fixed load = fridge, lights, fans, computer, ACs (summer), iron, kettle.
    Ratings are typical values from public sources, not measured."""
    f = np.full(T, 0.12)                                              # refrigerator, average 75-150 W
    f += 0.15 * win((18, 23)) if season == 'summer' else 0.15 * win((17.5, 23.5), (6, 7.5))   # LED lights
    f += 0.15 * win((9, 17))                                          # desktop computer
    if season == 'summer':
        f += 0.24 * win((0, 6), (10, 24))                             # 3 ceiling fans x 80 W
        f += 0.8 * win((22, 24), (0, 6)) + 1.0 * win((13, 17), (19, 23))     # inverter ACs (bedroom, living)
    f += 1.0 * win((8, 8.5))                                          # iron
    f += 1.5 * win((7, 7.25), (13, 13.25), (19.5, 19.75))             # electric kettle
    return f

# shiftable loads: kind block(P kW, hours) or energy(Pmax, kWh); allowed window; habitual start hour
def shiftables(season):
    L = [dict(n='Water pump', kind='block', P=0.75, hrs=1.0, allowed=win((6, 22)), hab=6.5),
         dict(n='Washing machine', kind='block', P=0.5, hrs=1.5, allowed=win((8, 20)), hab=18.0),
         dict(n='Dishwasher', kind='block', P=1.2, hrs=1.5, allowed=win((9, 23)), hab=21.5),
         dict(n='EV charger', kind='energy', P=3.3, E=6.0, allowed=win((0, 6), (9, 24)), hab=19.0)]
    # no water heater: the same four shiftable loads (pump, washing machine, dishwasher, EV) in every season
    return L

def habitual_profile(L):
    out = []
    for l in L:
        p = np.zeros(T); s = int(round(l['hab'] / DT))
        if l['kind'] == 'block':
            p[s:s + int(l['hrs'] / DT)] = l['P']
        else:
            rem = l['E']
            for t in range(s, T):
                e = min(l['P'] * DT, rem); p[t] = e / DT; rem -= e
                if rem <= 1e-9: break
        out.append(p)
    return np.array(out)

# ---------------------------------------------------------------- simulation
def run_battery(pv, load, policy):
    e = CFG['soc0'] * CFG['batt_kwh']; emin = CFG['soc_min'] * CFG['batt_kwh']; emax = CFG['batt_kwh']
    ch = np.zeros(T); dis = np.zeros(T); E = np.zeros(T); eta = CFG['eta']
    for t in range(T):
        net = pv[t] - load[t]
        if net > 0:
            c = min(net, CFG['batt_kw'], (emax - e) / (eta * DT)); ch[t] = max(c, 0); e += eta * ch[t] * DT
        elif policy(t, e):
            d = min(-net, CFG['batt_kw'], (e - emin) * eta / DT); dis[t] = max(d, 0); e -= dis[t] * DT / eta
        E[t] = e
    return ch, dis, E

def rule_schedule(L, pv, fixed, gridcharge=False, good=None, hold_pre=0.0, floor=None):
    """SOC- and tariff-aware rules (mirror of the Simulink controller). Returns shift power [n,T], battery arrays."""
    n = len(L); sh = np.zeros((n, T)); started = [False] * n; remE = [l.get('E', 0) for l in L]
    pk0v = int(np.argmax(is_peak))                       # first slot of the peak window
    e = CFG['soc0'] * CFG['batt_kwh']; emin = CFG['soc_min'] * CFG['batt_kwh']; emax = CFG['batt_kwh']; eta = CFG['eta']
    ch = np.zeros(T); dis = np.zeros(T); E = np.zeros(T)
    for t in range(T):
        soc = e / emax
        running = sh[:, t].copy()                       # blocks already running (pre-filled below)
        for i, l in enumerate(L):
            cur = running.sum() + 0
            surplus = pv[t] - fixed[t] - cur
            if l['kind'] == 'block':
                d = int(l['hrs'] / DT)
                if not started[i] and l['allowed'][t] and t + d <= T and l['allowed'][t:t + d].all():
                    later = [k for k in range(t + 1, T - d + 1) if l['allowed'][k:k + d].all()]
                    ok = (surplus >= 0.7 * l['P']) or (not is_peak[t] and soc >= 0.6)
                    if ok or not later:
                        started[i] = True; sh[i, t:t + d] = l['P']; running[i] = l['P']
            else:
                if remE[i] > 1e-9 and l['allowed'][t]:
                    need = math.ceil(remE[i] / (l['P'] * DT) - 1e-9)
                    left = int(l['allowed'][t:].sum())
                    go = (surplus >= 0.5 * l['P']) or (not is_peak[t] and soc >= 0.8) or left <= need
                    if go:
                        p = min(l['P'], remE[i] / DT); sh[i, t] = p; running[i] = p; remE[i] -= p * DT
        load = fixed[t] + sh[:, t].sum(); net = pv[t] - load
        if net > 0:
            c = min(net, CFG['batt_kw'], (emax - e) / (eta * DT)); ch[t] = max(c, 0); e += eta * ch[t] * DT
        elif is_peak[t] or soc > 0.8 or (good and not (pk0v - int(hold_pre / DT) <= t < pk0v)):   # peak window, nearly full, or (v2) a good PV day: discharge off-peak too, except just before the peak
            d = min(-net, CFG['batt_kw'], (e - emin) * eta / DT); dis[t] = max(d, 0); e -= dis[t] * DT / eta
        elif floor is not None and e > floor * emax:     # graded reserve (v3): off-peak discharge allowed down to a state-of-charge floor set by the forecast
            d = min(-net, CFG['batt_kw'], (e - floor * emax) * eta / DT); dis[t] = max(d, 0); e -= dis[t] * DT / eta
        if gridcharge and not is_peak[t] and not (pv[t] - load > 0) and dis[t] == 0:
            pk0 = int(np.argmax(is_peak))                # first peak slot; top up in the 2 h before it
            if pk0 - 8 <= t < pk0 and e < emax - 1e-9:
                c = min(CFG['batt_kw'], (emax - e) / (eta * DT)); ch[t] = c; e += eta * c * DT
        E[t] = e
    return sh, ch, dis, E

# ---------------------------------------------------------------- MILP
def solve_milp(L, pv, fixed, ngc=False):
    eta = CFG['eta']; emin = CFG['soc_min'] * CFG['batt_kwh']; emax = CFG['batt_kwh']; e0 = CFG['soc0'] * emax
    idx = {}; nv = 0
    def add(name, n):
        nonlocal nv; idx[name] = nv; nv += n
    for nm in ('imp', 'exp', 'ch', 'dis', 'e'): add(nm, T)
    for i, l in enumerate(L): add(f'x{i}', T)          # block: start binary; energy: power
    lb = np.zeros(nv); ub = np.full(nv, np.inf); integ = np.zeros(nv)
    ub[idx['ch']:idx['ch'] + T] = CFG['batt_kw']; ub[idx['dis']:idx['dis'] + T] = CFG['batt_kw']
    lb[idx['e']:idx['e'] + T] = emin; ub[idx['e']:idx['e'] + T] = emax
    rows = []; lo = []; hi = []
    A = lil_matrix((T * 3 + 4 * len(L) + 4, nv)); r = 0
    for t in range(T):
        # balance: pv + imp + dis - ch - exp - shift = fixed
        A[r, idx['imp'] + t] = 1; A[r, idx['dis'] + t] = 1; A[r, idx['ch'] + t] = -1; A[r, idx['exp'] + t] = -1
        for i, l in enumerate(L):
            if l['kind'] == 'energy': A[r, idx[f'x{i}'] + t] = -1
            else:
                d = int(l['hrs'] / DT)
                for k in range(max(0, t - d + 1), t + 1): A[r, idx[f'x{i}'] + k] = -l['P']
        lo.append(fixed[t] - pv[t]); hi.append(fixed[t] - pv[t]); r += 1
        # battery energy
        A[r, idx['e'] + t] = 1
        if t: A[r, idx['e'] + t - 1] = -1
        A[r, idx['ch'] + t] = -eta * DT; A[r, idx['dis'] + t] = DT / eta
        b = e0 if t == 0 else 0
        lo.append(b); hi.append(b); r += 1
    for i, l in enumerate(L):
        sl = slice(idx[f'x{i}'], idx[f'x{i}'] + T)
        if l['kind'] == 'block':
            d = int(l['hrs'] / DT); integ[sl] = 1
            for t in range(T):
                if not (t + d <= T and l['allowed'][t:t + d].all()): ub[idx[f'x{i}'] + t] = 0
                else: ub[idx[f'x{i}'] + t] = 1
            for t in range(T): A[r, idx[f'x{i}'] + t] = 1
            lo.append(1); hi.append(1); r += 1
        else:
            for t in range(T): ub[idx[f'x{i}'] + t] = l['P'] if l['allowed'][t] else 0
            for t in range(T): A[r, idx[f'x{i}'] + t] = DT
            lo.append(l['E']); hi.append(l['E']); r += 1
    if ngc:                                          # no grid charging: import never exceeds the load
        for t in range(T):
            A[r, idx['imp'] + t] = 1
            for i, l in enumerate(L):
                if l['kind'] == 'energy': A[r, idx[f'x{i}'] + t] = -1
                else:
                    d = int(l['hrs'] / DT)
                    for k in range(max(0, t - d + 1), t + 1): A[r, idx[f'x{i}'] + k] = -l['P']
            lo.append(-np.inf); hi.append(fixed[t]); r += 1
    A = A[:r].tocsr()
    c = np.zeros(nv)
    c[idx['imp']:idx['imp'] + T] = tariff * DT
    c[idx['exp']:idx['exp'] + T] = -CFG['export_price'] * DT
    c[idx['dis']:idx['dis'] + T] = CFG['degr'] * DT
    c[idx['e'] + T - 1] -= CFG['tariff_off'] * eta               # terminal stored-energy value
    res = milp(c, constraints=LinearConstraint(A, lo, hi), integrality=integ, bounds=Bounds(lb, ub),
               options=dict(time_limit=120, mip_rel_gap=1e-6))
    assert res.status == 0, res.message
    x = res.x; g = lambda nm: x[idx[nm]:idx[nm] + T].copy()
    sh = np.array([g(f'x{i}') if l['kind'] == 'energy' else
                   np.convolve(g(f'x{i}'), np.full(int(l['hrs'] / DT), l['P']))[:T] for i, l in enumerate(L)])
    return sh, g('ch'), g('dis'), g('e'), res.mip_gap, res.fun

# ---------------------------------------------------------------- accounting
def account(name, pv, fixed, sh, ch, dis, E):
    load = fixed + sh.sum(0); eta = CFG['eta']
    net = pv + dis - ch - load
    imp = np.maximum(-net, 0); exp = np.maximum(net, 0)
    resid = float(np.max(np.abs(pv + imp + dis - ch - exp - load)))
    assert resid < 1e-6, resid
    if ch.sum() + dis.sum() > 0:
        assert np.all(E >= CFG['soc_min'] * CFG['batt_kwh'] - 1e-6) and np.all(E <= CFG['batt_kwh'] + 1e-6)
        assert np.all(ch * dis < 1e-9)
    bill = float((imp * tariff).sum() * DT); credit = float(exp.sum() * DT * CFG['export_price'])
    degr = float(dis.sum() * DT * CFG['degr'])
    e_end = E[-1] if ch.sum() + dis.sum() > 0 else 0.0
    e0 = CFG['soc0'] * CFG['batt_kwh'] if ch.sum() + dis.sum() > 0 else 0.0
    term = (e0 - e_end) * CFG['tariff_off'] * eta                  # + = energy consumed from the store
    total = bill - credit + degr + term
    pv_used = float(pv.sum() * DT - exp.sum() * DT - ch.sum() * DT * 0)   # PV not exported (incl. to battery)
    return dict(name=name, bill=bill, export_credit=credit, degradation=degr, terminal_adj=float(term), total=float(total),
                import_kwh=float(imp.sum() * DT), export_kwh=float(exp.sum() * DT),
                peak_import_kwh=float(imp[is_peak].sum() * DT), load_kwh=float(load.sum() * DT),
                pv_kwh=float(pv.sum() * DT), self_consumption=pv_used / float(pv.sum() * DT),
                self_sufficiency=1 - float(imp.sum() / load.sum()), batt_throughput_kwh=float(dis.sum() * DT),
                balance_residual=resid), dict(imp=imp, exp=exp, E=E, ch=ch, dis=dis, sh=sh, load=load)

def main():
    out = dict(config={k: (v if not isinstance(v, np.ndarray) else v.tolist()) for k, v in CFG.items()}, seasons={})
    series = {}
    for season in ('summer', 'winter', 'cloudy'):
        set_season_tariff(season)
        pv = pv_profile(season); fixed = fixed_load(S0(season)); L = shiftables(S0(season))
        hab = habitual_profile(L); load_h = fixed + hab.sum(0)
        z = np.zeros(T)
        s0, d0 = account('Grid-tied PV only (no battery)', pv, fixed, hab, z, z, np.zeros(T))
        ch, dis, E = run_battery(pv, load_h, lambda t, e: True)
        s1, d1 = account('PV + battery, self-consumption', pv, fixed, hab, ch, dis, E)
        sh, ch, dis, E = rule_schedule(L, pv, fixed)
        s2, d2 = account('Rule-based EMS', pv, fixed, sh, ch, dis, E)
        good2 = bool(pv.sum() * DT >= CFG['v2_thr'])
        sh4, ch4, dis4, E4 = rule_schedule(L, pv, fixed, good=good2)
        s4, d4 = account('Rules v2 (forecast-aware discharge)', pv, fixed, sh4, ch4, dis4, E4)
        sh3, ch3, dis3, E3, gap, obj = solve_milp(L, pv, fixed)
        s3, d3 = account('MILP optimum (perfect foresight)', pv, fixed, sh3, ch3, dis3, E3)
        obj_full = obj + CFG['soc0'] * CFG['batt_kwh'] * CFG['tariff_off'] * CFG['eta']   # objective omits the constant e0 term
        assert abs(s3['total'] - obj_full) < 0.5, (s3['total'], obj_full)
        base = s1['total']; best = s3['total']
        gapcap = (s2['total'] - best)
        out['seasons'][season] = dict(
            scenarios=[s0, s1, s2, s3, s4], milp_gap=float(gap), rule2_share_of_achievable=(base - s4['total']) / (base - best) if base != best else None,
            saving_rule_vs_baseline=base - s2['total'], saving_milp_vs_baseline=base - best,
            rule_share_of_achievable=(base - s2['total']) / (base - best) if base != best else None,
            appliances=[dict(name=l['n'], kind=l['kind'], P=l['P'], energy_kwh=(l['E'] if l['kind'] == 'energy' else l['P'] * l['hrs'])) for l in L],
            load_kwh_fixed=float(fixed.sum() * DT), load_kwh_shift=float(hab.sum() * DT), pv_kwh=float(pv.sum() * DT),
            peak_load_kw=float(load_h.max()))
        series[season] = dict(L=[l['n'] for l in L], pv=pv, fixed=fixed, hab=hab, runs=[d0, d1, d2, d3, d4])
        # Simulink input table (1-minute zero-order hold)
        mins = np.arange(1440); sl = (mins // 15)
        import csv
        with open(f'data/simulink_inputs_{season}.csv', 'w', newline='') as f:
            w = csv.writer(f); w.writerow(['minute', 'pv_kW', 'fixed_load_kW', 'tariff_PKR_per_kWh'] + [f'habitual_{n}_kW' for n in series[season]['L']])
            for m in mins:
                w.writerow([m, round(pv[sl[m]], 4), round(fixed[sl[m]], 4), tariff[sl[m]]] + [round(hab[i, sl[m]], 4) for i in range(len(L))])
    json.dump(out, open('results.json', 'w'), indent=1)
    np.save('data/series.npy', series, allow_pickle=True)
    return out, series

if __name__ == '__main__':
    o, _ = main()
    for s, v in o['seasons'].items():
        print(s, 'PV', round(v['pv_kwh'], 1), 'fixed', round(v['load_kwh_fixed'], 1), 'shift', round(v['load_kwh_shift'], 1), 'peak kW', round(v['peak_load_kw'], 2), 'gap', v['milp_gap'])
        for sc in v['scenarios']:
            print(f"  {sc['name']:38s} total {sc['total']:9.0f} bill {sc['bill']:8.0f} cred {sc['export_credit']:7.0f} deg {sc['degradation']:6.0f} term {sc['terminal_adj']:6.0f} imp {sc['import_kwh']:5.1f} exp {sc['export_kwh']:5.1f} pk {sc['peak_import_kwh']:5.1f} SC {sc['self_consumption']:.2f}")
        print('  rule share of achievable saving:', v['rule_share_of_achievable'])
