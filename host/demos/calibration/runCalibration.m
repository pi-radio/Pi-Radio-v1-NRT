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

%% Calibrate the timing offsets on the TX side

% Calibrate the TX array on sdr0, using sdr1 as the reference RX
clc;
sdrA = sdr1;
sdrB = sdr0;
calTimingOffsetsTx;
sdr1 = sdrA;
sdr0 = sdrB;

clear sdrA sdrB;

%% Clear workspace variables
clear isDebug nadc ndac nch sdr0 sdr1 fs;