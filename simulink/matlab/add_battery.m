% add_battery.m  -- adds a 15 kWh / 5 kW battery with a bidirectional DC-DC converter to the
% 700 V DC link of grid_inv_test (the inverter's DC-link PI keeps 700 V while the battery moves +/-5 kW).
% NOT RUN by the author (no MATLAB available) -- if a block path or port fails, send me the error text.
% Works on a COPY: grid_inv_test_battery.slx. Needs the Simscape Electrical Specialized Power Systems library.
mdl0 = 'grid_inv_test'; mdl = 'grid_inv_test_battery';
load_system(mdl0); save_system(mdl0, [get_param(mdl0,'FileName') '.keep'], 'SaveDirtyReferencedModels','off');
f = get_param(mdl0,'FileName'); copyfile(f, fullfile(fileparts(f),[mdl '.slx'])); close_system(mdl0,0); load_system(mdl);

% ---------- parameters (edit here) ----------
Vbat = 400; Ah = 15000/Vbat;       % 15 kWh at 400 V nominal -> 37.5 Ah
Pmax = 5e3; Vdc = 700; Lb = 2e-3; fsw = 5e3; Ts = 5e-6;
Kp = 6; Ki = 3000;                 % battery-current PI (about 500 Hz bandwidth, 2 mH)
P_steps = [0 0.4 0.8]; P_vals = [0 Pmax -Pmax];   % W, + = discharge: idle, discharge 5 kW, charge 5 kW

% ---------- blocks ----------
p = [mdl '/Battery system']; add_block('built-in/Subsystem', p, 'Position',[100 600 400 800]);
function b = blk(src, dst, varargin), add_block(src, dst); b = dst; set_param(dst, varargin{:}); end
bat = blk('powerlib/Electrical Sources/Battery',[p '/Battery'], 'NominalVoltage',num2str(Vbat),'RatedCapacity',num2str(Ah),'InitialSOC','50','BatteryType','Lithium-Ion');
ind = blk('powerlib/Elements/Series RLC Branch',[p '/Lb'], 'BranchType','RL','Resistance','0.01','Inductance',num2str(Lb));
ims = blk('powerlib/Measurements/Current Measurement',[p '/i_bat'], 'OutputType','Complex'); set_param(ims,'OutputType','Real-Imag'); 
hb  = blk('powerlib/Power Electronics/Universal Bridge',[p '/Half bridge'], 'Arms','1','Device','IGBT / Diodes','SnubberResistance','1e5','Ron','1e-3');
vdc = blk('powerlib/Measurements/Voltage Measurement',[p '/Vdc sense']);
% control: I_ref = P_ref / Vbat ; PI -> voltage command ; D = 1-(Vbat - vcmd)/Vdc ; m = 2D-1
add_block('simulink/Sources/Step',[p '/Pref'],'Time','0.4','Before','0','After',num2str(Pmax));
add_block('simulink/Math Operations/Gain',[p '/1/Vbat'],'Gain',num2str(1/Vbat));
add_block('simulink/Math Operations/Sum',[p '/err'],'Inputs','+-');
add_block('simulink/Continuous/PID Controller',[p '/PI'],'P',num2str(Kp),'I',num2str(Ki),'Controller','PI');
add_block('simulink/Math Operations/Sum',[p '/D calc'],'Inputs','+-');   % placeholder for duty arithmetic
add_block('simulink/Sources/Constant',[p '/Vbat_c'],'Value',num2str(Vbat));
add_block('simulink/Sources/Constant',[p '/Vdc_c'],'Value',num2str(Vdc));
add_block('simulink/Math Operations/Gain',[p '/to m'],'Gain','2');
add_block('powerlib/Control & Measurements/Pulse & Signal Generators/PWM Generator (2-Level)',[p '/PWM'], ...
    'Arms','1','Fc',num2str(fsw),'SampleTime',num2str(Ts));
add_block('simulink/Sinks/To Workspace',[p '/soc_out'],'VariableName','soc_bat','SaveFormat','Structure With Time');
add_block('simulink/Sinks/To Workspace',[p '/pbat_out'],'VariableName','p_bat','SaveFormat','Structure With Time');

% ---------- print every port so wiring can be checked / finished ----------
for b = {bat, ind, ims, hb, vdc}
    ph = get_param(b{1},'PortHandles');
    fprintf('%-35s in=%d out=%d L=%d R=%d\n', b{1}, numel(ph.Inport), numel(ph.Outport), numel(ph.LConn), numel(ph.RConn));
end
fprintf(['\nPower wiring to make (battery +, via Lb and i_bat, to the half-bridge midpoint A; bridge DC+ / DC- onto the\n' ...
 'existing 700 V DC link nodes; battery - to DC-). Control: i_bat -> err -> PI -> D calc -> to m -> PWM -> bridge gate.\n' ...
 'Then: save_system, sim, plot soc_bat / p_bat / the Vdc scope.\n']);
save_system(mdl);
