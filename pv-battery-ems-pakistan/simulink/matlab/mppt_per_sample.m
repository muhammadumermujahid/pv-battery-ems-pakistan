function D = mppt1(V, I)
% P&O MPPT, per-sample version (the code in grid_inv_test; used for the reported results)

persistent Dprev Pprev Vprev
if isempty(Dprev)
    Dprev = 0.5;
    Pprev = 0;
    Vprev = 0;
end

P = V * I;
dD = 0.0001;

if (P - Pprev) ~= 0
    if (P - Pprev) > 0
        if (V - Vprev) > 0
            Dprev = Dprev - dD;
        else
            Dprev = Dprev + dD;
        end
    else
        if (V - Vprev) > 0
            Dprev = Dprev + dD;
        else
            Dprev = Dprev - dD;
        end
    end
end

if Dprev >= 0.9
    Dprev = 0.9;
elseif Dprev <= 0.1
    Dprev = 0.1;
end

D = Dprev;
Pprev = P;
Vprev = V;

end
