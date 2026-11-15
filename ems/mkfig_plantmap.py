import pandas as pd, numpy as np, matplotlib; matplotlib.use('Agg')
import os; os.makedirs("figures", exist_ok=True)
import matplotlib.pyplot as plt
plt.rcParams.update({'font.family':'serif','font.serif':['Times New Roman','Liberation Serif','DejaVu Serif'],'font.size':7,'axes.linewidth':0.6,'xtick.major.width':0.6,'ytick.major.width':0.6})
m = pd.read_csv('cosim_map_all.csv')
z = m[m.Pbat_set_kW == 0].sort_values('G_Wm2'); z = z[z.Ppv_kW > 1]          # PV only, above 1 kW (efficiency is meaningless below)
eff = 100 * z.Pgrid_kW / z.Ppv_kW
fig, (a, b) = plt.subplots(1, 2, figsize=(3.4, 2.0), gridspec_kw={'width_ratios': [1.3, 1]})
a.plot(z.G_Wm2, eff, 'o-', color='#0072BD', ms=3, lw=1.2, label='efficiency')
a.set_xlabel('Irradiance (W/m²)'); a.set_ylabel('PV-to-AC efficiency (%)', color='#0072BD'); a.set_ylim(76, 100); a.set_xlim(100, 1050)
a.tick_params(axis='y', colors='#0072BD'); a.grid(lw=0.3, color='#ccc'); a.set_axisbelow(True)
a2 = a.twinx(); a2.plot(z.G_Wm2, z.loss_kW, 's--', color='#D95319', ms=2.6, lw=1.0)
a2.set_ylim(0, 0.45); a2.set_ylabel('Loss (kW)', color='#D95319', labelpad=2); a2.tick_params(axis='y', colors='#D95319')
a.text(0.04, 0.94, '(a)', transform=a.transAxes, fontweight='bold', va='top')
for g, e in zip(z.G_Wm2, eff):
    if g in (150, 500, 1000): a.annotate(f'{e:.1f}', (g, e), textcoords='offset points', xytext=(10 if g == 150 else (-6 if g == 1000 else 0), -3 if g == 150 else 5), ha='center', fontsize=5.8, color='#0072BD')
# (b) extra loss from the battery path at ~zero PV, idle loss removed
n = m[m.G_Wm2 == 5].sort_values('Pbat_set_kW'); l0 = float(n[n.Pbat_set_kW == 0].loss_kW.iloc[0])
b.plot(n.Pbat_set_kW, 1000 * (n.loss_kW - l0), 'o-', color='#7E2F8E', ms=3, lw=1.2)
b.set_xlabel('Battery power (kW)\n(− charge, + discharge)'); b.set_ylabel('Extra loss (W)'); b.set_ylim(0, 40); b.grid(lw=0.3, color='#ccc'); b.set_axisbelow(True)
b.text(0.04, 0.92, '(b)', transform=b.transAxes, fontweight='bold', va='top')
for s_ in ('top',): a.spines[s_].set_visible(False); a2.spines[s_].set_visible(False); b.spines[s_].set_visible(False)
b.spines['right'].set_visible(False)
fig.subplots_adjust(left=0.13, right=0.985, bottom=0.25, top=0.97, wspace=0.95); fig.savefig('figures/fig_plantmap.png', dpi=600, facecolor='white')
