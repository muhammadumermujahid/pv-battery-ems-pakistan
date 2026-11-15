function D = mppt1(V, I)
% P&O MPPT, averaged version (decision once per N samples); used only for the comparison

persistent Dprev Pprev Vprev sumV sumI n
if isempty(Dprev), Dprev=0.5; Pprev=0; Vprev=0; sumV=0; sumI=0; n=0; end
N = 6000; dD = 0.003;
sumV = sumV + V; sumI = sumI + I; n = n + 1;
if n >= N
    Vavg = sumV/N; Iavg = sumI/N; P = Vavg*Iavg;
    sumV = 0; sumI = 0; n = 0;
    dP = P - Pprev; dV = Vavg - Vprev;
    if dP ~= 0
        if dP > 0
            if dV > 0, Dprev = Dprev - dD; else, Dprev = Dprev + dD; end
        else
            if dV > 0, Dprev = Dprev + dD; else, Dprev = Dprev - dD; end
        end
    end
    Pprev = P; Vprev = Vavg;
end
Dprev = min(max(Dprev, 0.1), 0.9); D = Dprev;
end
