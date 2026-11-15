"""Does grid charging explain the gap between rules and MILP?  (a) rules + off-peak grid top-up; (b) MILP forbidden to charge from the grid."""
import json, numpy as np
import ems10 as E
from ems10 import *
out={}
R=json.load(open('results.json'))['seasons']
for season in ('summer','winter','cloudy'):
    set_season_tariff(season)
    pv=pv_profile(season); fixed=fixed_load(S0(season)); L=shiftables(S0(season))
    sc=R[season]['scenarios']; base,rules,milp=sc[1]['total'],sc[2]['total'],sc[3]['total']
    sh,ch,dis,Eb=rule_schedule(L,pv,fixed,gridcharge=True)
    r_gc,_=account('rules+gc',pv,fixed,sh,ch,dis,Eb)
    sh,ch,dis,Eb,gap,obj=solve_milp(L,pv,fixed,ngc=True)
    m_n,_=account('milp no gc',pv,fixed,sh,ch,dis,Eb)
    # also: grid energy bought into battery in the free MILP
    sh,ch,dis,Eb,gap,obj=solve_milp(L,pv,fixed)
    m_f,d=account('milp',pv,fixed,sh,ch,dis,Eb)
    gc_kwh=float(np.maximum(ch-np.maximum(pv-(fixed+sh.sum(0)),0),0).sum()*DT)
    out[season]=dict(base=base,rules=rules,milp=milp,rules_gc=r_gc['total'],milp_nogc=m_n['total'],milp_grid_to_batt_kwh=gc_kwh,
       rho=(base-rules)/(base-milp),rho_rules_gc=(base-r_gc['total'])/(base-milp),rho_milp_nogc=(base-rules)/(base-m_n['total']))
    print(season,{k:round(v,3) for k,v in out[season].items()})
json.dump(out,open('gridcharge.json','w'),indent=1)
