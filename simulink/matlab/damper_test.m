% damper_test.m -- compares three input-filter configurations of the boost converter with the corrected 10 ms tracker:
%   (1) pure C_in (no damping), (2) the paper's series R_d = 8 ohm with C_in, (3) a parallel R-C damper (C_in pure, plus R_d2 in series with C_d across it).
% Damper design (Erickson-Maksimovic input-filter rule): n = C_d/C_in = 4, R_opt = R0*sqrt((2+n)(4+3n)/(2 n^2 (4+n))), R0 = sqrt(L/C_in).
% The model is NOT saved: at the end it is closed WITHOUT saving, which discards the added branch and every parameter change.
% Run this script from the folder that contains grid_inv_test_battery.slx (for example: cd('C:\work\pv_model')).
diary('damper_console.txt'); diary on
m = 'grid_inv_test_battery'; load_system(m); o = snapshot(m);
cin = find_system(m,'SearchDepth',1,'Name','Cin');
if isempty(cin), disp('No block named Cin at the top level. Series RLC Branch blocks found:'); disp(find_system(m,'MaskType','Series RLC Branch')); diary off; return; end
cin = cin{1}; c0.type = get_param(cin,'BranchType'); c0.R = get_param(cin,'Resistance'); c0.C = get_param(cin,'Capacitance');
fprintf('Cin as found: %s, R = %s, C = %s\n', c0.type, c0.R, c0.C);
L = 7e-3; C = 100e-6; R0 = sqrt(L/C); n = 4; Cd = n*C; Rd = R0*sqrt((2+n)*(4+3*n)/(2*n^2*(4+n)));
fprintf('Parallel damper design: R0 = %.2f ohm, n = %d, C_d = %.0f uF, R_d = %.2f ohm\n', R0, n, Cd*1e6, Rd);
Pav = containers.Map({300,600,1000},{2.898,5.914,9.841});
cfg = {'pure C','series 8 ohm','parallel R-C'}; errObj = [];
try
  for c = 1:3
    switch c
      case 1, set_param(cin,'BranchType','C','Capacitance',c0.C);
      case 2, set_param(cin,'BranchType','RC','Resistance','8','Capacitance',c0.C);
      case 3, set_param(cin,'BranchType','C','Capacitance',c0.C); add_damper(m,cin,Rd,Cd);
    end
    for G = [300 600 1000]
      restore_all(m,o); set_run(m,num2str(G),num2str(G),'0.5','1.0',{'10','0','0'},{'10','0','0'});
      t0 = tic; out = sim(m); S = readsigs(out); [tq,vq] = sg(out.get('vpv')); [td,id_] = sg(out.get('idio'));
      w = [0.5 1.0]; sp = S.tp >= w(1) & S.tp <= w(2); P = mean(S.ppv(sp))/1e3;
      p1 = movmean(S.ppv,200); v1 = movmean(vq,200); sq = tq >= w(1) & tq <= w(2);
      x = p1(sp) - mean(p1(sp)); fs = 1/mean(diff(S.tp(sp))); X = abs(fft(x))/numel(x); f = (0:numel(x)-1)'*fs/numel(x); b = f >= 5 & f <= 500; [a,k] = max(X(b)); fb = f(b);
      n2 = min(numel(S.tv),numel(td)); sv = S.tv(1:n2) >= w(1) & S.tv(1:n2) <= w(2); vv = S.vdc(1:n2); ii = id_(1:n2); pdc = mean(vv(sv).*ii(sv))/1e3;
      fprintf('%-13s G %4d | PV %.3f kW = %.1f %% of available | P(1ms) %.2f..%.2f kW | Vpv %.1f V, p-p(1ms) %.1f V | oscillation %3.0f Hz, %.3f kW | boost eff %.2f %% | %.0f s\n', ...
        cfg{c}, G, P, 100*P/Pav(G), min(p1(sp))/1e3, max(p1(sp))/1e3, mean(vq(sq)), max(v1(sq))-min(v1(sq)), fb(k), 2*a/1e3, 100*pdc/P, toc(t0));
    end
    if c == 3   % efficiency and THD with the parallel damper in the Table II run
      restore_all(m,o); set_run(m,'1000','600','0.5','1.2',{'10','0','0'},{'10','0','0'}); S = readsigs(sim(m));
      fprintf('parallel R-C, Table II run: PV %.3f / %.3f kW, AC %.3f / %.3f kW, THD(rect a) %.2f / %.2f %%\n', mw(S.tp,S.ppv,[0.3 0.5])/1e3, mw(S.tp,S.ppv,[0.9 1.1])/1e3, mw(S.tg,S.pg,[0.3 0.5])/1e3, mw(S.tg,S.pg,[0.9 1.1])/1e3, thd_rect(S.ta,S.ia,[0.3 0.5],1), thd_rect(S.ta,S.ia,[0.9 1.1],1));
    end
  end
catch errObj
end
close_system(m,0); disp('Model closed without saving: the damper branch and all changes are discarded; the saved model is unchanged.');
if ~isempty(errObj), diary off; rethrow(errObj); end
disp('ALL DONE'); diary off

function add_damper(m,cin,Rd,Cd)
  add_block(cin,[m '/Cdamp'],'Position',get_param(cin,'Position')+[60 0 60 0]);
  set_param([m '/Cdamp'],'BranchType','RC','Resistance',sprintf('%.6g',Rd),'Capacitance',sprintf('%.6g',Cd));
  pc = get_param(cin,'PortHandles'); pd = get_param([m '/Cdamp'],'PortHandles');
  add_line(m,pc.LConn(1),pd.LConn(1),'autorouting','on'); add_line(m,pc.RConn(1),pd.RConn(1),'autorouting','on');
end
function o = snapshot(m)
  o.list = {'Irradiance (1000)','Before'; 'Irradiance (1000)','After'; 'Irradiance (1000)','Time'; 'P1','Time'; 'P1','Before'; 'P1','After'; 'P2','Time'; 'P2','Before'; 'P2','After'};
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
  [S.tp,S.ppv] = sg(out.get('ppv')); [S.tv,S.vdc] = sg(out.get('vdc_bat'));
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
