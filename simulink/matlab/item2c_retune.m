% item2c_retune.m -- decoupling / current-loop gain variants on a weak grid (R2023a). Variants: 1 as built, 2 wL matched, 3 wL matched + P,I x0.5, 4 as-built wL + P,I x0.5, 5 wL matched + P,I x2.
m = 'grid_inv_test_battery'; load_system(m);
Sn = 10e3; Vll = 400; f0 = 50; Zb = Vll^2/Sn; xr = 7; Lf = 4.5e-3;
src = [m '/Three-Phase Source']; pd = [m '/PI_d']; pq = [m '/PI_q']; wd = [m '/wL_id']; wq = [m '/wL_iq'];
o.R = get_param(src,'Resistance'); o.L = get_param(src,'Inductance');
o.Pd = get_param(pd,'P'); o.Id = get_param(pd,'I'); o.Pq = get_param(pq,'P'); o.Iq = get_param(pq,'I'); o.wd = get_param(wd,'Gain'); o.wq = get_param(wq,'Gain');
o.iB = get_param([m '/Irradiance (1000)'],'Before'); o.iA = get_param([m '/Irradiance (1000)'],'After'); o.iT = get_param([m '/Irradiance (1000)'],'Time');
o.p1 = get_param([m '/P1'],'After'); o.stop = get_param(m,'StopTime');
set_param([m '/Irradiance (1000)'],'Before','600','After','1000','Time','0.25'); set_param([m '/P1'],'After','0'); set_param(m,'StopTime','0.6');
V = [0 1; 1 1; 1 .5; 0 .5; 1 2]; vname = {'as built','wL matched','wL matched, P/I x0.5','as built wL, P/I x0.5','wL matched, P/I x2'}; SCRs = [20 10 5 3 2];
rows = []; errObj = []; a = exp(2j*pi/3);
try
  for scr = SCRs
    Zg = Zb/scr; Rg = Zg/sqrt(1+xr^2); Lg = Rg*xr/(2*pi*f0); set_param(src,'Resistance',sprintf('%.6g',Rg),'Inductance',sprintf('%.6g',Lg));
    for v = 1:size(V,1)
      if V(v,1), g = sprintf('2*pi*50*%.6g', Lf+Lg); else, g = o.wd; end
      set_param(wd,'Gain',g); set_param(wq,'Gain',g);
      set_param(pd,'P',num2str(10*V(v,2)),'I',num2str(111*V(v,2))); set_param(pq,'P',num2str(10*V(v,2)),'I',num2str(111*V(v,2)));
      r = struct('SCR',scr,'variant',v,'Lg_mH',Lg*1e3); t0 = tic;
      try
        out = sim(m);
        ia = out.get('i_abc'); ta = ia.Time(:); ya = squeeze(ia.Data); if size(ya,2)~=3, ya = ya.'; end
        sel = ta >= 0.5 & ta <= 0.6; Y = ya(sel,:); n = size(Y,1); fs = 1/mean(diff(ta(sel))); w = 0.5-0.5*cos(2*pi*(0:n-1)'/(n-1));
        F = fft(Y.*w)/n; fq = (0:n-1)'*fs/n; [~,i1] = min(abs(fq-50)); ref = abs((F(i1,1)+a*F(i1,2)+a^2*F(i1,3))/3);
        hh = arrayfun(@(q) max(abs(F(max(1,round(i1*q)-2):round(i1*q)+2,1))), 2:50); r.THD_pct = 100*sqrt(sum(hh.^2))/abs(F(i1,1));
        ib = round(i1*2); [~,j] = max(abs(F(ib-2:ib+2,1))); j = ib-3+j; r.neg2_pct = 100*abs((F(j,1)+a^2*F(j,2)+a*F(j,3))/3)/ref;
        idq = out.get('idq'); tg = idq.Time(:); idm = squeeze(idq.Data); vdq = out.get('vdq'); vdm = squeeze(vdq.Data);
        if size(idm,1)==2 && size(idm,2)~=2, idm = idm.'; vdm = vdm.'; end
        sg = tg >= 0.5 & tg <= 0.6; x = idm(sg,1)-mean(idm(sg,1)); nn = numel(x); fsd = 1/mean(diff(tg(sg))); Xd = abs(fft(x.*(0.5-0.5*cos(2*pi*(0:nn-1)'/(nn-1)))))/nn; fd = (0:nn-1)'*fsd/nn;
        [mx,ix] = max(Xd(3:floor(nn/2))); r.id_dom_Hz = fd(ix+2); r.id_dom_A = 2*mx;
        s_ = out.get('vdc_bat'); if isstruct(s_), tv = s_.time(:); Vd = squeeze(s_.signals.values); else, tv = s_.Time(:); Vd = squeeze(s_.Data); end
        r.Vdc_dev_ss = max(abs(Vd(tv>=0.45)-700)); r.Vpcc_pu = mean(sqrt(vdm(sg,1).^2+vdm(sg,2).^2))/326.6; r.ok = 1;
      catch e1
        fprintf('   failed: %s\n', e1.message); r.THD_pct = NaN; r.neg2_pct = NaN; r.id_dom_Hz = NaN; r.id_dom_A = NaN; r.Vdc_dev_ss = NaN; r.Vpcc_pu = NaN; r.ok = 0;
      end
      fprintf('SCR %2d | %-24s | THD %5.2f %% | neg-seq 2nd %5.2f %% | d-ripple %5.0f Hz %.2f A | Vdc dev %.1f V | %.0f s\n', scr, vname{v}, r.THD_pct, r.neg2_pct, r.id_dom_Hz, r.id_dom_A, r.Vdc_dev_ss, toc(t0));
      rows = [rows; r]; %#ok<AGROW>
    end
  end
catch errObj
end
set_param(src,'Resistance',o.R,'Inductance',o.L); set_param(pd,'P',o.Pd,'I',o.Id); set_param(pq,'P',o.Pq,'I',o.Iq); set_param(wd,'Gain',o.wd); set_param(wq,'Gain',o.wq);
set_param([m '/Irradiance (1000)'],'Before',o.iB,'After',o.iA,'Time',o.iT); set_param([m '/P1'],'After',o.p1); set_param(m,'StopTime',o.stop);
if ~isempty(errObj), rethrow(errObj); end
T = struct2table(rows); writetable(T,'item2c_retune.csv'); disp(T);
