% thd_rerun.m -- recomputes grid-current THD with a CORRECTED harmonic-bin index.
% The Hann-window THD used for Table IV (midday rows), Tables IX/X and the revision runs searched harmonic k at bin round(i1*k)
% with i1 the 1-based index of 50 Hz, i.e. at the wrong frequency for k >= 4. This script reruns those cases and prints, for each,
% the rectangular-window THD (exact bins, whole cycles) and the corrected Hann THD, both for phase a and as a three-phase mean,
% with the three largest harmonics. Vdc and negative-sequence metrics are printed to confirm the runs match the earlier ones.
% Run this script from the folder that contains grid_inv_test_battery.slx (for example: cd('C:\work\pv_model')).
diary('thd_rerun_console.txt'); diary on
RUN = struct('CAL',1,'MID',1,'A',1,'B',1,'R2',1,'R3',1);      % set to 0 to skip a section
m = 'grid_inv_test_battery'; load_system(m); o = snapshot(m); Zb = 400^2/10e3; f0 = 50; Lf = 4.5e-3;
P = @(lab,S,w) fprintf('%-34s | rect a %6.2f %%, 3ph %6.2f %% (%s) | Hann a %6.2f %%, 3ph %6.2f %% | I1 %.2f A pk\n', lab, thd_rect(S.ta,S.ia,w,1), thd_rect(S.ta,S.ia,w,1:3), tops(nth(2,@thd_rect,S.ta,S.ia,w,1:3)), thd_hann_ok(S.ta,S.ia,w,1), thd_hann_ok(S.ta,S.ia,w,1:3), nth(3,@thd_rect,S.ta,S.ia,w,1:3));
if RUN.CAL   % calibration: Table II run, expect rect phase a = 1.80 % at 0.3-0.5 s and 3.13 % at 0.9-1.1 s
  restore_all(m,o); set_run(m,'1000','600','0.5','1.2',{'10','0','0'},{'10','0','0'}); S = readsigs(sim(m));
  disp('=== CAL (Table II run) ==='); P('1000 W/m2, 0.3-0.5 s',S,[0.3 0.5]); P('600 W/m2, 0.9-1.1 s',S,[0.9 1.1]);
end
if RUN.MID   % Table IV midday rows
  restore_all(m,o); set_run(m,'1000','1000','0.5','1.0',{'0.5','0','-5000'},{'10','0','0'}); S = readsigs(sim(m));
  disp('=== MID (Table IV midday) ==='); P('midday idle 0.3-0.5 s',S,[0.3 0.5]); P('midday charge 0.8-1.0 s',S,[0.8 1.0]);
end
if RUN.A     % Table IX
  disp('=== A (Table IX, midday run, X/R 7) ===');
  for scr = [0 100 20 10 5 3 2]
    restore_all(m,o); set_grid(m,o,scr,7,Zb,f0); set_run(m,'1000','1000','0.5','1.0',{'0.5','0','-5000'},{'10','0','0'}); S = readsigs(sim(m));
    fprintf('SCR %g: max|dVdc| idle %.2f V, charge %.2f V\n', scr, max(abs(S.vdc(S.tv>=0.2 & S.tv<=0.5)-700)), max(abs(S.vdc(S.tv>=0.5 & S.tv<=1.0)-700)));
    P(sprintf('  SCR %g idle 0.3-0.5 s',scr),S,[0.3 0.5]); P(sprintf('  SCR %g charge 0.8-1.0 s',scr),S,[0.8 1.0]);
  end
end
if RUN.B     % Table X
  disp('=== B (Table X, idle, 600->1000 W/m2 at 0.25 s, window 0.5-0.6 s) ===');
  for scr = [0 20 10 5 3 2]
    for v = 1:3
      if scr == 0 && v > 1, continue, end
      restore_all(m,o); set_grid(m,o,scr,7,Zb,f0);
      if scr > 0 && v > 1
        Lg = (Zb/scr)/sqrt(50)*7/(2*pi*f0); s0 = (Lf+Lg)/Lf; fac = [1 1 1.5]; g = sprintf('2*pi*50*%.6g', Lf+Lg);
        set_param([m '/wL_id'],'Gain',g); set_param([m '/wL_iq'],'Gain',g);
        set_param([m '/PI_d'],'P',num2str(10*s0*fac(v)),'I',num2str(111*s0*fac(v))); set_param([m '/PI_q'],'P',num2str(10*s0*fac(v)),'I',num2str(111*s0*fac(v)));
      end
      set_run(m,'600','1000','0.25','0.6',{'10','0','0'},{'10','0','0'}); S = readsigs(sim(m)); n2 = seqmetrics(S,[0.5 0.6]);
      vn = {'original','scaled','scaled x1.5'}; P(sprintf('SCR %g %s (neg2 %.2f %%)',scr,vn{v},n2),S,[0.5 0.6]);
    end
  end
end
if RUN.R2
  disp('=== R2 (PLL scaling, X/R 2) ==='); C = [20 7 .5; 20 7 .25; 5 7 .5; 5 7 .25; 2 7 .5; 2 7 .25; 5 2 1; 3 2 1; 2 2 1];
  for k = 1:size(C,1)
    restore_all(m,o); set_grid(m,o,C(k,1),C(k,2),Zb,f0); set_param([m '/PLL'],'ParK',sprintf('[%g %g 1]',180*C(k,3),3200*C(k,3)));
    set_run(m,'600','1000','0.25','0.6',{'10','0','0'},{'10','0','0'}); S = readsigs(sim(m));
    P(sprintf('SCR %g X/R %g PLL x%.2f',C(k,:)),S,[0.5 0.6]);
  end
end
if RUN.R3
  disp('=== R3 (decoupling / gain variants, X/R 7) ===');
  V = [0 1; 1 1; 1 .5; 0 .5; 1 2]; vname = {'as built','wL matched','wL matched, x0.5','as built wL, x0.5','wL matched, x2'};
  for scr = [20 10 5 3 2]
    for v = 1:size(V,1)
      restore_all(m,o); set_grid(m,o,scr,7,Zb,f0); Lg = (Zb/scr)/sqrt(50)*7/(2*pi*f0);
      if V(v,1), g = sprintf('2*pi*50*%.6g', Lf+Lg); set_param([m '/wL_id'],'Gain',g); set_param([m '/wL_iq'],'Gain',g); end
      set_param([m '/PI_d'],'P',num2str(10*V(v,2)),'I',num2str(111*V(v,2))); set_param([m '/PI_q'],'P',num2str(10*V(v,2)),'I',num2str(111*V(v,2)));
      set_run(m,'600','1000','0.25','0.6',{'10','0','0'},{'10','0','0'});
      try, S = readsigs(sim(m)); P(sprintf('SCR %g %s',scr,vname{v}),S,[0.5 0.6]); catch e1, fprintf('SCR %g %s: run failed (%s)\n',scr,vname{v},e1.message); end
    end
  end
end
restore_all(m,o); disp('ALL DONE'); diary off

function varargout = nth(k,f,varargin), out = cell(1,k); [out{:}] = f(varargin{:}); varargout{1} = out{k}; end
%% ============================ local functions ============================
function o = snapshot(m)
  o.list = {'Irradiance (1000)','Before'; 'Irradiance (1000)','After'; 'Irradiance (1000)','Time'; 'P1','Time'; 'P1','Before'; 'P1','After'; 'P2','Time'; 'P2','Before'; 'P2','After'; 'Gain_ff','Gain'; ...
            'Three-Phase Source','Resistance'; 'Three-Phase Source','Inductance'; 'PLL','ParK'; 'PI_d','P'; 'PI_d','I'; 'PI_q','P'; 'PI_q','I'; 'wL_id','Gain'; 'wL_iq','Gain'};
  o.v = cell(1,size(o.list,1)); for k = 1:size(o.list,1), o.v{k} = get_param([m '/' o.list{k,1}],o.list{k,2}); end
  o.stop = get_param(m,'StopTime');
end
function restore_all(m,o)
  try, if ~isempty(find_system(m,'SearchDepth',1,'Name','FF_meas')), unwire_ff(m); end, catch, end
  for k = 1:size(o.list,1), try, set_param([m '/' o.list{k,1}],o.list{k,2},o.v{k}); catch, end, end
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
function wire_ff(m,Voc,Rb)
  tw = find_system(m,'BlockType','ToWorkspace'); idx = 0;
  for k = 1:numel(tw), if strcmp(get_param(tw{k},'VariableName'),'ibat'), idx = k; end, end
  if idx == 0, error('no To Workspace block with VariableName ibat'); end
  lh = get_param(tw{idx},'LineHandles'); sp = get_param(lh.Inport(1),'SrcPortHandle');
  a = 1 - exp(-5e-6/0.5e-3);
  add_block('simulink/User-Defined Functions/Fcn',[m '/FF_meas'],'Expr',sprintf('(%g - %g*u[1])*u[1]',Voc,Rb));
  add_block('simulink/Discrete/Discrete Transfer Fcn',[m '/FF_lp'],'Numerator',sprintf('[%.8g]',a),'Denominator',sprintf('[1 %.8g]',-(1-a)),'SampleTime','5e-6');
  ph1 = get_param([m '/FF_meas'],'PortHandles'); ph2 = get_param([m '/FF_lp'],'PortHandles'); pg = get_param([m '/Gain_ff'],'PortHandles');
  add_line(m,sp,ph1.Inport(1)); add_line(m,ph1.Outport(1),ph2.Inport(1));
  lg = get_param([m '/Gain_ff'],'LineHandles'); delete_line(lg.Inport(1)); add_line(m,ph2.Outport(1),pg.Inport(1));
end
function unwire_ff(m)
  for b = {'FF_meas','FF_lp'}
    lh = get_param([m '/' b{1}],'LineHandles');
    for f = {'Inport','Outport'}, h = lh.(f{1}); h = h(h > 0); for q = 1:numel(h), try, delete_line(h(q)); catch, end, end, end
    delete_block([m '/' b{1}]);
  end
  add_line(m,'Sum/1','Gain_ff/1');
end
function S = readsigs(out)
  S = struct();
  [S.tp,S.ppv] = sg(out.get('ppv')); [S.ti,S.ibat] = sg(out.get('ibat')); [S.tv,S.vdc] = sg(out.get('vdc_bat'));
  idq = out.get('idq'); vdq = out.get('vdq'); S.tg = idq.Time(:); idm = squeeze(idq.Data); vdm = squeeze(vdq.Data);
  if size(idm,1)==2 && size(idm,2)~=2, idm = idm.'; vdm = vdm.'; end
  S.pg = -1.5*(vdm(:,1).*idm(:,1) + vdm(:,2).*idm(:,2));   % sign fixed: id is negative for export in this model (checked: PV-only idle gives +export)
  S.id = idm(:,1); S.iq = idm(:,2); S.vd = vdm(:,1); S.vq = vdm(:,2);
  ia = out.get('i_abc'); S.ta = ia.Time(:); x = squeeze(ia.Data); if size(x,1) < size(x,2), x = x.'; end; S.ia = x;
  S.tpll = []; S.pll = []; S.tvp = []; S.vpv = [];
  try, [S.tpll,S.pll] = sg(out.get('pll_f')); catch, end
  try, [S.tvp,S.vpv] = sg(out.get('vpv')); catch, end
end
function [t,x] = sg(s)
  if isstruct(s), t = s.time(:); x = squeeze(s.signals(1).values); else, t = s.Time(:); x = squeeze(s.Data); end
  if size(x,1) < size(x,2), x = x.'; end
  if size(x,2) > 1, x = x(:,1); end
end
function y = itp(t,x,tt)
  if isempty(t), y = nan(size(tt)); return, end
  [t,iu] = unique(t); y = interp1(t,x(iu),tt,'linear','extrap');
end
function v = mw(t,x,w), v = mean(x(t>=w(1) & t<=w(2))); end
function [pk,rt] = stepdev(S,st)
  sel = S.tv > st & S.tv < st+0.2; vs = S.vdc(sel); ts = S.tv(sel); [~,kk] = max(abs(vs-700)); pk = vs(kk)-700;
  kl = find(abs(vs-700) > 5, 1, 'last'); if isempty(kl), rt = 0; else, rt = (ts(kl)-st)*1e3; end
end
function [thd,hs] = thd_hann_ok(t,X,w,phases)
  % Hann-windowed THD(2-50); harmonic k searched at the CORRECT bin (k*b, b = 50 Hz bin offset) +/- 2 bins
  thd = 0; hs = zeros(1,49);
  for ph = phases
    s = t >= w(1) & t < w(2); y = X(s,ph); n = numel(y); fs = 1/mean(diff(t(s))); A = abs(fft(y.*(0.5-0.5*cos(2*pi*(0:n-1)'/(n-1)))))/n;
    b = round(50*n/fs); h = arrayfun(@(k) max(A(k*b-1:k*b+3)), 2:50); a1 = max(A(b:b+2));
    thd = thd + 100*sqrt(sum(h.^2))/a1/numel(phases); hs = hs + 100*h/a1/numel(phases);
  end
end
function [thd,hs,i1pk] = thd_rect(t,X,w,phases)
  % rectangular window over exactly (w2-w1) seconds (whole cycles); exact harmonic bins
  thd = 0; hs = zeros(1,49); i1pk = 0;
  for ph = phases
    k0 = find(t >= w(1),1); dt = mean(diff(t(k0:k0+100))); n = round((w(2)-w(1))/dt); y = X(k0:k0+n-1,ph);
    A = abs(fft(y))/n; b = round(50*n*dt); h = A((2:50)*b+1)'; a1 = A(b+1);
    thd = thd + 100*sqrt(sum(h.^2))/a1/numel(phases); hs = hs + 100*h/a1/numel(phases); i1pk = i1pk + 2*a1/numel(phases);
  end
end
function s = tops(hs), [v,k] = sort(hs,'descend'); s = sprintf('h%d %.2f, h%d %.2f, h%d %.2f', k(1)+1, v(1), k(2)+1, v(2), k(3)+1, v(3)); end
function [neg2,fdom,adom] = seqmetrics(S,w)
  a = exp(2j*pi/3); sel = S.ta >= w(1) & S.ta <= w(2); Y = S.ia(sel,:); n = size(Y,1); fs = 1/mean(diff(S.ta(sel)));
  F = fft(Y.*(0.5-0.5*cos(2*pi*(0:n-1)'/(n-1))))/n; fq = (0:n-1)'*fs/n; [~,i1] = min(abs(fq-50)); ref = abs((F(i1,1)+a*F(i1,2)+a^2*F(i1,3))/3);
  ib = round(i1*2); [~,j] = max(abs(F(ib-2:ib+2,1))); j = ib-3+j; neg2 = 100*abs((F(j,1)+a^2*F(j,2)+a*F(j,3))/3)/ref;
  q = S.tg >= w(1) & S.tg <= w(2); x = S.id(q)-mean(S.id(q)); nn = numel(x); fsd = 1/mean(diff(S.tg(q))); Xd = abs(fft(x.*(0.5-0.5*cos(2*pi*(0:nn-1)'/(nn-1)))))/nn; fd = (0:nn-1)'*fsd/nn;
  [mx,ix] = max(Xd(3:floor(nn/2))); fdom = fd(ix+2); adom = 2*mx;
end
