% Calibrate the IQ imbalances on sdrRx, which has a center frequency at 58
% GHz. The reference transmitter is sdrTx, which has a center frequency of
% 56.464 GHz. Node sdrTx generates a tone at sc=400, which corresponds to
% 56.464 + (400*1.92) = 57.232 GHz. This tone is received by sdrRx on
% subcarrier -400, since 58000 - (400*1.92) = 57.232 GHz.

% sdrTx.lo.configure('../../config/lmx_registers_56.464ghz.txt');
% sdrRx.lo.configure('../../config/lmx_registers_58ghz.txt');

% Configure the RX number of samples, etc
nFFT = 1024;    % num of FFT points
nread = nFFT;   % Number of samples to read
nskip = nFFT;  % Number of samples to skip
ntimes = 200;    % Number of batches to receive
scIndex = 400;  % Transmit at +400, receive at -400

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
for expType = 1:2
    for rxIndex=1:sdrRx.nch
        for itimes=1:ntimes       
            td = rxtd(:,itimes,rxIndex);
            re = rms(real(td));
            im = rms(imag(td));
            if (expType == 2)
                im = im*sdrRx.calRxIQa(rxIndex);
            end
            alphas(rxIndex,itimes) = re/im;
        end

        if (expType == 1)
            subplot(4,1,1);
            plot(alphas(rxIndex,:), cols(rxIndex));
            a = mean(alphas(rxIndex, :));
            sdrRx.calRxIQa(rxIndex) = a;
            hold on;
            ylim([0.5 1.5]);
            title('Before RX-side IQ Alpha Cal');
        elseif (expType == 2)
            subplot(4,1,2);
            plot(alphas(rxIndex,:), cols(rxIndex));
            hold on;
            ylim([0.5 1.5]);
            title('After RX-side IQ Alpha Cal');
        end
    end % rxIndex
end % expType. Calibrating the Alpha values

% Measure and calibrate the quadrateure phase (v) values
nvhypo = 101;
vhypos = linspace(-1, 1, nvhypo); % In radian

% Store the underired (i.e, upper) sideband values in here
usbs = zeros(sdrRx.nch, ntimes, nvhypo);

% Store the best "v" value here
bestvs = zeros(sdrRx.nch, ntimes);

for expType = 1:1
    for rxIndex=1:sdrRx.nch
        for itimes=1:ntimes
            td = rxtd(:, itimes, rxIndex);
            for ivhypo=1:nvhypo
                vhypo = vhypos(ivhypo);
                re = real(td);
                im = imag(td);
                im = im*sdrRx.calRxIQa(rxIndex); % Apply the alpha correction
                im = re*((-1)*tan(vhypo)) + im/(cos(vhypo));
                tdMod = re + 1j*im; % Modified time-domain waveform after applying the vhypo
                fd = fftshift(fft(tdMod));
                usb = fd(nFFT/2 + 1 + scIndex); % This is the upper (undesired) sideband
                usbs(rxIndex, itimes, ivhypo) = usb;
            end % ivhypo
            
            l = usbs(rxIndex, itimes, :);
            l = reshape(l, 1, []);
            [~, pos] = min(abs(l));
            bestvs(rxIndex, itimes) = vhypos(pos);
            
        end % ntimes
        
        subplot(4,1,3);
        plot(
    end % rxIndex
end % expType. Calibrating the quadrature phase (v) values





% % Clear the workspace variables, and make sure both nodes revert to 58 GHz
% sdrTx.lo.configure('../../config/lmx_registers_58ghz.txt');
% sdrRx.lo.configure('../../config/lmx_registers_58ghz.txt');
