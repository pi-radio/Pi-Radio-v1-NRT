% Calibrate the IQ imbalances on sdrRx, which has a center frequency at 58
% GHz. The reference transmitter is sdrTx, which has a center frequency of
% 56.464 GHz. Node sdrTx generates a tone at sc=400, which corresponds to
% 56.464 + (400*1.92) = 57.232 GHz. This tone is received by sdrRx on
% subcarrier -400, since 58000 - (400*1.92) = 57.232 GHz.

sdrRx.lo.configure('../../config/lmx_registers_58ghz.txt');

% Configure the RX number of samples, etc
nFFT = 1024;    % num of FFT points
nread = nFFT;   % Number of samples to read
nskip = nFFT*1;  % Number of samples to skip
ntimes = 100;    % Number of batches to receive
scIndex = 300;  % Transmit at +scIndex, receive at -scIndex

% The offset LO will differ based on which subcarrier we are going to use,
% and what the FFT size is. Below are a few examples that you can play
% around with.
if (nFFT == 1024) && (scIndex == 300)
    sdrTx.lo.configure('../../config/lmx_registers_56.848ghz.txt');
elseif (nFFT == 1024) && (scIndex == 400)
    sdrTx.lo.configure('../../config/lmx_registers_56.464ghz.txt');
elseif (nFFT == 512) && (scIndex == 200)
    sdrTx.lo.configure('../../config/lmx_registers_56.464ghz.txt');
else
    fprintf('Error. Configuration not supported');
end


% Create a single tone at subcarrier +400 and transmit it from one channel
% on sdrTx
refTxIndex = 2;
txfd = zeros(nFFT, 1);
txtd = zeros(nFFT, sdrTx.nch);
txfd(nFFT/2 + 1 + scIndex) = 1+0i;
txtd(:,refTxIndex) = ifft(fftshift(txfd));
m = max(abs(txtd(:,refTxIndex)));
txtd = txtd/m*15000;
sdrTx.send(txtd);
pause(0.1);

% Receive on sdrRx
rxtd = sdrRx.recv(nread,nskip,ntimes);
%rxtd = sdrRx.applyCalDelayADC(rxtd);
pause(0.1);
nvhypo = 51;
vhypos = linspace(-1,1,nvhypo);
sbsStore = zeros(sdrRx.nch, ntimes, nvhypo); % Used only for debug
sbsLog = zeros(sdrRx.nch, ntimes); % Stores the SBS to compare before and after calibration

% First, estimate Alpha
for rxIndex=1:sdrRx.nch
    sumRe = 0;
    sumIm = 0;
    for itimes=1:ntimes
        td = rxtd(:,itimes,rxIndex);
        sumRe = sumRe + rms(real(td));
        sumIm = sumIm + rms(imag(td));
    end % itimes
    sdrRx.calRxIQa(rxIndex) = sumRe / sumIm;
end %rxIndex

for expType = 1:2
    cumulativeUSB = zeros(sdrRx.nch, nvhypo);
    cumulativeLSB = zeros(sdrRx.nch, nvhypo);
    for rxIndex = 1:sdrRx.nch
        for itimes=1:ntimes
            for ivhypo = 1:nvhypo

                if (expType == 2) && (ivhypo ~= int16(nvhypo/2))
                    continue;
                end
                td = rxtd(:,itimes,rxIndex);
                reOld = real(td);
                imOld = imag(td);
                v = vhypos(ivhypo);
                a = sdrRx.calRxIQa(rxIndex);

                if (expType == 2)
                    v = v + sdrRx.calRxIQv(rxIndex);
                end

                re = (1/a)*reOld;
                im = reOld*(-1*tan(v)/a) + imOld*(1/cos(v));
                tdMod = re + 1j*im;
                fd = fftshift(fft(tdMod));
                % "sbs" stands for sideband suppression. This is the
                % undesired sideband power divided by that of the desired
                % sideband
                sbs = fd(nFFT/2 + 1 + scIndex) / fd(nFFT/2 + 1 - scIndex);
                sbs = abs(sbs);
                sbsStore(rxIndex, itimes, ivhypo) = mag2db(sbs); % Used only for debug
                cumulativeUSB(rxIndex, ivhypo)  = cumulativeUSB(rxIndex, ivhypo) + abs(fd(nFFT/2 + 1 + scIndex));
                cumulativeLSB(rxIndex, ivhypo)  = cumulativeLSB(rxIndex, ivhypo) + abs(fd(nFFT/2 + 1 - scIndex));

                if (ivhypo == int16(nvhypo/2))
                    sbsLog(rxIndex, itimes) = mag2db(sbs);
                end

            end % ivhypo            
        end % itimes
    end % rxIndex
    
    if (expType == 1)
        
        figure(3); clf;
        for rxIndex = 1:sdrRx.nch
            % Plot the uncalibrated SBS as a function of itimes
            subplot(3,4,rxIndex);
            plot(sbsLog(rxIndex,:));
            title('Pre-Cal RX-side IQ: Sideband Supp');
            xlabel('itimes'); ylabel('Suppression (dB)');
            ylim([-40 0]); grid on;
            
            subplot(3,4,rxIndex+4);
            m = cumulativeUSB(rxIndex,:) ./cumulativeLSB(rxIndex,:);
            m = mag2db(m);
            [~, pos] = min(m);
            sdrRx.calRxIQv(rxIndex) = vhypos(pos);
            plot(vhypos, m); grid on;
            xlabel('V Hypotheses'); ylabel('Sideband Suppression');
        end        
        
    elseif (expType == 2)
        for rxIndex = 1:sdrRx.nch
            % Plot the calibrated SBS as a function of itimes
            subplot(3,4,rxIndex+8);
            plot(sbsLog(rxIndex,:));
            title('Post-Cal RX-side IQ: Sideband Supp');
            xlabel('itimes'); ylabel('Suppression (dB)');
            ylim([-40 0]); grid on;
        end 
    end % if expType is 1 or 2 (plotting and saving cal factors)
    
end % for expType

% Stop transmitting and do a dummy read on both nodes
txtd = zeros(nFFT, sdrTx.nch);
sdrTx.send(txtd);
sdrRx.send(txtd);
sdrTx.recv(nread,nskip,ntimes);
sdrRx.recv(nread,nskip,ntimes);

% Clear the workspace variables, and make sure both nodes revert to 58 GHz
sdrTx.lo.configure('../../config/lmx_registers_58ghz.txt');
sdrRx.lo.configure('../../config/lmx_registers_58ghz.txt');

clear a ahypos aMinIndex ans cumulativeSBS expType fd iahypo im imOld;
clear itimes ivhypo m minimum nahypo nFFT nread nskip ntimes nvhypo;
clear re reOld rxIndex rxtd sbs sbsLog sbsStore scIndex td tdMod txfd;
clear txtd v vhypos vMinIndex x y s refTxIndex;
clear cumulativeUSB  cumulativeLSB sumRe sumIm;