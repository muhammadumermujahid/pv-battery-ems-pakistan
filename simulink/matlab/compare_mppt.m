% Compares the per-sample and averaged P&O variants in grid_inv_test (constant irradiance).
% Makes a backup copy of the model, restores the original MPPT code at the end.
mdl = 'grid_inv_test';
load_system(mdl);
f = get_param(mdl,'FileName');
bak = strrep(f,'.slx',['_backup_' datestr(now,'yyyymmdd_HHMMSS') '.slx']);
copyfile(f, bak);
fprintf('Backup saved: %s\n', bak);
vP = 'ppv'; vD = 'duty';   % To Workspace variable names (power, duty)

blk  = sfroot().find('-isa','Stateflow.EMChart','Path',[mdl '/MPPT Function']);
orig = blk.Script;
avgcode = fileread('mppt_averaged.m');   % keep this file in the same folder

names = {'per-sample (in model)','averaged N=6000 dD=0.003'};
codes = {orig, avgcode};
win = [0.3 0.5; 0.9 1.1];
try
  for k = 1:2
    blk.Script = codes{k};
    out = sim(mdl);
    S = {out.get(vP), out.get(vD)};
    T = cell(1,2); X = cell(1,2);
    for q = 1:2
      v = S{q};
      if isa(v,'timeseries')
        T{q} = v.Time(:); X{q} = reshape(v.Data,[],1);
      elseif isstruct(v)
        T{q} = v.time(:); X{q} = reshape(v.signals.values,[],1);
      else
        error('Unknown log format for signal %d', q);
      end
    end
    fprintf('\n--- %s ---\n', names{k});
    for w = 1:2
      ip = T{1}>=win(w,1) & T{1}<=win(w,2);
      id = T{2}>=win(w,1) & T{2}<=win(w,2);
      fprintf('window %.1f-%.1f s: mean P_pv = %.2f kW | duty mean = %.4f, std = %.5f\n', ...
        win(w,1), win(w,2), mean(X{1}(ip))/1e3, mean(X{2}(id)), std(X{2}(id)));
    end
  end
catch ME
  blk.Script = orig;
  disp('Error, original MPPT code restored');
  rethrow(ME);
end
blk.Script = orig;
disp('Done, original MPPT code restored')
