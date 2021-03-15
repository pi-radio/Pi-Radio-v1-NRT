% This is the "master" script to run calibration. There are two nodes: sdr0
% and sdr1. The "slave" scripts require references to sdrTx and sdrRx, and
% this is controlled by the master script.

%% Set up the Nodes for Calibration (the baseband subsystem)

% Add the folder containing +piradio to the MATLAB path.
addpath('../../');
addpath('../../helper');
isDebug = false;		% print debug messages

sdr0 = piradio.sdr.FullyDigital('ip', "192.168.1.50", 'isDebug', isDebug, ...
    'figNum', 100, 'name', 'revB-0007');

sdr1 = piradio.sdr.FullyDigital('ip', "192.168.1.51", 'isDebug', isDebug, ...
    'figNum', 101, 'name', 'revB-0001');

% Read some parameters of the SDR in local variables
nadc = sdr0.nadc;   % num of A/D converters
ndac = sdr0.ndac;   % num of D/A converters
nch = sdr0.nch;     % num of channels
fs = sdr0.fs;       % sample frequency in Hz
                    % (pre-interpolation at the TX)
                    % (post-decimation at the RX)

sdr0.fpga.configure('../../config/rfsoc.cfg');
sdr1.fpga.configure('../../config/rfsoc.cfg');

% Make sure we aren't transmitting anything
txtd = zeros(1024, 4);
sdr0.send(txtd);
sdr1.send(txtd);
clear txtd;

sdr0.rffeTx.powerDown();
sdr0.rffeRx.powerDown();
sdr0.lo.configure('../../config/lmx_registers_58ghz.txt');
sdr0.rffeTx.configure(9, '../../config/hmc6300_registers.txt');
sdr0.rffeRx.configure(9, '../../config/hmc6301_registers.txt');

sdr1.rffeTx.powerDown();
sdr1.rffeRx.powerDown();
sdr1.lo.configure('../../config/lmx_registers_58ghz.txt');
sdr1.rffeTx.configure(9, '../../config/hmc6300_registers.txt');
sdr1.rffeRx.configure(9, '../../config/hmc6301_registers.txt');

%% Calibrate the timing and phase offsets on the TX side

% Calibrate the TX array on sdr0, using sdr1 as the reference RX
clc;
sdrTx = sdr0;
sdrRx = sdr1;
calTimingPhaseTx;
sdr0 = sdrTx;
sdr1 = sdrRx;
clear sdrTx sdrRx;

% Calibrate the TX array on sdr1, using sdr0 as the reference RX
clc;
sdrTx = sdr1;
sdrRx = sdr0;
calTimingPhaseTx;
sdr1 = sdrTx;
sdr0 = sdrRx;
clear sdrTx sdrRx;

%% Calibrate the timing and phase offsets on the RX side

% Calibrate the RX array on sdr0, using sdr1 as the reference TX
clc;
sdrTx = sdr1;
sdrRx = sdr0;
calTimingPhaseRx;
sdr0 = sdrRx;
sdr1 = sdrTx;
clear sdrTx sdrRx;

% Calibrate the RX array on sdr1, using sdr0 as the reference TX
clc;
sdrTx = sdr0;
sdrRx = sdr1;
calTimingPhaseRx;
sdr1 = sdrRx;
sdr0 = sdrTx;
clear sdrTx sdrRx;

%% Calibrate the RX-side IQ Imbalances

% Calibrate the RX array on sdr0, using sdr1 as the reference TX
clc;
sdrTx = sdr1;
sdrRx = sdr0;
calIQrx;
sdr0 = sdrRx;
sdr1 = sdrTx;
clear sdrTx sdrRx;

% Calibrate the RX array on sdr1, using sdr0 as the reference TX
clc;
sdrTx = sdr0;
sdrRx = sdr1;
calIQrx;
sdr1 = sdrRx;
sdr0 = sdrTx;
clear sdrTx sdrRx;

%% Calibrate the TX-side IQ Imbalances

% Calibrate the TX array on sdr0, using sdr1 as the reference RX
clc;
sdrTx = sdr0;
sdrRx = sdr1;
calIQtx;
sdr1 = sdrRx;
sdr0 = sdrTx;
clear sdrTx sdrRx;

% Calibrate the TX array on sdr1, using sdr0 as the reference RX
clc;
sdrTx = sdr1;
sdrRx = sdr0;
calIQtx;
sdr0 = sdrRx;
sdr1 = sdrTx;
clear sdrTx sdrRx;

%% Clear workspace variables
clear isDebug nadc ndac nch sdr0 sdr1 fs;