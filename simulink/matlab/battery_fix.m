% battery_fix.m -- battery current loop: diagnosis of the Saturation2 clamp, then all battery results with it corrected.
% Wiring (model_dump.txt): err = Gain(P*/400) - i_bat -> PI (19, 3600, 50 us) -> Vsum = V_bat - PI -> Divide = Vsum / Saturation2(V_dc)
% -> Saturation1 (0.05..0.95) = d -> 2d-1 -> half-bridge PWM. Saturation2 is limited to +/-0.5, so it outputs 0.5 instead of
% V_dc (about 700 V): the duty is (V_bat - PI)/0.5, 1400 times the intended (V_bat - PI)/V_dc.
%   Part D (as built): logs d, the PI output and the Saturation2 output in the 300 W/m2 battery test   ~4 min
%   Part C (corrected, Saturation2 limits 100..1000 V so it passes V_dc): 300 W/m2 and midday tests with
%          feed-forward on and off, figure data fine_battery_fixed.txt                               ~16 min
%   Part M (corrected): 34-point loss map                                                             ~50 min
% All at 1 us with the 10 ms tracker; console in battery_fix_console.txt. Model closed WITHOUT saving.
% Run this script from the folder that contains grid_inv_test_battery.slx (for example: cd('C:\work\pv_model')).
diary('battery_fix_console.txt'); diary on
RUN = struct('D',1,'C',1,'M',1);
m = 'grid_inv_test_battery'; load_system(m); TS = 1e-6; errObj = [];
try
  % ---- 1 us step (same 11 parameters as before) and 10 ms tracker window ----
  blks = find_system(m,'FollowLinks','on','LookUnderMasks','none','Type','Block'); n5 = 0;
  for k = 1:numel(blks)
    dp = get_param(blks{k},'DialogParameters'); if isempty(dp), continue, end
    fn = fieldnames(dp);
    for j = 1:numel(fn)
      try, v = get_param(blks{k},fn{j}); catch, continue, end
      if ischar(v) && any(strcmpi(strtrim(v),{'5e-6','5e-06'})), set_param(blks{k},fn{j},'1e-06'); n5 = n5 + 1; end
    end
  end
  set_param(m,'FixedStep','1e-06');
  rt = sfroot; ch = rt.find('-isa','Stateflow.EMChart','Path',[m '/MPPT Function']); S0 = ch.Script;
  assert(contains(S0,'Nn = 2000'), 'Tracker script does not contain Nn = 2000');
  ch.Script = strrep(S0,'Nn = 2000','Nn = 10000');
  fprintf('Model at 1 us: %d step parameters changed; tracker window 10000 calls\n', n5);
  % ---- loggers for the duty, the PI output and the Saturation2 output (removed when the model is closed unsaved) ----
  lg = {'dg_d','Saturation1'; 'dg_pi','PI'; 'dg_s2','Saturation2'};
  for k = 1:size(lg,1)
    add_block('simulink/Sinks/To Workspace',[m '/' lg{k,1}],'VariableName',lg{k,1},'SaveFormat','Timeseries','SampleTime','-1');
    add_line(m,[lg{k,2} '/1'],[lg{k,1} '/1'],'autorouting','on');
  end
  o = snapshot(m); P1o = {o.v{4},o.v{5},o.v{6}}; P2o = {o.v{7},o.v{8},o.v{9}};
  fprintf('Saturation2 as built: Upper %s, Lower %s | P1 %s at %s s, P2 %s at %s s\n', get_param([m '/Saturation2'],'UpperLimit'), get_param([m '/Saturation2'],'LowerLimit'), o.v{6}, o.v{4}, o.v{9}, o.v{7});

  if RUN.D
    disp('=== D: as built (Saturation2 +/-0.5), 300 W/m2 battery test, feed-forward on ===');
    restore_all(m,o); set_run(m,'300','300','0.5','1.0',P1o,P2o); t0 = tic; out = sim(m); S = readsigs(out); Dg = readdiag(out);
    batt_report(S, Dg, 'as built', 1); fprintf('   %.0f s\n', toc(t0));
  end

  % ---- correction: Saturation2 passes the DC-link voltage (limits 100..1000 V instead of +/-0.5) ----
  set_param([m '/Saturation2'],'UpperLimit','1000','LowerLimit','100'); o = snapshot(m);
  disp('Saturation2 set to 100..1000 V for all following runs');

  if RUN.C
    for ff = [1 0]
      fprintf('=== C: corrected, 300 W/m2 battery test, feed-forward %d ===\n', ff);
      restore_all(m,o); if ~ff, set_param([m '/Gain_ff'],'Gain','0'); end
      set_run(m,'300','300','0.5','1.0',P1o,P2o); t0 = tic; out = sim(m); S = readsigs(out); Dg = readdiag(out);
      batt_report(S, Dg, 'corrected', ff);
      if ff
        [tu,iu] = unique(S.ti); ib = S.ibat(iu); iav = movmean(ib,200e-6,'SamplePoints',tu); tg = (0:1e-4:1.0)';
        writetable(table(tg, itp(tu,iav,tg), itp(tu,ib,tg), itp(S.tv,S.vdc,tg), itp(S.tg,S.pg,tg), itp(S.tp,S.ppv,tg), 'VariableNames',{'t','ibat_avg_A','ibat_sample_A','vdc_V','pgrid_W','ppv_W'}),'fine_battery_fixed.txt');
        disp('   figure data written: fine_battery_fixed.txt');
      end
      fprintf('   %.0f s\n', toc(t0));
      fprintf('=== C: corrected, midday 1000 W/m2, -5 kW at 0.5 s, feed-forward %d ===\n', ff);
      restore_all(m,o); if ~ff, set_param([m '/Gain_ff'],'Gain','0'); end
      set_run(m,'1000','1000','0.5','1.0',{'0.5','0','-5000'},{'10','0','0'}); t0 = tic; out = sim(m); S = readsigs(out); Dg = readdiag(out);
      [pk,tk,rtm] = stepdev(S,0.5); [th1,i11] = thd_rect(S.ta,S.ia,[0.3 0.5],1); [th2,i12] = thd_rect(S.ta,S.ia,[0.8 1.0],1);
      fprintf('   export %.2f -> %.2f kW | PV %.2f / %.2f kW | Ibat %.2f A | peak Vdc %+.1f V at %.0f ms, back in %.0f ms | max|dVdc| %.2f / %.2f V | Vdc mean %.2f / %.2f V\n', ...
        mw(S.tg,S.pg,[0.3 0.4])/1e3, mw(S.tg,S.pg,[0.6 1.0])/1e3, mw(S.tp,S.ppv,[0.3 0.4])/1e3, mw(S.tp,S.ppv,[0.6 1.0])/1e3, mw(S.ti,S.ibat,[0.6 1.0]), pk, tk, rtm, ...
        max(abs(S.vdc(S.tv>=0.2 & S.tv<=0.5)-700)), max(abs(S.vdc(S.tv>=0.5 & S.tv<=1.0)-700)), mw(S.tv,S.vdc,[0.3 0.4]), mw(S.tv,S.vdc,[0.6 1.0]));
      fprintf('   THD %.2f / %.2f %% (I1 %.2f / %.2f A, TRD %.2f / %.2f %%) | settle %.1f ms | duty at a limit %.1f %% | %.0f s\n', th1, th2, i11, i12, th1*i11/20.41, th2*i12/20.41, settle(S,0.5,-12.5), limfrac(Dg,[0.6 1.0]), toc(t0));
    end
  end

  if RUN.M
    disp('=== M: corrected, 34-point loss map (constant irradiance, battery step at 0.1 s, mean over 0.4-0.6 s) ==='); pairs = [];
    for g = [5 50 150 300], for pb = [-5 -2.5 0 2.5 5], pairs(end+1,:) = [g pb]; end, end %#ok<AGROW>
    for pb = [-5 -2.5 0 2.5], pairs(end+1,:) = [500 pb]; end %#ok<AGROW>
    for pb = [-5 -2.5 0 2.5], pairs(end+1,:) = [700 pb]; end %#ok<AGROW>
    for pb = [-5 -2.5 0], pairs(end+1,:) = [850 pb]; end %#ok<AGROW>
    for pb = [-5 -2.5 0], pairs(end+1,:) = [1000 pb]; end %#ok<AGROW>
    w = [0.4 0.6];
    for k = 1:size(pairs,1)
      g = pairs(k,1); pb = pairs(k,2); restore_all(m,o);
      set_run(m,sprintf('%g',g),sprintf('%g',g),'0.5','0.6',{'0.1','0',sprintf('%g',pb*1e3)},{'10','0','0'}); t0 = tic; S = readsigs(sim(m));
      Ppv = mw(S.tp,S.ppv,w)/1e3; Pg = mw(S.tg,S.pg,w)/1e3; Pb = mw(S.ti,S.ibat,w)*400/1e3; sv = S.tv>=w(1) & S.tv<=w(2);
      fprintf('E %2d/34 G %4g Pbat %+4.1f | Ppv %.3f Pbat %.3f Pgrid %.3f loss %.3f kW | Vdc %.1f (%.1f..%.1f) | %.0f s\n', k, g, pb, Ppv, Pb, Pg, Ppv+Pb-Pg, mean(S.vdc(sv)), min(S.vdc(sv)), max(S.vdc(sv)), toc(t0));
    end
  end
catch errObj
end
close_system(m,0); disp('Model closed without saving; the saved model is unchanged.');
if ~isempty(errObj), diary off; rethrow(errObj); end
disp('ALL DONE'); diary off

% ============================ local functions ============================
function batt_report(S, Dg, lab, ff)
  W = [0.3 0.4; 0.5 0.7; 0.9 1.0]; T = [0.2 0.4; 0.5 0.7; 0.82 1.0]; nm = {'Idle','Discharge','Charge'}; ref = [0 12.5 -12.5];
  for q = 1:3
    sel = S.tv >= W(q,1) & S.tv <= W(q,2); [th,i1] = thd_rect(S.ta,S.ia,T(q,:),1);
    si = S.ti >= W(q,1) & S.ti <= W(q,2); ib = S.ibat(si);
    fprintf('%-9s FF %d %-9s | Ibat %.2f A (ripple %.2f A p-p) | Vdc %.2f (%.2f..%.2f) V | PV %.2f | export %.2f kW | THD %.2f %% | TRD %.2f %% | duty %.3f, at a limit %.1f %% of samples | PI %.1f..%.1f V\n', ...
      lab, ff, nm{q}, mean(ib), max(ib)-min(ib), mean(S.vdc(sel)), min(S.vdc(sel)), max(S.vdc(sel)), mw(S.tp,S.ppv,W(q,:))/1e3, mw(S.tg,S.pg,W(q,:))/1e3, th, th*i1/20.41, ...
      mw(Dg.t,Dg.d,W(q,:)), limfrac(Dg,W(q,:)), min(Dg.pi(Dg.t>=W(q,1) & Dg.t<=W(q,2))), max(Dg.pi(Dg.t>=W(q,1) & Dg.t<=W(q,2))));
    if q > 1, fprintf('             settle to +/-1.25 A of %+.1f A: %.1f ms after the step\n', ref(q), settle(S, 0.4*(q==2)+0.8*(q==3), ref(q))); end
  end
  for st = [0.4 0.8], [pk,tk,rtm] = stepdev(S,st); fprintf('   step at %.1f s: peak %+.1f V at %.0f ms, back within +/-5 V after %.0f ms\n', st, pk, tk, rtm); end
  s0 = S.tv < 0.05; [vmin,kmin] = min(S.vdc(s0)); tv0 = S.tv(s0); i0 = S.ti < 0.05;
  fprintf('   start-up: Vdc min %.1f V at %.1f ms | |Ibat| max %.1f A in the first 50 ms | duty at a limit %.1f %% in 0-50 ms | Saturation2 output %.3f..%.3f\n', ...
    vmin, tv0(kmin)*1e3, max(abs(S.ibat(i0))), limfrac(Dg,[0 0.05]), min(Dg.s2), max(Dg.s2));
end
function f = limfrac(Dg,w)
  s = Dg.t >= w(1) & Dg.t <= w(2); x = Dg.d(s); f = 100*mean(x <= 0.0501 | x >= 0.9499);
end
function ts = settle(S,st,ref)
  [tu,iu] = unique(S.ti); ib = S.ibat(iu); iav = movmean(ib,200e-6,'SamplePoints',tu);
  s = tu > st & tu < st + 0.2; tt = tu(s); bad = find(abs(iav(s) - ref) > 1.25, 1, 'last');
  if isempty(bad), ts = 0; else, ts = (tt(bad) - st)*1e3; end
end
function Dg = readdiag(out)
  [Dg.t,Dg.d] = sg(out.get('dg_d')); [tp,Dg.pi] = sg(out.get('dg_pi')); [ts,Dg.s2] = sg(out.get('dg_s2'));
  Dg.pi = itp(tp,Dg.pi,Dg.t); Dg.s2 = itp(ts,Dg.s2,Dg.t);
end
function o = snapshot(m)
  o.list = {'Irradiance (1000)','Before'; 'Irradiance (1000)','After'; 'Irradiance (1000)','Time'; 'P1','Time'; 'P1','Before'; 'P1','After'; 'P2','Time'; 'P2','Before'; 'P2','After'; 'Gain_ff','Gain'};
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
function S = readsigs(out)
  S = struct();
  [S.tp,S.ppv] = sg(out.get('ppv')); [S.ti,S.ibat] = sg(out.get('ibat')); [S.tv,S.vdc] = sg(out.get('vdc_bat'));
  idq = out.get('idq'); vdq = out.get('vdq'); S.tg = idq.Time(:); idm = squeeze(idq.Data); vdm = squeeze(vdq.Data);
  if size(idm,1)==2 && size(idm,2)~=2, idm = idm.'; vdm = vdm.'; end
  S.pg = -1.5*(vdm(:,1).*idm(:,1) + vdm(:,2).*idm(:,2));
  ia = out.get('i_abc'); S.ta = ia.Time(:); x = squeeze(ia.Data); if size(x,1) < size(x,2), x = x.'; end; S.ia = x;
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
function [thd,i1] = thd_rect(t,X,w,ph)
  k0 = find(t >= w(1),1); dt = mean(diff(t(k0:k0+100))); n = round((w(2)-w(1))/dt); y = X(k0:k0+n-1,ph);
  A = abs(fft(y))/n; b = round(50*n*dt); thd = 100*sqrt(sum(A((2:50)*b+1).^2))/A(b+1); i1 = 2*A(b+1);
end
