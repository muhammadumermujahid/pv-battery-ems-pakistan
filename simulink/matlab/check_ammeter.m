% check_ammeter.m - shows what the PV ammeter, voltmeter and input capacitor are wired to
m = 'grid_inv_test_battery';
load_system(m);
blocks = {'Ammeter', 'Voltmeter', 'Cin'};
for i = 1:3
    pc = get_param([m '/' blocks{i}], 'PortConnectivity');
    for k = 1:numel(pc)
        d = [pc(k).DstBlock(:); pc(k).SrcBlock(:)];
        txt = '';
        for j = 1:numel(d)
            if d(j) > 0
                txt = [txt '  |  ' getfullname(d(j))];
            end
        end
        fprintf('%s port %s ->%s\n', blocks{i}, pc(k).Type, txt);
    end
end
close_system(m, 0);
