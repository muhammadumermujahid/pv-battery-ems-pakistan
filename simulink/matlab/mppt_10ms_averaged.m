function D = mppt1(V, I)
% Corrected P&O for the MATLAB Function block "MPPT Function" in grid_inv_test_battery.
% Original block: step 1e-4 on every 5 us call (see paper Sec. IV-F). This version averages
% V and I over Nn calls (Nn = 2000 -> 10 ms at 5 us) and then takes one step dD.
% Use together with a 8 ohm series resistance in the Cin branch (BranchType 'RC').
persistent Dprev Pprev Vprev sV sI n
if isempty(Dprev)
    Dprev = 0.5; Pprev = 0; Vprev = 0; sV = 0; sI = 0; n = 0;
end
dD = 0.003; Nn = 2000;
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
