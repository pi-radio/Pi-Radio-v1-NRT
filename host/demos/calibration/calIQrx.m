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
scIndex = 400;  % Transmit at +scIndex, receive at -scIndex

% The offset LO will differ based on which subcarrier we are going to use.
if (scIndex == 300)
    sdrTx.lo.configure('../../config/lmx_registers_56.848ghz.txt');
elseif (scIndex == 400)
    sdrTx.lo.configure('../../config/lmx_registers_56.464ghz.txt');
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

% Measure and calibrate the Alpha values
alphas = zeros(sdrRx.nch, ntimes);
cols = 'yrgb';
figure(4); clf;

% Store the underired (i.e, upper) sideband values in here
sbssAlpha = zeros(sdrRx.nch, ntimes);

for expType = 1:2
    for rxIndex=1:sdrRx.nch
        for itimes=1:ntimes       
            td = rxtd(:,itimes,rxIndex);
            re = real(td);
            im = imag(td);            
            if (expType == 2)
                im = im*sdrRx.calRxIQa(rxIndex);
            end
            
            td = re + 1j*im;
            fd = fftshift(fft(td));
            % "sbs" stands for "side band suppression"
            sbs = fd(nFFT/2 + 1 + scIndex) / fd(nFFT/2 + 1 - scIndex);
            sbssAlpha(rxIndex, itimes) = mag2db(abs(sbs));
            
            re = rms(re);
            im = rms(im);
            
            alphas(rxIndex,itimes) = re/im;
        end % itimes

        if (expType == 1)
            % Plot the Alphas
            subplot(5,2,1);
            plot(alphas(rxIndex,:), cols(rxIndex));
            a = mean(alphas(rxIndex, :));
            sdrRx.calRxIQa(rxIndex) = a;
            hold on; ylim([0 2]);
            title('Before RX-side IQ Alpha Cal');
            ylabel('Alpha'); xlabel('itimes');grid on;
            % Plot the undesired sideband
            subplot(5,2,3);
            plot(sbssAlpha(rxIndex,:), cols(rxIndex));
            hold on; grid on;
            ylim([-50 0]);
            title('Before RX-side IQ Alpha Cal');
            ylabel('Sideband Suppression(dB)');
            xlabel('itimes');
        elseif (expType == 2)
            % Plot the Alphas
            subplot(5,2,2);
            plot(alphas(rxIndex,:), cols(rxIndex));
            hold on; ylim([0 2]);
            title('After RX-side IQ Alpha Cal');
            ylabel('Alpha'); xlabel('itimes'); grid on;
            % Plot the undesired sideband
            subplot(5,2,4);
            plot(sbssAlpha(rxIndex,:), cols(rxIndex));
            hold on; grid on;
            ylim([-50 0]);
            title('After RX-side IQ Alpha Cal');
            ylabel('Sideband Suppression(dB)');
            xlabel('itimes');
        end
    end % rxIndex
end % expType. Calibrating the Alpha values

% Measure and calibrate the quadrateure phase (v) values
nvhypo = 201;
vmax = 1; % go from -1 rad to +1 rad
vhypos = linspace(-vmax, vmax, nvhypo); % In radian

% Store the best "v" value here
bestvs = zeros(sdrRx.nch, ntimes);

% In iter=1, we get the baseline readings. In subsequent iterations, we
% nudge the values of "vee" in the right directions.

sdrRx.calRxIQv = zeros(1, sdrRx.nch);
% "sbssVee" stands for side band suppressions as a function of v
sbssVee = zeros(sdrRx.nch, ntimes, nvhypo);
bestsbs = zeros(sdrRx.nch, ntimes);

niter = 5;
for iter = 1:niter
    for rxIndex=1:sdrRx.nch
        for itimes=1:ntimes
            td = rxtd(:, itimes, rxIndex);
            
            % Apply the alpha correction
            re = real(td);
            im = imag(td);
            im = im*sdrRx.calRxIQa(rxIndex);
            td = re + 1j*im;
            
            % Apply the "v" correction from the previous iter
            v = sdrRx.calRxIQv(rxIndex);
            re = real(td);
            im = imag(td);
            im = re*((-1)*tan(v)) + im/(cos(v));
            td = re + 1j*im; % Modified time-domain waveform after applying the vhypo            
            
            for ivhypo=1:nvhypo
                vhypo = vhypos(ivhypo);
                re = real(td);
                im = imag(td);
                
                im = re*((-1)*tan(vhypo)) + im/(cos(vhypo));                
                
                tdMod = re + 1j*im; % Modified time-domain waveform after applying the vhypo
                fd = fftshift(fft(tdMod));
                % "sbs" stands for sideband suppression. This is the
                % undesired sideband power divided by that of the desired
                % sideband
                sbs = fd(nFFT/2 + 1 + scIndex) / fd(nFFT/2 + 1 - scIndex);
                sbssVee(rxIndex, itimes, ivhypo) = mag2db(abs(sbs));
            end % ivhypo
            
            l = sbssVee(rxIndex, itimes, :);
            l = reshape(l, 1, []);
            [val, pos] = min(l); % What gives us the best suppression?
            bestvs(rxIndex, itimes) = vhypos(pos);
            bestsbs(rxIndex, itimes) = val;
            
        end % ntimes

        % Apply the Cal
        sdrRx.calRxIQv(rxIndex) = sdrRx.calRxIQv(rxIndex) + mean(bestvs(rxIndex,:));

        % Plot out the required graphs
        if (iter == 1)
            subplot(5,2,5);
            plot(bestvs(rxIndex,:), cols(rxIndex));
            title('Before RX-side IQ Vee Cal');
            hold on;
            ylabel('Vee (radian)');
            xlabel('itimes');
            ylim([-vmax vmax]);
            grid on;
            
            subplot(5,2,7);
            mp = int16(nvhypo/2);
            l = sbssVee(rxIndex,:,mp);
            l = reshape(l, 1, []);
            plot(l, cols(rxIndex));
            hold on;
            ylabel('Sideband Suppression (dB)');
            xlabel('itimes');
            title('Before RX-side Vee Cal');
            grid on; grid minor;
            ylim([-50 0]);
            
            subplot(5,2,9)
            for itimes=1:ntimes
                l = sbssVee(rxIndex, itimes, :);
                l = reshape(l, 1, []);
                plot(vhypos, l, cols(rxIndex));
                hold on;
            end
            title('Before RX-side Vee Cal');
            xlabel('Vee Hypotheses');
            ylabel('Undesired sideband (dB)');
            grid on;
            %ylim([-50 0]);
            
        elseif (iter == niter)
            subplot(5,2,6);
            plot(bestvs(rxIndex,:), cols(rxIndex));
            title('After RX-side IQ Vee Cal');
            hold on;
            ylabel('Vee (radian)');
            xlabel('itimes');
            hold on;
            ylim([-vmax vmax]);
            grid on;
            
            subplot(5,2,8);
            l = sbssVee(rxIndex,:,mp);
            l = reshape(l, 1, []);
            plot(l, cols(rxIndex));
            hold on;
            ylabel('Sideband Suppression (dB)');
            xlabel('itimes');
            title('After RX-side Vee Cal');
            grid on; grid minor;
            ylim([-50 0]);
            
            subplot(5,2,10)
            for itimes=1:ntimes
                l = sbssVee(rxIndex, itimes, :);
                l = reshape(l, 1, []);
                plot(vhypos, l, cols(rxIndex));
                hold on;
            end
            title('After RX-side Vee Cal');
            xlabel('Vee Hypotheses');
            ylabel('Undesired sideband (dB)');
            grid on;
            %ylim([-50 0]);
        end        
    end % rxIndex
    mean(bestvs')
end % iter. Calibrating the quadrature phase (v) values

% Stop transmitting and do a dummy read on both nodes
txtd = zeros(nFFT, sdrTx.nch);
sdrTx.send(txtd);
sdrRx.send(txtd);
sdrTx.recv(nread,nskip,ntimes);
sdrRx.recv(nread,nskip,ntimes);

% Clear the workspace variables, and make sure both nodes revert to 58 GHz
sdrTx.lo.configure('../../config/lmx_registers_58ghz.txt');
sdrRx.lo.configure('../../config/lmx_registers_58ghz.txt');

clear a alphas ans bestvs cols expType fd im iter itimes ivhypo l m nFFT;
clear niter nread nskip ntimes vnhypo pos re rxIndex rxtd scIndex td tdMod;
clear txfd txtd usb usbsAlpha  vhypo vhypos bestsbs mp sbs sbssAlpha;
clear bestusbs nvhypo usbs v val sbssVee vmax;