"""Rules v2 with better forecasts and a site-independent threshold, tested at six Pakistani sites (PVGIS-ERA5 2016-2020).
Train = 2016-2018, test = 2019-2020. Capture rho = (J_SC - J_rule)/(J_SC - J_MILP). -> site_forecast.json"""
import json, numpy as np
from sitelib import SITES
B = json.load(open('site_base.json')); LV = json.load(open('site_levels.json'))
FL = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
yr = lambda r: int(r['date'][:4])
D = {}
for s in SITES:
    b = B[s]; n = len(b)
    D[s] = dict(pv=np.array([r['pv'] for r in b]), sc=np.array([r['sc'] for r in b]), v1=np.array([r['v1'] for r in b]), mi=np.array([r['milp'] for r in b]),
                pk1=np.array([r['pk_v1'] for r in b]), yr=np.array([yr(r) for r in b]), doy=np.array([int(np.floor(i % 365.25)) for i in range(n)]),
                cost=np.array([x['cost'] for x in LV[s]]), peak=np.array([x['peak'] for x in LV[s]]))
    D[s]['tr'] = D[s]['yr'] <= 2018; D[s]['te'] = ~D[s]['tr']
    D[s]['mean'] = D[s]['pv'][D[s]['tr']].mean()
rng = np.random.default_rng(1)
def shifted(a, k):                       # value k days earlier (first days repeat day 0)
    return np.concatenate([np.full(k, a[0]), a[:-k]])
def forecasts(s):
    p = D[s]['pv']; n = len(p); F = {}
    F['persistence'] = shifted(p, 1)
    F['min of last 2 days'] = np.minimum(shifted(p, 1), shifted(p, 2))
    F['min of last 3 days'] = np.minimum(np.minimum(shifted(p, 1), shifted(p, 2)), shifted(p, 3))
    F['3-day mean'] = (shifted(p, 1) + shifted(p, 2) + shifted(p, 3)) / 3
    t30 = np.array([p[max(0, i - 30):i].mean() if i else p[0] for i in range(n)])
    F['30-day mean'] = t30
    F['blend 0.5/0.5'] = 0.5 * shifted(p, 1) + 0.5 * t30
    # climatology of the training years (same +-15 days of the year)
    tr = D[s]['tr']; doy = D[s]['doy']
    clim = np.array([p[tr & (np.abs(((doy - d + 183) % 365) - 183) <= 15)].mean() for d in doy]); F['_clim'] = clim
    return F
# pooled regression in relative units (training years, all sites): p_i/m ~ a + b p1/m + c p2/m + d t30/m + e clim/m
X = []; Y = []
for s in SITES:
    F = forecasts(s); m = D[s]['mean']; p = D[s]['pv']; tr = D[s]['tr']
    f = np.c_[np.ones(len(p)), shifted(p, 1) / m, shifted(p, 2) / m, F['30-day mean'] / m, F['_clim'] / m]
    X.append(f[tr]); Y.append((p / m)[tr])
beta = np.linalg.lstsq(np.vstack(X), np.concatenate(Y), rcond=None)[0]; print('beta', beta.round(3))
for s in SITES:
    F = forecasts(s); m = D[s]['mean']; p = D[s]['pv']
    f = np.c_[np.ones(len(p)), shifted(p, 1) / m, shifted(p, 2) / m, F['30-day mean'] / m, F['_clim'] / m]
    F['regression'] = (f @ beta) * m
    F['climatology only'] = F.pop('_clim')
    for sig in (0.15, 0.30): F[f'perfect + {int(sig*100)} % error'] = p * (1 + sig * rng.standard_normal(len(p)))
    F['perfect'] = p.copy(); D[s]['F'] = F
FN = ['persistence', 'min of last 2 days', 'min of last 3 days', '3-day mean', '30-day mean', 'blend 0.5/0.5', 'climatology only', 'regression', 'perfect + 30 % error', 'perfect + 15 % error', 'perfect']
def rho(s, J, mask): d = D[s]; return float((d['sc'][mask] - J[mask]).sum() / (d['sc'][mask] - d['mi'][mask]).sum() * 100)
def pick_binary(s, fc, thr): return np.where(fc >= thr, D[s]['cost'][:, 0], D[s]['v1'])          # v2: off-peak discharge on (floor 0.2) if forecast >= thr
def pick_graded(s, fc, lo, hi):                                                                   # v3: floor falls linearly from none (<= lo) to 0.2 (>= hi)
    m = D[s]['mean']; x = (fc / m - lo) / (hi - lo); x = np.clip(x, 0, 1)
    idx = np.where(x <= 0, -1, np.minimum(len(FL) - 1, np.round((1 - x) * (len(FL) - 1)).astype(int)))
    J = D[s]['cost'][np.arange(len(x)), np.maximum(idx, 0)]; return np.where(idx < 0, D[s]['v1'], J)
out = {'beta': beta.tolist(), 'sites': {}}
# threshold fraction f of the site's mean daily PV chosen on training years of Islamabad with persistence
fs = np.arange(0.2, 1.01, 0.05)
tr_all = lambda s: D[s]['tr']
best = {}
for fn in FN:
    sc = [np.mean([rho(s, pick_binary(s, D[s]['F'][fn], f * D[s]['mean']), tr_all(s)) for s in SITES]) for f in fs]
    best[fn] = float(fs[int(np.argmax(sc))])
print('best f (pooled, training years):', {k: round(v, 2) for k, v in best.items()})
print('Islamabad: 25 kWh =', round(25 / D['islamabad']['mean'], 3), 'x mean daily PV', round(D['islamabad']['mean'], 1), 'kWh')
tab = {}
for fn in FN:
    f = best[fn]; tab[fn] = {s: rho(s, pick_binary(s, D[s]['F'][fn], f * D[s]['mean']), D[s]['te']) for s in SITES}
    tab[fn]['mean'] = float(np.mean([tab[fn][s] for s in SITES]))
v1 = {s: rho(s, D[s]['v1'], D[s]['te']) for s in SITES}; v1['mean'] = float(np.mean(list(v1.values())))
print('test-year rho (%), binary v2 with threshold f chosen on training years of all sites')
print('%-24s' % 'forecast', *['%9s' % s[:8] for s in SITES], '%7s' % 'mean')
print('%-24s' % 'v1', *['%9.1f' % v1[s] for s in SITES], '%7.1f' % v1['mean'])
for fn in FN: print('%-24s' % fn, *['%9.1f' % tab[fn][s] for s in SITES], '%7.1f' % tab[fn]['mean'], ' f=%.2f' % best[fn])
# leave-one-site-out: choose f on the other sites, test on the held-out site (persistence)
loso = {}
for fn in ('persistence', 'regression'):
    r = {}
    for h in SITES:
        oth = [s for s in SITES if s != h]
        sc = [np.mean([rho(s, pick_binary(s, D[s]['F'][fn], f * D[s]['mean']), tr_all(s)) for s in oth]) for f in fs]; f = fs[int(np.argmax(sc))]
        r[h] = (float(f), rho(h, pick_binary(h, D[h]['F'][fn], f * D[h]['mean']), D[h]['te']))
    loso[fn] = r; print('leave-one-site-out', fn, {h: (round(a, 2), round(b, 1)) for h, (a, b) in r.items()})
# fixed 25 kWh (absolute) everywhere vs relative threshold, persistence
ab = {s: rho(s, pick_binary(s, D[s]['F']['persistence'], 25.0), D[s]['te']) for s in SITES}; print('absolute 25 kWh, persistence:', {k: round(v, 1) for k, v in ab.items()})
# dull days: 100 dullest test days per site, persistence vs regression vs perfect
dull = {}
for fn in ('persistence', 'regression', 'perfect + 30 % error', 'perfect'):
    f = best[fn]; r = {}
    for s in SITES:
        p = D[s]['pv']; te = D[s]['te']; thr = np.sort(p[te])[min(39, te.sum() - 1)]; mk = te & (p <= thr)        # dullest ~5 % of test days
        r[s] = (rho(s, pick_binary(s, D[s]['F'][fn], f * D[s]['mean']), mk), rho(s, D[s]['v1'], mk))
    dull[fn] = r
print('dullest 40 test days per site (rho v2 / v1):', {fn: {s: tuple(round(x, 0) for x in v) for s, v in r.items()} for fn, r in dull.items()})
# graded reserve, tuned on training years (pooled, persistence and regression)
gr = {}
for fn in ('persistence', 'regression'):
    bestg = None
    for lo in np.arange(0.2, 0.8, 0.1):
        for hi in np.arange(lo + 0.2, 1.31, 0.1):
            sc = np.mean([rho(s, pick_graded(s, D[s]['F'][fn], lo, hi), D[s]['tr']) for s in SITES])
            if bestg is None or sc > bestg[0]: bestg = (sc, lo, hi)
    _, lo, hi = bestg; gr[fn] = dict(lo=float(lo), hi=float(hi), test={s: rho(s, pick_graded(s, D[s]['F'][fn], lo, hi), D[s]['te']) for s in SITES})
    gr[fn]['test']['mean'] = float(np.mean(list(gr[fn]['test'].values()))); print('graded', fn, round(lo, 1), round(hi, 1), {k: round(v, 1) for k, v in gr[fn]['test'].items()})
# peak import days (test years), best binary rule vs v1
pk = {}
for fn in ('persistence', 'regression'):
    f = best[fn]; pk[fn] = {s: (float((np.where(D[s]['F'][fn] >= f * D[s]['mean'], D[s]['peak'][:, 0], D[s]['pk1'])[D[s]['te']] > 0.05).mean() * 100)) for s in SITES}
print('share of test days with peak-window import (%):', {fn: {s: round(v, 1) for s, v in r.items()} for fn, r in pk.items()}, 'v1', {s: round(float((D[s]['pk1'][D[s]['te']] > 0.05).mean() * 100), 1) for s in SITES})
# trade-off: threshold fraction vs capture on all test days, on the dullest 40 test days, rupees lost against v1 on those days, and peak-import days
trade = {}
for fn in ('persistence', 'min of last 2 days', 'min of last 3 days', 'regression', 'perfect + 30 % error', 'perfect'):
    rows = []
    for f in (0.2, 0.35, 0.55, 0.7, 0.85):
        a = []; d = []; lost = []; pkd = []
        for s in SITES:
            p = D[s]['pv']; te = D[s]['te']; thr = np.sort(p[te])[39]; mk = te & (p <= thr)
            J = pick_binary(s, D[s]['F'][fn], f * D[s]['mean'])
            a.append(rho(s, J, te)); d.append(rho(s, J, mk)); lost.append(float((J[mk] - D[s]['v1'][mk]).mean()))
            pkd.append(float((np.where(D[s]['F'][fn] >= f * D[s]['mean'], D[s]['peak'][:, 0], D[s]['pk1'])[te] > 0.05).mean() * 100))
        rows.append(dict(f=f, rho_all=float(np.mean(a)), rho_dull=float(np.mean(d)), extra_cost_dull=float(np.mean(lost)), peak_days=float(np.mean(pkd))))
    trade[fn] = rows
    print(fn, [(r['f'], round(r['rho_all'], 1), round(r['rho_dull']), round(r['extra_cost_dull']), round(r['peak_days'], 1)) for r in rows])
out['tradeoff'] = trade
out.update(best_f=best, v1=v1, table=tab, loso=loso, absolute25=ab, dull={k: v for k, v in dull.items()}, graded=gr, peakdays=pk, mean_pv={s: float(D[s]['mean']) for s in SITES})
json.dump(out, open('site_forecast.json', 'w'), indent=1)
