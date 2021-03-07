%% DEMO: Basic Tx/Rx to test the RFSoC board and the Pi-Radio v1 SDR

%% Packages
% Add the folder containing +piradio to the MATLAB path.
addpath('../../');

%% Parameters
isDebug = true;		% print debug messages
ndac = 8;			% num of D/A converters
nadc = 8;			% num of A/D converters
nch = 4;            % number of channels

fs = 1966.08e6;		% sample frequency
                    % (pre-interpolation at the TX)
                    % (post-decimation at the RX)

%% Create two Fully Digital SDRs (sdr0 and sdr1)
sdr0 = piradio.sdr.FullyDigital('ip', "10.1.1.50", ...
	'ndac', ndac, 'nadc', nadc, 'nch', nch, 'isDebug', isDebug, ...
    'figNum', 100);

sdr1 = piradio.sdr.FullyDigital('ip', "10.1.1.51", ...
	'ndac', ndac, 'nadc', nadc, 'nch', nch, 'isDebug', isDebug, ...
    'figNum', 101);

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
scMultiple = 25;

% Initialize the TX data. Each TX channel sends a different tone
txtd = zeros(nFFT, nch);
for ich = 1:1
	txfd = zeros(nFFT,1);
   	txfd(nFFT/2 + 1 + scMultiple) = 1;
	txfd = fftshift(txfd);
	txtd(:,ich) = ifft(txfd);
end

txtd = txtd./max(abs(txtd))*15000;

% Send the data to the DACs
sdrTX.send(txtd);

%% Receive discontinuous data from the ADCs
nFFT = 1024;	% number of samples to generate for each DAC
nread = nFFT/4; % read ADC data for 256 cc (4 samples per cc)
nskip = 1024; % skip ADC data for 512 cc
ntimes = 20;

% Then, read data from the ADCs. Note that the returned data should be a
% tensor with dimensions: nsamp x ntimes x nadc
nsamp = ntimes*nFFT*nadc;

% First, set the read and skip timings
sdrRX.set('nread', nread, 'nskip', nskip, 'nbytes', nsamp*2);
sdrRX.ctrlFlow();

rxtd = sdrRX.recv(nsamp);

%% Close the TCP Connections and clear the Workspace variables
clear sdr0 sdr1;
clear sdrTX sdrRX;
clear ans fs iadc idac ip isDebug itimes mem nadc ndac nFFT nread nsamp;
clear nskip ntimes rxtd scs scMultiple txfd txtd nch ich;