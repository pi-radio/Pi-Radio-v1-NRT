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
    fprintf('Error. Consiguration not supported');
end


% Create a single tone at subcarrier +400 and transmit it from one channel
% on sdrTx
txfd = zeros(nFFT, 1);
txtd = zeros(nFFT, sdrTx.nch);
txfd(nFFT/2 + 1 + scIndex) = 1+0i;
txtd(:,1) = ifft(fftshift(txfd));
m = max(abs(txtd(:,1)));
txtd = txtd/m*15000;
sdrTx.send(txtd);

% Receive on sdrRx
rxtd = sdrRx.recv(nread,nskip,ntimes);
nahypo = 51;
nvhypo = 101;
ahypos = linspace(0,2,nahypo);
vhypos = linspace(-1,1,nvhypo);
sbsStore = zeros(sdrRx.nch, ntimes, nahypo, nvhypo); % Used only for debug
sbsLog = zeros(sdrRx.nch, ntimes); % Stores the SBS to compare before and after calibration

for expType = 1:2
    expType
    cumulativeSBS = zeros(sdrRx.nch, nahypo, nvhypo);
    for rxIndex = 1:sdrRx.nch
        rxIndex
        for itimes=1:ntimes
            for iahypo = 1:nahypo
                for ivhypo = 1:nvhypo
                    
                    if (expType == 2) && (iahypo ~= (int16(nahypo/2))) && (ivhypo ~= int16(nvhypo/2))
                        continue;
                    end
                    td = rxtd(:,itimes,rxIndex);
                    reOld = real(td);
                    imOld = imag(td);
                    a = ahypos(iahypo);
                    v = vhypos(ivhypo);
                    
                    if (expType == 2)
                        a = a * sdrRx.calRxIQa(rxIndex);
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
                    sbsStore(rxIndex, itimes, iahypo, ivhypo) = mag2db(sbs); % Used only for debug
                    cumulativeSBS(rxIndex, iahypo, ivhypo)  = cumulativeSBS(rxIndex, iahypo, ivhypo) + sbs;
                    
                    if (iahypo == (int16(nahypo/2))) && (ivhypo == int16(nvhypo/2))
                        sbsLog(rxIndex, itimes) = mag2db(sbs);
                    end
                    
                end % ivhypo
            end % iahypo
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
            m = cumulativeSBS(rxIndex,:,:);
            m = reshape(m, nahypo, nvhypo);
            m = mag2db(m);
            [x,y] = meshgrid(vhypos, ahypos);
            surf(x, y, m); view(2); shading interp;
            xlabel('V Hypotheses'); ylabel('A Hypotheses');
                                    
            % Find the Cal factors and save it to the sdr
            minimum = min(min(m));
            [aMinIndex,vMinIndex] = find(m==minimum);
            sdrRx.calRxIQa(rxIndex) = ahypos(aMinIndex);
            sdrRx.calRxIQv(rxIndex) = vhypos(vMinIndex);
            s = sprintf('V: %2.2f, Alpha: %2.2f', vhypos(vMinIndex), ahypos(aMinIndex));
            title(s);
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

% % Used only for debug
% figure(1); clf;
% for rxIndex = 1:sdrRx.nch
%     subplot(2,2,rxIndex);
%     for itimes=1:ntimes
%         m = sbsStore(rxIndex,itimes,:,:);
%         m = reshape(m, nahypo, nvhypo);
%         surf(m); hold on;
%         view([0,270]); colorbar;
%         grid on; shading interp;
%         xlabel('V Hypotheses');
%         ylabel('Alpha Hypotheses');
%         colorbar;
%     end
% end


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
clear txtd v vhypos vMinIndex x y s;
