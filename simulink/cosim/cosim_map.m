% cosim_map.m  -- plant loss map for the EMS co-simulation.  Plain script: type  cosim_map  in the Command Window.
% STATUS: NOT RUN by the author (no MATLAB on the writing side). If a block name or signal differs, send me the message.
%
% What it does: for each operating point (irradiance G, battery power Pbat) it simulates the integrated model
% 'grid_inv_test_battery' for 0.6 s with CONSTANT irradiance and a battery power step at 0.1 s, then averages
% 0.4-0.6 s (whole 50 Hz cycles) and logs  Ppv, battery power, grid power, loss and DC-link voltage.
% A 24 h run at 5 us would need ~17 billion steps, so the day is covered through this map (see cosim_ingest.py).
%
% BEFORE RUNNING (once, 1 minute):
%   1. Open grid_inv_test_battery. The irradiance source must read the workspace variable  G_Wm2  (e.g. Constant block value G_Wm2).
%      The battery 'Pref' Step block: Time = 0.1, Before = 0, After = Pbat_W   (workspace variable, + = discharge).
%      The script tries to find these blocks and set them; it prints what it found.
%   2. Logged signals needed (To Workspace, 'Structure With Time'): ppv, idq, vdq, ibat, vdc.  Optional: p_bat, vbat.
%   3. powergui stays Discrete, Ts = 5e-6.
mdl = 'grid_inv_test_battery'; load_system(mdl);
Tstop = 0.6; win = [0.40 0.60]; Vbat_nom = 400; Pmax_inv_kW = 9.5;   % skip points that would exceed the inverter current limit
G_list    = [0 50 150 300 500 700 1000];       % W/m^2
Pbat_list = [-5 -2.5 0 2.5 5];                % kW, + = discharge

% ---- locate blocks (prints them; edit the two patterns if your names differ)
steps = find_system(mdl,'LookUnderMasks','all','FollowLinks','on','BlockType','Step');
nm = get_param(steps,'Name'); if ischar(nm), nm = {nm}; end
ip = find(~cellfun('isempty', regexp(nm,'^P_?ref\d*$','ignorecase')));
if isempty(ip)
    fprintf('No Step block named Pref / P_ref found. All Step blocks in the model:\n'); cellfun(@(x) fprintf('   %s\n',x), steps);
    error('Tell me which Step block is the battery power reference (and any second one), or set its After value to Pbat_W by hand, Time 0.1, and comment out this check.');
end
% first reference step -> Pbat_W at 0.1 s; any further reference step (e.g. P_ref2, the charge step) is switched off
[~,o] = sort(nm(ip)); ip = ip(o); pref = steps(ip);
set_param(pref{1},'Time','0.1','Before','0','After','Pbat_W');
for q = 2:numel(pref), set_param(pref{q},'Before','0','After','0'); fprintf('Switched off extra step: %s\n', pref{q}); end
irr = find_system(mdl,'LookUnderMasks','all','RegExp','on','Name','(?i)^(irradiance|G|Gin|irr|sun)');
irr = irr(arrayfun(@(k) any(strcmp(get_param(irr{k},'BlockType'),{'Constant','Step','FromWorkspace'})), 1:numel(irr)));
fprintf('Pref block : %s  (After = Pbat_W, Time = 0.1)\n', pref{1});
if numel(irr)==1, set_param(irr{1},'Value','G_Wm2'); fprintf('Irradiance : %s -> G_Wm2\n', irr{1});
else, fprintf('Irradiance block not identified automatically (%d candidates). Make sure it reads G_Wm2, then continue.\n', numel(irr)); cellfun(@(x) fprintf('   candidate: %s\n',x), irr); end
set_param(mdl,'StopTime',num2str(Tstop));

rows = []; sgn = []; k = 0;
for g = G_list
    for pb = Pbat_list
        if g/1000*9.71 + max(pb,0) > Pmax_inv_kW, fprintf('skip G=%d Pbat=%+.1f (inverter limit)\n', g, pb); continue; end
        assignin('base','G_Wm2',g); assignin('base','Pbat_W',pb*1e3);
        t0 = tic; out = sim(mdl); k = k+1;
        r = measure_point(out, win, Vbat_nom);  r.G = g; r.Pbat_set = pb;
        fprintf('G=%4d Pbat=%+4.1f | Ppv %.2f Pbat %.2f Pgrid %.2f loss %.3f kW | Vdc %.0f (%.0f..%.0f) | %.0f s\n', ...
            g, pb, r.Ppv, r.Pbat, r.Pgrid, r.Ppv + r.Pbat - r.Pgrid, r.Vmean, r.Vmin, r.Vmax, toc(t0));
        rows = [rows; r]; %#ok<AGROW>
    end
end
T = struct2table(rows);
% sign check: with Pbat = 0 and PV > 1 kW the grid power must be about +Ppv (export). If it is about -Ppv, flip the sign of Pgrid.
ix = T.Pbat_set==0 & T.Ppv>1; 
if any(ix) && mean(T.Pgrid(ix)./T.Ppv(ix)) < 0, T.Pgrid = -T.Pgrid; fprintf('Grid-power sign flipped (dq convention).\n'); end
T.loss_kW = T.Ppv + T.Pbat - T.Pgrid;
T = T(:,{'G','Pbat_set','Ppv','Pbat','Pgrid','loss_kW','Vmean','Vmin','Vmax'});
T.Properties.VariableNames = {'G_Wm2','Pbat_set_kW','Ppv_kW','Pbat_kW','Pgrid_kW','loss_kW','vdc_mean','vdc_min','vdc_max'};
writetable(T,'cosim_map.csv'); disp(T); fprintf('\nSaved cosim_map.csv  -- send it back, or copy it to ems10_home/ and run cosim_ingest.py\n');

function r = measure_point(out, win, Vbat_nom)
    ev = @(n) out.get(n);
    sig = @(s) deal_ts(s);
    [tp,Ppv] = sig(ev('ppv')); [ti,Ib] = sig(ev('ibat')); [tv,Vd] = sig(ev('vdc'));
    idq = ev('idq'); vdq = ev('vdq'); tg = idq.Time(:); idm = squeeze(idq.Data); vdm = squeeze(vdq.Data);
    if size(idm,1)==2 && size(idm,2)~=2, idm = idm.'; vdm = vdm.'; end
    Pg = 1.5*(vdm(:,1).*idm(:,1) + vdm(:,2).*idm(:,2));
    m = @(t,x) mean(x(t>=win(1) & t<=win(2)));
    r.Ppv = m(tp,Ppv)/1e3; r.Pgrid = m(tg,Pg)/1e3;
    try, [tb,Pb] = sig(ev('p_bat')); r.Pbat = m(tb,Pb)/1e3; catch, r.Pbat = m(ti,Ib)*Vbat_nom/1e3; end   % + = discharge
    sel = tv>=win(1) & tv<=win(2); r.Vmean = mean(Vd(sel)); r.Vmin = min(Vd(sel)); r.Vmax = max(Vd(sel));
end
function [t,x] = deal_ts(s)
    if isstruct(s), t = s.time(:); x = squeeze(s.signals.values); x = x(:);
    elseif isa(s,'timeseries'), t = s.Time(:); x = squeeze(s.Data); x = x(:);
    else, error('unexpected signal type %s', class(s)); end
end
