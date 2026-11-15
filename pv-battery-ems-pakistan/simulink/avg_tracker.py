# Averaged model of the PV input stage + the model's own P&O code (from model_dump.txt), no PWM:
# array (exact Simscape single-diode parameters) -> input network -> ammeter -> 7 mH -> switch node (1-D)*700 V.
# The tracker sees the node voltage and the INDUCTOR current, as in the Simulink model.
import numpy as np, sys
from scipy.optimize import brentq
IL,I0,nI,Rs,Rsh,Nc=13.8306,4.8519e-12,0.48952,0.24814,482.6219,156
Vt=1.380649e-23*298.15/1.602176634e-19; a=nI*Nc*Vt
def Imod(V,G): return brentq(lambda I: IL*G/1000-I0*(np.exp((V+I*Rs)/a)-1)-(V+I*Rs)/Rsh-I,-60,IL*G/1000+5)
def run(G,circ,Tw,T=2.0,dt=5e-6,L=7e-3,Vdc=700.0):
    vg=np.arange(0,460,0.05); ig=np.array([2*Imod(v/8,G) for v in vg])
    Ipv=lambda v: np.interp(v,vg,ig)
    Pm=(vg*ig).max()
    Cin,Rser,Cd,Rd = circ
    vC=380.0; vCd=380.0; iL=0.0; v=380.0
    Dprev=0.5;Pprev=0;Vprev=0;sV=0;sI=0;n=0;Nn=int(round(Tw/dt)); dD=0.003
    N=int(T/dt); acc=[]; vs=[]
    for k in range(N):
        # node voltage v: Ipv(v) - iL - (v-vC)/Rser - (v-vCd)/Rd = 0  (Rser=0 -> v=vC; Cd=0 -> no damper)
        if Rser>0:
            f=lambda x: Ipv(x)-iL-(x-vC)/Rser-((x-vCd)/Rd if Cd>0 else 0)
            v=brentq(f,0,455)
            iC=(v-vC)/Rser
        else:
            v=vC
        iCd=(v-vCd)/Rd if Cd>0 else 0.0
        if Rser==0: iC=Ipv(v)-iL-iCd
        # tracker (exact logic of the model, override never active)
        sV+=v; sI+=iL; n+=1
        if n>=Nn:
            Vm=sV/n; Im=sI/n; P=Vm*Im
            if P!=Pprev:
                if P>Pprev: Dprev+= -dD if Vm>Vprev else dD
                else:       Dprev+=  dD if Vm>Vprev else -dD
            Dprev=min(0.9,max(0.1,Dprev)); Pprev=P; Vprev=Vm; sV=sI=0; n=0
        # states (semi-implicit Euler)
        iL+=dt*(v-(1-Dprev)*Vdc)/L
        vC+=dt*iC/Cin
        if Cd>0: vCd+=dt*iCd/Cd
        if k*dt>=T/2: acc.append(v*Ipv(v)); vs.append(v)
    return np.mean(acc)/Pm*100, np.mean(vs), np.min(vs), np.max(vs)
cases={'pure C 100uF':(100e-6,0,0,0),'series 8ohm 100uF':(100e-6,8,0,0),'series 8ohm 500uF':(500e-6,8,0,0),'parallel R-C':(100e-6,0,400e-6,5.12348)}
for G in (300,1000):
    for name,c in cases.items():
        for Tw in (10e-3,50e-3):
            if G==1000 and Tw==50e-3: continue
            s,vm,v0,v1=run(G,c,Tw)
            print('G %4d %-18s Tw %2.0f ms: %.1f %% of Pmpp, Vpv %.1f V (%.0f..%.0f)'%(G,name,Tw*1e3,s,vm,v0,v1),flush=True)
