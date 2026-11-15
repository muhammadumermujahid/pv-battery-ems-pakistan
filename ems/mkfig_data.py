import json,numpy as np,matplotlib; matplotlib.use('Agg')
import os; os.makedirs("figures", exist_ok=True)
import matplotlib.pyplot as plt
import sys; sys.path.insert(0,'.')
import ems10 as m
plt.rcParams.update({'font.family':'serif','font.serif':['Times New Roman','Liberation Serif','DejaVu Serif'],'font.size':7,'axes.linewidth':0.6,'xtick.major.width':0.6,'ytick.major.width':0.6,'mathtext.fontset':'stix'})
C={'grid':'#EDB120','selfc':'#0072BD','rules':'#D95319','rules2':'#77AC30','milp':'#7E2F8E'}
R=json.load(open('results.json'))
# ---- Fig: cost bars, grouped
names=['PV only','PV + battery','Rules v1','Rules v2','MILP']; cols=[C['grid'],C['selfc'],C['rules'],C['rules2'],C['milp']]; IDX=[0,1,2,4,3]
days=[('summer','Summer'),('winter','Winter'),('cloudy','Overcast')]
fig,ax=plt.subplots(figsize=(3.3,2.15))
w=0.16
for gi,(k,lab) in enumerate(days):
    sc=R['seasons'][k]['scenarios']
    for i in range(5):
        x=gi+(i-2)*w*1.05; val=sc[IDX[i]]['total']
        ax.bar(x,val,w,color=cols[i],linewidth=0,label=names[i] if gi==0 else None)
        ax.text(x,val+(28 if val>=0 else -28),f'{val:.0f}'.replace('-','−'),ha='center',va='bottom' if val>=0 else 'top',fontsize=5.0)
ax.axhline(0,color='#222',lw=0.6)
ax.set_xticks(range(3)); ax.set_xticklabels([d[1] for d in days],fontweight='bold'); ax.tick_params(axis='x',length=0,pad=3)
ax.set_ylabel('Adjusted daily cost (PKR)'); ax.set_ylim(-540,1360)
ax.grid(axis='y',lw=0.5,color='#d9d9d9'); ax.set_axisbelow(True)
for s_ in ('top','right','left'): ax.spines[s_].set_visible(False)
ax.tick_params(axis='y',length=0)
ax.legend(ncol=5,loc='upper center',bbox_to_anchor=(0.5,1.14),frameon=False,fontsize=5.8,handlelength=0.8,handleheight=0.8,columnspacing=0.8,handletextpad=0.3,prop={'weight':'bold','size':5.8})
fig.tight_layout(pad=0.3); fig.savefig('figures/fig_cost_by_strategy.png',dpi=600,facecolor='white'); plt.close(fig)
# ---- Fig: summer SOC and grid
S=np.load('data/series.npy',allow_pickle=True).item()['summer']; H=m.H
r=S['runs']
fig,(a,b)=plt.subplots(2,1,figsize=(3.3,3.05),sharex=True,gridspec_kw={'height_ratios':[1,1.05],'hspace':0.12})
for ax in (a,b): ax.axvspan(19,23,color='#e6e6e6',alpha=0.8,lw=0); ax.grid(lw=0.3,color='#ccc'); ax.set_axisbelow(True)
for idx,key,lab,lw,z in ((1,'selfc','PV + battery',1.3,2),(3,'milp','MILP optimum',1.9,3),(2,'rules','Rules v1',1.0,4),(4,'rules2','Rules v2',1.0,5)):
    a.plot(H,r[idx]['E']/15*100,color=C[key],lw=lw,ls='-',label=lab,zorder=z)
for idx,key,lab,lw,z in ((3,'milp','MILP optimum',1.9,3),(2,'rules','Rules v1',1.0,4),(4,'rules2','Rules v2',1.0,5)):
    b.plot(H,r[idx]['imp']-r[idx]['exp'],color=C[key],lw=lw,ls='-',label=lab,zorder=z)
a.set_ylabel('State of charge (%)'); a.set_ylim(0,105); a.text(0.01,0.93,'(a)',transform=a.transAxes,fontweight='bold',va='top')
b.set_ylabel('Grid power (kW)\nimport +, export −'); b.axhline(0,color='#222',lw=0.5); b.text(0.01,0.93,'(b)',transform=b.transAxes,fontweight='bold',va='top')
a.text(21,12,'peak\n19–23 h',ha='center',fontsize=6,color='#555')
b.set_xlim(0,24); b.set_xticks(range(0,25,3)); b.set_xticklabels([f'{h:02d}:00' for h in range(0,25,3)]); b.set_xlabel('Time of day (h)')
hh,ll=a.get_legend_handles_labels(); o=[ll.index(n) for n in ('PV + battery','Rules v1','Rules v2','MILP optimum')]
a.legend([hh[i] for i in o],[ll[i] for i in o],loc='lower center',ncol=4,frameon=False,handlelength=1.5,columnspacing=1.0,bbox_to_anchor=(0.5,1.0),prop={'weight':'bold','size':6.2})
for ax in (a,b):
    for s_ in ('top','right'): ax.spines[s_].set_visible(False)
fig.subplots_adjust(left=0.15,right=0.955,top=0.93,bottom=0.115,hspace=0.12)
fig.savefig('figures/fig_summer_soc_grid.png',dpi=600,facecolor='white'); plt.close(fig)
