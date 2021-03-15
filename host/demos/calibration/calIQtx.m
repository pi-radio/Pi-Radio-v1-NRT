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
nskip = nFFT*301;     % Number of samples to skip
ntimes = 300;       % Number of batches to receive
scIndex = 400;   % txIndex transmits at SC = txIndex*scMultiple

% Create nch tones (one from each channel)
txfd = zeros(nFFT, 1);
txtd = zeros(nFFT, 1); % Carries just a single tone on one channel
txtdMod = zeros(nFFT, sdrTx.nch);

txfd(nFFT/2 + 1 + scIndex) = 1+0i;
txtd = ifft(fftshift(txfd));    
m = max(abs(txtd));
txtd = txtd/m*5000;
figure(3); clf;
cols = 'mrgb';

magReAlpha  = zeros(sdrTx.nch, ntimes);     % magnitude of the RX waveforms, when only Re is being transmitted
magImAlpha  = zeros(sdrTx.nch, ntimes);     % magnitude of the RX waveforms, when only Im is being transmitted


% expType = 1: Transmit only the real. Measure RX power
% expType = 2: Transmit only the imag. Measure RX power
for expType = 1:2
    
    for txIndex=1:sdrTx.nch
        txtdMod = zeros(nFFT, sdrTx.nch);
        
        if (expType == 1)
            txtdMod(:,txIndex) = real(txtd);
        elseif (expType == 2)
            txtdMod(:,txIndex) = j*imag(txtd);
        end

        sdrTx.send(txtdMod);
        rxtd = sdrRx.recv(nread,nskip,ntimes);
        rxtd = sdrRx.applyCalRxIQ(rxtd);
        figure(3);
        refRxIndex = 2;
        for itimes = 1:ntimes
      
            if (expType == 1)
                td = rxtd(:, itimes, refRxIndex); % Use rxIndex refRxIndex as the reference
                fd = fftshift(fft(td));
                fdMod = zeros(nFFT, 1);
                fdMod(nFFT/2 + 1 + scIndex) = fd(nFFT/2 + 1 + scIndex);
                fdMod(nFFT/2 + 1 - scIndex) = fd(nFFT/2 + 1 - scIndex);
                fdMod = fftshift(fdMod);
                td = ifft(fdMod);
                magRe = rms(abs(td));
                magReAlpha(txIndex, itimes) = magRe;
            elseif (expType == 2)
                td = rxtd(:, itimes, refRxIndex); % Use rxIndex refRxIndex as the reference
                fd = fftshift(fft(td));
                fdMod = zeros(nFFT, 1);
                fdMod(nFFT/2 + 1 + scIndex) = fd(nFFT/2 + 1 + scIndex);
                fdMod(nFFT/2 + 1 - scIndex) = fd(nFFT/2 + 1 - scIndex);
                fdMod = fftshift(fdMod);
                td = ifft(fdMod);
                magIm = rms(abs(td));
                magImAlpha(txIndex, itimes) = magIm;
            end
            
        end % itimes
        
        % Calculate Alpha
        if (expType == 2)
            l = magReAlpha(txIndex, :) ./ magImAlpha(txIndex, :);
            sdrTx.calTxIQa(txIndex) = mean(l);
        end
        
    end % txIndex
end % expType

% We have measured Alpha. Now, we have to cycle through all the "v"
% hypotheses on the TX, and measure the undesired sideband power. Set the
% TX center frequency to 58 GHz, and the RX center frequency to 56.464 GHz.
% Transmit on SC +400. The undesired sideband will be at 57.232 GHz. This
% will be received by the receiver at SC +400. Integrate this power over a
% large number of RX captures.

sdrTx.lo.configure('../../config/lmx_registers_58ghz.txt');
sdrRx.lo.configure('../../config/lmx_registers_56.464ghz.txt');
refRxIndex = 2; % Which RX index to use as the reference receiver?
nvhypo = 31;
vhypos = linspace(-1, 1, nvhypo);
sbAccum = zeros(sdrTx.nch, nvhypo);

for txIndex = 1:sdrTx.nch
    
    for ivhypo = 1:nvhypo
        vhypo = vhypos(ivhypo);
        sdrTx.calTxIQv(txIndex) = vhypo;
        txtdMod = zeros(nFFT, sdrTx.nch);
        txtdMod(:,txIndex) = txtd;
        txtdMod = sdrTx.applyCalTxIQ(txtdMod);
        sdrTx.send(txtdMod);
        
        rxtd = sdrRx.recv(nread,nskip,ntimes);
        rxtd = sdrRx.applyCalRxIQ(rxtd);
        for itimes=1:ntimes
            td = rxtd(:,itimes,refRxIndex);
            fd = fftshift(fft(td));
            sbAccum(txIndex, ivhypo) = sbAccum(txIndex, ivhypo) + abs(fd(nFFT/2 + 1 + scIndex));
        end %itimes
    end % ivhypo
    
    % Plot and calculate the best "v" to use
    figure(3);
    subplot(3,1,1);
    l = sbAccum(txIndex, :);
    plot(vhypos, mag2db(l), cols(txIndex));
    hold on; grid on;
    [~, pos] = min(l);
    sdrTx.calTxIQv(txIndex) = vhypos(pos);
end % txIndex

% Now, apply the calibrations, and measure the sideband suppression

sdrTx.lo.configure('../../config/lmx_registers_58ghz.txt');
sdrRx.lo.configure('../../config/lmx_registers_58ghz.txt');

sbsStore = zeros(sdrTx.nch, ntimes);

for expType = 1:2
    for txIndex=1:sdrTx.nch
        txtdMod = zeros(nFFT, sdrTx.nch);
        txtdMod(:,txIndex) = txtd;
        if (expType == 2)
            txtdMod = sdrTx.applyCalTxIQ(txtdMod);
        end
        sdrTx.send(txtdMod);
        
        rxtd = sdrRx.recv(nread,nskip,ntimes);
        rxtd = sdrRx.applyCalRxIQ(rxtd);
        for itimes=1:ntimes
            td = rxtd(:,itimes,refRxIndex);
            fd = fftshift(fft(td));
            sbsStore(txIndex, itimes) = fd(nFFT/2 + 1 - scIndex) / fd(nFFT/2 + 1 + scIndex);
        end %itimes

        % Plot
        figure(3);
        if (expType == 1)
            subplot(3,1,2);
            l = abs(sbsStore(txIndex, :));
            plot(mag2db(l), cols(txIndex));
            hold on; grid on;
            title('Before TX-side IQ Cal: Sideband Suppression');
            xlabel('itimes'); ylabel('Suppression (dB)');
            ylim([-30 0]);
        elseif (expType == 2)
            subplot(3,1,3);
            l = abs(sbsStore(txIndex, :));
            plot(mag2db(l), cols(txIndex));
            hold on; grid on;
            title('After TX-side IQ Cal: Sideband Suppression');
            xlabel('itimes'); ylabel('Suppression (dB)');
            ylim([-30 0]);
        end
        
    end % txIndex
end % expType

% Stop transmitting and do a dummy read on both nodes
txtd = zeros(nFFT, sdrTx.nch);
sdrTx.send(txtd);
sdrRx.send(txtd);
sdrTx.recv(nread,nskip,ntimes);
sdrRx.recv(nread,nskip,ntimes);

clear ans cols expType fd fdMod itimes l m magIm magImAlpha;
clear magRe magReAlpha nFFT nread nskip ntimes rxtd sbs sbssAlpha scIndex;
clear td txfd txIndex txtd txtdMod refRxIndex nvhypo ivhypo pos sbAccum;
clear sbsStore vhypo vhypos;