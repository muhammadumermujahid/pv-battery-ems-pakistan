% item1_battery.m -- battery SOC / reference-ramp / feed-forward test on grid_inv_test_battery (R2023a). Run as a script.
m = 'grid_inv_test_battery'; load_system(m);
%% assumed generic NMC pack, scaled to 400 V at 50 % SOC
soc_pt = [0 10 20 30 50 70 80 90 100];
vcell  = [3.00 3.45 3.55 3.62 3.72 3.90 4.00 4.10 4.20];
R_pt   = [0.30 0.20 0.14 0.12 0.10 0.095 0.09 0.095 0.10];        % pack resistance, ohm
Voc_f = @(s) interp1(soc_pt, vcell*400/3.72, s, 'pchip');  Rb_f = @(s) interp1(soc_pt, R_pt, s, 'pchip');
%% cases: [SOC %, ramp time s (0 = step), feed-forward on, gain = 1/Voc (1) or original fixed gain (0)]
C = [10 0 1 1; 20 0 1 1; 50 0 1 1; 80 0 1 1; 95 0 1 1; 10 0 1 0; 95 0 1 0; ...
     10 0 0 1; 50 0 0 1; 95 0 0 1; 50 .05 1 1; 50 .2 1 1; 50 .05 0 1; 50 .2 0 1];
o.amp = get_param([m '/Battery'],'Amplitude'); o.R = get_param([m '/Rbat'],'Resistance');
o.G = get_param([m '/Gain'],'Gain'); o.Gff = get_param([m '/Gain_ff'],'Gain'); o.stop = get_param(m,'StopTime');
o.irrB = get_param([m '/Irradiance (1000)'],'Before'); o.irrA = get_param([m '/Irradiance (1000)'],'After');
fprintf('Original: Amplitude=%s  Rbat=%s  Gain=%s  Gain_ff=%s  Stop=%s\n', o.amp, o.R, o.G, o.Gff, o.stop);
set_param(m,'StopTime','1.0'); set_param([m '/Irradiance (1000)'],'Before','300','After','300');
%% rate limiter on the power reference (transparent until a ramp is set)
lh = get_param([m '/Sum'],'LineHandles'); delete_line(lh.Outport(1));
add_block('simulink/Discontinuities/Rate Limiter',[m '/RL_Pref'],'RisingSlewLimit','1e9','FallingSlewLimit','-1e9');
add_line(m,'Sum/1','RL_Pref/1'); add_line(m,'RL_Pref/1','Gain/1'); add_line(m,'RL_Pref/1','Gain_ff/1');
rows = []; SIG = struct([]); errObj = [];
wI = [0.30 0.40]; wD = [0.65 0.78]; wC = [0.92 1.00];
mw = @(t,x,w) mean(x(t>=w(1) & t<=w(2)));
try
  for k = 1:size(C,1)
    soc = C(k,1); ramp = C(k,2); ff = C(k,3); gm = C(k,4); Voc = Voc_f(soc); Rb = Rb_f(soc);
    set_param([m '/Battery'],'Amplitude',sprintf('%.6g',Voc)); set_param([m '/Rbat'],'Resistance',sprintf('%.6g',Rb));
    if gm, set_param([m '/Gain'],'Gain',sprintf('%.10g',1/Voc)); else, set_param([m '/Gain'],'Gain',o.G); end
    if ff, set_param([m '/Gain_ff'],'Gain',o.Gff); else, set_param([m '/Gain_ff'],'Gain','0'); end
    if ramp > 0, sl = 5000/ramp; set_param([m '/RL_Pref'],'RisingSlewLimit',num2str(sl),'FallingSlewLimit',num2str(-sl));
    else, set_param([m '/RL_Pref'],'RisingSlewLimit','1e9','FallingSlewLimit','-1e9'); end
    t0 = tic; out = sim(m);
    D = struct();
    for nm = {'ppv','ibat','vdc_bat'}
        s = out.get(nm{1});
        if isstruct(s), t = s.time(:); x = squeeze(s.signals.values); else, t = s.Time(:); x = squeeze(s.Data); end
        D.(nm{1}) = struct('t',t,'x',x(:));
    end
    idq = out.get('idq'); vdq = out.get('vdq'); tg = idq.Time(:); idm = squeeze(idq.Data); vdm = squeeze(vdq.Data);
    if size(idm,1)==2 && size(idm,2)~=2, idm = idm.'; vdm = vdm.'; end
    Pg = 1.5*(vdm(:,1).*idm(:,1) + vdm(:,2).*idm(:,2));
    if mw(tg,Pg,wI)*mw(D.ppv.t,D.ppv.x,wI) < 0, Pg = -Pg; end
    I = D.ibat.x; ti = D.ibat.t; V = D.vdc_bat.x; tv = D.vdc_bat.t;
    r = struct('SOC',soc,'ramp_s',ramp,'FF',ff,'gain_1overVoc',gm,'Voc_V',Voc,'Rbat_ohm',Rb);
    sv = tv >= 0.38; r.Vdc_min = min(V(sv)); r.Vdc_max = max(V(sv)); r.Vdc_dev_max = max(abs(V(sv)-700));
    r.Ibat_peak_A = max(abs(I(ti >= 0.38)));
    for w = {'I',wI;'D',wD;'C',wC}'
        Im = mw(ti,I,w{2}); Pb = (Voc - Rb*Im)*Im/1e3;
        Ppv = mw(D.ppv.t,D.ppv.x,w{2})/1e3; Pgr = mw(tg,Pg,w{2})/1e3;
        r.(['Pbat_' w{1}]) = Pb; r.(['Ppv_' w{1}]) = Ppv; r.(['Pgrid_' w{1}]) = Pgr; r.(['loss_' w{1}]) = Ppv + Pb - Pgr;
        r.(['Vdc_' w{1}]) = mw(tv,V,w{2});
    end
    r.track_err_D_pct = (r.Pbat_D - 5)/5*100;
    if ramp <= 0.05, r.track_err_C_pct = (r.Pbat_C + 5)/5*100; else, r.track_err_C_pct = NaN; end
    xs = movmean(I,[40 0]); sel = ti >= 0.4 & ti < 0.8; ts = ti(sel); xs = xs(sel); tgt = mw(ti,I,wD);
    last = find(abs(xs - tgt) > 0.05*abs(tgt), 1, 'last'); if isempty(last), r.settle_ms = 0; else, r.settle_ms = (ts(min(last+1,numel(ts))) - 0.4)*1e3; end   % NOT VALID (ripple), do not use
    r.extra_loss_D_kW = r.loss_D - r.loss_I;
    fprintf('%2d/%d SOC %2d ramp %.2f FF %d g1/Voc %d | Voc %.0f V R %.3f | Vdc dev %.1f V (%.0f..%.0f) | Ipk %.1f A | Pbat %.2f kW (%.1f %%) | extra loss %.3f kW | %.0f s\n', ...
        k,size(C,1),soc,ramp,ff,gm,Voc,Rb,r.Vdc_dev_max,r.Vdc_min,r.Vdc_max,r.Ibat_peak_A,r.Pbat_D,r.track_err_D_pct,r.extra_loss_D_kW,toc(t0));
    rows = [rows; r]; %#ok<AGROW>
    dd = 20; SIG(k).case = C(k,:); SIG(k).t = tv(1:dd:end); SIG(k).vdc = V(1:dd:end); SIG(k).ti = ti(1:dd:end); SIG(k).ibat = I(1:dd:end);
  end
catch errObj
end
%% restore the model
try
  rl = get_param([m '/RL_Pref'],'LineHandles'); delete_line(rl.Inport(1)); delete_line(rl.Outport(1)); delete_block([m '/RL_Pref']);
  add_line(m,'Sum/1','Gain/1'); add_line(m,'Sum/1','Gain_ff/1');
catch e2, fprintf('Restore of the rate limiter failed (%s): delete RL_Pref by hand and reconnect Sum -> Gain and Sum -> Gain_ff.\n', e2.message); end
set_param([m '/Battery'],'Amplitude',o.amp); set_param([m '/Rbat'],'Resistance',o.R); set_param([m '/Gain'],'Gain',o.G);
set_param([m '/Gain_ff'],'Gain',o.Gff); set_param(m,'StopTime',o.stop);
set_param([m '/Irradiance (1000)'],'Before',o.irrB,'After',o.irrA);
if ~isempty(errObj), rethrow(errObj); end
T = struct2table(rows); writetable(T,'item1_battery.csv'); save('item1_signals.mat','SIG','C');
disp(T(:,{'SOC','ramp_s','FF','gain_1overVoc','Voc_V','Vdc_dev_max','Ibat_peak_A','Pbat_D','track_err_D_pct','extra_loss_D_kW'}));
