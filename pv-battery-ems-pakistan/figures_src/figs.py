from lib import *
BLUE='#d6e8f5'; AMB='#fbefcc'; GRN='#e2eed2'; GRY='#ececec'; PUR='#e4d3ea'; RED='#f8dccd'

def fig1():
    s=S(460,358,y0=42); T,B=60,210
    # PV
    s.wire([(34,T),(34,100)]); s.wire([(34,170),(34,B)])
    s.box(20,100,28,70,AMB,'#111',2)
    s.add('<path d="M20,170 L48,100" stroke="#111" stroke-width="1"/>')
    s.add('<path d="M26,112 h8 M30,108 v8" stroke="#111" stroke-width="1"/><path d="M36,160 h8" stroke="#111" stroke-width="1"/>')
    s.wire([(2,88),(14,100)],arrow=True,w=1); s.wire([(2,102),(14,114)],arrow=True,w=1)
    # rails
    s.wire([(34,T),(84,T)]); s.ind(84,T,40); s.wire([(124,T),(160,T)])
    s.diode(160,T,30); s.wire([(190,T),(388,T)])
    s.wire([(34,B),(388,B)])
    # Cin, S1, Cdc, half-bridge
    s.comp(60,T,'<path d="M0,0 L14,0 l3,-6 l6,12 l6,-12 l6,12 l6,-12 l3,6 L52,0"/>',90); s.cap(60,T+52,B-T-52,90)
    s.text(70,T+30,'<i>R</i><sub>d</sub>',anchor='start',size=11.5); s.text(70,T+96,'<i>C</i><sub>in</sub>',anchor='start',size=11.5)
    s.igbt(146,T,B-T); s.cap(226,T,B-T,90)
    s.igbt(262,T,75); s.igbt(262,T+75,75)
    for x in (60,146,226,262): s.dot(x,T); s.dot(x,B)
    s.dot(262,135)
    s.wire([(262,135),(282,135)]); s.ind(282,135,40); s.wire([(322,135),(348,135)]); s.wire([(348,135),(348,135+0)])
    s.batt(348,135,75,90); s.dot(348,B)
    # inverter
    s.box(388,46,64,178,PUR,'#111',3); s.dot(388,T); s.dot(388,B)
    s.text(420,120,'3-phase\nIGBT\nbridge',size=13); s.text(420,168,'PLL,\ndq PI',size=12,fill='#444')
    # AC side
    ys=[282,297,312]; xs=[400,418,436]
    for x,y in zip(xs,ys):
        s.wire([(x,224),(x,y),(370,y)]); s.ind(330,y,40,3); s.wire([(330,y),(278 if y==297 else (278 if y!=297 else 278),y)])
    # grid source
    s.add('<circle cx="262" cy="297" r="22" fill="#fff" stroke="#111" stroke-width="1.2"/><path d="M251,297 q5.5,-12 11,0 t11,0" fill="none" stroke="#111" stroke-width="1.3"/>')
    s.add('<path d="M345,276 l6,12 M360,291 l6,12" stroke="#111" stroke-width="1"/>') if False else None
    # labels
    s.text(2,232,'PV array\n9.84 kWp',anchor='start',size=12.5)
    s.text(140,232,'Boost, 7 mH, 5 kHz\nP&O, 10 ms window\n<i>C</i><sub>in</sub> 100 µF, <i>R</i><sub>d</sub> 8 Ω',size=11.5)
    s.text(226,232,'DC link\n2 mF, 700 V',size=12.5)
    s.text(322,232,'Half-bridge\n10 mH, 5 kHz\nBattery 400 V, 15 kWh',size=12.5)
    s.text(304,340,'L filter, 4.5 mH per phase',anchor='start',size=12.5)
    s.text(262,336,'Grid\n400 V, 50 Hz',size=12.5)
    return s.svg('Power circuit of the 10 kWp plant with the battery stage on the DC link')

def fig2():
    s=S(460,236)
    yd,yq=60,170
    # row d
    s.wire([(4,yd),(44.5,yd)],arrow=True); s.text(2,yd-7,'<i>V</i><sub>dc</sub>*',anchor='start',size=12.5); s.text(2,yd+17,'= 700 V',anchor='start',size=12)
    s.sigma(52,yd); s.text(40,yd-9,'+',size=11); s.text(62,yd+17,'−',size=11)
    s.wire([(59.5,yd),(70,yd)],arrow=True)
    s.lbox(70,yd-20,80,40,'DC-link PI\n<i>K</i><sub>p</sub> 0.3, <i>K</i><sub>i</sub> 10',BLUE,size=12.5)
    s.wire([(150,yd),(162,yd)],arrow=True)
    s.sigma(170,yd)
    s.wire([(177.5,yd),(188,yd)],arrow=True)
    s.lbox(188,yd-20,74,40,'Current PI\n<i>K</i><sub>p</sub> 10, <i>K</i><sub>i</sub> 111',BLUE,size=12.5)
    s.wire([(262,yd),(274.5,yd)],arrow=True); s.sigma(282,yd); s.text(268,yd-8,'+',size=11)
    s.wire([(289.5,yd),(312,yd)],arrow=True)
    s.box(312,40,58,64,GRY,'#111',3); s.text(341,56,'dq → abc\n÷ <i>V</i><sub>dc</sub>/2\nPWM\n5 kHz',size=12,lh=13)
    s.wire([(370,yd),(396,yd)],arrow=True)
    s.box(396,40,60,64,AMB,'#111',3); s.text(426,64,'Inverter,\nL filter,\ngrid',size=12.5,lh=14)
    # FF into Sigma2 (top) and decoupling into Sigma3 (top)
    s.wire([(170,30),(170,52)],arrow=True); s.text(170,22,'<i>P</i>*/(1.5 <i>v</i><sub>d</sub>)',size=12); s.text(180,44,'+',size=11,anchor='start')
    s.wire([(282,30),(282,52)],arrow=True); s.text(282,22,'<i>v</i><sub>d</sub> − ω<i>L i</i><sub>q</sub>',size=12); s.text(292,44,'+',size=11,anchor='start')
    # Vdc feedback into sigma1 bottom
    s.wire([(52,100),(52,68)],arrow=True); s.text(46,96,'<i>V</i><sub>dc</sub>',anchor='end',size=12)
    # row q
    s.wire([(4,yq),(162.5,yq)],arrow=True); s.text(4,yq-6,'<i>i</i><sub>q</sub>* = 0',anchor='start',size=12.5)
    s.sigma(170,yq); s.text(156,yq-8,'+',size=11)
    s.wire([(177.5,yq),(188,yq)],arrow=True)
    s.lbox(188,yq-20,74,40,'Current PI\n<i>K</i><sub>p</sub> 10, <i>K</i><sub>i</sub> 111',BLUE,size=12.5)
    s.wire([(262,yq),(274.5,yq)],arrow=True); s.sigma(282,yq); s.text(268,yq-8,'+',size=11)
    s.wire([(289.5,yq),(341,yq),(341,104)],arrow=True)
    s.wire([(282,204),(282,177.5)],arrow=True); s.text(282,216,'<i>v</i><sub>q</sub> + ω<i>L i</i><sub>d</sub>',size=12); s.text(292,194,'+',size=11,anchor='start')
    # measurement band
    s.lbox(188,100,80,40,'abc → dq',GRY,size=12.5)
    s.wire([(188,108),(170,108),(170,67.5)],arrow=True); s.text(160,92,'<i>i</i><sub>d</sub>',anchor='end',size=12); s.text(180,80,'−',size=11,anchor='start')
    s.wire([(188,132),(170,132),(170,162.5)],arrow=True); s.text(160,146,'<i>i</i><sub>q</sub>',anchor='end',size=12); s.text(180,154,'−',size=11,anchor='start')
    s.lbox(62,100,70,40,'PLL\nθ, ω',PUR,size=12.5)
    s.wire([(4,120),(62,120)],arrow=True); s.text(6,114,'<i>v</i><sub>abc</sub>',anchor='start',size=12)
    s.wire([(132,120),(188,120)],arrow=True); s.text(152,114,'θ',size=12.5)
    s.wire([(426,104),(426,122),(268,122)],arrow=True); s.text(312,116,'<i>i</i><sub>abc</sub>',size=12)
    # hop where vq* wire crosses the measurement line
    s.add('<path d="M335,122 a6,6 0 0 1 12,0" fill="none" stroke="#111" stroke-width="1.2"/>'.replace('M335,122','M335,122'))
    return s.svg('Grid-side control: DC-link PI, dq current PIs with decoupling and PLL')

def fig3():
    s=S(460,252)
    ins=[('PV profile\n10 kWp',AMB),('Fixed household\nload',BLUE),('ToU tariff\n34.53 / 46.85 PKR/kWh',RED),('Battery state of charge\n15 kWh',GRN),('Appliance windows\nand deadlines',GRY)]
    for i,(t,c) in enumerate(ins):
        y=4+i*49; s.lbox(2,y,146,38,t,c,size=12.5,lh=14); s.wire([(148,y+19),(170,y+19)])
    s.wire([(170,23),(170,219)]); s.dot(170,121); s.wire([(170,121),(194,121)],arrow=True)
    s.box(194,64,104,114,PUR,'#111',4); s.text(246,102,'EMS controller\n\nrule-based\nor MILP\n(15-min step)',size=12.5,lh=14)
    s.wire([(298,121),(318,121)]); s.wire([(318,36),(318,171)]); s.dot(318,121)
    outs=[(36,'Battery power\n±5 kW, η = 0.96',GRN),(103,'Appliance start\ntimes (4 loads)',GRY),(170,'Grid import / export\n(net billing)',BLUE)]
    for y,t,c in outs:
        s.wire([(318,y),(336,y)],arrow=True); s.lbox(336,y-19,122,38,t,c,size=12.5,lh=14)
    s.wire([(397,189),(397,210)],arrow=True); s.lbox(336,210,122,32,'Daily cost (PKR)',RED,size=12.5)
    return s.svg('EMS inputs, controller and outputs')

def fig4():
    s=S(460,432)
    s.term(230,14,116,24,'Start of time step <i>t</i>'.replace('<i>','').replace('</i>',''))
    s.wire([(230,26),(230,40)],arrow=True)
    s.lbox(14,40,432,36,'Read PV power, fixed load, battery energy, tariff,\npeak window and appliance windows',BLUE,size=12.5,lh=14)
    s.wire([(230,76),(230,90)]); s.wire([(115,90),(345,90)]); s.wire([(115,90),(115,106)],arrow=True); s.wire([(345,90),(345,106)],arrow=True)
    s.diamond(115,148,206,84,'Appliance not yet\nstarted and inside\nits window?',AMB)
    s.diamond(345,148,206,84,'Net power\nPV − load > 0 ?',AMB)
    for cx in (115,345):
        s.wire([(cx,190),(cx,200)]); s.wire([(cx-54,200),(cx+54,200)])
    xs=[(61,'Yes'),(169,'No'),(291,'Yes'),(399,'No')]
    for x,l in xs:
        s.wire([(x,200),(x,222)],arrow=True); s.text(x+4,214,l,anchor='start',size=12)
    bx=[(4,'Start if PV surplus\n≥ 70 % of rating,\nor off-peak and\nSOC ≥ 60 %, or\ndeadline reached\n(EV: 50 %, 80 %)',PUR),
        (116,'Hold the\nappliance\nfor a later\nstep',GRY),
        (234,'Charge battery\nfrom the surplus\n(max 5 kW, up\nto 100 % SOC)',GRN),
        (346,'Discharge in the\npeak window, if\nSOC > 80 %, or (v2)\nif forecast PV\n≥ 25 kWh (to 20 %)',GRN)]
    for x,t,c in bx: s.lbox(x,222,110 if x!=116 else 104,98,t,c,size=12,lh=13.5)
    for x in (61,168,291,399): s.wire([(x,320),(x,338)])
    s.wire([(61,338),(399,338)]); s.wire([(230,338),(230,352)],arrow=True)
    s.lbox(14,352,432,40,'Grid power = load + battery − PV; import × tariff,\nor export × 10.5 PKR/kWh; add to the daily cost',BLUE,size=12.5,lh=14)
    s.wire([(230,392),(230,406)],arrow=True); s.term(230,418,116,24,'Next time step')
    return s.svg('Rule-based EMS decision logic for one time step')

FIGS={'fig1':fig1,'fig2':fig2,'fig3':fig3,'fig4':fig4}
if __name__=='__main__':
    html=['<!doctype html><meta charset="utf-8"><title>Paper diagrams</title><style>body{font:14px sans-serif;margin:20px;background:#fff}figure{margin:0 0 28px}svg{max-width:100%;height:auto;border:1px solid #ddd}</style>']
    for k,f in FIGS.items():
        v=f(); open(k+'.svg','w').write(v); html.append(f'<figure>{v}<figcaption>{k}</figcaption></figure>')
    open('diagrams.html','w').write('\n'.join(html)); print('ok')
