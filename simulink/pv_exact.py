# Exact array curve from the Simscape parameters in model_dump.txt (per module: IL, I0, nI, Rs, Rsh, Ncell; 8 series x 2 parallel, 25 C)
import numpy as np
from scipy.optimize import brentq
IL,I0,nI,Rs,Rsh,Nc=13.8306,4.8519e-12,0.48952,0.24814,482.6219,156
Vt=1.380649e-23*298.15/1.602176634e-19; a=nI*Nc*Vt
def Imod(V,G):
    f=lambda I: IL*G/1000-I0*(np.exp((V+I*Rs)/a)-1)-(V+I*Rs)/Rsh-I
    return brentq(f,-60,IL*G/1000+5)
def curve(G,Vg): return np.array([v*2*Imod(v/8,G) for v in Vg])
Vg=np.arange(1.0,452.0,0.1)
res={}
for G in (300,600,1000):
    P=curve(G,Vg); k=P.argmax(); dP=np.gradient(P,Vg); Isc=2*Imod(0,G)
    res[G]=(P[k],Vg[k],Isc)
    print('G %4d: Pmpp %.3f kW at %.1f V | Isc %.2f A | r_pv %.1f ohm'%(G,P[k]/1e3,Vg[k],Isc,Vg[k]/(P[k]/Vg[k])))
    for C in (100e-6,500e-6):
        for Tw in (10e-3,50e-3):
            b=C*Vg/Tw; ok=np.where((Vg<Vg[k])&(dP>=b))[0]
            j=ok[-1] if len(ok) else 0
            print('     C %3.0f uF, Tw %2.0f ms: equilibrium %.0f V, %.1f %% of Pmpp'%(C*1e6,Tw*1e3,Vg[j],100*P[j]/P[k]))
