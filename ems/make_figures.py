import json, numpy as np, matplotlib
import os; os.makedirs("figures", exist_ok=True)
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import ems10 as m
R = json.load(open('results.json')); S = np.load('data/series.npy', allow_pickle=True).item()
INK, SUB, MUTE, GRID = '#0b0b0b', '#52514e', '#898781', '#e1e0d9'
COL = {'gray': '#898781', 'blue': '#2a78d6', 'orange': '#eb6834', 'aqua': '#1baf7a', 'yellow': '#eda100'}
SC = [COL['gray'], COL['blue'], COL['orange'], '#7e2f8e', COL['aqua']]
SN = ['Grid-tied PV only', 'PV + battery (self-consumption)', 'Rule-based EMS', 'MILP optimum']
plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 10, 'axes.edgecolor': MUTE, 'axes.labelcolor': SUB,
    'xtick.color': SUB, 'ytick.color': SUB, 'axes.spines.top': False, 'axes.spines.right': False,
    'axes.facecolor': '#fcfcfb', 'figure.facecolor': '#fcfcfb', 'savefig.facecolor': '#fcfcfb', 'svg.fonttype': 'none'})
t = m.H + m.DT / 2
def style(ax, ylabel):
    ax.set_xlim(0, 24); ax.set_xticks(range(0, 25, 3)); ax.set_xticklabels([f'{h:02d}:00' for h in range(0, 25, 3)])
    ax.grid(axis='y', color=GRID, lw=0.8); ax.set_axisbelow(True); ax.set_ylabel(ylabel)
    ax.axvspan(*m.CFG['peak'][season], color='#eda100', alpha=0.10, lw=0)
def legend(ax, ncol):
    ax.legend(loc='upper center', bbox_to_anchor=(0.5, -0.14), ncol=ncol, frameon=False, labelcolor=SUB)
def save(fig, name):
    fig.savefig(f'figures/{name}.png', dpi=300, bbox_inches='tight'); fig.savefig(f'figures/{name}.svg', bbox_inches='tight'); plt.close(fig)
for season in ('summer', 'winter'):
    s = S[season]; runs = s['runs']; cap = m.CFG['batt_kwh']
    # 1 PV vs load
    fig, ax = plt.subplots(figsize=(7.5, 3.8))
    ax.fill_between(t, s['pv'], color=COL['yellow'], alpha=0.35, lw=0, label='PV generation (10 kWp)')
    ax.plot(t, s['pv'], color=COL['yellow'], lw=2)
    ax.plot(t, s['fixed'] + s['hab'].sum(0), color=COL['blue'], lw=2, label='Home demand (habitual use)')
    style(ax, 'Power (kW)'); ax.set_ylim(0); legend(ax, 2)
    ax.set_title(f'{season.capitalize()} day: PV generation vs home demand', loc='left', color=INK, fontsize=11)
    save(fig, f'fig_{season}_1_pv_vs_load')
    # 2 SOC
    fig, ax = plt.subplots(figsize=(7.5, 3.8))
    for k in (1, 2, 3):
        e = np.insert(runs[k]['E'], 0, m.CFG['soc0'] * cap) / cap * 100
        ax.plot(np.append(m.H, 24), e, color=SC[k], lw=2, label=SN[k])
    style(ax, 'Battery state of charge (%)'); ax.set_ylim(0, 105); legend(ax, 3)
    ax.set_title(f'{season.capitalize()} day: battery state of charge', loc='left', color=INK, fontsize=11)
    save(fig, f'fig_{season}_2_soc')
    # 3 grid exchange
    fig, ax = plt.subplots(figsize=(7.5, 3.8))
    for k in (2, 3):
        ax.plot(t, runs[k]['imp'] - runs[k]['exp'], color=SC[k], lw=2, label=SN[k])
    ax.axhline(0, color=MUTE, lw=1)
    style(ax, 'Grid power (kW)  import + / export −'); legend(ax, 2)
    ax.set_title(f'{season.capitalize()} day: exchange with the grid', loc='left', color=INK, fontsize=11)
    save(fig, f'fig_{season}_3_grid')
    # 4 appliance schedule
    L = s['L']; n = len(L)
    fig, axes = plt.subplots(3, 1, figsize=(7.5, 1.0 + 1.4 * 3), sharex=True)
    for ax, (ttl, mat, c) in zip(axes, [('Habitual', s['hab'], COL['gray']), ('Rule-based EMS', runs[2]['sh'], COL['orange']), ('MILP optimum', runs[3]['sh'], COL['aqua'])]):
        for i in range(n):
            on = mat[i] > 1e-6
            ax.broken_barh([(m.H[j], m.DT) for j in np.where(on)[0]], (i - 0.35, 0.7), facecolors=c, edgecolor='#fcfcfb', lw=0.5)
        ax.set_yticks(range(n)); ax.set_yticklabels(L, fontsize=8); ax.set_ylim(-0.6, n - 0.4); ax.invert_yaxis()
        ax.axvspan(*m.CFG['peak'][season], color='#eda100', alpha=0.10, lw=0); ax.set_xlim(0, 24)
        ax.set_title(ttl, loc='left', fontsize=9, color=SUB, pad=2); ax.grid(axis='x', color=GRID, lw=0.8); ax.set_axisbelow(True)
    axes[-1].set_xticks(range(0, 25, 3)); axes[-1].set_xticklabels([f'{h:02d}:00' for h in range(0, 25, 3)])
    fig.suptitle(f'{season.capitalize()} day: flexible-appliance schedule (shaded = peak tariff)', x=0.01, ha='left', color=INK, fontsize=11)
    fig.tight_layout(); save(fig, f'fig_{season}_4_schedule')
# 5 cost comparison, both seasons
fig, axes = plt.subplots(1, 2, figsize=(9, 3.8), sharey=True)
for ax, season in zip(axes, ('summer', 'winter')):
    sc = R['seasons'][season]['scenarios']; v = [sc[i]['total'] for i in (0, 1, 2, 4, 3)]   # PV only, +battery, rules v1, rules v2, MILP
    b = ax.bar(range(5), v, color=SC, width=0.62, edgecolor='#fcfcfb', lw=2)
    for i, y in enumerate(v): ax.text(i, y + 15, f'{y:,.0f}', ha='center', color=INK, fontsize=9)
    ax.set_xticks(range(5)); ax.set_xticklabels(['Grid-tied\nPV only', 'PV +\nbattery', 'Rules\nv1', 'Rules\nv2', 'MILP\noptimum'], fontsize=8)
    ax.set_title(season.capitalize(), loc='left', color=INK, fontsize=11); ax.grid(axis='y', color=GRID, lw=0.8); ax.set_axisbelow(True)
axes[0].set_ylabel('Net daily cost (PKR)')
fig.tight_layout(); save(fig, 'fig_5_cost_comparison')
print('ok')
