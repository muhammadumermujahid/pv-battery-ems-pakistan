function D = mppt1(V, I, Vdc)
% MATLAB Function block "MPPT Function": 10 ms averaged P&O with a DC-link voltage override.
% Third input Vdc is wired from the DC-link voltage measurement (Vdc_meas). Above Vhi the duty ratio is moved toward
% the PV open-circuit voltage (kv per volt) and the P&O state is held (paper Sec. IV-G).
persistent Dprev Pprev Vprev sV sI n
if isempty(Dprev)
    Dprev = 0.5; Pprev = 0; Vprev = 0; sV = 0; sI = 0; n = 0;
end
dD = 0.003; Nn = 2000; Vhi = 735; kv = 0.01;
if Vdc > Vhi
    D = max(0.05, Dprev - kv*(Vdc - Vhi)); sV = 0; sI = 0; n = 0; Pprev = V*I; Vprev = V;
    return
end
sV = sV + V; sI = sI + I; n = n + 1;
if n >= Nn
    Vm = sV/n; Im = sI/n; P = Vm*Im;
    if (P - Pprev) ~= 0
        if (P - Pprev) > 0
            if (Vm - Vprev) > 0, Dprev = Dprev - dD; else, Dprev = Dprev + dD; end
        else
            if (Vm - Vprev) > 0, Dprev = Dprev + dD; else, Dprev = Dprev - dD; end
        end
    end
    if Dprev >= 0.9, Dprev = 0.9; elseif Dprev <= 0.1, Dprev = 0.1; end
    Pprev = P; Vprev = Vm; sV = 0; sI = 0; n = 0;
end
D = Dprev;
end
