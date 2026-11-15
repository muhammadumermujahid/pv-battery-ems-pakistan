function h = bs_ports(blk)
% physical ports of a block ordered top->bottom (top = "+" for sources). For the 1-arm Universal Bridge returns a struct.
ph = get_param(blk,'PortHandles');
if isfield(ph,'LConn') && numel(ph.RConn) >= 2 && numel(ph.LConn) >= 1 && contains(get_param(blk,'Name'),'HB')
    r = ph.RConn(:); y = arrayfun(@(p) bs_y(get_param(p,'Position')), r); [~,ix] = sort(y);
    h = struct('A', ph.LConn(1), 'dcp', r(ix(1)), 'dcn', r(ix(2)));
    return
end
phys = [ph.LConn(:); ph.RConn(:)];
y = arrayfun(@(p) bs_y(get_param(p,'Position')), phys); [~,ix] = sort(y); h = phys(ix);
end
