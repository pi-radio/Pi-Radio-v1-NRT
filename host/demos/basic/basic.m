%% DEMO: Basic Tx/Rx to test the RFSoC board and the Pi-Radio v1 SDR

%% Packages
% Add the folder containing +piradio to the MATLAB path.
addpath('../../');

%% Parameters
isDebug = true;		% print debug messages

%% Create two Fully Digital SDRs (sdr0 and sdr1)
sdr0 = piradio.sdr.FullyDigital('ip', "10.1.1.50", 'isDebug', isDebug, ...
    'figNum', 100, 'name', 'revB-0007');

sdr1 = piradio.sdr.FullyDigital('ip', "10.1.1.51", 'isDebug', isDebug, ...
    'figNum', 101, 'name', 'revB-0001');

% Configure the RFSoC
sdr0.fpga.configure('../../config/rfsoc.cfg');
sdr1.fpga.configure('../../config/rfsoc.cfg');

% Configure the LMX chip on the Pi-Radio v1 transceiver board. Choose:
sdr0.lo.configure('../../config/lmx_registers_58ghz.txt');
sdr1.lo.configure('../../config/lmx_registers_58ghz.txt');

% Configure the HMC6300 TX chips on the Pi-Radio v1 transceiver board.
%   The first parameter is the TX index:
%       Use {1,2,3,4} to configure an individual TX channel
%       Use 9 to configure all TX channels
%   The second parameter is the file name:
%       hmc6300_registers.txt   % (configure for external LO and power on)
%       hmc6300_pdn.txt         % (power down the HMC6300)
sdr0.rffeTx.configure(9, '../../config/hmc6300_registers.txt');
sdr1.rffeTx.configure(9, '../../config/hmc6300_registers.txt');

% Configure the HMC6301 RX chips on the Pi-Radio v1 transceiver board.
%   The first parameter is the RX index:
%       Use {1,2,3,4} to configure an individual RX channel
%       Use 9 to configure all RX channels
%   The second parameter is the file name:
%       hmc6301_registers.txt   % (configure for external LO and power on)
%       hmc6301_pdn.txt         % (power down the HMC6301)
sdr0.rffeRx.configure(9, '../../config/hmc6301_registers.txt');
sdr1.rffeRx.configure(9, '../../config/hmc6301_registers.txt');

% Read some parameters of the SDR and save them in local variables
nadc = sdr0.nadc;   % num of A/D converters
ndac = sdr0.ndac;   % num of D/A converters
nch = sdr0.nch;     % num of channels
fs = sdr0.fs;       % sample frequency in Hz
                    % (pre-interpolation at the TX)
                    % (post-decimation at the RX)

% Make sure that the nodes are silent (not transmitting)
nFFT = 1024;
txtd = zeros(nFFT, nch);
sdr0.send(txtd);
sdr1.send(txtd);

%% Decide which is the TX and which is the RX
sdrTX = sdr0;
sdrRX = sdr1;

%% Create time-domain samples and send them to the DACs
clc;
nFFT = 1024;	% number of samples to generate for each DAC
scToUse = 400;   % select a subcarrier to generate data for each DAC

% Initialize the TX data. Each TX channel sends a different tone
txtd = zeros(nFFT, nch);
for ich = 1:1
	txfd = zeros(nFFT,1);
   	txfd(nFFT/2 + 1 + scToUse) = 1;
	txfd = fftshift(txfd);
	txtd(:,ich) = ifft(txfd);
end

txtd = txtd./max(abs(txtd))*15000;

% Send the data to the DACs
sdrTX.send(txtd);

%% Receive data from the ADCs

% To read data from the ADCs we use the `recv` method of the FullyDigital
% sdr class. This method has 3 arguments. 
% *  nsamp: number of continuous samples to read per channel
% *  nskip: number of samples to skip
% * nbatch: number of batches

nFFT = 1024;	% num of FFT points
nskip = 1024;	% skip ADC data for 1024 cc
ntimes = 200;	% num of batches

% Finally, call the `recv` method
rxtd = sdrRX.recv(nFFT, nskip, ntimes);

%% Close the TCP Connections and clear the Workspace variables
clear sdr0 sdr1;
clear sdrTX sdrRX;
clear ans fs iadc idac ip isDebug itimes mem nadc ndac nFFT nbatch nsamp;
clear nskip ntimes rxtd scs scToUse txfd txtd nch ich;