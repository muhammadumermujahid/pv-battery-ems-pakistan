% build_battery_stage.m  -- a SCRIPT (run it by typing  build_battery_stage  in the Command Window, or press Run in the Editor) (R2023a, Simscape Electrical - Specialized Power Systems)
% Builds the 15 kWh battery + bidirectional half-bridge + current controller as a subsystem
% 'Battery_Stage', then tests it ALONE on a stiff 700 V DC source (model battery_stage_test.slx).
% Step 2 (manual, 2 min): copy Battery_Stage into grid_inv_test_battery and wire its DC+ / DC- ports to
% the two 700 V DC-link nodes (drag a branch off the DC-link capacitor lines), and set irradiance to 300 W/m^2.
%
% STATUS: the controller gains were checked in an averaged Python model (stable, ~6 % overshoot, ~20 ms settling),
% but this script has NOT been run in MATLAB. If a block path or parameter name errors, send me the message.
P.Vbat = 400; P.Ah = 37.5; P.Lb = 10e-3; P.Rb = 0.02; P.fsw = 5e3; P.Tpwm = 5e-6;
P.Vdc = 700; P.Pmax = 5e3; P.Tctl = 5e-5; P.Kp = 19; P.Ki = 3600;
P.t_dis = 0.4; P.t_chg = 0.8; P.Tstop = 1.0;

mdl = 'battery_stage_test';
if bdIsLoaded(mdl), close_system(mdl,0); end
new_system(mdl); open_system(mdl);
set_param(mdl,'Solver','FixedStepDiscrete','FixedStep',num2str(P.Tpwm),'StopTime',num2str(P.Tstop));
bs_addb('powerlib/powergui',[mdl '/powergui'],'SimulationMode','Discrete','SampleTime',num2str(P.Tpwm));

%% ---- subsystem  (bs_setp warns instead of stopping when a parameter name differs in your release)
ss = [mdl '/Battery_Stage']; add_block('built-in/Subsystem', ss, 'Position',[250 100 450 260]);
Simulink.SubSystem.deleteContents(ss);
bat = bs_addb('powerlib/Electrical Sources/Battery',[ss '/Battery'],'Position',[30 200 90 260]);
bs_setp(bat,'BatteryType','Lithium-Ion','NominalVoltage',num2str(P.Vbat),'RatedCapacity',num2str(P.Ah),'InitialSOC','50');
ind = bs_addb('powerlib/Elements/Series RLC Branch',[ss '/Lb'],'Position',[170 100 220 130]);
bs_setp(ind,'BranchType','RL','Resistance',num2str(P.Rb),'Inductance',num2str(P.Lb));
ims = bs_addb('powerlib/Measurements/Current Measurement',[ss '/i_bat'],'Position',[110 100 150 130]);
hb  = bs_addb('powerlib/Power Electronics/Universal Bridge',[ss '/HB'],'Position',[270 80 340 180]);
bs_setp(hb,'Arms','1','Device','IGBT / Diodes','SnubberResistance','1e5','Ron','1e-3','ForwardVoltages','[1 0.8]');
vb  = bs_addb('powerlib/Measurements/Voltage Measurement',[ss '/V_bat'],'Position',[110 260 150 290]);
vd  = bs_addb('powerlib/Measurements/Voltage Measurement',[ss '/V_dc'],'Position',[400 260 440 290]);
pDCp = bs_addb('powerlib/Elements/Connection Port',[ss '/DCp'],'Position',[500 60 530 80]);
pDCn = bs_addb('powerlib/Elements/Connection Port',[ss '/DCn'],'Position',[500 220 530 240]);
bs_setp(pDCp,'Side','Right'); bs_setp(pDCn,'Side','Right');
add_block('simulink/Sources/Step',[ss '/P_ref'],'Time',num2str(P.t_dis),'Before','0','After',num2str(P.Pmax),'Position',[30 340 60 370]);
add_block('simulink/Sources/Step',[ss '/P_ref2'],'Time',num2str(P.t_chg),'Before','0','After',num2str(-2*P.Pmax),'Position',[30 390 60 420]);
add_block('simulink/Math Operations/Sum',[ss '/P_sum'],'Inputs','++','Position',[90 360 110 390]);
add_block('simulink/Math Operations/Gain',[ss '/1_over_Vbat'],'Gain',num2str(1/P.Vbat),'Position',[130 360 170 390]);
add_block('simulink/Discrete/Zero-Order Hold',[ss '/ZOH_i'],'SampleTime',num2str(P.Tctl),'Position',[190 420 220 450]);
add_block('simulink/Math Operations/Sum',[ss '/err'],'Inputs','+-','Position',[240 365 260 395]);
add_block('simulink/Discrete/Discrete PID Controller',[ss '/PI'],'Controller','PI','P',num2str(P.Kp),'I',num2str(P.Ki), ...
    'SampleTime',num2str(P.Tctl),'Position',[280 360 340 400]);
add_block('simulink/Math Operations/Sum',[ss '/Vb_minus_vL'],'Inputs','+-','Position',[360 365 380 395]);
add_block('simulink/Math Operations/Divide',[ss '/Du'],'Position',[400 360 430 395]);
add_block('simulink/Discontinuities/Saturation',[ss '/sat'],'UpperLimit','0.95','LowerLimit','0.05','Position',[450 360 480 390]);
add_block('simulink/Math Operations/Gain',[ss '/two'],'Gain','2','Position',[500 360 530 390]);
add_block('simulink/Math Operations/Bias',[ss '/minus1'],'Bias','-1','Position',[550 360 580 390]);
bs_addb('powerlib/Control & Measurements/Pulse & Signal Generators/PWM Generator (2-Level)',[ss '/PWM'],'Position',[600 350 680 400]);
bs_setp([ss '/PWM'],'Fc',num2str(P.fsw),'SampleTime',num2str(P.Tpwm));   % then open the block and choose '1 arm / half bridge' by hand

%% ---- signal wiring (named ports; checked by add_line errors)
L = @(a,b) add_line(ss,a,b,'autorouting','on');
L('P_ref/1','P_sum/1'); L('P_ref2/1','P_sum/2'); L('P_sum/1','1_over_Vbat/1'); L('1_over_Vbat/1','err/1');
L('i_bat/1','ZOH_i/1'); L('ZOH_i/1','err/2'); L('err/1','PI/1');
L('V_bat/1','Vb_minus_vL/1'); L('PI/1','Vb_minus_vL/2'); L('Vb_minus_vL/1','Du/1'); L('V_dc/1','Du/2');
L('Du/1','sat/1'); L('sat/1','two/1'); L('two/1','minus1/1'); L('minus1/1','PWM/1');

%% ---- power wiring by port position (top port = +). Prints what it connected.
pt = @(blk) bs_ports(blk);
B = pt(bat); I1 = pt(ims); LB = pt(ind); H = pt(hb); VB = pt(vb); VD = pt(vd);
fprintf('Battery ports: %d | i_bat: %d | Lb: %d | HB: %d (expect A + DC+ DC-)\n', numel(B),numel(I1),numel(LB),numel(H));
% battery (+) -> i_bat -> Lb -> bridge A ; bridge DC+ -> DCp ; bridge DC- and battery (-) -> DCn
bs_conn(ss, B(1), I1(1)); bs_conn(ss, I1(2), LB(1)); bs_conn(ss, LB(2), H.A);
bs_conn(ss, H.dcp, get_param(pDCp,'PortHandles').RConn(1)); 
bs_conn(ss, H.dcn, get_param(pDCn,'PortHandles').RConn(1));
bs_conn(ss, B(2), get_param(pDCn,'PortHandles').RConn(1));
% PWM -> bridge gate, voltage sensors
add_line(ss, get_param([ss '/PWM'],'PortHandles').Outport(1), get_param(hb,'PortHandles').Inport(1));
bs_conn(ss, VB(1), B(1)); bs_conn(ss, VB(2), B(2)); bs_conn(ss, VD(1), H.dcp); bs_conn(ss, VD(2), H.dcn);
% logging
add_block('simulink/Sinks/To Workspace',[ss '/log_ibat'],'VariableName','i_bat','SaveFormat','Structure With Time','Position',[110 140 160 160]);
add_line(ss,'i_bat/1','log_ibat/1');

%% ---- harness: stiff 700 V DC source
src = bs_addb('powerlib/Electrical Sources/DC Voltage Source',[mdl '/Vdc_700'],'Amplitude',num2str(P.Vdc),'Position',[120 120 170 170]);
rs  = bs_addb('powerlib/Elements/Series RLC Branch',[mdl '/Rdc'],'BranchType','R','Resistance','0.05','Position',[200 100 240 130]);
spt = bs_ports(src); rpt = bs_ports(rs); sp = get_param(ss,'PortHandles');
fprintf('Subsystem physical ports (L/R): %d / %d\n', numel(sp.LConn), numel(sp.RConn));
if numel(sp.RConn) >= 2 && numel(spt) >= 2 && numel(rpt) >= 2
    sy = arrayfun(@(p) bs_y(get_param(p,'Position')), sp.RConn(:)); [~,sx] = sort(sy);
    bs_conn(mdl, spt(1), rpt(1)); bs_conn(mdl, rpt(2), sp.RConn(sx(1))); bs_conn(mdl, spt(2), sp.RConn(sx(2)));
end
fprintf('\nIf the script stopped before this line, the printed port counts above tell me which block differs.\n');
save_system(mdl);
fprintf('Saved %s.slx. Finish the harness: Vdc_700 (+) -> Rdc -> Battery_Stage DC+, Vdc_700 (-) -> Battery_Stage DC-, then Run.\n', mdl);
fprintf('After the run:  plot(i_bat.time, squeeze(i_bat.signals.values))  -> expect 0, +12.5 A, -12.5 A.\n');
