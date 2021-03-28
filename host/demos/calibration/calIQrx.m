% Calibrate the IQ imbalances on sdrRx, which has a center frequency at 58
% GHz. The reference transmitter is sdrTx, which has a center frequency of
% 56.464 GHz. Node sdrTx generates a tone at sc=400, which corresponds to
% 56.464 + (400*1.92) = 57.232 GHz. This tone is received by sdrRx on
% subcarrier -400, since 58000 - (400*1.92) = 57.232 GHz.

sdrRx.lo.configure('../../config/lmx_registers_58ghz.txt');
sdrTx.lo.configure('../../config/lmx_registers_58ghz.txt');

% Configure the RX number of samples, etc
nFFT = 1024;    % num of FFT points
nread = nFFT;   % Number of samples to read
nskip = nFFT*1;  % Number of samples to skip
ntimes = 100;    % Number of batches to receive
scIndex = 400;  % Transmit at -scIndex, receive at +scIndex

% The offset LO will differ based on which subcarrier we are going to use,
% and what the FFT size is. Below are a few examples that you can play
% around with.
if (nFFT == 1024) && (scIndex == 400)
    sdrTx.lo.configure('../../config/lmx_registers_59.536ghz.txt');
elseif (nFFT == 512) && (scIndex == 200)
    sdrTx.lo.configure('../../config/lmx_registers_59.536ghz.txt');
else
    fprintf('Error. Configuration not supported');
end


% Create a single tone at subcarrier +400 and transmit it from one channel
% on sdrTx at a time.
sumRe = zeros(sdrTx.nch, sdrRx.nch);
sumIm = zeros(sdrTx.nch, sdrRx.nch);
for txIndex=1:sdrTx.nch
    txfd = zeros(nFFT, 1);
    txtd = zeros(nFFT, sdrTx.nch);
    txfd(nFFT/2 + 1 - scIndex) = 1+0i;
    txtd(:,txIndex) = ifft(fftshift(txfd));
    m = max(abs(txtd(:,txIndex)));
    txtd = txtd/m*20000;
    sdrTx.send(txtd);
    pause(0.1);

    % Receive on sdrRx
    rxtd = sdrRx.recv(nread,nskip,ntimes);
    pause(0.5);
    nvhypo = 101;
    vhypos = linspace(-1,1,nvhypo);

    for rxIndex=1:sdrRx.nch
        for itimes=1:ntimes
            td = rxtd(:,itimes,rxIndex);
            fd = fftshift(fft(td));
            fdMod = zeros(1, nFFT);
            fdMod(nFFT/2 + 1 - scIndex) = fd(nFFT/2 + 1 - scIndex);
            fdMod(nFFT/2 + 1 + scIndex) = fd(nFFT/2 + 1 + scIndex);
            fdMod = fftshift(fdMod);
            td = ifft(fdMod);
            sumRe(txIndex, rxIndex) = sumRe(txIndex, rxIndex) + rms(real(td));
            sumIm(txIndex, rxIndex) = sumIm(txIndex, rxIndex) + rms(imag(td));
        end % itimes
    end %rxIndex
end % txIndex

% Calculate the Alphas
for rxIndex = 1:sdrRx.nch
    a = sum(sumRe(:,rxIndex)) / sum(sumIm(:,rxIndex));
    sdrRx.calRxIQa(rxIndex) = a;
end

sbsLog   = zeros(sdrTx.nch, sdrRx.nch, ntimes); % Stores the SBS to compare before and after calibration

% expType = 1: Plot the SBS, without any corrections (red)
% expType = 2: Apply alpha. Plot the SBS. Search for best "v" (blue)
% expType = 3: Apply alpha and v. Plot the SBS.

figure(3); clf;
refTxIndex = zeros(1, sdrRx.nch);
for expType = 1:3
    cumulativeSBS = zeros(sdrTx.nch, sdrRx.nch, nvhypo);
    
    for txIndex = 1:sdrTx.nch
        
        txfd = zeros(nFFT, 1);
        txtd = zeros(nFFT, sdrTx.nch);
        txfd(nFFT/2 + 1 - scIndex) = 1+0i;
        txtd(:,txIndex) = ifft(fftshift(txfd));
        m = max(abs(txtd(:,txIndex)));
        txtd = txtd/m*10000;
        sdrTx.send(txtd);
        pause(0.05);
        rxtd = sdrRx.recv(nread,nskip,ntimes);
        pause(0.05);

        for rxIndex = 1:sdrRx.nch
            for itimes=1:ntimes
                for ivhypo = 1:nvhypo

                    if (expType ~= 2) && (ivhypo ~= int16(nvhypo/2))
                        continue;
                    end
                    
                    td = rxtd(:,itimes,rxIndex);
                    reOld = real(td);
                    imOld = imag(td);
                    v = vhypos(ivhypo);
                    
                    if (expType == 1)
                        a = 1;
                    else
                        a = sdrRx.calRxIQa(rxIndex);
                    end
                    
                    if (expType == 3)
                        v = sdrRx.calRxIQv(rxIndex);
                    end

                    re = (1/a)*reOld;
                    im = reOld*(-1*tan(v)/a) + imOld*(1/cos(v));
                    tdMod = re + 1j*im;
                    fd = fftshift(fft(tdMod));
                    % "sbs" stands for sideband suppression. This is the
                    % undesired sideband power divided by that of the desired
                    % sideband
                    sbs = fd(nFFT/2 + 1 - scIndex) / fd(nFFT/2 + 1 + scIndex);
                    sbs = abs(sbs);
                    cumulativeSBS(txIndex, rxIndex, ivhypo)  = cumulativeSBS(txIndex, rxIndex, ivhypo) + sbs;
                    if (ivhypo == int16(nvhypo/2))
                        sbsLog(txIndex, rxIndex, itimes) = sbs;
                    end

                end % ivhypo            
            end % itimes
        end % rxIndex
    end % txIndex
    
    figure(3);
    cols = 'rbg';
    for rxIndex = 1:sdrRx.nch
        
        if (expType == 1)
            bestSBS = 0;
            % Find the TX with the worst LSB/USB ratio. This is
            % refTxIndex(rxIndex)
            for txIndex = 1:sdrTx.nch
                a = sbsLog(txIndex, rxIndex, :);
                a = reshape(a, 1, []);
                a = max(a);
                if (a > bestSBS)
                    bestSBS = a;
                    refTxIndex(rxIndex) = txIndex;
                end
            end
        end

        % Plot the SBS as a function of itimes
        subplot(2,4,rxIndex);
        l = sbsLog(refTxIndex(rxIndex), rxIndex, :);
        l = reshape(l, 1, []);
        plot(mag2db(l), cols(expType)); hold on;
        title('RX-side IQ: Sideband Supp');
        xlabel('itimes'); ylabel('Suppression (dB)');
        ylim([-40 0]); grid on; grid minor;
    end % rxIndex
          
    if (expType == 2)
        for rxIndex = 1:sdrRx.nch            
            subplot(2,4,rxIndex+4);
            m = cumulativeSBS(refTxIndex(rxIndex), rxIndex,:);
            m = reshape(m, 1, []);
            m = m / min(m);
            m = mag2db(m);
            [~, pos] = min(m);
            sdrRx.calRxIQv(rxIndex) = vhypos(pos);
            plot(vhypos, m); grid on;
            xlabel('V Hypotheses'); ylabel('Sideband Suppression');
        end % rxIndex    
    end % if expType is 1, 2, or 3 (plotting and saving cal factors)
    
end % for expType

% Stop transmitting and do a dummy read on both nodes
txtd = zeros(nFFT, sdrTx.nch);
sdrTx.send(txtd);
sdrRx.send(txtd);
sdrTx.recv(nread,nskip,ntimes);
sdrRx.recv(nread,nskip,ntimes);

% Clear the workspace variables, and make sure both nodes revert to 58 GHz
sdrTx.lo.configure('../../config/lmx_registers_59ghz.txt');
sdrRx.lo.configure('../../config/lmx_registers_59ghz.txt');

clear a ahypos aMinIndex ans cumulativeSBS expType fd iahypo im imOld;
clear itimes ivhypo m minimum nahypo nFFT nread nskip ntimes nvhypo;
clear re reOld rxIndex rxtd sbs sbsLog sbsStore scIndex td tdMod txfd;
clear txtd v vhypos vMinIndex x y s refTxIndex;
clear cumulativeUSB  cumulativeLSB sumRe sumIm;
clear bestSBS l pos txIndex;