% finestep_test.m -- step-size sensitivity of the plant model (5 us vs 1 us), corrected tracker kept at a 10 ms window.
% Part A: duty-resolution test. For every tracker step, the change of the PV voltage is measured; at 5 us the modulator
%         has 40 levels per 200 us carrier period (0.025 duty, 17.5 V), at 1 us it has 200 levels (0.005 duty, 3.5 V).
% Part B: Table II run (1000 -> 600 W/m2) at 1 us: efficiency and THD, to check that the headline plant numbers do not depend on the step.
% Part C: input-filter comparison at 1 us (pure C, series 8 ohm, parallel R-C) at 300 and 1000 W/m2.
% The model is NOT saved: it is closed without saving at the end (also after an error). Expected run time 40-50 min.
% Run this script from the folder that contains grid_inv_test_battery.slx (for example: cd('C:\work\pv_model')).
diary('finestep_console.txt'); diary on
m = 'grid_inv_test_battery'; load_system(m);
errObj = [];
try
  %% ---- find every parameter that holds the 5 us step ----
  fprintf('Solver FixedStep: %s | solver: %s\n', get_param(m,'FixedStep'), get_param(m,'Solver'));
  blks = find_system(m,'FollowLinks','on','LookUnderMasks','none','Type','Block'); C = {};
  for k = 1:numel(blks)
    dp = get_param(blks{k},'DialogParameters'); if isempty(dp), continue, end
    for f = fieldnames(dp)'
      try, v = get_param(blks{k},f{1}); catch, continue, end
      if ischar(v) && (any(strcmpi(strtrim(v),{'5e-6','5e-06','5.0e-6','0.000005','Ts','Ts_Power','Ts_Control'})))
        C(end+1,:) = {blks{k}, f{1}, v}; %#ok<AGROW>
      end
    end
  end
  if isempty(C), C = cell(0,3); end
  fprintf('Parameters holding the step (%d):\n', size(C,1)); for k = 1:size(C,1), fprintf('   %s : %s = %s\n', C{k,1}, C{k,2}, C{k,3}); end
  vars = unique(C(~cellfun(@(x) ~isnan(str2double(x)), C(:,3)),3));      % symbolic values such as Ts
  mw0 = get_param(m,'ModelWorkspace'); varOrig = struct();
  for k = 1:numel(vars)
    nm = vars{k};
    if hasVariable(mw0,nm), varOrig.(nm) = {'model', getVariable(mw0,nm)}; fprintf('   variable %s in model workspace = %g\n', nm, getVariable(mw0,nm));
    elseif evalin('base',sprintf('exist(''%s'',''var'')',nm)), varOrig.(nm) = {'base', evalin('base',nm)}; fprintf('   variable %s in base workspace = %g\n', nm, evalin('base',nm));
    else, fprintf('   variable %s not found in model or base workspace\n', nm); end
  end
  rt = sfroot; ch = rt.find('-isa','Stateflow.EMChart','Path',[m '/MPPT Function']); S0 = ch.Script;
  try, fprintf('Tracker chart sample time: %s\n', ch.SampleTime); catch, disp('Tracker chart sample time: (not readable)'); end
  assert(contains(S0,'Nn = 2000'), 'Tracker script does not contain "Nn = 2000"; stop.');
  fsOrig = get_param(m,'FixedStep');
  setstep = @(ts) set_step(m, C, varOrig, ch, S0, ts);
  cin = [m '/Cin']; c0.R = get_param(cin,'Resistance'); c0.C = get_param(cin,'Capacitance');
  L = 7e-3; Cc = 100e-6; R0 = sqrt(L/Cc); nn = 4; Cd = nn*Cc; Rd = R0*sqrt((2+nn)*(4+3*nn)/(2*nn^2*(4+nn)));
  Pav = containers.Map({300,600,1000},{2.898,5.914,9.841});

  %% ---- Part A: duty-resolution test at 5 us and 1 us (series 8 ohm, 1000 W/m2, 1.0 s) ----
  disp('=== A: PV-voltage change per tracker step ===');
  for ts = [5e-6 1e-6]
    setstep(ts); set_run(m,'1000','1000','0.5','1.0');
    t0 = tic; out = sim(m); [tq,vq] = sg(out.get('vpv')); [td,du] = sg(out.get('duty')); [tp,pp] = sg(out.get('ppv'));
    fprintf('step %g s: logged dt of vpv %.2g s\n', ts, mean(diff(tq(1:1000))));
    ich = find(abs(diff(du)) > 1e-6); tch = td(ich+1); tch = tch(tch > 0.2 & tch < 0.95); dV = zeros(size(tch));
    for k = 1:numel(tch)
      b = tq >= tch(k)-0.005 & tq < tch(k)-0.001; a = tq >= tch(k)+0.004 & tq < tch(k)+0.009; dV(k) = mean(vq(a)) - mean(vq(b));
    end
    ad = abs(dV); sp = tp >= 0.5 & tp <= 1.0;
    fprintf('   %d steps | |dVpv| < 1 V: %d | 1-6 V: %d | 6-12 V: %d | > 12 V: %d | median of |dV| > 1 V: %.1f V | max %.1f V\n', numel(ad), sum(ad<1), sum(ad>=1 & ad<6), sum(ad>=6 & ad<12), sum(ad>=12), median(ad(ad>=1)), max(ad));
    fprintf('   PV %.3f kW (%.1f %% of available), Vpv %.1f V, p-p(1 ms) %.1f V | %.0f s\n', mean(pp(sp))/1e3, 100*mean(pp(sp))/1e3/9.841, mean(vq(tq>=0.5)), max(movmean(vq(tq>=0.5),round(1e-3/mean(diff(tq)))))-min(movmean(vq(tq>=0.5),round(1e-3/mean(diff(tq))))), toc(t0));
  end

  %% ---- Part B: Table II run at 1 us ----
  disp('=== B: Table II run at 1 us (series 8 ohm) ===');
  setstep(1e-6); set_run(m,'1000','600','0.5','1.2'); t0 = tic; S = readsigs(sim(m));
  for w = [0.3 0.5; 0.9 1.1]'
    fprintf('   %.1f-%.1f s | PV %.3f kW | AC %.3f kW | PV-to-AC %.2f %% | THD(rect a) %.2f %% | I1 %.2f A pk\n', w(1), w(2), mw(S.tp,S.ppv,w)/1e3, mw(S.tg,S.pg,w)/1e3, 100*mw(S.tg,S.pg,w)/mw(S.tp,S.ppv,w), thd_rect(S.ta,S.ia,w,1), i1pk(S.ta,S.ia,w,1));
  end
  fprintf('   (5 us reference: 9.73 / 5.87 kW, 96.74 / 94.98 %%, THD 1.80 / 3.13 %%) | %.0f s\n', toc(t0));

  %% ---- Part C: input-filter comparison at 1 us ----
  disp('=== C: input circuits at 1 us ===');
  cfg = {'pure C','series 8 ohm','parallel R-C'};
  for c = 1:3
    switch c
      case 1, set_param(cin,'BranchType','C','Capacitance',c0.C);
      case 2, set_param(cin,'BranchType','RC','Resistance','8','Capacitance',c0.C);
      case 3, set_param(cin,'BranchType','C','Capacitance',c0.C); add_damper(m,cin,Rd,Cd);
    end
    for G = [300 1000]
      set_run(m,num2str(G),num2str(G),'0.5','1.0'); t0 = tic; out = sim(m); S = readsigs(out); [tq,vq] = sg(out.get('vpv'));
      sp = S.tp >= 0.5 & S.tp <= 1.0; P = mean(S.ppv(sp))/1e3; dtp = mean(diff(S.tp(1:1000))); nw = round(1e-3/dtp);
      p1 = movmean(S.ppv,nw); v1 = movmean(vq,round(1e-3/mean(diff(tq(1:1000))))); sq = tq >= 0.5 & tq <= 1.0;
      x = p1(sp) - mean(p1(sp)); fsx = 1/dtp; X = abs(fft(x))/numel(x); f = (0:numel(x)-1)'*fsx/numel(x); bnd = f >= 5 & f <= 500; [a,k] = max(X(bnd)); fb = f(bnd);
      fprintf('%-13s G %4d | PV %.3f kW = %.1f %% of available | Vpv %.1f V, p-p(1ms) %.1f V | largest ripple %3.0f Hz, %.3f kW | %.0f s\n', cfg{c}, G, P, 100*P/Pav(G), mean(vq(sq)), max(v1(sq))-min(v1(sq)), fb(k), 2*a/1e3, toc(t0));
    end
  end
catch errObj
end
close_system(m,0);
if exist('varOrig','var')
  for f = fieldnames(varOrig)', if strcmp(varOrig.(f{1}){1},'base'), assignin('base',f{1},varOrig.(f{1}){2}); end, end
end
disp('Model closed without saving; the saved model is unchanged.');
if ~isempty(errObj), diary off; rethrow(errObj); end
disp('ALL DONE'); diary off

function set_step(m, C, varOrig, ch, S0, ts)
  for k = 1:size(C,1)
    if ~isnan(str2double(C{k,3})), set_param(C{k,1}, C{k,2}, sprintf('%g',ts)); end
  end
  for f = fieldnames(varOrig)'
    if strcmp(varOrig.(f{1}){1},'model'), assignin(get_param(m,'ModelWorkspace'), f{1}, ts); else, assignin('base', f{1}, ts); end
  end
  fs = get_param(m,'FixedStep'); if ~strcmpi(fs,'auto'), set_param(m,'FixedStep',sprintf('%g',ts)); end
  try, st = str2double(ch.SampleTime); catch, st = NaN; end
  if ~isnan(st) && st > 0, ch.SampleTime = sprintf('%g',ts); end   % chart with an explicit step: make it run at the new step
  ch.Script = strrep(S0, 'Nn = 2000', sprintf('Nn = %d', round(10e-3/ts)));
end
function set_run(m,g1,g2,gt,tstop)
  set_param([m '/Irradiance (1000)'],'Before',g1,'After',g2,'Time',gt); set_param(m,'StopTime',tstop);
  set_param([m '/P1'],'After','0'); set_param([m '/P2'],'After','0');
end
function add_damper(m,cin,Rd,Cd)
  add_block(cin,[m '/Cdamp'],'Position',get_param(cin,'Position')+[60 0 60 0]);
  set_param([m '/Cdamp'],'BranchType','RC','Resistance',sprintf('%.6g',Rd),'Capacitance',sprintf('%.6g',Cd));
  pc = get_param(cin,'PortHandles'); pd = get_param([m '/Cdamp'],'PortHandles');
  add_line(m,pc.LConn(1),pd.LConn(1),'autorouting','on'); add_line(m,pc.RConn(1),pd.RConn(1),'autorouting','on');
end
function S = readsigs(out)
  S = struct();
  [S.tp,S.ppv] = sg(out.get('ppv'));
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
function thd = thd_rect(t,X,w,ph)
  k0 = find(t >= w(1),1); dt = mean(diff(t(k0:k0+100))); n = round((w(2)-w(1))/dt); y = X(k0:k0+n-1,ph);
  A = abs(fft(y))/n; b = round(50*n*dt); thd = 100*sqrt(sum(A((2:50)*b+1).^2))/A(b+1);
end
function a = i1pk(t,X,w,ph)
  k0 = find(t >= w(1),1); dt = mean(diff(t(k0:k0+100))); n = round((w(2)-w(1))/dt); y = X(k0:k0+n-1,ph);
  A = abs(fft(y))/n; a = 2*A(round(50*n*dt)+1);
end
