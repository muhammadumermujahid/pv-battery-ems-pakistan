% item2_weakgrid.m -- weak-grid sweep on grid_inv_test_battery (R2023a). Run as a script. NOTE: the 'stable' column is not valid (see README).
m = 'grid_inv_test_battery'; load_system(m);
Sn = 10e3; Vll = 400; f0 = 50; Zb = Vll^2/Sn;                       % SCR defined against the 10 kVA inverter rating
C = [0 7 1];                                                         % [SCR (0 = original strong grid), X/R, PLL gain scale]
for scr = [20 10 5 3 2], for s = [1 .5 .25], C(end+1,:) = [scr 7 s]; end, end %#ok<SAGROW>
for scr = [5 3 2], C(end+1,:) = [scr 2 1]; end                       %#ok<SAGROW>
src = [m '/Three-Phase Source']; pll = [m '/PLL'];
o.R = get_param(src,'Resistance'); o.L = get_param(src,'Inductance'); o.K = get_param(pll,'ParK');
o.iB = get_param([m '/Irradiance (1000)'],'Before'); o.iA = get_param([m '/Irradiance (1000)'],'After'); o.iT = get_param([m '/Irradiance (1000)'],'Time');
o.p1 = get_param([m '/P1'],'After'); o.stop = get_param(m,'StopTime');
fprintf('Original: R=%s L=%s ParK=%s Irr %s->%s at %s  P1 After=%s  Stop=%s\n', o.R, o.L, o.K, o.iB, o.iA, o.iT, o.p1, o.stop);
set_param([m '/Irradiance (1000)'],'Before','600','After','1000','Time','0.25'); set_param([m '/P1'],'After','0'); set_param(m,'StopTime','0.6');
mw = @(t,x,w) mean(x(t>=w(1) & t<=w(2))); wA = [0.45 0.60];
rows = []; SIG = struct([]); errObj = [];
try
  for k = 1:size(C,1)
    scr = C(k,1); xr = C(k,2); ps = C(k,3);
    if scr == 0, set_param(src,'Resistance',o.R,'Inductance',o.L); Lg = NaN; Rg = NaN;
    else, Zg = Zb/scr; Rg = Zg/sqrt(1+xr^2); Lg = Rg*xr/(2*pi*f0); set_param(src,'Resistance',sprintf('%.6g',Rg),'Inductance',sprintf('%.6g',Lg)); end
    set_param(pll,'ParK',sprintf('[%g %g 1]',180*ps,3200*ps));
    r = struct('SCR',scr,'XR',xr,'PLLscale',ps,'Lg_mH',Lg*1e3,'Rg_ohm',Rg,'ok',1); t0 = tic;
    try
        out = sim(m); D = struct();
        for nm = {'ppv','vdc_bat'}
            s_ = out.get(nm{1}); if isstruct(s_), t = s_.time(:); x = squeeze(s_.signals.values); else, t = s_.Time(:); x = squeeze(s_.Data); end
            D.(nm{1}) = struct('t',t,'x',x(:));
        end
        idq = out.get('idq'); vdq = out.get('vdq'); tg = idq.Time(:); idm = squeeze(idq.Data); vdm = squeeze(vdq.Data);
        if size(idm,1)==2 && size(idm,2)~=2, idm = idm.'; vdm = vdm.'; end
        pf = out.get('pll_f'); tf = pf.Time(:); ff = squeeze(pf.Data); ff = ff(:);
        ia = out.get('i_abc'); ta = ia.Time(:); ya = squeeze(ia.Data); if size(ya,2)~=3, ya = ya.'; end
        V = D.vdc_bat.x; tv = D.vdc_bat.t; Pg = 1.5*(vdm(:,1).*idm(:,1) + vdm(:,2).*idm(:,2));
        if mw(tg,Pg,wA)*mw(D.ppv.t,D.ppv.x,wA) < 0, Pg = -Pg; end
        r.Vpcc_pu = mw(tg,sqrt(vdm(:,1).^2 + vdm(:,2).^2),wA)/326.6; r.Ppv_kW = mw(D.ppv.t,D.ppv.x,wA)/1e3; r.Pgrid_kW = mw(tg,Pg,wA)/1e3;
        r.Vdc_dev_step = max(abs(V(tv>=0.25)-700)); r.Vdc_dev_ss = max(abs(V(tv>=wA(1))-700));
        r.PLLf_dev_step = max(abs(ff(tf>=0.25)-50)); r.PLLf_pp_ss = max(ff(tf>=0.5)) - min(ff(tf>=0.5));
        sd = tg >= 0.5; r.id_ripple_pct = (max(idm(sd,1)) - min(idm(sd,1)))/abs(mean(idm(sd,1)))*100;
        sel = ta >= 0.50 & ta <= 0.60; x = ya(sel,1); n = numel(x); fs = 1/mean(diff(ta(sel)));
        X = abs(fft(x.*(0.5-0.5*cos(2*pi*(0:n-1)'/(n-1)))))/n; fq = (0:n-1)'*fs/n; [~,i1] = min(abs(fq-50));
        h = arrayfun(@(q) max(X(max(1,round(i1*q)-2):round(i1*q)+2)), 2:50); r.THD_pct = 100*sqrt(sum(h.^2))/X(i1); r.Ia_pk_A = 2*X(i1)*2;
        r.stable = double(r.Vdc_dev_ss < 10 && r.id_ripple_pct < 20 && r.THD_pct < 8);      % NOT VALID, do not use
        SIG(k).case = C(k,:); SIG(k).tv = tv(1:20:end); SIG(k).vdc = V(1:20:end);
    catch e1
        r.ok = 0; fprintf('   case failed: %s\n', e1.message);
        for fn = {'Vpcc_pu','Ppv_kW','Pgrid_kW','Vdc_dev_step','Vdc_dev_ss','PLLf_dev_step','PLLf_pp_ss','id_ripple_pct','THD_pct','Ia_pk_A'}, r.(fn{1}) = NaN; end, r.stable = 0;
    end
    fprintf('%2d/%d SCR %2d X/R %d PLL x%.2f | Lg %.1f mH | Vpcc %.3f pu | Vdc dev step %.1f / ss %.1f V | THD %.2f %% | %.0f s\n', k,size(C,1),scr,xr,ps,Lg*1e3,r.Vpcc_pu,r.Vdc_dev_step,r.Vdc_dev_ss,r.THD_pct,toc(t0));
    rows = [rows; r]; %#ok<AGROW>
  end
catch errObj
end
set_param(src,'Resistance',o.R,'Inductance',o.L); set_param(pll,'ParK',o.K);
set_param([m '/Irradiance (1000)'],'Before',o.iB,'After',o.iA,'Time',o.iT); set_param([m '/P1'],'After',o.p1); set_param(m,'StopTime',o.stop);
if ~isempty(errObj), rethrow(errObj); end
T = struct2table(rows); writetable(T,'item2_weakgrid.csv'); save('item2_signals.mat','SIG','C'); disp(T);
