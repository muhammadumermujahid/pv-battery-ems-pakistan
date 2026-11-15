import ems10 as m, numpy as np, copy, io, contextlib, json
base=copy.deepcopy(m.CFG); SENS=[]
def run(label=None, **kw):
    m.CFG.update(copy.deepcopy(base)); m.CFG.update(kw)
    with contextlib.redirect_stdout(io.StringIO()):
        o,_=m.main()
    row=dict(case=label or str(kw))
    for s in ('summer','winter'):
        v=o['seasons'][s]; sc=v['scenarios']
        row[s]=dict(baseline=sc[1]['total'], rule=sc[2]['total'], milp=sc[3]['total'], rule_share=v['rule_share_of_achievable'], rule2=sc[4]['total'], rule2_share=v['rule2_share_of_achievable'])
    SENS.append(row)
run('Base case'); run('Degradation 0 PKR/kWh',degr=0.0); run('Degradation 13.4 PKR/kWh (warranty throughput)',degr=13.4)
run('Export price 20 PKR/kWh',export_price=20.0); run('Export price 5 PKR/kWh',export_price=5.0)
run('Earlier assumed tariff 30/55 PKR/kWh, 17-22 h',tariff_off=30.0,tariff_peak=55.0,peak=dict(summer=(17.0,22.0),winter=(17.0,22.0)))
run('Winter peak 17-21 h (another source)',peak=dict(summer=(19.0,23.0),winter=(17.0,21.0)))
run('Peak 18-22 h in both seasons (earlier assumption)',peak=dict(summer=(18.0,22.0),winter=(18.0,22.0)))
run('Degradation 5 PKR/kWh (earlier assumption)',degr=5.0)
run('Battery 10 kWh',batt_kwh=10.0)
run('Base case')   # restores results.json and series
json.dump(SENS,open('sensitivity.json','w'),indent=1)
