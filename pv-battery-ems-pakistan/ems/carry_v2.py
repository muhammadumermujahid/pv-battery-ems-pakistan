"""Rules v2 with the state of charge carried between days (1,825 real days). good = forecast daily PV >= thr; forecast = oracle or yesterday's PV."""
import json, datetime as dt, numpy as np
import ems10 as E
from ems10 import *
HOT = {4,5,6,7,8,9,10}
raw = [l.strip().split(',') for l in open('data/pvgis_series_2016_2020_raw.csv') if l[:2] == '20' and ':' in l[:9]]
t0 = dt.datetime(int(raw[0][0][:4]), int(raw[0][0][4:6]), int(raw[0][0][6:8]), int(raw[0][0][9:11]))
G = np.array([float(r[1]) for r in raw]); hrs = np.arange(len(G)) + 0.5; emax = CFG['batt_kwh']
variants = {'v1': (None, None), 'v2 oracle 25': ('o', 25), 'v2 persist 25': ('p', 25), 'v2 persist 5': ('p', 5), 'v2 persist 35': ('p', 35), 'v2 always': ('o', 0)}
soc = {k: 0.5 for k in variants}; cost = {k: [] for k in variants}; days = []
d = dt.date(2016, 1, 2); prev = None
while d <= dt.date(2020, 12, 30):
    start = (dt.datetime(d.year, d.month, d.day) - t0).total_seconds() / 3600 - 5.0
    g = np.interp(start + H + DT / 2, hrs, G); pv = np.minimum(CFG['pv_kwp'] * g / 1000 * CFG['pv_pr'], CFG['inv_kw']); e = float(pv.sum() * DT)
    ls = 'summer' if d.month in HOT else 'winter'; set_season_tariff(ls); fixed = fixed_load(ls); L = shiftables(ls)
    for k, (kind, thr) in variants.items():
        f = e if kind == 'o' else (prev if prev is not None else e)
        good = None if kind is None else bool(f >= thr)
        CFG['soc0'] = soc[k]; sh, ch, dis, Eb = rule_schedule(L, pv, fixed, good=good); r, _ = account('x', pv, fixed, sh, ch, dis, Eb)
        soc[k] = float(Eb[-1] / emax); cost[k].append(r['total'])
    prev = e; days.append((str(d), ls)); d += dt.timedelta(days=1)
C = json.load(open('carry.json')); HS = np.array(C['HS']); MO = np.array(C['MO']); s = np.array([x[1] for x in days])
for nm, m in (('hot', s == 'summer'), ('cool', s == 'winter'), ('all', s != '')):
    print(nm, {k: round(100 * (HS[m].sum() - np.sum(np.array(v)[m])) / (HS[m].sum() - MO[m].sum()), 1) for k, v in cost.items()})
json.dump({k: v for k, v in cost.items()}, open('carry_v2.json', 'w'))
