from lib import *
BL='#0072BD'; AM='#EDB120'; GR='#77AC30'; PU='#7E2F8E'; RD='#D95319'; GY='#595959'
def ic(s,kind,cx,cy):
    g=[]
    if kind=='data':
        g.append(f'<path d="M{cx-17},{cy-14} v26 a17,6 0 0 0 34,0 v-26" fill="#d6e8f5" stroke="{BL}" stroke-width="1.6"/><ellipse cx="{cx}" cy="{cy-14}" rx="17" ry="6" fill="#c2dbee" stroke="{BL}" stroke-width="1.6"/><path d="M{cx-17},{cy-3} a17,6 0 0 0 34,0 M{cx-17},{cy+5} a17,6 0 0 0 34,0" fill="none" stroke="{BL}" stroke-width="1.2"/>')
        g.append(f'<circle cx="{cx+16}" cy="{cy-17}" r="6" fill="#fbbf24" stroke="{AM}" stroke-width="1.4"/>'+''.join(f'<path d="M{cx+16+9*__import__("math").cos(a):.1f},{cy-17+9*__import__("math").sin(a):.1f} l{4*__import__("math").cos(a):.1f},{4*__import__("math").sin(a):.1f}" stroke="{AM}" stroke-width="1.4"/>' for a in [i*0.785 for i in range(8)]))
    elif kind=='pv':
        g.append(f'<polygon points="{cx-20},{cy+14} {cx-10},{cy-14} {cx+20},{cy-14} {cx+10},{cy+14}" fill="#d6e8f5" stroke="{BL}" stroke-width="1.7"/>')
        g.append(f'<path d="M{cx-5},{cy+14} L{cx+5},{cy-14} M{cx-0.0},{cy-14} v0 M{cx-16},{cy+4} H{cx+14} M{cx-13},{cy-5} H{cx+17}" stroke="{BL}" stroke-width="1.1" fill="none"/><path d="M{cx+5},{cy+14} L{cx+15},{cy-14}" stroke="{BL}" stroke-width="1.1"/>')
        g.append(f'<path d="M{cx-4},{cy+14} v8 M{cx+6},{cy+14} v8" stroke="{GY}" stroke-width="1.6"/>')
    elif kind=='batt':
        g.append(f'<rect x="{cx-20}" y="{cy-11}" width="36" height="24" rx="4" fill="#e2eed2" stroke="{GR}" stroke-width="1.8"/><rect x="{cx+16}" y="{cy-5}" width="4" height="12" rx="1.5" fill="{GR}"/>')
        g.append(''.join(f'<rect x="{cx-16+i*11}" y="{cy-7}" width="8" height="16" rx="1.5" fill="{GR}"/>' for i in range(3)))
        g.append(f'<path d="M{cx-26},{cy+20} h52" stroke="{GY}" stroke-width="1.6"/>')
    elif kind=='inv':
        g.append(f'<rect x="{cx-21}" y="{cy-15}" width="42" height="30" rx="4" fill="#e4d3ea" stroke="{PU}" stroke-width="1.8"/><path d="M{cx-21},{cy+15} L{cx+21},{cy-15}" stroke="{PU}" stroke-width="1.4"/>')
        g.append(f'<path d="M{cx-16},{cy-8} h10 M{cx-16},{cy-4} h10" stroke="{PU}" stroke-width="1.6"/><path d="M{cx+4},{cy+8} q4,-8 8,0 t8,0" fill="none" stroke="{PU}" stroke-width="1.6"/>')
    elif kind=='scope':
        g.append(f'<rect x="{cx-22}" y="{cy-16}" width="44" height="32" rx="4" fill="#fff" stroke="{GY}" stroke-width="1.8"/><path d="M{cx-17},{cy+6} h8 l3,-14 l5,22 l4,-18 l3,10 h11" fill="none" stroke="{RD}" stroke-width="1.8"/><path d="M{cx-17},{cy-10} v22 M{cx-17},{cy+12} h34" stroke="{GY}" stroke-width="1" opacity=".6"/>')
    elif kind=='doc':
        g.append(f'<path d="M{cx-14},{cy-18} h20 l8,8 v28 h-28 z" fill="#d6e8f5" stroke="{BL}" stroke-width="1.7"/><path d="M{cx+6},{cy-18} v8 h8" fill="none" stroke="{BL}" stroke-width="1.4"/>'+''.join(f'<path d="M{cx-9},{cy-5+i*7} h18" stroke="{BL}" stroke-width="1.4"/>' for i in range(3)))
    elif kind=='rules':
        g.append(f'<polygon points="{cx},{cy-18} {cx+11},{cy-8} {cx},{cy+2} {cx-11},{cy-8}" fill="#fbefcc" stroke="{AM}" stroke-width="1.6"/><path d="M{cx-9},{cy-3} L{cx-17},{cy+8} M{cx+9},{cy-3} L{cx+17},{cy+8}" stroke="{GY}" stroke-width="1.4"/><rect x="{cx-26}" y="{cy+8}" width="18" height="10" rx="2" fill="#d6e8f5" stroke="{PU}" stroke-width="1.4"/><rect x="{cx+8}" y="{cy+8}" width="18" height="10" rx="2" fill="#e2eed2" stroke="{GR}" stroke-width="1.4"/>')
    elif kind=='milp':
        g.append(''.join(f'<rect x="{cx-18+i*13}" y="{cy-16+j*13}" width="11" height="11" rx="1.5" fill="{"#d9c0e0" if (i+j)%2==0 else "#fff"}" stroke="{PU}" stroke-width="1.3"/>' for i in range(3) for j in range(3)))
        g.append(f'<text x="{cx+27}" y="{cy-6}" font-size="15" font-style="italic" fill="{PU}">Σ</text>')
    elif kind=='bars':
        g.append(f'<path d="M{cx-22},{cy+16} h44 M{cx-22},{cy+16} v-32" stroke="{GY}" stroke-width="1.5" fill="none"/>'+''.join(f'<rect x="{cx-17+i*12}" y="{cy+16-h}" width="8" height="{h}" fill="{c}"/>' for i,(h,c) in enumerate([(14,AM),(24,BL),(18,RD),(28,PU)])))
    elif kind=='sliders':
        for i,(k) in enumerate([-8,5,-2]):
            y=cy-12+i*12
            g.append(f'<path d="M{cx-20},{y} h40" stroke="{GY}" stroke-width="1.6"/><circle cx="{cx+k*1.8:.1f}" cy="{y}" r="4.2" fill="#fff" stroke="{PU}" stroke-width="1.7"/>')
    s.add(f'<g transform="translate({cx},{cy}) scale(0.72) translate({-cx},{-cy})">'+''.join(g)+'</g>')

def card(s,x,y,w,h,kind,title,lines):
    s.add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="#fff" stroke="#374151" stroke-width="1.5"/>')
    ic(s,kind,x+w/2,y+25)
    s.text(x+w/2,y+58,title,size=13.5,weight='bold')
    s.text(x+w/2,y+75,'\n'.join(lines),size=12,fill='#222',lh=13.5)

def overview():
    W,H=900,322; s=S(W,H)
    cw,gap=146,38; xs=[9+i*(cw+gap) for i in range(5)]
    s.add('<rect x="3" y="3" width="894" height="146" rx="10" fill="#f8fafc" stroke="#94a3b8" stroke-dasharray="5 4"/>')
    s.add('<rect x="3" y="171" width="894" height="146" rx="10" fill="#f8fafc" stroke="#94a3b8" stroke-dasharray="5 4"/>')
    s.text(14,19,'A. Converter-level model (Simulink, 1 µs step)',anchor='start',size=13,weight='bold',fill='#334155')
    s.text(14,187,'B. Energy management model (Python, 15-minute steps, 24 h)',anchor='start',size=13,weight='bold',fill='#334155')
    y1,y2,h=28,196,112
    top=[('data','Site and tariff data',['PVGIS-ERA5, Islamabad','IESCO ToU tariff','home loads']),
         ('pv','PV array and MPPT',['8 × 2 × 615 W, 9.84 kWp','boost 7 mH, 5 kHz','P&O MPPT, 10 ms window']),
         ('batt','DC link and battery',['700 V, 2 mF DC link','half-bridge, 10 mH','400 V, 15 kWh battery']),
         ('inv','Grid inverter',['3-phase IGBT bridge','PLL, dq current PIs','4.5 mH filter, 50 Hz grid']),
         ('scope','Plant measurements',['efficiency, THD, tracking','±5 kW steps, voltage dips','weak-grid SCR sweep'])]
    for x,(k,t,l) in zip(xs,top): card(s,x,y1,cw,h,k,t,l)
    for i in range(4): s.wire([(xs[i]+cw+2,y1+h/2),(xs[i+1]-2,y1+h/2)],arrow=True,w=1.8,col='#374151')
    bot=[('doc','EMS inputs',['PV, loads, ToU tariff','battery SOC and limits','appliance windows']),
         ('rules','Rule-based EMS',['tariff and SOC rules','appliance start times','battery power']),
         ('milp','MILP benchmark',['perfect foresight','start-time binaries','HiGHS solver']),
         ('bars','Evaluation',['adjusted daily cost','peak-hour import, ρ','summer, winter, overcast']),
         ('sliders','Sensitivity tests',['degradation, export price','tariff, peak window','battery size'])]
    xr=xs[::-1]
    for x,(k,t,l) in zip(xr,bot): card(s,x,y2,cw,h,k,t,l)
    for i in range(4): s.wire([(xr[i]-2,y2+h/2),(xr[i+1]+cw+2,y2+h/2)],arrow=True,w=1.8,col='#374151')
    cx=xs[4]+cw/2
    s.wire([(cx,y1+h+2),(cx,y2-2)],arrow=True,w=1.8,col='#374151')
    s.text(cx-8,y1+h+17,'limits and 34-point loss map\n<i>L̂</i>(<i>P</i><sub>pv</sub>, <i>P</i><sub>bat</sub>) for re-costing',anchor='end',size=11,fill='#334155',lh=12.5)
    return s.svg('Overview of the complete model: converter-level plant and energy management layer')
if __name__=='__main__':
    open('fig0.svg','w').write(overview()); print('ok')
