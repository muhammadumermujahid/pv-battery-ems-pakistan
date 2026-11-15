% master_rerun.m -- ONE script: reruns every remaining test with the corrected tracker and writes ALL values to files.
% Sections: A weak grid midday (Table IX) | B weak grid gains (Table X) | C measured-battery-power feed-forward | D midday without feed-forward | E 34-point loss map | F figure data export
% Output files (in the project folder): master_rerun_console.txt (everything printed), master_A..E .csv, master_results.mat, figdata_*.csv
% The model is NOT saved; every changed parameter and the temporary wiring in section C are restored after each run and at the end. Do not press Ctrl+C (if you must, close the model WITHOUT saving).
% Run this script from the folder that contains grid_inv_test_battery.slx (for example: cd('C:\work\pv_model')).
diary('master_rerun_console.txt'); diary on
RUN = struct('A',1,'B',1,'C',1,'D',1,'E',1,'F',1);      % set a section to 0 to skip it
m = 'grid_inv_test_battery'; load_system(m);
o = snapshot(m); cleanupObj = onCleanup(@() restore_all(m,o)); %#ok<NASGU>
Zb = 400^2/10e3; f0 = 50; Lf = 4.5e-3; RES = struct();
fprintf('Original: P1 Time %s After %s | P2 Time %s After %s | Stop %s\n', o.v{4}, o.v{6}, o.v{7}, o.v{9}, o.stop);

%% ---------------- A: weak grid, midday run: 1000 W/m2, idle then -5 kW at 0.5 s (Table IX) ----------------
if RUN.A
 try
  disp('=== A: weak grid midday (Table IX) ==='); RA = [];
  for scr = [0 100 20 10 5 3 2]
    restore_all(m,o); set_grid(m,o,scr,7,Zb,f0);
    set_run(m,'1000','1000','0.5','1.0',{'0.5','0','-5000'},{'10','0','0'});
    t0 = tic; out = sim(m); S = readsigs(out); r = struct();
    r.SCR = scr; r.Zg_ohm = (scr>0)*Zb/max(scr,1);
    r.dVdc_idle = max(abs(S.vdc(S.tv>=0.2 & S.tv<=0.5)-700)); r.dVdc_charge = max(abs(S.vdc(S.tv>=0.5 & S.tv<=1.0)-700));
    r.THD_idle = thd_hann(S.ta,S.ia,[0.3 0.5],1:3); r.THD_charge = thd_hann(S.ta,S.ia,[0.8 1.0],1:3);
    r.Vpcc_pu = mw(S.tg,sqrt(S.vd.^2+S.vq.^2),[0.8 1.0])/326.6; r.Pgrid_kW = mw(S.tg,S.pg,[0.8 1.0])/1e3; r.Ppv_kW = mw(S.tp,S.ppv,[0.8 1.0])/1e3;
    fprintf('A SCR %4g | Zg %.2f ohm | max|dVdc| %.2f / %.2f V | THD %.2f / %.2f %% | Vpcc %.3f pu | PV %.2f export %.2f kW | %.0f s\n', scr, r.Zg_ohm, r.dVdc_idle, r.dVdc_charge, r.THD_idle, r.THD_charge, r.Vpcc_pu, r.Ppv_kW, r.Pgrid_kW, toc(t0));
    RA = [RA; r]; %#ok<AGROW>
  end
  RES.A = struct2table(RA); writetable(RES.A,'master_A_weakgrid_midday.csv');
 catch e, fprintf('SECTION A FAILED: %s\n', e.message); end
end

%% ---------------- B: weak grid, idle, 600->1000 W/m2 at 0.25 s: original / scaled / 1.5x scaled gains (Table X) ----------------
if RUN.B
 try
  disp('=== B: weak grid gains (Table X) ==='); RB = [];
  vname = {'original','scaled','scaled x1.5'};
  for scr = [0 20 10 5 3 2]
    for v = 1:3
      if scr == 0 && v > 1, continue, end
      restore_all(m,o); set_grid(m,o,scr,7,Zb,f0); Lg = 0; kpv = 10;
      if scr > 0
        Zg = Zb/scr; Rg = Zg/sqrt(1+49); Lg = Rg*7/(2*pi*f0);
        if v > 1
          fac = [1 1 1.5]; s0 = (Lf+Lg)/Lf; g = sprintf('2*pi*50*%.6g', Lf+Lg);
          set_param([m '/wL_id'],'Gain',g); set_param([m '/wL_iq'],'Gain',g);
          kp = 10*s0*fac(v); ki = 111*s0*fac(v); kpv = kp;
          set_param([m '/PI_d'],'P',num2str(kp),'I',num2str(ki)); set_param([m '/PI_q'],'P',num2str(kp),'I',num2str(ki));
        end
      end
      set_run(m,'600','1000','0.25','0.6',{'10','0','0'},{'10','0','0'});
      t0 = tic; out = sim(m); S = readsigs(out);
      r = struct('SCR',scr,'variant',vname{v},'Lg_mH',Lg*1e3); r.Kp = kpv;
      r.THD_a = thd_hann(S.ta,S.ia,[0.5 0.6],1); r.THD_3ph = thd_hann(S.ta,S.ia,[0.5 0.6],1:3);
      [r.neg2_pct,r.id_dom_Hz,r.id_dom_A] = seqmetrics(S,[0.5 0.6]);
      r.Vdc_dev_ss = max(abs(S.vdc(S.tv>=0.45)-700)); r.Vdc_dev_step = max(abs(S.vdc(S.tv>=0.25)-700)); r.Vpcc_pu = mw(S.tg,sqrt(S.vd.^2+S.vq.^2),[0.5 0.6])/326.6;
      fprintf('B SCR %2g | %-11s | Kp %.1f | THD phase a %.2f %% (3-phase %.2f) | neg-seq 2nd %.2f %% | d-ripple %.0f Hz %.2f A | Vdc dev ss %.1f V | %.0f s\n', scr, vname{v}, r.Kp, r.THD_a, r.THD_3ph, r.neg2_pct, r.id_dom_Hz, r.id_dom_A, r.Vdc_dev_ss, toc(t0));
      RB = [RB; r]; %#ok<AGROW>
    end
  end
  RES.B = struct2table(RB); writetable(RES.B,'master_B_weakgrid_gains.csv');
 catch e, fprintf('SECTION B FAILED: %s\n', e.message); end
end

%% ---------------- C: feed-forward from MEASURED battery power (battery test, 300 W/m2) ----------------
if RUN.C
 try
  disp('=== C: measured-battery-power feed-forward ==='); RC = []; restore_all(m,o);
  Voc = str2double(get_param([m '/Battery'],'Amplitude')); Rb = str2double(get_param([m '/Rbat'],'Resistance'));
  fprintf('Battery source %.1f V, Rbat %.3f ohm: measured power = (Voc - Rbat*ibat)*ibat from the logged battery current, 0.5 ms first-order filter\n', Voc, Rb);
  for variant = 1:2
    restore_all(m,o);
    if variant == 2, wire_ff(m,Voc,Rb); end
    set_run(m,'300','300','0.5','1.0',{o.v{4},o.v{5},o.v{6}},{o.v{7},o.v{8},o.v{9}});
    t0 = tic; out = sim(m); S = readsigs(out);
    vn = {'reference','measured'}; r = struct(); r.variant = vn{variant};
    [pk1,rt1] = stepdev(S,0.4); [pk2,rt2] = stepdev(S,0.8);
    r.dev_step1 = pk1; r.return_ms1 = rt1; r.dev_step2 = pk2; r.return_ms2 = rt2; r.Ibat_D = mw(S.ti,S.ibat,[0.65 0.78]); r.Ibat_C = mw(S.ti,S.ibat,[0.92 1.0]);
    r.export_D_kW = mw(S.tg,S.pg,[0.65 0.78])/1e3; r.export_C_kW = mw(S.tg,S.pg,[0.92 1.0])/1e3;
    fprintf('C %-9s | step +5 kW: peak dev %+.1f V, back in %.0f ms | step -5 kW: peak dev %+.1f V, back in %.0f ms | Ibat %.2f / %.2f A | export %.2f / %.2f kW | %.0f s\n', r.variant, pk1, rt1, pk2, rt2, r.Ibat_D, r.Ibat_C, r.export_D_kW, r.export_C_kW, toc(t0));
    RC = [RC; struct2table(r)]; %#ok<AGROW>
    if variant == 2, unwire_ff(m); end
  end
  RES.C = RC; writetable(RC,'master_C_measured_ff.csv');
 catch e, fprintf('SECTION C FAILED: %s\n', e.message); try, unwire_ff(m); catch, end, end
end

%% ---------------- D: midday step to -5 kW WITHOUT feed-forward (1000 W/m2) ----------------
if RUN.D
 try
  disp('=== D: midday without feed-forward ==='); restore_all(m,o); RD = [];
  for ff = [1 0]
    restore_all(m,o); if ff == 0, set_param([m '/Gain_ff'],'Gain','0'); end
    set_run(m,'1000','1000','0.5','1.0',{'0.5','0','-5000'},{'10','0','0'});
    t0 = tic; out = sim(m); S = readsigs(out); [pk,rt] = stepdev(S,0.5);
    r = struct('FF',ff,'peak_dev_V',pk,'return_ms',rt,'Vdc_min',min(S.vdc(S.tv>0.5)),'Vdc_max',max(S.vdc(S.tv>0.5)),'Ibat_C',mw(S.ti,S.ibat,[0.8 1.0]),'export_idle',mw(S.tg,S.pg,[0.3 0.4])/1e3,'export_charge',mw(S.tg,S.pg,[0.7 1.0])/1e3);
    fprintf('D FF %d | peak Vdc deviation %+.1f V (%.0f..%.0f V) | back within +/-5 V after %.0f ms | export %.2f -> %.2f kW | %.0f s\n', ff, pk, r.Vdc_min, r.Vdc_max, rt, r.export_idle, r.export_charge, toc(t0));
    RD = [RD; r]; %#ok<AGROW>
  end
  RES.D = struct2table(RD); writetable(RES.D,'master_D_midday_noff.csv');
 catch e, fprintf('SECTION D FAILED: %s\n', e.message); end
end

%% ---------------- E: 34-point plant loss map (constant irradiance, battery step at 0.1 s, mean over 0.4-0.6 s) ----------------
if RUN.E
 try
  disp('=== E: loss map ==='); restore_all(m,o); pairs = [];
  for g = [5 50 150 300], for pb = [-5 -2.5 0 2.5 5], pairs(end+1,:) = [g pb]; end, end %#ok<AGROW>
  for pb = [-5 -2.5 0 2.5], pairs(end+1,:) = [500 pb]; end %#ok<AGROW>
  for pb = [-5 -2.5 0 2.5], pairs(end+1,:) = [700 pb]; end %#ok<AGROW>
  for pb = [-5 -2.5 0], pairs(end+1,:) = [850 pb]; end %#ok<AGROW>
  for pb = [-5 -2.5 0], pairs(end+1,:) = [1000 pb]; end %#ok<AGROW>
  RE = []; w = [0.4 0.6];
  for k = 1:size(pairs,1)
    g = pairs(k,1); pb = pairs(k,2); restore_all(m,o);
    set_run(m,sprintf('%g',g),sprintf('%g',g),'0.5','0.6',{'0.1','0',sprintf('%g',pb*1e3)},{'10','0','0'});
    t0 = tic; out = sim(m); S = readsigs(out);
    Ppv = mw(S.tp,S.ppv,w)/1e3; Pg = mw(S.tg,S.pg,w)/1e3; Pb = mw(S.ti,S.ibat,w)*400/1e3; sv = S.tv>=w(1) & S.tv<=w(2);
    r = struct('G_Wm2',g,'Pbat_set_kW',pb,'Ppv_kW',Ppv,'Pbat_kW',Pb,'Pgrid_kW',Pg,'loss_kW',Ppv+Pb-Pg,'vdc_mean',mean(S.vdc(sv)),'vdc_min',min(S.vdc(sv)),'vdc_max',max(S.vdc(sv)));
    fprintf('E %2d/34 G %4g Pbat %+4.1f | Ppv %.3f Pbat %.3f Pgrid %.3f loss %.3f kW | Vdc %.1f (%.1f..%.1f) | %.0f s\n', k, g, pb, Ppv, Pb, Pg, r.loss_kW, r.vdc_mean, r.vdc_min, r.vdc_max, toc(t0));
    RE = [RE; r]; %#ok<AGROW>
    if mod(k,5) == 0, writetable(struct2table(RE),'master_E_cosim_map.csv'); end
  end
  RES.E = struct2table(RE); writetable(RES.E,'master_E_cosim_map.csv');
 catch e, fprintf('SECTION E FAILED: %s\n', e.message); end
end

%% ---------------- F: figure data (corrected tracker): Fig. 5/6 from the 1000->600 W/m2 run, battery-stage figure from the 300 W/m2 run ----------------
if RUN.F
 try
  disp('=== F: figure data ==='); restore_all(m,o);
  set_run(m,'1000','600','0.5','1.2',{'10','0','0'},{'10','0','0'}); out = sim(m); S = readsigs(out); tt = (0:1e-4:1.2)';
  T = table(tt, itp(S.tp,S.ppv,tt), itp(S.tg,S.pg,tt), itp(S.tv,S.vdc,tt), itp(S.tvp,S.vpv,tt), itp(S.tg,S.id,tt), itp(S.tg,S.iq,tt), 'VariableNames',{'t','ppv_W','pgrid_W','vdc_V','vpv_V','id_A','iq_A'});
  if ~isempty(S.tpll), T.pll_Hz = itp(S.tpll,S.pll,tt); end
  writetable(T,'figdata_fig5_run_1000to600.csv');
  sel = S.ta >= 0.30 & S.ta <= 0.36; writetable(table(S.ta(sel),S.ia(sel,1),S.ia(sel,2),S.ia(sel,3),'VariableNames',{'t','ia','ib','ic'}),'figdata_fig6a_iabc_1000.csv');
  restore_all(m,o); set_run(m,'300','300','0.5','1.0',{o.v{4},o.v{5},o.v{6}},{o.v{7},o.v{8},o.v{9}}); out = sim(m); S = readsigs(out); tt = (0:1e-4:1.0)';
  writetable(table(tt, itp(S.ti,S.ibat,tt), itp(S.tv,S.vdc,tt), itp(S.tg,S.pg,tt), itp(S.tp,S.ppv,tt), 'VariableNames',{'t','ibat_A','vdc_V','pgrid_W','ppv_W'}),'figdata_battery_stage_300.csv');
  disp('figure data written');
 catch e, fprintf('SECTION F FAILED: %s\n', e.message); end
end
restore_all(m,o); save('master_results.mat','RES'); disp('ALL DONE'); diary off

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
function thd = thd_hann(t,X,w,phases)
  thd = 0;
  for ph = phases
    s = t >= w(1) & t <= w(2); y = X(s,ph); n = numel(y); fs = 1/mean(diff(t(s))); A = abs(fft(y.*(0.5-0.5*cos(2*pi*(0:n-1)'/(n-1)))))/n; f = (0:n-1)'*fs/n;
    [~,i1] = min(abs(f-50)); h = arrayfun(@(k) max(A(max(1,round(i1*k)-2):round(i1*k)+2)), 2:50); thd = thd + 100*sqrt(sum(h.^2))/A(i1)/numel(phases);
  end
end
function [neg2,fdom,adom] = seqmetrics(S,w)
  a = exp(2j*pi/3); sel = S.ta >= w(1) & S.ta <= w(2); Y = S.ia(sel,:); n = size(Y,1); fs = 1/mean(diff(S.ta(sel)));
  F = fft(Y.*(0.5-0.5*cos(2*pi*(0:n-1)'/(n-1))))/n; fq = (0:n-1)'*fs/n; [~,i1] = min(abs(fq-50)); ref = abs((F(i1,1)+a*F(i1,2)+a^2*F(i1,3))/3);
  ib = round(i1*2); [~,j] = max(abs(F(ib-2:ib+2,1))); j = ib-3+j; neg2 = 100*abs((F(j,1)+a^2*F(j,2)+a*F(j,3))/3)/ref;
  q = S.tg >= w(1) & S.tg <= w(2); x = S.id(q)-mean(S.id(q)); nn = numel(x); fsd = 1/mean(diff(S.tg(q))); Xd = abs(fft(x.*(0.5-0.5*cos(2*pi*(0:nn-1)'/(nn-1)))))/nn; fd = (0:nn-1)'*fsd/nn;
  [mx,ix] = max(Xd(3:floor(nn/2))); fdom = fd(ix+2); adom = 2*mx;
end
