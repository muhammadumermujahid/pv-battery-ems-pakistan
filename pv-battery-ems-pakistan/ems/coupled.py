"""Couple the Simulink plant to the EMS: PV power reaching the AC bus is scaled by the simulated PV-to-AC efficiency
(96.9 % at 1000 W/m2, 95.3 % at 600 W/m2, linear in between, 95.3 % below 600 - the lowest measured point).
This is applied on top of PR=0.78, so it is a conservative (double-counting) stress test."""
import json, numpy as np
import ems10 as E
from ems10 import *
def eff(pv):
    x = np.clip(pv/10.0, 0, 1)       # irradiance fraction (10 kWp)
    return np.where(x>=0.6, 0.953+(0.969-0.953)*(x-0.6)/0.4, 0.953)
out={}
for season in ('summer','winter','cloudy'):
    set_season_tariff(season)
    pv0=pv_profile(season); pv=pv0*eff(pv0)
    fixed=fixed_load(S0(season)); L=shiftables(S0(season)); hab=habitual_profile(L); z=np.zeros(T)
    ch,dis,Eb=run_battery(pv,fixed+hab.sum(0),lambda t,e:True); s1,_=account('sc',pv,fixed,hab,ch,dis,Eb)
    sh,ch,dis,Eb=rule_schedule(L,pv,fixed); s2,_=account('rules',pv,fixed,sh,ch,dis,Eb)
    sh,ch,dis,Eb,g,o=solve_milp(L,pv,fixed); s3,_=account('milp',pv,fixed,sh,ch,dis,Eb)
    b,r,m=s1['total'],s2['total'],s3['total']
    out[season]=dict(pv_kwh=float(pv.sum()*DT),pv_kwh_ideal=float(pv0.sum()*DT),sc=b,rules=r,milp=m,rho=(b-r)/(b-m),peak_sc=s1['peak_import_kwh'],peak_rules=s2['peak_import_kwh'],peak_milp=s3['peak_import_kwh'])
    print(season,{k:round(v,3) for k,v in out[season].items()})
json.dump(out,open('coupled.json','w'),indent=1)
