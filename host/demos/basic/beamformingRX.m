% In this demo, we assume that sdr0 and sdr1 are open, and are fully
% calibrated. Look at the calibration demo to make sure this is done. In
% the minimum, the timing and phase offsets need to be calibrated.

% Choose which is the TX and which is the RX. Configure the LOs to make
% sure the center frequency is the same.
sdrTx = sdr0;
sdrRx = sdr1;

% Transmit a wideband signal from one channel on the TX. On the RX, capture
% samples, and apply the calibrations. Then, apply BF vectors for a set of
% AoA values. Plot them out.

nFFT = 1024;
nread = nFFT;
nskip = nFFT*101;
ntimes = 100;
txfd = zeros(nFFT, 1);
constellation = [1+1j 1-1j -1+1j -1-1j];

scMin = -450; scMax = 450;
for scIndex = scMin:scMax
    txfd(nFFT/2 + 1 + scIndex) = constellation(randi(4));
end
txfd = fftshift(txfd);
txtd = ifft(txfd);
m = max(abs(txtd));
txtd = txtd / m * 15000;
refTxIndex = 1;
txtdMod = zeros(nFFT, sdrTx.nch);
txtdMod(:, refTxIndex) = txtd;
sdrTx.send(txtdMod);

rxtd = sdrRx.recv(nread, nskip, ntimes);
rxtd = sdrRx.applyCalRxArray(rxtd);
rxtd = sdrRx.applyCalRxIQ(rxtd);

naoa = 101;
aoas = linspace(-1, 1, naoa);
pArray = zeros(1, naoa);

for iaoa = 1:naoa
    p = 0;
    aoa = aoas(iaoa);
    for itimes = 1:ntimes
        tdbf = zeros(nFFT, 1);
        for rxIndex=1:sdrRx.nch
            td = rxtd(:,itimes,rxIndex);
            tdbf = tdbf + td * exp(1j*rxIndex*pi*sin(aoa)); % Apply BF Vec
        end % rxIndex
        fd = fftshift(fft(tdbf));
        p = p + sum(abs(fd( nFFT/2 + 1 + scMin : nFFT/2 + 1 + scMax)));
    end %itimes
    pArray(iaoa) = p;
end % iaoa

% Plot
pArray = pArray / max(pArray);
figure(3); clf;
plot(rad2deg(aoas), mag2db(pArray));
xlabel('Angle of Arrival (Deg)');
ylabel('Power (dB)');
grid on; grid minor;
ylim([-15 0])

% Stop transmitting and do a dummy read
txtd = zeros(nFFT, sdrTx.nch);
sdrTx.send(txtd);
sdrRx.recv(nread, nskip, ntimes);

% Clear workspace variables
clear aoa aoas fd iaoa naoa p pArray refTxIndex td tdbf txtdMod;
clear sdrTx sdrRx ans itimes m nFFT nread nskip ntimes rxIndex rxtd;
clear scIndex txfd txtd constellation scMax scMin;
