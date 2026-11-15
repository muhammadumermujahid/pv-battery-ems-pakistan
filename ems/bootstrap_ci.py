"""Bootstrap confidence intervals for the capture ratio over the 1,825 real days (variability.json, v2days.json).
rho = (sum SC - sum rules) / (sum SC - sum MILP). Day resampling and month-block resampling, 10,000 draws, seed 1."""
import json, numpy as np
rng = np.random.default_rng(1); B = 10000
v = json.load(open('variability.json')); d2 = json.load(open('v2days.json'))
assert all(a['date'] == b['date'] for a, b in zip(v, d2))
sc = np.array([x['cost'][1] for x in v]); r1 = np.array([x['cost'][2] for x in v]); mi = np.array([x['cost'][3] for x in v])
r2 = np.array([x['g1_h0'] for x in d2])          # v2 variant: off-peak discharge allowed on every day (no forecast)
m = np.array([x['month'] for x in v]); yr = np.array([int(x['date'][:4]) for x in v]); n = len(v)
def rho(a, i): return (sc[i].sum() - a[i].sum()) / (sc[i].sum() - mi[i].sum())
keys = yr * 100 + m; blocks = [np.where(keys == k)[0] for k in np.unique(keys)]
def ci_day(a, idx):  return np.percentile([rho(a, idx[rng.integers(0, len(idx), len(idx))]) for _ in range(B)], [2.5, 97.5])
def ci_block(a):     return np.percentile([rho(a, np.concatenate([blocks[p] for p in rng.integers(0, len(blocks), len(blocks))])) for _ in range(B)], [2.5, 97.5])
def ci_mean(x):      return np.percentile([x[rng.integers(0, n, n)].mean() for _ in range(B)], [2.5, 97.5])
allidx = np.arange(n); hot = np.isin(m, [4, 5, 6, 7, 8, 9, 10]); out = {'n_days': n, 'B': B, 'seed': 1}
for nm, a in (('v1', r1), ('v2_offpeak_every_day', r2)):
    out[nm] = {'rho': rho(a, allidx), 'ci_day': list(ci_day(a, allidx)), 'ci_month_block': list(ci_block(a)),
               'hot_AprOct': {'rho': rho(a, np.where(hot)[0]), 'ci_day': list(ci_day(a, np.where(hot)[0]))},
               'cool_NovMar': {'rho': rho(a, np.where(~hot)[0]), 'ci_day': list(ci_day(a, np.where(~hot)[0]))},
               'per_year': {int(y): rho(a, np.where(yr == y)[0]) for y in np.unique(yr)}}
out['saving_rules_vs_SC'] = {'mean': (sc - r1).mean(), 'ci': list(ci_mean(sc - r1))}
out['gap_rules_minus_MILP'] = {'mean': (r1 - mi).mean(), 'ci': list(ci_mean(r1 - mi))}
out['v2_minus_v1_saving'] = {'mean': (r1 - r2).mean(), 'ci': list(ci_mean(r1 - r2))}
json.dump(out, open('bootstrap_ci.json', 'w'), indent=1)
print(json.dumps(out, indent=1))
