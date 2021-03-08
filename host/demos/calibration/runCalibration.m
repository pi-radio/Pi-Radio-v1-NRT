% This is the "master" script to run calibration. There are two nodes: sdr0
% and sdr1. The "slave" scripts require references to sdrA and sdrB, and
% this is controlled by the master script.

%% Set up the Nodes for Calibration (the baseband subsystem)

% Add the folder containing +piradio to the MATLAB path.
addpath('../../');
addpath('../../helper');
isDebug = false;		% print debug messages
ndac = 8;			% num of D/A converters
nadc = 8;			% num of A/D converters
nch = 4;            % number of channels

fs = 1966.08e6;		% sample frequency
                    % (pre-interpolation at the TX)
                    % (post-decimation at the RX)

sdr0 = piradio.sdr.FullyDigital('ip', "10.1.1.50", ...
	'ndac', ndac, 'nadc', nadc, 'nch', nch, 'isDebug', isDebug, ...
    'figNum', 100);

sdr1 = piradio.sdr.FullyDigital('ip', "10.1.1.51", ...
	'ndac', ndac, 'nadc', nadc, 'nch', nch, 'isDebug', isDebug, ...
    'figNum', 101);

sdr0.fpga.configure('../../config/rfsoc.cfg');
sdr1.fpga.configure('../../config/rfsoc.cfg');

% Make sure we aren't transmitting anything
txtd = zeros(1024, 4);
sdr0.send(txtd);
sdr1.send(txtd);

sdr0.rffeTx.powerDown();
sdr0.rffeRx.powerDown();
sdr0.lo.configure('../../config/lmx_registers_58ghz.txt');
sdr0.rffeTx.configure(9, '../../config/hmc6300_registers.txt');
sdr0.rffeRx.configure(9, '../../config/hmc6301_registers.txt');


% Set up the RF components on sdrB as the Reference RX. Note that we will
% use only one RX channel
sdr1.rffeTx.powerDown();
sdr1.rffeRx.powerDown();
sdr1.lo.configure('../../config/lmx_registers_58ghz.txt');
sdr1.rffeTx.configure(9, '../../config/hmc6300_registers.txt');
sdr1.rffeRx.configure(9, '../../config/hmc6301_registers.txt');

%% Calibrate the timing and phase offsets on the TX side

% Calibrate the TX array on sdr0, using sdr1 as the reference RX
clc;
sdrA = sdr0;
sdrB = sdr1;
calTimingPhaseTx;
sdr0 = sdrA;
sdr1 = sdrB;
clear sdrA sdrB;

% Calibrate the TX array on sdr1, using sdr0 as the reference RX
clc;
sdrA = sdr1;
sdrB = sdr0;
calTimingPhaseTx;
sdr1 = sdrA;
sdr0 = sdrB;
clear sdrA sdrB;

%% Calibrate the timing and phase offsets on the RX side
% Calibrate the RX array on sdr0, using sdr1 as the reference TX
clc;
sdrA = sdr0;
sdrB = sdr1;
calTimingPhaseRx;
sdr0 = sdrA;
sdr1 = sdrB;
clear sdrA sdrB;

%% Clear workspace variables
clear isDebug nadc ndac nch sdr0 sdr1 fs;