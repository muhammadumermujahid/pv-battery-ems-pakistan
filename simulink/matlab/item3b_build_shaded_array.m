% Splits PV-615W (8x2) into two series sections (Nser = 4 each, Npar = 2) with anti-parallel bypass
% diodes and a second irradiance source (Irradiance_B). Does NOT save the model.
% Method notes: the wires on the PV + terminal report no end ports through Src/DstPortHandle, so the
% three neighbouring ports (Ammeter, Voltmeter, Cin) are found by geometry (nearest port to a wire point).
% Do not walk LineChildren recursively: the list contains the line itself (infinite loop).
bdclose all
cd('<project folder>');
m = 'grid_inv_test_battery'; load_system(m);
A = [m '/PV-615W (8x2)']; B = [m '/PV_B']; stp = [m '/Irradiance (1000)']; stpB = [m '/Irradiance_B'];
o.B = get_param(stp,'Before'); o.A = get_param(stp,'After'); o.p1 = get_param([m '/P1'],'After'); o.p2 = get_param([m '/P2'],'After'); o.stop = get_param(m,'StopTime');
set_param(A,'Nser','4'); pos = get_param(A,'Position'); add_block(A,B,'Position',pos+[0 140 0 140]); set_param(B,'Nser','4');
pA = get_param(A,'PortHandles'); pB = get_param(B,'PortHandles');
lh = get_param(A,'LineHandles'); root = lh.RConn(1);
grp = unique([root; get_param(root,'LineChildren')]); grp = grp(grp > 0 & ishandle(grp));
E = []; for i = 1:numel(grp), E = [E; get_param(grp(i),'Points')]; end
pc = get_param(A,'PortConnectivity'); nbs = [];
for j = 1:numel(pc), if strcmp(pc(j).Type,'RConn1'), nbs = [pc(j).SrcBlock(:); pc(j).DstBlock(:)]; end, end
nbs = nbs(ishandle(nbs)); P = [];
for i = 1:numel(nbs)
  ph = get_param(nbs(i),'PortHandles'); cand = [ph.LConn(:); ph.RConn(:)]; dist = zeros(numel(cand),1);
  for q = 1:numel(cand), ps = get_param(cand(q),'Position'); dist(q) = min(sqrt(sum((E - repmat(ps,size(E,1),1)).^2,2))); end
  [dm,qi] = min(dist); if dm < 20, P(end+1,1) = cand(qi); end
end
if numel(P) ~= 3, error('Expected 3 ports on the + net; found %d', numel(P)); end
for i = 1:numel(grp), try, delete_line(grp(i)); catch, end, end
add_line(m, pA.RConn(1), pB.RConn(2)); for i = 1:numel(P), add_line(m, pB.RConn(1), P(i)); end
lib = 'powerlib/Power Electronics/Diode'; DA = [m '/BD_A']; DB = [m '/BD_B'];
add_block(lib, DA, 'Position', [pos(3)+60 pos(2) pos(3)+100 pos(2)+30]); add_block(lib, DB, 'Position', [pos(3)+60 pos(2)+140 pos(3)+100 pos(2)+170]);
dA = get_param(DA,'PortHandles'); dB = get_param(DB,'PortHandles');
add_line(m, dA.LConn(1), pA.RConn(2)); add_line(m, dA.RConn(1), pA.RConn(1)); add_line(m, dB.LConn(1), pB.RConn(2)); add_line(m, dB.RConn(1), pB.RConn(1));
add_block(stp, stpB, 'Position', get_param(stp,'Position')+[0 140 0 140]); ph2 = get_param(stpB,'PortHandles'); add_line(m, ph2.Outport(1), pB.Inport(1));
% check: uniform 1000/1000 W/m2 gave 9.752 kW, 367.4 V (single block: 9.741 kW)
% then save_system(m) manually.
