% Run this in MATLAB with grid_inv_test open (or loadable). It prints the parameters
% the paper quotes, and searches the model for any battery / storage blocks.
mdl = 'grid_inv_test'; load_system(mdl);
fprintf('Solver: %s, step %s, stop %s\n', get_param(mdl,'SolverType'), get_param(mdl,'FixedStep'), get_param(mdl,'StopTime'));
% 1) every numeric workspace variable (Ls, Cdc, Kp, Ki, Ts, Nser, Npar ...)
w = evalin('base','whos'); 
for k = 1:numel(w)
    if any(strcmp(w(k).class,{'double','single'})) && prod(w(k).size) <= 6
        fprintf('%-18s = %s\n', w(k).name, mat2str(evalin('base',w(k).name),6));
    end
end
% 2) battery / storage blocks anywhere in the model
b = [find_system(mdl,'LookUnderMasks','all','RegExp','on','Name','(?i)batter|storage|soc');
     find_system(mdl,'LookUnderMasks','all','RegExp','on','MaskType','(?i)batter')];
fprintf('Battery-like blocks found: %d\n', numel(b)); cellfun(@(x) fprintf('  %s\n',x), unique(b));
% 3) key block parameters: PV array, inductors, capacitors, grid source, MPPT step
for t = {'PV Array','Inductor','Capacitor','Three-Phase Source','Series RLC Branch'}
    h = find_system(mdl,'LookUnderMasks','all','RegExp','on','Name',['(?i)' t{1}]);
    for i = 1:numel(h)
        dp = get_param(h{i},'DialogParameters'); if isempty(dp), continue; end
        fn = fieldnames(dp); fprintf('\n[%s]\n', h{i});
        for j = 1:min(numel(fn),12), try, fprintf('  %s = %s\n', fn{j}, get_param(h{i},fn{j})); catch, end, end
    end
end
