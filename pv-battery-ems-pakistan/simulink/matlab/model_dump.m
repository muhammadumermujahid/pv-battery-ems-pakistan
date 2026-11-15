% model_dump.m -- writes a complete description of the model to model_dump.txt:
% solver settings, callbacks and workspace variables; every block with all its dialog parameters;
% every connection (signal and physical); the full code of every MATLAB Function / MPPT block;
% all logging (To Workspace) blocks. Read-only: the model is closed without saving.
% Run this script from the folder that contains grid_inv_test_battery.slx (for example: cd('C:\work\pv_model')).
m = 'grid_inv_test_battery';
load_system(m);
fid = fopen('model_dump.txt', 'w');

% ---------- 1. model settings ----------
fprintf(fid, '=== MODEL SETTINGS ===\n');
cfg = {'Solver','SolverType','FixedStep','StartTime','StopTime','SimulationMode'};
for i = 1:numel(cfg)
    fprintf(fid, '%s = %s\n', cfg{i}, val2str(get_param(m, cfg{i})));
end
cb = {'PreLoadFcn','PostLoadFcn','InitFcn','StartFcn','StopFcn'};
for i = 1:numel(cb)
    s = get_param(m, cb{i});
    if ~isempty(s), fprintf(fid, '%s:\n%s\n', cb{i}, s); end
end
mw = get_param(m, 'ModelWorkspace'); vars = whos(mw);
fprintf(fid, '\n--- model workspace variables (%d) ---\n', numel(vars));
for i = 1:numel(vars)
    fprintf(fid, '%s = %s\n', vars(i).name, val2str(getVariable(mw, vars(i).name)));
end
bw = evalin('base', 'whos');
fprintf(fid, '\n--- base workspace numeric variables ---\n');
for i = 1:numel(bw)
    if any(strcmp(bw(i).class, {'double','single','logical'})) && prod(bw(i).size) <= 20
        fprintf(fid, '%s = %s\n', bw(i).name, val2str(evalin('base', bw(i).name)));
    end
end

% ---------- 2. every block, its parameters and its connections ----------
blks = find_system(m, 'FollowLinks', 'off', 'LookUnderMasks', 'none', 'Type', 'Block');
fprintf(fid, '\n=== BLOCKS (%d) ===\n', numel(blks));
for i = 1:numel(blks)
    b = blks{i};
    fprintf(fid, '\n[%s]\n', strrep(b, sprintf('\n'), ' '));
    fprintf(fid, '  BlockType = %s | MaskType = %s | Library = %s\n', get_param(b,'BlockType'), val2str(get_param(b,'MaskType')), val2str(get_param(b,'ReferenceBlock')));
    dp = get_param(b, 'DialogParameters');
    if ~isempty(dp)
        fn = fieldnames(dp);
        for j = 1:numel(fn)
            try
                fprintf(fid, '  %s = %s\n', fn{j}, val2str(get_param(b, fn{j})));
            catch
            end
        end
    end
    pc = get_param(b, 'PortConnectivity');
    for k = 1:numel(pc)
        d = [pc(k).SrcBlock(:); pc(k).DstBlock(:)];
        txt = '';
        for j = 1:numel(d)
            if d(j) > 0
                txt = [txt '  |  ' strrep(getfullname(d(j)), sprintf('\n'), ' ')];
            end
        end
        fprintf(fid, '  port %s ->%s\n', pc(k).Type, txt);
    end
end

% ---------- 3. code of every MATLAB Function / Stateflow chart ----------
rt = sfroot;
charts = rt.find('-isa', 'Stateflow.EMChart');
fprintf(fid, '\n=== MATLAB FUNCTION BLOCKS (%d) ===\n', numel(charts));
for i = 1:numel(charts)
    if startsWith(charts(i).Path, m)
        fprintf(fid, '\n--- %s (SampleTime %s) ---\n%s\n', charts(i).Path, val2str(charts(i).SampleTime), charts(i).Script);
    end
end

% ---------- 4. logging blocks ----------
tw = find_system(m, 'BlockType', 'ToWorkspace');
fprintf(fid, '\n=== TO WORKSPACE BLOCKS (%d) ===\n', numel(tw));
for i = 1:numel(tw)
    fprintf(fid, '%s | VariableName %s | SampleTime %s | SaveFormat %s | Decimation %s\n', strrep(tw{i}, sprintf('\n'), ' '), ...
        get_param(tw{i},'VariableName'), get_param(tw{i},'SampleTime'), get_param(tw{i},'SaveFormat'), get_param(tw{i},'Decimation'));
end

fclose(fid);
close_system(m, 0);
disp('model_dump.txt written; model closed without saving.');

function s = val2str(v)
    if ischar(v)
        s = strrep(v, sprintf('\n'), ' ');
    elseif isstring(v)
        s = char(join(v, ' '));
    elseif isnumeric(v) || islogical(v)
        if numel(v) <= 50, s = mat2str(v, 6); else, s = sprintf('<%s %s>', class(v), mat2str(size(v))); end
    elseif iscell(v)
        s = sprintf('<cell %s>', mat2str(size(v)));
    else
        s = sprintf('<%s>', class(v));
    end
end
