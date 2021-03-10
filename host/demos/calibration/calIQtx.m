% Calibrate the TX-side IQ imbalances

% Measure the alpha values. Set both nodes to be on the same center
% frequency. Transmit a single tone (only the real or imaginary component,
% one at a time). Measure the received power on a reference RX channel. All
% four TX channels are active, each transmitting a unique tone.

sdrTx.lo.configure('../../config/lmx_registers_58ghz.txt');
sdrRx.lo.configure('../../config/lmx_registers_58ghz.txt');

% Configure the RX number of samples, etc
nFFT = 1024;        % num of FFT points
nread = nFFT;       % Number of samples to read
nskip = nFFT*1;     % Number of samples to skip
ntimes = 100;       % Number of batches to receive
scMultiple = 100;   % txIndex transmits at SC = txIndex*scMultiple

% Create nch tones (one from each channel)
txfd = zeros(nFFT, sdrTx.nch);
txtd = zeros(nFFT, sdrTx.nch);
for txIndex = 1:sdrTx.nch
    txfd(nFFT/2 + 1 + scIndex*txIndex, txIndex) = 1+0i;
    txtd(:,txIndex) = ifft(fftshift(txfd));    
end
m = max(abs(txtd(:,1)));
txtd = txtd/m*15000;

% expType = 1: Transmit complex. Measure the sideband suppression
% expType = 2: Transmit only the real. Measure RX power
% expType = 3: Transmit only the imag. Measure RX power
% pre-compensate the TX waveform based on the measured alpha
% exptype = 4: Transmit only the real. Measure RX power
% exptype = 5: Transmit only the imag. Measure RX power
% Verify that the residual alpha is close to 0.
% expType = 6: Transmit complex. Measure the sideband suppression.
for expType = 1:4
    
    if (expType == 1)
        txtdMod = real(txtd);
    elseif (expType == 2)
        txtdMod = imag(txtd);
    elseif (expType == 3)
        
    elseif (expType == 4)
    end
    
    sdrTx.send(txtd);
end