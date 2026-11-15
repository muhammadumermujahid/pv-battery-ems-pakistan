% bias_test.m -- does the input-capacitor current in the measured PV current bias the 10 ms tracker?
% The PV ammeter sits between the capacitor node and the boost inductor, so the tracker sees i_L = i_pv - i_C.
% Four 2.0 s runs at 300 W/m2 and 1 us, means over 1.0-2.0 s:
%   T1 parallel R-C damper (100 uF + 5.12 ohm/400 uF), 50 ms window
%   T2 series 8 ohm with C_in = 500 uF (same total capacitance, no damper), 10 ms window
%   T3 series 8 ohm with C_in = 500 uF, 50 ms window
%   T4 parallel R-C damper, 10 ms window (repeat of the 86.7 % run, 2 s long)
% Prediction if the capacitor current is the cause: T2 and T4 fail (about 85-90 %, Vpv near 300 V); T1 and T3 track (99-100 %).
% Run this script from the folder that contains grid_inv_test_battery.slx (for example: cd('C:\work\pv_model')).
diary('bias_test_console.txt'); diary on
m = 'grid_inv_test_battery'; load_system(m); TS = 1e-6; errObj = [];
try
  blks = find_system(m,'FollowLinks','on','LookUnderMasks','none','Type','Block'); n5 = 0;
  for k = 1:numel(blks)
    dp = get_param(blks{k},'DialogParameters'); if isempty(dp), continue, end
    for f = fieldnames(dp)'
      try, v = get_param(blks{k},f{1}); catch, continue, end
      if ischar(v) && any(strcmpi(strtrim(v),{'5e-6','5e-06','5.0e-6','0.000005'})), set_param(blks{k},f{1},sprintf('%g',TS)); n5 = n5 + 1; end
    end
  end
  set_param(m,'FixedStep',sprintf('%g',TS));
  rt = sfroot; ch = rt.find('-isa','Stateflow.EMChart','Path',[m '/MPPT Function']); S0 = ch.Script; assert(contains(S0,'Nn = 2000'));
  fprintf('Model at 1 us: %d step parameters changed\n', n5);
  cin = [m '/Cin']; C0 = get_param(cin,'Capacitance');
  set_param([m '/Irradiance (1000)'],'Before','300','After','300','Time','0.5'); set_param(m,'StopTime','2.0');
  set_param([m '/P1'],'Time','10','Before','0','After','0'); set_param([m '/P2'],'Time','10','Before','0','After','0');
  L = 7e-3; Cc = 100e-6; nn = 4; Cd = nn*Cc; Rd = sqrt(L/Cc)*sqrt((2+nn)*(4+3*nn)/(2*nn^2*(4+nn)));
  runs = {'T1 parallel R-C, 50 ms', 'damper', 50e-3; 'T2 series 8 ohm 500 uF, 10 ms', 'c500', 10e-3; ...
          'T3 series 8 ohm 500 uF, 50 ms', 'c500', 50e-3; 'T4 parallel R-C, 10 ms', 'damper', 10e-3};
  for r = 1:size(runs,1)
    if ~isempty(find_system(m,'SearchDepth',1,'Name','Cdamp')), delete_damper(m); end
    if strcmp(runs{r,2},'damper')
      set_param(cin,'BranchType','C','Capacitance',C0); add_damper(m,cin,Rd,Cd);
    else
      set_param(cin,'BranchType','RC','Resistance','8','Capacitance','500e-6');
    end
    ch.Script = strrep(S0,'Nn = 2000',sprintf('Nn = %d',round(runs{r,3}/TS)));
    t0 = tic; out = sim(m); [tp,pp] = sg(out.get('ppv')); [tq,vq] = sg(out.get('vpv'));
    sp = tp >= 1.0 & tp <= 2.0; sq = tq >= 1.0 & tq <= 2.0; P = mean(pp(sp))/1e3;
    v1 = movmean(vq, round(1e-3/mean(diff(tq(1:1000)))));
    fprintf('%-31s | PV %.3f kW = %.1f %% of 2.898 kW | Vpv %.1f V (1 ms means %.1f..%.1f V) | %.0f s\n', runs{r,1}, P, 100*P/2.898, mean(vq(sq)), min(v1(sq)), max(v1(sq)), toc(t0));
  end
catch errObj
end
close_system(m,0); disp('Model closed without saving; the saved model is unchanged.');
if ~isempty(errObj), diary off; rethrow(errObj); end
disp('ALL DONE'); diary off

function add_damper(m,cin,Rd,Cd)
  add_block(cin,[m '/Cdamp'],'Position',get_param(cin,'Position')+[60 0 60 0]);
  set_param([m '/Cdamp'],'BranchType','RC','Resistance',sprintf('%.6g',Rd),'Capacitance',sprintf('%.6g',Cd));
  pc = get_param(cin,'PortHandles'); pd = get_param([m '/Cdamp'],'PortHandles');
  add_line(m,pc.LConn(1),pd.LConn(1),'autorouting','on'); add_line(m,pc.RConn(1),pd.RConn(1),'autorouting','on');
end
function delete_damper(m)
  lh = get_param([m '/Cdamp'],'LineHandles');
  for h = [lh.LConn(:); lh.RConn(:)]', if h > 0, delete_line(h); end, end
  delete_block([m '/Cdamp']);
end
function [t,x] = sg(s)
  if isstruct(s), t = s.time(:); x = squeeze(s.signals(1).values); else, t = s.Time(:); x = squeeze(s.Data); end
  if size(x,1) < size(x,2), x = x.'; end
  if size(x,2) > 1, x = x(:,1); end
end
