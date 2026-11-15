% fine_reruns.m -- reruns every plant result that depends on the model step at 1 us (tracker window kept at 10 ms).
% The 5 us model quantizes both modulators to 40 levels per carrier period, which inflates the grid-current THD
% (1.80 -> 0.74 % at 1000 W/m2) and coarsens the tracker. Sections (set a flag to 0 to skip):
%   S1 Table V plant chain (1000 -> 600 W/m2)            ~5 min
%   S2 battery stage, Table IX rows and midday rows      ~20 min
%   S3 harmonic content against irradiance               ~15 min
%   S4 weak grid, midday run (Table X)                   ~35 min
%   S5 weak grid, gain sets (Table XI)                   ~45 min
%   S6 weak-grid variants (PLL, X/R 2, decoupling/gains) ~90 min
%   S7 tracker steady states 300-1000 W/m2               ~30 min
%   S8 34-point plant loss map for the EMS re-costing    ~40 min
% Everything printed goes to fine_reruns_console.txt as it runs. Figure data go to fine_fig5_run.txt, fine_fig6a_iabc.txt and fine_battery.txt
% (comma-separated text, readable in Notepad). Total about 4.5 h: start it before you sleep. The model is closed WITHOUT saving at the end.
% Run this script from the folder that contains grid_inv_test_battery.slx (for example: cd('C:\work\pv_model')).
diary('fine_reruns_console.txt'); diary on
RUN = struct('S1',1,'S2',1,'S3',1,'S4',1,'S5',1,'S6',1,'S7',1,'S8',1);
m = 'grid_inv_test_battery'; load_system(m); Zb = 400^2/10e3; f0 = 50; Lf = 4.5e-3; TS = 1e-6;
errObj = [];
try
  % ---- switch the model to 1 us: same search as finestep_test.m (literal 5e-6 values, symbolic Ts variables, chart sample time) ----
  blks = find_system(m,'FollowLinks','on','LookUnderMasks','none','Type','Block'); C = cell(0,3);
  for k = 1:numel(blks)
    dp = get_param(blks{k},'DialogParameters'); if isempty(dp), continue, end
    for f = fieldnames(dp)'
      try, v = get_param(blks{k},f{1}); catch, continue, end
      if ischar(v) && any(strcmpi(strtrim(v),{'5e-6','5e-06','5.0e-6','0.000005','Ts','Ts_Power','Ts_Control'})), C(end+1,:) = {blks{k}, f{1}, v}; end %#ok<AGROW>
    end
  end
  nlit = 0;
  for k = 1:size(C,1)
    if ~isnan(str2double(C{k,3})), set_param(C{k,1}, C{k,2}, sprintf('%g',TS)); nlit = nlit + 1;
    else
      mw0 = get_param(m,'ModelWorkspace');
      if hasVariable(mw0,C{k,3}), assignin(mw0, C{k,3}, TS); elseif evalin('base',sprintf('exist(''%s'',''var'')',C{k,3})), assignin('base', C{k,3}, TS); end
    end
  end
  if ~strcmpi(get_param(m,'FixedStep'),'auto'), set_param(m,'FixedStep',sprintf('%g',TS)); end
  rt = sfroot; ch = rt.find('-isa','Stateflow.EMChart','Path',[m '/MPPT Function']); S0 = ch.Script; assert(contains(S0,'Nn = 2000'), 'Tracker script does not contain "Nn = 2000"; stop.');
  try, st = str2double(ch.SampleTime); catch, st = NaN; end
  if ~isnan(st) && st > 0, ch.SampleTime = sprintf('%g',TS); end
  ch.Script = strrep(S0,'Nn = 2000',sprintf('Nn = %d',round(10e-3/TS)));
  fprintf('Model at %g s: %d step parameters found (%d literal), FixedStep %s, tracker window %d calls (10 ms)\n', TS, size(C,1), nlit, get_param(m,'FixedStep'), round(10e-3/TS));
  o = snapshot(m);
  fprintf('P1: Time %s After %s | P2: Time %s After %s\n', o.v{4}, o.v{6}, o.v{7}, o.v{9});
  P1orig = {o.v{4},o.v{5},o.v{6}}; P2orig = {o.v{7},o.v{8},o.v{9}};

  if RUN.S1
    disp('=== S1: Table V (1000 -> 600 W/m2 at 0.5 s) ===');
    restore_all(m,o); set_run(m,'1000','600','0.5','1.2',{'10','0','0'},{'10','0','0'}); t0 = tic; S = readsigs(sim(m));
    for w = [0.3 0.5; 0.9 1.1]'
      ppv = mw(S.tp,S.ppv,w)/1e3; pac = mw(S.tg,S.pg,w)/1e3; pdc = mw(S.tdc,S.pdc,w)/1e3;
      [th,i1] = thd_rect(S.ta,S.ia,w,1); [th20,c5] = thd20k(S.ta,S.ia,w);
      fprintf('%.1f-%.1f s | PV %.3f | DC-link %.3f | AC %.3f kW | boost %.2f | inverter %.2f | PV-to-AC %.2f %% | Vdc %.2f V | I1 %.2f A pk | THD(2-50) %.2f %% | THD to 20 kHz %.2f %% | 5 kHz %.3f %% | %s\n', ...
        w(1), w(2), ppv, pdc, pac, 100*pdc/ppv, 100*pac/pdc, 100*pac/ppv, mw(S.tv,S.vdc,w), i1, th, th20, c5, tops(S.ta,S.ia,w));
    end
    tg = (0:1e-4:1.2)'; T = table(tg, itp(S.tp,S.ppv,tg), itp(S.tg,S.pg,tg), itp(S.tv,S.vdc,tg), itp(S.tvp,S.vpv,tg), itp(S.tg,S.id,tg), itp(S.tg,S.iq,tg), 'VariableNames',{'t','ppv_W','pgrid_W','vdc_V','vpv_V','id_A','iq_A'});
    writetable(T,'fine_fig5_run.txt'); sel = S.ta >= 0.30 & S.ta <= 0.36;
    writetable(table(S.ta(sel),S.ia(sel,1),S.ia(sel,2),S.ia(sel,3),'VariableNames',{'t','ia','ib','ic'}),'fine_fig6a_iabc.txt'); disp('figure data written: fine_fig5_run.txt, fine_fig6a_iabc.txt');
    pd = [NaN NaN]; if ~isempty(S.tpll), pd = [max(abs(S.pll(S.tpll<=0.1)-50)), max(abs(S.pll(S.tpll>0.1)-50))]; end
    tt = S.tv; vv = S.vdc; k = find(tt > 0.5 & abs(vv-700) > 5, 1, 'last');
    fprintf('start-up Vdc max %.1f V | after step min %.1f V | back within +/-5 V after %.0f ms | id %.2f -> %.2f A | iq %.2f A | PLL dev %.3f / %.3f Hz | %.0f s\n', max(vv(tt<0.1)), min(vv(tt>0.5 & tt<0.7)), (tt(k)-0.5)*1e3, abs(mw(S.tg,S.id,[0.4 0.5])), abs(mw(S.tg,S.id,[0.9 1.1])), mw(S.tg,S.iq,[0.9 1.1]), pd(1), pd(2), toc(t0));
  end

  if RUN.S2
    disp('=== S2: battery stage (300 W/m2, original P1/P2) and midday (1000 W/m2, -5 kW at 0.5 s) ===');
    for ff = [1 0]
      restore_all(m,o); if ~ff, set_param([m '/Gain_ff'],'Gain','0'); end
      set_run(m,'300','300','0.5','1.0',P1orig,P2orig); t0 = tic; S = readsigs(sim(m));
      W = [0.3 0.4; 0.5 0.7; 0.9 1.0]; T = [0.2 0.4; 0.5 0.7; 0.82 1.0]; lab = {'Idle','Discharge','Charge'};
      for q = 1:3
        sel = S.tv >= W(q,1) & S.tv <= W(q,2); [th,i1] = thd_rect(S.ta,S.ia,T(q,:),1);
        fprintf('FF %d %-9s | Ibat %.2f A | Vdc %.1f (%.0f-%.0f) V | PV %.2f kW | export %.2f kW | THD %.2f %% | I1 %.2f A pk | TRD %.2f %%\n', ff, lab{q}, mw(S.ti,S.ibat,W(q,:)), mean(S.vdc(sel)), min(S.vdc(sel)), max(S.vdc(sel)), mw(S.tp,S.ppv,W(q,:))/1e3, mw(S.tg,S.pg,W(q,:))/1e3, th, i1, th*i1/20.41);
      end
      for st = [0.4 0.8], [pk,tk,rtm] = stepdev(S,st); fprintf('   step at %.1f s: peak %+.1f V at %.0f ms, back within +/-5 V after %.0f ms\n', st, pk, tk, rtm); end
      fprintf('   start-up Vdc min %.1f V (0-40 ms) | %.0f s\n', min(S.vdc(S.tv<0.04)), toc(t0));
      if ff
        [tu,iu] = unique(S.ti); ib = S.ibat(iu); iav = movmean(ib,200e-6,'SamplePoints',tu); tg = (0:1e-4:1.0)';
        writetable(table(tg, itp(tu,iav,tg), itp(tu,ib,tg), itp(S.tv,S.vdc,tg), itp(S.tg,S.pg,tg), itp(S.tp,S.ppv,tg), 'VariableNames',{'t','ibat_avg_A','ibat_sample_A','vdc_V','pgrid_W','ppv_W'}),'fine_battery.txt');
        pp = ib(tu >= 0.5 & tu <= 0.7); fprintf('   discharge ripple %.2f A peak to peak | figure data written: fine_battery.txt\n', max(pp)-min(pp));
      end
      restore_all(m,o); if ~ff, set_param([m '/Gain_ff'],'Gain','0'); end
      set_run(m,'1000','1000','0.5','1.0',{'0.5','0','-5000'},{'10','0','0'}); t0 = tic; S = readsigs(sim(m)); [pk,tk,rtm] = stepdev(S,0.5);
      [th1,i11] = thd_rect(S.ta,S.ia,[0.3 0.5],1); [th2,i12] = thd_rect(S.ta,S.ia,[0.8 1.0],1);
      fprintf('FF %d midday | export %.2f -> %.2f kW | PV %.2f / %.2f kW | Ibat %.2f A | peak Vdc %+.1f V, back in %.0f ms | THD %.2f / %.2f %% (I1 %.2f / %.2f A, TRD %.2f / %.2f %%) | %.0f s\n', ff, mw(S.tg,S.pg,[0.3 0.4])/1e3, mw(S.tg,S.pg,[0.6 1.0])/1e3, mw(S.tp,S.ppv,[0.3 0.4])/1e3, mw(S.tp,S.ppv,[0.6 1.0])/1e3, mw(S.ti,S.ibat,[0.6 1.0]), pk, rtm, th1, th2, i11, i12, th1*i11/20.41, th2*i12/20.41, toc(t0));
    end
  end

  if RUN.S3
    disp('=== S3: harmonic currents against irradiance (idle, 1.0 s, window 0.5-1.0 s) ===');
    for G = [5 100 300 1000]
      restore_all(m,o); set_run(m,num2str(G),num2str(G),'0.5','1.0',{'10','0','0'},{'10','0','0'}); t0 = tic; S = readsigs(sim(m));
      A = hamp(S.ta,S.ia,[0.5 1.0]);
      fprintf('G %4d | I1 %.3f A pk | h2 %.3f h5 %.3f h7 %.3f h11 %.3f h13 %.3f A (3-phase mean) | THD %.2f %% | %.0f s\n', G, A(1), A(2), A(5), A(7), A(11), A(13), thd_rect(S.ta,S.ia,[0.5 1.0],1), toc(t0));
    end
  end

  if RUN.S4
    disp('=== S4: weak grid, midday run, X/R 7 ===');
    for scr = [0 100 20 10 5 3 2]
      restore_all(m,o); set_grid(m,o,scr,7,Zb,f0); set_run(m,'1000','1000','0.5','1.0',{'0.5','0','-5000'},{'10','0','0'}); t0 = tic; S = readsigs(sim(m));
      fprintf('SCR %4g | max|dVdc| %.2f / %.2f V | THD %.2f / %.2f %% (%s) | Vpcc %.3f pu | %.0f s\n', scr, max(abs(S.vdc(S.tv>=0.2 & S.tv<=0.5)-700)), max(abs(S.vdc(S.tv>=0.5 & S.tv<=1.0)-700)), thd_rect(S.ta,S.ia,[0.3 0.5],1), thd_rect(S.ta,S.ia,[0.8 1.0],1), tops(S.ta,S.ia,[0.8 1.0]), mw(S.tg,sqrt(S.vd.^2+S.vq.^2),[0.8 1.0])/326.6, toc(t0));
    end
  end

  if RUN.S5
    disp('=== S5: weak grid, gain sets (idle, 600 -> 1000 W/m2 at 0.25 s, window 0.5-0.6 s) ===');
    vn = {'original','scaled','scaled x1.5'};
    for scr = [0 20 10 5 3 2]
      for v = 1:3
        if scr == 0 && v > 1, continue, end
        restore_all(m,o); set_grid(m,o,scr,7,Zb,f0); kp = 10;
        if scr > 0 && v > 1
          Lg = (Zb/scr)/sqrt(50)*7/(2*pi*f0); s0 = (Lf+Lg)/Lf; fac = [1 1 1.5]; kp = 10*s0*fac(v); g = sprintf('2*pi*50*%.6g', Lf+Lg);
          set_param([m '/wL_id'],'Gain',g); set_param([m '/wL_iq'],'Gain',g);
          set_param([m '/PI_d'],'P',num2str(kp),'I',num2str(111*s0*fac(v))); set_param([m '/PI_q'],'P',num2str(kp),'I',num2str(111*s0*fac(v)));
        end
        set_run(m,'600','1000','0.25','0.6',{'10','0','0'},{'10','0','0'}); t0 = tic; S = readsigs(sim(m));
        fprintf('SCR %2g %-11s Kp %5.1f | THD %.2f %% (%s) | neg-seq 2nd %.2f %% | Vdc dev ss %.1f V | %.0f s\n', scr, vn{v}, kp, thd_rect(S.ta,S.ia,[0.5 0.6],1), tops(S.ta,S.ia,[0.5 0.6]), seqneg(S,[0.5 0.6]), max(abs(S.vdc(S.tv>=0.45)-700)), toc(t0));
      end
    end
  end

  if RUN.S6
    disp('=== S6: weak-grid variants ===');
    Cp = [20 7 .5; 20 7 .25; 5 7 .5; 5 7 .25; 2 7 .5; 2 7 .25; 5 2 1; 3 2 1; 2 2 1];
    for k = 1:size(Cp,1)
      restore_all(m,o); set_grid(m,o,Cp(k,1),Cp(k,2),Zb,f0); set_param([m '/PLL'],'ParK',sprintf('[%g %g 1]',180*Cp(k,3),3200*Cp(k,3)));
      set_run(m,'600','1000','0.25','0.6',{'10','0','0'},{'10','0','0'}); t0 = tic; S = readsigs(sim(m));
      fprintf('SCR %2g X/R %g PLL x%.2f | THD %.2f %% | neg-seq 2nd %.2f %% | Vdc dev ss %.1f V | Vpcc %.3f pu | %.0f s\n', Cp(k,:), thd_rect(S.ta,S.ia,[0.5 0.6],1), seqneg(S,[0.5 0.6]), max(abs(S.vdc(S.tv>=0.45)-700)), mw(S.tg,sqrt(S.vd.^2+S.vq.^2),[0.5 0.6])/326.6, toc(t0));
    end
    V = [1 1; 1 .5; 0 .5; 1 2]; vname = {'wL matched','wL matched, x0.5','as built wL, x0.5','wL matched, x2'};
    for scr = [20 10 5 3 2]
      for v = 1:size(V,1)
        restore_all(m,o); set_grid(m,o,scr,7,Zb,f0); Lg = (Zb/scr)/sqrt(50)*7/(2*pi*f0);
        if V(v,1), g = sprintf('2*pi*50*%.6g', Lf+Lg); set_param([m '/wL_id'],'Gain',g); set_param([m '/wL_iq'],'Gain',g); end
        set_param([m '/PI_d'],'P',num2str(10*V(v,2)),'I',num2str(111*V(v,2))); set_param([m '/PI_q'],'P',num2str(10*V(v,2)),'I',num2str(111*V(v,2)));
        set_run(m,'600','1000','0.25','0.6',{'10','0','0'},{'10','0','0'}); t0 = tic;
        try
          S = readsigs(sim(m));
          fprintf('SCR %2g %-18s | THD %.2f %% | neg-seq 2nd %.2f %% | Vdc dev ss %.1f V | Vpcc %.3f pu | I1 %.2f A | %.0f s\n', scr, vname{v}, thd_rect(S.ta,S.ia,[0.5 0.6],1), seqneg(S,[0.5 0.6]), max(abs(S.vdc(S.tv>=0.45)-700)), mw(S.tg,sqrt(S.vd.^2+S.vq.^2),[0.5 0.6])/326.6, nth2(S.ta,S.ia,[0.5 0.6]), toc(t0));
        catch e1, fprintf('SCR %2g %-18s | run failed: %s\n', scr, vname{v}, e1.message); end
      end
    end
  end

  if RUN.S7
    disp('=== S7: tracker steady states (series 8 ohm, 1.0 s, window 0.5-1.0 s) ===');
    Gs = 300:100:1000; Pav = [2.898 3.907 4.913 5.914 6.908 7.895 8.872 9.841];
    for k = 1:numel(Gs)
      restore_all(m,o); set_run(m,num2str(Gs(k)),num2str(Gs(k)),'0.5','1.0',{'10','0','0'},{'10','0','0'}); t0 = tic; S = readsigs(sim(m));
      P = mw(S.tp,S.ppv,[0.5 1.0])/1e3; fprintf('G %4d | PV %.3f kW = %.1f %% of available %.3f kW | %.0f s\n', Gs(k), P, 100*P/Pav(k), Pav(k), toc(t0));
    end
  end
  if RUN.S8
    disp('=== S8: 34-point loss map (constant irradiance, battery step at 0.1 s, mean over 0.4-0.6 s) ==='); pairs = [];
    for g = [5 50 150 300], for pb = [-5 -2.5 0 2.5 5], pairs(end+1,:) = [g pb]; end, end %#ok<AGROW>
    for pb = [-5 -2.5 0 2.5], pairs(end+1,:) = [500 pb]; end %#ok<AGROW>
    for pb = [-5 -2.5 0 2.5], pairs(end+1,:) = [700 pb]; end %#ok<AGROW>
    for pb = [-5 -2.5 0], pairs(end+1,:) = [850 pb]; end %#ok<AGROW>
    for pb = [-5 -2.5 0], pairs(end+1,:) = [1000 pb]; end %#ok<AGROW>
    w = [0.4 0.6];
    for k = 1:size(pairs,1)
      g = pairs(k,1); pb = pairs(k,2); restore_all(m,o); set_run(m,sprintf('%g',g),sprintf('%g',g),'0.5','0.6',{'0.1','0',sprintf('%g',pb*1e3)},{'10','0','0'}); t0 = tic; S = readsigs(sim(m));
      Ppv = mw(S.tp,S.ppv,w)/1e3; Pg = mw(S.tg,S.pg,w)/1e3; Pb = mw(S.ti,S.ibat,w)*400/1e3; sv = S.tv>=w(1) & S.tv<=w(2);
      fprintf('E %2d/34 G %4g Pbat %+4.1f | Ppv %.3f Pbat %.3f Pgrid %.3f loss %.3f kW | Vdc %.1f (%.1f..%.1f) | %.0f s\n', k, g, pb, Ppv, Pb, Pg, Ppv+Pb-Pg, mean(S.vdc(sv)), min(S.vdc(sv)), max(S.vdc(sv)), toc(t0));
    end
  end
catch errObj
end
close_system(m,0); disp('Model closed without saving; the saved model is unchanged.');
if ~isempty(errObj), diary off; rethrow(errObj); end
disp('ALL DONE'); diary off

function o = snapshot(m)
  o.list = {'Irradiance (1000)','Before'; 'Irradiance (1000)','After'; 'Irradiance (1000)','Time'; 'P1','Time'; 'P1','Before'; 'P1','After'; 'P2','Time'; 'P2','Before'; 'P2','After'; 'Gain_ff','Gain'; ...
            'Three-Phase Source','Resistance'; 'Three-Phase Source','Inductance'; 'PLL','ParK'; 'PI_d','P'; 'PI_d','I'; 'PI_q','P'; 'PI_q','I'; 'wL_id','Gain'; 'wL_iq','Gain'};
  o.v = cell(1,size(o.list,1)); for k = 1:size(o.list,1), o.v{k} = get_param([m '/' o.list{k,1}],o.list{k,2}); end
  o.stop = get_param(m,'StopTime');
end
function restore_all(m,o)
  for k = 1:size(o.list,1), set_param([m '/' o.list{k,1}],o.list{k,2},o.v{k}); end
  set_param(m,'StopTime',o.stop);
end
function set_run(m,g1,g2,gt,tstop,p1,p2)
  set_param([m '/Irradiance (1000)'],'Before',g1,'After',g2,'Time',gt); set_param(m,'StopTime',tstop);
  set_param([m '/P1'],'Time',p1{1},'Before',p1{2},'After',p1{3}); set_param([m '/P2'],'Time',p2{1},'Before',p2{2},'After',p2{3});
end
function set_grid(m,o,scr,xr,Zb,f0)
  src = [m '/Three-Phase Source'];
  if scr == 0, set_param(src,'Resistance',o.v{11},'Inductance',o.v{12});
  else, Zg = Zb/scr; Rg = Zg/sqrt(1+xr^2); Lg = Rg*xr/(2*pi*f0); set_param(src,'Resistance',sprintf('%.6g',Rg),'Inductance',sprintf('%.6g',Lg)); end
end
function S = readsigs(out)
  S = struct();
  [S.tp,S.ppv] = sg(out.get('ppv')); [S.ti,S.ibat] = sg(out.get('ibat')); [S.tv,S.vdc] = sg(out.get('vdc_bat'));
  idq = out.get('idq'); vdq = out.get('vdq'); S.tg = idq.Time(:); idm = squeeze(idq.Data); vdm = squeeze(vdq.Data);
  if size(idm,1)==2 && size(idm,2)~=2, idm = idm.'; vdm = vdm.'; end
  S.pg = -1.5*(vdm(:,1).*idm(:,1) + vdm(:,2).*idm(:,2)); S.id = idm(:,1); S.iq = idm(:,2); S.vd = vdm(:,1); S.vq = vdm(:,2);
  ia = out.get('i_abc'); S.ta = ia.Time(:); x = squeeze(ia.Data); if size(x,1) < size(x,2), x = x.'; end; S.ia = x;
  S.tpll = []; S.pll = []; S.tdc = []; S.pdc = []; S.tvp = []; S.vpv = [];
  try, [S.tvp,S.vpv] = sg(out.get('vpv')); catch, end
  try, [S.tpll,S.pll] = sg(out.get('pll_f')); catch, end
  try, [td,id_] = sg(out.get('idio')); n = min(numel(td),numel(S.vdc)); S.tdc = td(1:n); S.pdc = S.vdc(1:n).*id_(1:n); catch, end
end
function [t,x] = sg(s)
  if isstruct(s), t = s.time(:); x = squeeze(s.signals(1).values); else, t = s.Time(:); x = squeeze(s.Data); end
  if size(x,1) < size(x,2), x = x.'; end
  if size(x,2) > 1, x = x(:,1); end
end
function v = mw(t,x,w), v = mean(x(t>=w(1) & t<=w(2))); end
function y = itp(t,x,tq)
  if isempty(t), y = nan(size(tq)); return, end
  [t,iu] = unique(t); y = interp1(t,x(iu),tq,'linear','extrap');
end
function [pk,tk,rt] = stepdev(S,st)
  sel = S.tv > st & S.tv < st+0.2; vs = S.vdc(sel); ts = S.tv(sel); [~,kk] = max(abs(vs-700)); pk = vs(kk)-700; tk = (ts(kk)-st)*1e3;
  kl = find(abs(vs-700) > 5, 1, 'last'); if isempty(kl), rt = 0; else, rt = (ts(kl)-st)*1e3; end
end
function [A,b,n] = spec(t,X,w,ph)
  k0 = find(t >= w(1),1); dt = mean(diff(t(k0:k0+100))); n = round((w(2)-w(1))/dt); y = X(k0:k0+n-1,ph); A = abs(fft(y))/n; b = round(50*n*dt);
end
function [thd,i1] = thd_rect(t,X,w,ph)
  [A,b] = spec(t,X,w,ph); thd = 100*sqrt(sum(A((2:50)*b+1).^2))/A(b+1); i1 = 2*A(b+1);
end
function i1 = nth2(t,X,w), [~,i1] = thd_rect(t,X,w,1); end
function [th20,c5] = thd20k(t,X,w)
  [A,b,n] = spec(t,X,w,1); dt = (w(2)-w(1))/n; k20 = round(20000*n*dt)+1; mask = true(k20,1); mask(1) = false; mask(b+1) = false;
  th20 = 100*sqrt(sum(A(mask).^2))/A(b+1); c5 = 100*A(round(5000*n*dt)+1)/A(b+1);
end
function s = tops(t,X,w)
  [A,b] = spec(t,X,w,1); h = 100*A((2:50)*b+1)/A(b+1); [v,k] = sort(h,'descend'); s = sprintf('h%d %.2f, h%d %.2f, h%d %.2f', k(1)+1, v(1), k(2)+1, v(2), k(3)+1, v(3));
end
function A = hamp(t,X,w)
  A = zeros(1,13);
  for ph = 1:3, [S,b] = spec(t,X,w,ph); A = A + 2*S((1:13)*b+1)'/3; end
end
function neg2 = seqneg(S,w)
  a = exp(2j*pi/3); sel = S.ta >= w(1) & S.ta < w(2); Y = S.ia(sel,:); n = size(Y,1); F = fft(Y)/n; b = round(50*n*mean(diff(S.ta(sel))));
  ref = abs((F(b+1,1)+a*F(b+1,2)+a^2*F(b+1,3))/3); neg2 = 100*abs((F(2*b+1,1)+a^2*F(2*b+1,2)+a*F(2*b+1,3))/3)/ref;
end
