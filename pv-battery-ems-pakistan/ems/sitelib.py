"""Shared helpers: load a PVGIS-ERA5 hourly series (2016-2020, UTC labels hh:30, local time UTC+5) and cut it into daily 15-min PV profiles."""
import datetime as dt, numpy as np
import ems10 as E
from ems10 import *
HOT = {4,5,6,7,8,9,10}
SITES = ['islamabad','lahore','multan','peshawar','quetta','karachi']
def load_days(site):
    raw = [l.strip().split(',') for l in open(f'data/sites/{site}.csv') if l[:2] == '20' and ':' in l[:9]]
    t0 = dt.datetime(int(raw[0][0][:4]), int(raw[0][0][4:6]), int(raw[0][0][6:8]), int(raw[0][0][9:11]))
    G = np.array([float(r[1]) for r in raw]); hrs = np.arange(len(G)) + 0.5
    d = dt.date(2016, 1, 2); days = []
    while d <= dt.date(2020, 12, 30):
        start = (dt.datetime(d.year, d.month, d.day) - t0).total_seconds() / 3600 - 5.0
        g = np.interp(start + H + DT / 2, hrs, G)
        days.append((d, np.minimum(CFG['pv_kwp'] * g / 1000 * CFG['pv_pr'], CFG['inv_kw'])))
        d += dt.timedelta(days=1)
    return days
def setup(d):
    ls = 'summer' if d.month in HOT else 'winter'; set_season_tariff(ls)
    return ls, fixed_load(ls), shiftables(ls)
