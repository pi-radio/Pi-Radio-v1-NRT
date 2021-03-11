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
scIndex = 400;   % txIndex transmits at SC = txIndex*scMultiple

% Create nch tones (one from each channel)
txfd = zeros(nFFT, 1);
txtd = zeros(nFFT, 1); % Carries just a single tone on one channel
txtdMod = zeros(nFFT, sdrTx.nch);

txfd(nFFT/2 + 1 + scIndex) = 1+0i;
txtd = ifft(fftshift(txfd));    
m = max(abs(txtd));
txtd = txtd/m*15000;
figure(4); clf;
cols = 'yrgb';

sbssAlpha   = zeros(sdrTx.nch, ntimes);     % sideband suppressions, as a function of alpha
magReAlpha  = zeros(sdrTx.nch, ntimes);     % magnitude of the RX waveforms, when only Re is being transmitted
magImAlpha  = zeros(sdrTx.nch, ntimes);     % magnitude of the RX waveforms, when only Im is being transmitted

% expType = 1: Transmit complex. Measure the sideband suppression
% expType = 2: Transmit only the real. Measure RX power
% expType = 3: Transmit only the imag. Measure RX power
% pre-compensate the TX waveform based on the measured alpha
% exptype = 4: Transmit only the real. Measure RX power
% exptype = 5: Transmit only the imag. Measure RX power
% Verify that the residual alpha is close to 0.
% expType = 6: Transmit complex. Measure the sideband suppression.
for expType = 1:6
    
    for txIndex=1:sdrTx.nch
        txtdMod = zeros(nFFT, sdrTx.nch);
        
        if (expType == 1)
            txtdMod(:,txIndex) = txtd;
        elseif (expType == 2)
            txtdMod(:,txIndex) = real(txtd);
        elseif (expType == 3)
            txtdMod(:,txIndex) = j*imag(txtd);
        elseif (expType == 4)
            % Apply the alpha Cal. Nothing to do here, since the alpha
            % correction is applied on the imaginary part
            txtdMod(:,txIndex) = real(txtd);
        elseif (expType == 5)
            % Apply the alpha Cal by scaling the imaginary part
            txtdMod(:,txIndex) = sdrTx.calTxIQa(txIndex) * j * imag(txtd);            
        elseif (expType == 6)
            % Apply the alpha Cal
            txtdMod(:,txIndex) = real(txtd) + sdrTx.calTxIQa(txIndex) * j * imag(txtd);
        end

        sdrTx.send(txtdMod);
        rxtd = sdrRx.recv(nread,nskip,ntimes);
        rxtd = sdrRx.applyCalRxIQ(rxtd);
        figure(4);
        refRxIndex = 2;
        for itimes = 1:ntimes
      
            if (expType == 1) || (expType == 6)
                td = rxtd(:, itimes, refRxIndex); % Use refRxIndex as the reference
                fd = mag2db(abs(fftshift(fft(td))));
                % "sbs": sideband suppression (unwanted - wanted)
                sbs = fd(nFFT/2 + 1 - scIndex) - fd(nFFT/2 + 1 + scIndex);
                sbssAlpha(txIndex, itimes) = sbs;
            elseif (expType == 2) || (expType == 4)
                td = rxtd(:, itimes, refRxIndex); % Use rxIndex refRxIndex as the reference
                fd = fftshift(fft(td));
                fdMod = zeros(nFFT, 1);
                fdMod(nFFT/2 + 1 + scIndex) = fd(nFFT/2 + 1 + scIndex);
                fdMod(nFFT/2 + 1 - scIndex) = fd(nFFT/2 + 1 - scIndex);
                fdMod = fftshift(fdMod);
                td = ifft(fdMod);
                magRe = rms(abs(td));
                magReAlpha(txIndex, itimes) = magRe;
            elseif (expType == 3) || (expType == 5)
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
        
        % Plot stuff here
        if (expType == 1)
            subplot(4,1,1);
            plot(sbssAlpha(txIndex,:), cols(txIndex));
            title('Before TX-side IQ Alpha Cal');
            xlabel('itimes'); ylabel('Sideband Suppression (dB)');
            hold on; grid on; ylim([-50 0]);
        elseif (expType == 2)
            % Nothing to do here
        elseif (expType == 3)
            l = magReAlpha(txIndex, :) ./ magImAlpha(txIndex, :);
            subplot(4,1,2);
            plot(l, cols(txIndex));
            title('Before TX-side IQ Alpha Cal');
            xlabel('itimes'); ylabel('Measured Alpha');
            hold on; grid on; ylim([0 2]);
            sdrTx.calTxIQa(txIndex) = mean(l);
        elseif (expType == 4)
            % Nothing to do here
        elseif (expType == 5)
            l = magReAlpha(txIndex, :) ./ magImAlpha(txIndex, :);
            subplot(4,1,3);
            plot(l, cols(txIndex));
            title('After TX-side IQ Alpha Cal');
            xlabel('itimes'); ylabel('Measured Alpha');
            hold on; grid on; ylim([0 2]);
        elseif (expType == 6)
            subplot(4,1,4);
            plot(sbssAlpha(txIndex,:), cols(txIndex));
            title('After TX-side IQ Alpha Cal');
            xlabel('itimes'); ylabel('Sideband Suppression (dB)');
            hold on; grid on; ylim([-50 0]);
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
clear td txfd txIndex txtd txtdMod refRxIndex;