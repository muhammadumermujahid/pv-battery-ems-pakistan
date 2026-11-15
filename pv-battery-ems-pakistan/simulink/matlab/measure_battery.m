% measure_battery.m  -- plain script. Run AFTER simulating the model with To Workspace blocks 'ibat' and 'vdc'
% (Save format: Structure With Time).  Type  measure_battery  in the Command Window.
% --- read the logged signals (works with a Simulink.SimulationOutput 'out' or with plain workspace variables) ---
if exist('out','var'), get_ = @(n) out.get(n); else, get_ = @(n) evalin('base', n); end
ib = get_('ibat');
if isstruct(ib), ti = ib.time(:); i = squeeze(ib.signals.values); i = i(:);
elseif isa(ib,'timeseries'), ti = ib.Time(:); i = squeeze(ib.Data); i = i(:);
else, error('ibat has an unexpected type: %s', class(ib)); end
try, vd = get_('vdc_bat'); catch, vd = get_('vdc'); end   % vdc_bat = the To Workspace block added for this test
if isstruct(vd), tv = vd.time(:); v = squeeze(vd.signals.values); v = v(:);
elseif isa(vd,'timeseries'), tv = vd.Time(:); v = squeeze(vd.Data); v = v(:);
else, tv = out.tout(:); v = vd(:); end             % your original model logs vdc as a plain array against tout
fprintf('ibat: %d samples, peak %.2f A | vdc: %d samples, mean %.1f V\n', numel(i), max(abs(i)), numel(v), mean(v));
win = [0.30 0.40; 0.50 0.70; 0.90 1.00];  expI = [0 12.5 -12.5];  names = {'idle','discharge 5 kW','charge 5 kW'};
figure('Name','Battery stage test','Position',[100 100 900 650]);
subplot(2,1,1); plot(ti,i,'LineWidth',1); hold on; grid on;
plot([0 0.4 0.4 0.8 0.8 1.0],[0 0 12.5 12.5 -12.5 -12.5],'r--','LineWidth',1.2);
legend('measured battery current','expected (+12.5 A discharge, -12.5 A charge)','Location','best'); ylabel('Battery current (A)'); title('Battery current');
subplot(2,1,2); plot(tv,v,'LineWidth',1); grid on; hold on; yline(700,'r--'); ylim([600 800]);
legend('DC-link voltage','700 V','Location','best'); ylabel('V_{dc} (V)'); xlabel('Time (s)'); title('DC-link voltage');
fprintf('\n%-16s %-12s %-14s %-14s %-12s\n','window','mean I (A)','expected (A)','mean Vdc (V)','Vdc min/max');
for k = 1:3
    a = win(k,1); b = win(k,2);
    mi = mean(i(ti>=a & ti<=b)); sel = tv>=a & tv<=b;
    fprintf('%-16s %-12.2f %-14.1f %-14.1f %.0f / %.0f\n', names{k}, mi, expI(k), mean(v(sel)), min(v(sel)), max(v(sel)));
end
% ---- step response: overshoot and true settling time (last exit from the +/-5 % band) -------------
fprintf('\nStep response (band = +/-5 %% of the step target)\n');
tests = {'discharge step at 0.4 s',0.4,0.8,12.5,12.5; 'charge step at 0.8 s',0.8,1.0,-12.5,25};   % last column = size of the step (A)
for k = 1:2
    t0 = tests{k,2}; t1 = tests{k,3}; tgt = tests{k,4}; sel = ti>=t0 & ti<t1;
    ts = ti(sel); xs = movmean(i, [40 0]); xs = xs(sel); outb = abs(xs-tgt) > 0.05*abs(tgt);   % current averaged over one 200 us switching period
    last = find(outb,1,'last'); if isempty(last), st = 0; else, st = (ts(min(last+1,numel(ts)))-t0)*1e3; end
    if tgt>0, osA = max(xs)-tgt; else, osA = tgt-min(xs); end
    fprintf('  %-26s overshoot %4.1f A = %4.1f %% of the %.1f A step   settling %6.1f ms\n', tests{k,1}, osA, osA/tests{k,5}*100, tests{k,5}, st);
end
fprintf('  Peak |i_bat| over the whole run: %.1f A at t = %.3f s (start-up transient if t is near 0)\n', max(abs(i)), ti(find(abs(i)==max(abs(i)),1)));
sel = ti>0.05; fprintf('  Peak |i_bat| after 0.05 s: %.1f A\n', max(abs(i(sel))));
fprintf('  Switching ripple in the discharge window: %.2f A peak-to-peak\n', max(i(ti>0.55&ti<0.7))-min(i(ti>0.55&ti<0.7)));

% ---- grid side, from signals your model already logs (idq, vdq, i_abc, ppv) ----------------------
try
    idq_ = out.get('idq'); vdq_ = out.get('vdq'); tg = idq_.Time(:);
    idm = squeeze(idq_.Data); vdm = squeeze(vdq_.Data); if size(idm,1)==2 && size(idm,2)~=2, idm = idm.'; vdm = vdm.'; end
    Pg = 1.5*(vdm(:,1).*idm(:,1) + vdm(:,2).*idm(:,2));      % W, sign: see note below
    ppv_ = out.get('ppv'); tp = ppv_.time(:); Ppv = squeeze(ppv_.signals.values); Ppv = Ppv(:);
    fprintf('\nGrid side (dq power; sign convention as in your model: check that PV-only idle window reads sensible)\n');
    fprintf('%-16s %-14s %-14s\n','window','P_pv (kW)','P_grid dq (kW)');
    for k = 1:3
        a = win(k,1); b = win(k,2);
        fprintf('%-16s %-14.2f %-14.2f\n', names{k}, mean(Ppv(tp>=a & tp<=b))/1e3, mean(Pg(tg>=a & tg<=b))/1e3);
    end
    ia = out.get('i_abc'); ta = ia.Time(:); ya = squeeze(ia.Data); if size(ya,2)~=3, ya = ya.'; end
    fprintf('\nGrid-current THD (phase a, 2nd-50th harmonic, about 10 cycles, away from the steps)\n');
    thdw = [0.20 0.40; 0.50 0.70; 0.82 1.00];   % whole numbers of 50 Hz cycles, away from the steps
    for k = [1 2 3]
        sel = ta>=thdw(k,1) & ta<=thdw(k,2);
        x = ya(sel,1); n = numel(x); fs = 1/mean(diff(ta(sel))); X = abs(fft(x.*(0.5-0.5*cos(2*pi*(0:n-1)'/(n-1)))))/n; f = (0:n-1)'*fs/n;
        [~,i1] = min(abs(f-50)); h = arrayfun(@(m) max(X(max(1,round(i1*m)-2):round(i1*m)+2)), 2:50);
        fprintf('  %-16s fundamental %.2f A pk,  THD %.2f %%\n', names{k}, 2*X(i1)*2, 100*sqrt(sum(h.^2))/X(i1));
    end
catch err
    fprintf('\n(Grid-side section skipped: %s)\n', err.message);
end

try, exportgraphics(gcf, 'fig_battery_stage.png', 'Resolution', 300); fprintf('\nSaved fig_battery_stage.png in the current folder\n'); catch, end
