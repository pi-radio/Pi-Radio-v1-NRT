%% DEMO: Basic Tx/Rx to test the RFSoC board and the Pi-Radio v1 SDR

%% Packages
% Add the folder containing +piradio to the MATLAB path.
addpath('../../');

%% Parameters
mem = "bram";		% Memory type
isDebug = true;		% print debug messages
ndac = 8;			% num of D/A converters
nadc = 8;			% num of A/D converters
nch = 4;            % number of channels

fs = 1966.08e6;		% sample frequency
                    % (pre-interpolation at the TX)
                    % (post-decimation at the RX)

%% Create two Fully Digital SDRs (sdr0 and sdr1)
sdr0 = piradio.sdr.FullyDigital('ip', "10.1.1.43", 'mem', mem, ...
	'ndac', ndac, 'nadc', nadc, 'isDebug', isDebug, ...
    'figNum', 100);

%sdr1 = piradio.sdr.FullyDigital('ip', "10.1.1.44", 'mem', mem, ...
	%'ndac', ndac, 'nadc', nadc, 'isDebug', isDebug, ...
    %'figNum', 101);


% Set the number of DACs and ADCs of the RFSoC
sdr0.fpga.set('ndac', ndac, 'nadc', nadc, 'nch', nch);
%sdr1.fpga.set('ndac', ndac, 'nadc', nadc, 'nch', nch);

% Configure the RFSoC
sdr0.fpga.configure('../../config/rfsoc.cfg');
%sdr1.fpga.configure('../../config/rfsoc.cfg');

% Configure the LMX chip on the Pi-Radio v1 transceiver board. Choose:
%   lmx_registers_58ghz.txt    % (set fc to 58 GHz and power on)
%   lmx_registers_pdn.txt      % (power down the LMX)
sdr0.configLMX('../../config/lmx_registers_58ghz.txt');
%sdr1.configLMX('../../config/lmx_registers_58ghz.txt');

% Configure the HMC6300 TX chips on the Pi-Radio v1 transceiver board.
%   The first parameter is the TX index:
%       Use {1,2,3,4} to configure an individual TX channel
%       Use 9 to configure all TX channels
%   The second parameter is the file name:
%       hmc6300_registers.txt   % (configure for external LO and power on)
%       hmc6300_pdn.txt         % (power down the HMC6300)
sdr0.configHMC6300(9, '../../config/hmc6300_registers.txt');
%sdr1.configHMC6300(9, '../../config/hmc6300_registers.txt');

% Configure the HMC6301 RX chips on the Pi-Radio v1 transceiver board.
%   The first parameter is the RX index:
%       Use {1,2,3,4} to configure an individual RX channel
%       Use 9 to configure all RX channels
%   The second parameter is the file name:
%       hmc6301_registers.txt   % (configure for external LO and power on)
%       hmc6301_pdn.txt         % (power down the HMC6301)
sdr0.configHMC6301(9, '../../config/hmc6301_registers.txt');
%sdr1.configHMC6301(9, '../../config/hmc6301_registers.txt');

%% Decide which is the TX and which is the RX
sdrTX = sdr0;
sdrRX = sdr0;

%% Create time-domain samples and send them to the DACs
clc;
nFFT = 1024;	% number of samples to generate for each DAC
scMultiple = 75;

% Initialize the TX data. Each TX channel sends a different tone
txtd = zeros(nFFT, nch);
for ich = 1:nch
	txfd = zeros(nFFT,1);
   	txfd(nFFT/2 + 1 + scMultiple*ich) = 1;
	txfd = fftshift(txfd);
	txtd(:,ich) = ifft(txfd);
end

txtd = txtd./abs(max(txtd))*1000;

% Plot the tx data
scs = linspace(-nFFT/2, nFFT/2-1, nFFT);

figure(1);
clf;
for ich = 1:nch
	subplot(1,4,ich);
	plot(scs,(abs(fftshift(fft(txtd(:,ich))))));
	axis tight;
	grid on; grid minor;
	ylabel('Magnitude [Abs]', 'interpreter', 'latex', 'fontsize', 12);
	xlabel('Subcarrier Index', 'interpreter', 'latex', 'fontsize', 12);
	title(sprintf('DAC %d', ich), 'interpreter', 'latex', 'fontsize', 14);
end

% Send the data to the DACs
sdrTX.send(txtd);

%% Receive continous data from the ADCs
clc;
nFFT = 1024;
nsamp = nFFT*2*nch; % Each channel uses 2 ADCs
sdrRX.set('nread', 0, 'nskip', 0);
sdrRX.ctrlFlow();
rxtd = sdrRX.recv(nsamp);

% Plot the rx data
scs = linspace(-nFFT/2, nFFT/2-1, nFFT);

figure(2);
clf;
for ich = 1:nch
	subplot(1,nch,ich);
	plot(scs, 10*log10(abs(fftshift(fft(rxtd(:,ich))))));
	axis tight;	grid on; grid minor;
	ylabel('Magnitude [dB]', 'interpreter', 'latex', 'fontsize', 12);
	xlabel('Subcarrier Index', 'interpreter', 'latex', 'fontsize', 12);
	title(sprintf('Channel %d', ich), 'interpreter', 'latex', 'fontsize', 14);
    ylim([20 80]);
end

%% Receive discontinus data from the ADCs
nread = nFFT/2; % read ADC data for 512 cc
nskip = 512; % skip ADC data for 512 cc
ntimes = 2;

% First, set the read and skip timings
sdrRX.set('nread', nread, 'nskip', nskip);
sdrRX.ctrlFlow();

% Then, read data from the ADCs. Note that the returned data should be a
% tensor with dimensions: nsamp x ntimes x nadc
nsamp = ntimes*nFFT*2*nadc;
rxtd = sdrRX.recv(nsamp);

figure(2);
for itimes=1:ntimes
    for ich = 1:nadc
		subplot(2,nadc/2,ich);
		plot(scs, 10*log10(abs(fftshift(fft(rxtd(:,itimes,ich))))));
		axis tight; grid on; grid minor;
		ylabel('Magnitude [dB]', 'interpreter', 'latex', 'fontsize', 12);
		xlabel('Subcarrier Index', 'interpreter', 'latex', 'fontsize', 12);
		title(sprintf('ADC %d', ich), 'interpreter', 'latex', 'fontsize', 14);
        ylim([20 70]);
    end
    pause(1);
end

%% Close the TCP Connections and clear the Workspace variables
clear sdr0 sdr1;
clear sdrTX sdrRX;
clear ans fs iadc idac ip isDebug itimes mem nadc ndac nFFT nread nsamp;
clear nskip ntimes rxtd scs scMultiple txfd txtd nch ich;
