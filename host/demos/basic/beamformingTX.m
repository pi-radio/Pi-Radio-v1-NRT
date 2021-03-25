% In this demo, we assume that sdr0 and sdr1 are open, and are fully
% calibrated. Look at the calibration demo to make sure this is done. In
% the minimum, the timing and phase offsets need to be calibrated.

% Choose which is the TX and which is the RX. Configure the LOs to make
% sure the center frequency is the same.
sdrTx = sdr1;
sdrRx = sdr0;

nFFT = 1024;
nread = nFFT;
nskip = nFFT*1;
ntimes = 200;
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

naod = 21;
aods = linspace(-1, 1, naod);
pArray = zeros(1, naod);

for iaod = 1:naod
    p = 0;
    fprintf('.');
    txtdMod = zeros(nFFT, sdrTx.nch);
    aod = aods(iaod);
    for txIndex=1:sdrTx.nch
        txtdMod(:, txIndex) = txtd * exp(1j*txIndex*pi*sin(aod)); % Apply BF
    end
    txtdMod = sdrTx.applyCalTxArray(txtdMod);
    sdrTx.send(txtdMod);

    rxtd = sdrRx.recv(nread, nskip, ntimes);
    rxtd = sdrRx.applyCalRxArray(rxtd);
    rxtd = sdrRx.applyCalRxIQ(rxtd);
    
    for itimes = 1:ntimes
        refRxIndex = 1;
        fd = fftshift(fft(rxtd(:, itimes, refRxIndex)));
        p = p + sum(abs(fd( nFFT/2 + 1 + scMin : nFFT/2 + 1 + scMax)));
    end %itimes
    pArray(iaod) = p;
end % iaoa

% Plot
pArray = pArray / max(pArray);
figure(3); clf;
plot(rad2deg(aods), mag2db(pArray));
xlabel('Angle of Departure (Deg)');
ylabel('Power (dB)');
grid on; grid minor;
ylim([-20 0])

% Stop transmitting and do a dummy read
txtd = zeros(nFFT, sdrTx.nch);
sdrTx.send(txtd);
sdrRx.recv(nread, nskip, ntimes);

% Clear workspace variables
clear aoa aoas fd iaoa naoa p pArray refTxIndex td tdbf txtdMod;
clear sdrTx sdrRx ans itimes m nFFT nread nskip ntimes rxIndex rxtd;
clear scIndex txfd txtd constellation scMax scMin;
