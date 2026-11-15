import re
FONT="'Times New Roman','Liberation Serif',serif"
def mk(s):
    s=s.replace('&','&amp;')
    s=re.sub(r'<i>(.*?)</i>',r'<tspan font-style="italic">\1</tspan>',s)
    s=re.sub(r'<sub>(.*?)</sub>',r'<tspan baseline-shift="sub" font-size="75%">\1</tspan>',s)
    s=re.sub(r'<sup>(.*?)</sup>',r'<tspan baseline-shift="super" font-size="75%">\1</tspan>',s)
    return s
class S:
    def __init__(s,W,H,y0=0): s.W=W;s.H=H;s.y0=y0;s.e=[]
    def add(s,x): s.e.append(x)
    def wire(s,pts,w=1.2,arrow=False,col='#111',dash=None):
        d='M'+' L'.join(f'{x:g},{y:g}' for x,y in pts)
        m=' marker-end="url(#ar)"' if arrow else ''
        da=f' stroke-dasharray="{dash}"' if dash else ''
        s.add(f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{w}" stroke-linejoin="round"{m}{da}/>')
    def dot(s,x,y,r=2.4): s.add(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#111"/>')
    def text(s,x,y,t,anchor='middle',size=13,weight='normal',fill='#111',lh=14.5):
        lines=t.split('\n')
        for i,l in enumerate(lines):
            s.add(f'<text x="{x}" y="{y+i*lh:g}" text-anchor="{anchor}" font-size="{size}" font-weight="{weight}" fill="{fill}">{mk(l)}</text>')
    def box(s,x,y,w,h,fill='#fff',stroke='#111',rx=3,sw=1.2): s.add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
    def lbox(s,x,y,w,h,t,fill='#fff',size=13,stroke='#111',rx=3,weight='normal',lh=14.5):
        s.box(x,y,w,h,fill,stroke,rx); n=len(t.split('\n')); s.text(x+w/2,y+h/2-(n-1)*lh/2+size*0.34,t,size=size,weight=weight,lh=lh)
    def diamond(s,cx,cy,w,h,t,fill='#fff',size=12.5):
        s.add(f'<polygon points="{cx},{cy-h/2} {cx+w/2},{cy} {cx},{cy+h/2} {cx-w/2},{cy}" fill="{fill}" stroke="#111" stroke-width="1.2"/>')
        n=len(t.split('\n')); s.text(cx,cy-(n-1)*7.25+size*0.34,t,size=size)
    def term(s,cx,cy,w,h,t,size=13):
        s.add(f'<rect x="{cx-w/2}" y="{cy-h/2}" width="{w}" height="{h}" rx="{h/2}" fill="#1f2d3d"/>'); s.text(cx,cy+size*0.34,t,size=size,fill='#fff',weight='bold')
    def sigma(s,cx,cy,r=7.5):
        s.add(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#fff" stroke="#111" stroke-width="1.2"/><line x1="{cx-r*0.7:.1f}" y1="{cy-r*0.7:.1f}" x2="{cx+r*0.7:.1f}" y2="{cy+r*0.7:.1f}" stroke="#111"/><line x1="{cx-r*0.7:.1f}" y1="{cy+r*0.7:.1f}" x2="{cx+r*0.7:.1f}" y2="{cy-r*0.7:.1f}" stroke="#111"/>')
    # components: local horizontal along +x from (0,0) to (L,0); rot=0 horizontal, 90 vertical downward
    def comp(s,x,y,body,rot=0):
        s.add(f'<g transform="translate({x},{y}) rotate({rot})" fill="none" stroke="#111" stroke-width="1.2" stroke-linejoin="round">{body}</g>')
    def ind(s,x,y,L=40,n=4,rot=0):
        r=L/(2*n); d=f'M0,0'+''.join(f' a{r:g},{r:g} 0 0 1 {2*r:g},0' for _ in range(n)); s.comp(x,y,f'<path d="{d}"/>',rot)
    def cap(s,x,y,L,rot=0):
        c=L/2; s.comp(x,y,f'<path d="M0,0 L{c-3},0 M{c+3},0 L{L},0"/><path d="M{c-3},-9 L{c-3},9 M{c+3},-9 L{c+3},9" stroke-width="1.8"/>',rot)
    def diode(s,x,y,L=30,rot=0):
        c=L/2; s.comp(x,y,f'<path d="M0,0 L{c-6},0 M{c+6},0 L{L},0"/><polygon points="{c-6},-7 {c-6},7 {c+6},0" fill="#111"/><path d="M{c+6},-7 L{c+6},7"/>',rot)
    def sw(s,x,y,L,rot=0):
        c=L/2; s.comp(x,y,f'<path d="M0,0 L{c-12},0 M{c+12},0 L{L},0"/><path d="M{c-12},0 L{c+10},-9"/><circle cx="{c-12}" cy="0" r="1.8" fill="#111"/><circle cx="{c+12}" cy="0" r="1.8" fill="#111"/><path d="M{c-4},-7.5 L{c-4},-17" stroke-dasharray="2 2"/>',rot)
    def igbt(s,x,y,L,rot=90):
        c=L/2; s.comp(x,y,f'<path d="M0,0 L{c-10},0 M{c+10},0 L{L},0"/><path d="M{c-10},0 L{c+10},0" stroke-width="2.4"/><path d="M{c-9},6 L{c+9},6" stroke-width="1.8"/><path d="M{c},6 L{c},15"/><polygon points="{c+9},0 {c+3},-4 {c+3},4" fill="#111" stroke="none"/>',rot)
    def batt(s,x,y,L,rot=0):
        c=L/2; s.comp(x,y,f'<path d="M0,0 L{c-9},0 M{c+9},0 L{L},0"/><path d="M{c-9},-10 L{c-9},10 M{c-3},-6 L{c-3},6 M{c+3},-10 L{c+3},10 M{c+9},-6 L{c+9},6" stroke-width="1.8"/>',rot)
    def svg(s,title=''):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 {s.y0} {s.W} {s.H-s.y0}" width="{s.W}" height="{s.H-s.y0}" font-family="{FONT}" role="img" aria-label="{title}">'
          '<defs><marker id="ar" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto" markerUnits="userSpaceOnUse"><path d="M0,0.5 L8,4 L0,7.5 z" fill="#111"/></marker></defs>'
          f'<rect x="0" y="{s.y0}" width="{s.W}" height="{s.H-s.y0}" fill="#fff"/>'+''.join(s.e)+'</svg>')
