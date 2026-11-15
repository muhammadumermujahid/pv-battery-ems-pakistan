import pandas as pd, numpy as np, matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
plt.rcParams.update({'font.family':'serif','font.serif':['Times New Roman','Liberation Serif','DejaVu Serif'],'font.size':7,'axes.linewidth':0.6,'xtick.major.width':0.6,'ytick.major.width':0.6,'legend.fontsize':6.5,'legend.frameon':False})
B,O,Y,G='#0072BD','#D95319','#EDB120','#7E2F8E'
def ax_fmt(a):
    a.grid(lw=0.3,color='#ccc'); a.set_axisbelow(True)
    for s in ('top','right'): a.spines[s].set_visible(False)
def lab(a,t): a.text(0.985,0.93,t,transform=a.transAxes,fontweight='bold',va='top',ha='right',fontsize=8)
sm=lambda x,n=1: x
# ---- Fig. 5
d=pd.read_csv('newfig/fig5_run.csv'); t=d.t
fig,ax=plt.subplots(3,1,figsize=(3.4,3.5),sharex=True)
ax[0].plot(t,sm(d.ppv_W)/1e3,color=B,lw=0.9,label='PV'); ax[0].plot(t,sm(d.pgrid_W)/1e3,color=O,lw=0.9,label='AC to grid'); ax[0].set_ylabel('Power (kW)'); ax[0].set_ylim(0,13); ax[0].legend(loc='lower right',ncol=2)
ax[1].plot(t,d.vdc_V,color=B,lw=0.9); ax[1].set_ylabel('$V_{dc}$ (V)'); ax[1].set_ylim(675,725)
ax[2].plot(t,sm(d.vpv_V),color=B,lw=0.9); ax[2].set_ylabel('$V_{pv}$ (V)'); ax[2].set_ylim(330,430); ax[2].set_xlabel('Time (s)'); ax[2].set_xlim(0,1.2)
for a,l in zip(ax,'abc'): ax_fmt(a); lab(a,'('+l+')'); a.axvline(0.5,color='#999',lw=0.5,ls=':')
fig.subplots_adjust(left=0.13,right=0.985,top=0.985,bottom=0.1,hspace=0.14); fig.savefig('img/fig5.png',dpi=600,facecolor='white'); plt.close(fig)
# ---- Fig. 6
c=pd.read_csv('newfig/iabc.csv')
fig,(a,b)=plt.subplots(2,1,figsize=(3.4,3.9))
for k,col,n in zip(('ia','ib','ic'),(B,O,Y),'abc'): a.plot((c.t-0.30)*1e3,c[k],color=col,lw=0.7,label=n)
a.set_xlabel('Time (ms)'); a.set_ylabel('Phase current (A)'); a.set_xlim(0,60); a.set_ylim(-26,32); a.legend(loc='upper left',ncol=3,bbox_to_anchor=(0.0,1.0)); ax_fmt(a); lab(a,'(a)')
b.plot(t,d.id_A,color=B,lw=0.8,label='$i_d$'); b.plot(t,d.iq_A,color=O,lw=0.8,label='$i_q$'); b.set_xlabel('Time (s)'); b.set_ylabel('Current (A)'); b.set_xlim(0,1.2); b.set_ylim(-3,25); b.legend(loc='center right',ncol=1,bbox_to_anchor=(1.0,0.62)); ax_fmt(b); lab(b,'(b)')
fig.subplots_adjust(left=0.13,right=0.985,top=0.985,bottom=0.09,hspace=0.28); fig.savefig('img/fig6.png',dpi=600,facecolor='white'); plt.close(fig)
# ---- battery stage (100 us samples; the 5 kHz ripple is not resolved, so the 200 us average is plotted)
e=pd.read_csv('newfig/battery.csv'); t=e.t
iavg=e.ibat_avg_A; ref=np.where(t<0.4,0,np.where(t<0.8,12.5,-12.5))
fig,ax=plt.subplots(3,1,figsize=(3.4,4.3),sharex=True)
ax[0].plot(t,e.ibat_sample_A,color='#5BB4E8',lw=0.4,label='Measured (100 µs samples)'); ax[0].plot(t,iavg,color='#0B2A6B',lw=0.9,label='Switching-period average'); ax[0].plot(t,ref,color=O,lw=0.9,ls='--',label='Reference'); ax[0].set_ylabel('Battery current (A)'); ax[0].set_ylim(-22,22); ax[0].legend(loc='lower left',bbox_to_anchor=(0.12,0.0))
ax[1].plot(t,e.vdc_V,color=B,lw=0.8,label='$V_{dc}$'); ax[1].axhline(700,color=O,lw=0.8,ls='--',label='700 V reference'); ax[1].set_ylabel('DC-link voltage (V)'); ax[1].set_ylim(675,725); ax[1].legend(loc='upper right')
ax[2].plot(t,sm(e.pgrid_W)/1e3,color=B,lw=0.9,label='Net export to grid'); ax[2].plot(t,sm(e.ppv_W)/1e3,color=Y,lw=0.9,label='PV power'); ax[2].set_ylabel('Power (kW)'); ax[2].set_ylim(-4,10); ax[2].set_xlabel('Time (s)'); ax[2].set_xlim(0,1.0); ax[2].legend(loc='lower left',bbox_to_anchor=(0.12,0.0))
for a,l in zip(ax,'abc'): ax_fmt(a); lab(a,'('+l+')'); [a.axvline(x,color='#999',lw=0.5,ls=':') for x in (0.4,0.8)]
fig.subplots_adjust(left=0.14,right=0.985,top=0.985,bottom=0.08,hspace=0.12); fig.savefig('img/fig_battery_stage.png',dpi=600,facecolor='white'); plt.close(fig)
print('ok')
