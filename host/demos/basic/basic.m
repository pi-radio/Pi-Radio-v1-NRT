%% DEMO: Basic Tx/Rx with the Pi-Radio 140 GHz, 8 channel SDR

%% Packages
% Add the folder containing +piradio to the MATLAB path.
addpath('../../');

%% Parameters
ip = "10.1.1.43";	% IP Address 
mem = "bram";		% Memory type
isDebug = true;		% print debug messages
ndac = 8;			% num of D/A converters
nadc = 8;			% num of A/D converters
nch = 4;            % number of channels
fs = 1966.08e6;		% sample frequency

%% Create a Fully Digital SDR
sdr0 = piradio.sdr.FullyDigital('ip', ip, 'mem', mem, ...
	'ndac', ndac, 'nadc', nadc, 'isDebug', isDebug);


% Set the number of DACs and ADCs of the RFSoC
sdr0.fpga.set('ndac', ndac, 'nadc', nadc, 'nch', nch);

% Configure the RFSoC
sdr0.fpga.configure('../../config/rfsoc.cfg');

%% Create time-domain samples and send them to the DACs
clc;
nFFT = 1024;	% number of samples to generate for each DAC
scToUse = 100;

% Initialize the tx data
txtd = zeros(nFFT, nch);
for ich = 1:nch
	txfd = zeros(nFFT,1);
   	txfd(nFFT/2 + 1 + scToUse) = 1;
	txfd = fftshift(txfd);
	txtd(:,ich) = ifft(txfd);
end

txtd = txtd./abs(max(txtd))*32000;

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
sdr0.send(txtd);

%% Receive continous data from the ADCs
clc;
nFFT = 1024;
nsamp = nFFT*2*nch; % Each channel uses 2 ADCs
sdr0.set('nread', 0, 'nskip', 0);
sdr0.ctrlFlow();
rxtd = sdr0.recv(nsamp);

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
sdr0.set('nread', nread, 'nskip', nskip);
sdr0.ctrlFlow();

% Then, read data from the ADCs. Note that the returned data should be a
% tensor with dimensions: nsamp x ntimes x nadc
nsamp = ntimes*nFFT*2*nadc;
rxtd = sdr0.recv(nsamp);

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
clear sdr0;
clear ans fs iadc idac ip isDebug itimes mem nadc ndac nFFT nread nsamp;
clear nskip ntimes rxtd scs scToUse txfd txtd;