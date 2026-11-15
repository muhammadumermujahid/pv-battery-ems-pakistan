% make_battery_figure.m -- plain script. Run after the model has been simulated (variable 'out' in the workspace).
% Saves fig_battery_stage.png (600 dpi, IEEE single-column width 3.45 in) in the current folder.
if ~exist('out','var'), error('Run the model first (press Run), then run this script.'); end
% ---- data --------------------------------------------------------------------------------------
ib = out.get('ibat'); ti = ib.time(:); i = squeeze(ib.signals.values); i = i(:);
try, vd = out.get('vdc_bat'); catch, vd = out.get('vdc'); end
if isstruct(vd), tv = vd.time(:); v = squeeze(vd.signals.values); v = v(:); else, tv = out.tout(:); v = vd(:); end
iavg = movmean(i,[40 0]);                                  % average over one 200 us switching period
tref = [0 0.4 0.4 0.8 0.8 1.0]; iref = [0 0 12.5 12.5 -12.5 -12.5];
haveGrid = true;
try
    idq_ = out.get('idq'); vdq_ = out.get('vdq'); tg = idq_.Time(:);
    idm = squeeze(idq_.Data); vdm = squeeze(vdq_.Data); if size(idm,1)==2 && size(idm,2)~=2, idm = idm.'; vdm = vdm.'; end
    Pexp = -1.5*(vdm(:,1).*idm(:,1) + vdm(:,2).*idm(:,2))/1e3;   % kW, + = export (sign as found in the idle window)
    Pexp = movmean(Pexp, 4000);                                  % 20 ms (one 50 Hz cycle) smoothing, display only
    pp = out.get('ppv'); tp = pp.time(:); Ppv = squeeze(pp.signals.values); Ppv = Ppv(:)/1e3; Ppv = movmean(Ppv, 4000);
catch, haveGrid = false; end
% ---- figure ------------------------------------------------------------------------------------
% colour-blind-safe palette (Okabe-Ito): blue, vermilion, orange, sky blue
c1 = [0.00 0.45 0.70]; c2 = [0.84 0.37 0.00]; c3 = [0.90 0.62 0.00]; csky = [0.34 0.71 0.91]; cg = [0.35 0.35 0.35];
f = figure('Units','inches','Position',[1 1 3.45 4.6],'Color','w');
tl = tiledlayout(3,1,'TileSpacing','compact','Padding','compact');
ax1 = nexttile; hold on; box on; grid on;
plot(ti,i,'Color',csky,'LineWidth',0.4);
plot(ti,iavg,'Color',[0 0.15 0.40],'LineWidth',1.4);
plot(tref,iref,'--','Color',c2,'LineWidth',1.6);
ylabel('Battery current (A)'); ylim([-22 22]); xlim([0 1]);
legend({'Measured','Switching-period average','Reference'},'Location','southwest','FontSize',6,'Box','off');
text(0.02,0.92,'(a)','Units','normalized','FontSize',8,'FontWeight','bold');
ax2 = nexttile; hold on; box on; grid on;
plot(tv,v,'Color',c1,'LineWidth',1.2); yline(700,'--','Color',c2,'LineWidth',1.4);
sv = v(tv>0.05); ylabel('DC-link voltage (V)'); ylim([floor(min(sv)-5) ceil(max(sv)+5)]); xlim([0 1]);
legend({'V_{dc}','700 V reference'},'Location','northeast','FontSize',6,'Box','off');
text(0.02,0.92,'(b)','Units','normalized','FontSize',8,'FontWeight','bold');
ax3 = nexttile; hold on; box on; grid on;
if haveGrid
    plot(tg,Pexp,'Color',c1,'LineWidth',1.4); plot(tp,Ppv,'Color',c3,'LineWidth',1.4);
    legend({'Net export to grid','PV power'},'Location','southwest','FontSize',6,'Box','off');
end
ylabel('Power (kW)'); xlabel('Time (s)'); xlim([0 1]); ylim([-4 10]);
text(0.02,0.92,'(c)','Units','normalized','FontSize',8,'FontWeight','bold');
set([ax1 ax2 ax3],'FontSize',7,'LineWidth',0.5,'FontName','Times New Roman','GridAlpha',0.15);
% mark the two steps on every panel
for a = [ax1 ax2 ax3], xline(a,0.4,':','Color',cg,'HandleVisibility','off'); xline(a,0.8,':','Color',cg,'HandleVisibility','off'); end
xticklabels(ax1,[]); xticklabels(ax2,[]);
exportgraphics(f,'fig_battery_stage.png','Resolution',600);
fprintf('Saved fig_battery_stage.png (600 dpi) in %s\n', pwd);

% ---- transient numbers for the paper ------------------------------------------------------------
fprintf('\nStep transients (window = 0.3 s after each step)\n');
steps = [0.4 12.5; 0.8 -12.5];
for k = 1:2
    t0 = steps(k,1); tgt = steps(k,2); sw = tv>=t0 & tv<t0+0.3; tw = tv(sw); vw = v(sw);
    [~,ip] = max(abs(vw-700)); dev = vw(ip)-700;
    out5 = find(abs(vw-700) > 5, 1, 'last'); if isempty(out5), t5 = 0; else, t5 = (tw(out5)-t0)*1e3; end
    cw = ti>=t0 & ti<t0+0.3; tc = ti(cw); ca = iavg(cw); outc = find(abs(ca-tgt) > 1.25, 1, 'last');
    if isempty(outc), tcs = 0; else, tcs = (tc(outc)-t0)*1e3; end
    fprintf('  step at %.1f s: DC-link peak deviation %+.1f V (at %.0f ms), back within +/-5 V after %.0f ms; current within +/-1.25 A after %.0f ms\n', t0, dev, (tw(ip)-t0)*1e3, t5, tcs);
end
if haveGrid
    for k = 1:2
        t0 = steps(k,1); sel = tg>=t0 & tg<t0+0.3; fprintf('  step at %.1f s: net export reaches %.2f kW at the extreme (smoothed)\n', t0, ...
            max(Pexp(sel))*(k==1) + min(Pexp(sel))*(k==2));
    end
end
