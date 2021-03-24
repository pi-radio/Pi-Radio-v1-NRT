% This script calibrates the RX-side ADC timing offsets. The RX under
% calibration is sdrRx, and the reference TX is sdrTx.

% Configure the RX number of samples, etc
nFFT = 1024;    % num of FFT points
nread = nFFT;   % Number of samples to read
nskip = nFFT*1;  % Number of samples to skip
ntimes = 30;    % Number of batches to receive

% Generate the TX waveform
scMin = -450;
scMax = 450;
niter =  5;
constellation = [1+1j 1-1j -1+1j -1-1j];

% expType = 1: Make initial measurements of the fractional timing offset
%
% expType = 2: Correct the fractional offsets and see if the residual
% errors are close to 0. Also measure the integer timing offsets.
%
% expType = 3: Correct the integer offsets, and make sure that the
% errors are now 0.

% How many unique fractional timing offsets are we going to search through?
nto = 31;
figure(3); clf;

pdpStore = zeros(sdrRx.nadc, 3, niter, nFFT);
sdrRx.calDelayADC = zeros(1, sdrRx.nadc);

for expType = 1:3
    
    maxPos = zeros(sdrRx.nadc, niter);
    maxVal = zeros(sdrRx.nadc, niter);
    intPos = zeros(sdrRx.nadc, niter);
        
    for iter = 1:niter
        fprintf('\n');
        txfd = zeros(nFFT, 1);
        
        for scIndex = scMin:scMax
            if scIndex ~= 0
                %txfd(nFFT/2 + 1 + scIndex, 1) = sdrTx.refConstellation(nFFT/2 + 1 + scIndex, 1);
                txfd(nFFT/2 + 1 + scIndex) = constellation(randi(4));
            end
        end % scIndex
        txfd = fftshift(txfd);
        txtd = ifft(txfd);
        txtd = real(txtd);
        txfd = fft(txtd);
        
        m = max(abs(txtd));
       
        % Scale and send the signal from sdrTx
        txtd = txtd/m*15000;
        txtdMod = zeros(nFFT, sdrTx.nch);
        txtdMod(:,1) = txtd;
        sdrTx.send(txtdMod);
        
        % Receive the signal from sdrRx
        rxtd = sdrRx.recvADC(nread,nskip,ntimes);
        size(rxtd);
                
        for iadc=1:sdrRx.nadc
            tos = linspace(-0.5, 0.5, nto);
            for ito = 1:nto
                to = tos(ito);
                fprintf('.');
                for itimes=1:ntimes
                    if (expType == 1)
                        rxtdShifted = fracDelay(rxtd(:,itimes,iadc), to, nFFT);
                    elseif ((expType == 2) || (expType == 3))
                        rxtdShifted = fracDelay(rxtd(:,itimes,iadc), to + sdrRx.calDelayADC(iadc), nFFT);
                    end
                    rxfd = fft(rxtdShifted);
                    corrfd = rxfd .* conj(txfd);
                    corrtd = ifft(corrfd);
                    
                    [~, pos] = max(abs(corrtd));
                    val = corrtd(pos);
                    if abs(val) > abs(maxVal(iadc, iter))
                        % We have bound a "better" timing offset
                        maxVal(iadc, iter) = abs(val);
                        maxPos(iadc, iter) = tos(ito);
                        intPos(iadc, iter) = pos;
                        
                        % Measure the phase at the "best" to
                        pdpStore(iadc, expType, iter, :) = corrtd;
                        
                    end % if abs(val) > ...
                end % itimes
            end % ito
        end % rxIndex        
    end % iter
    
    % Calculate the fractional and integer timing offsets
    cols = ['m-o'; 'm-*'; 'r-o'; 'r-*'; 'b-o'; 'g-o'; 'b-*'; 'g-*'; ];
    figure(3);
    for iadc=1:sdrRx.nadc
        
        % Fractional
        l = maxPos(iadc, :) - maxPos(1, :);
        l = reshape(l, 1, []);
        l = (wrapToPi(l*2*pi))/(2*pi);
        if (expType == 1)
            figure(3);
            subplot(6,1,1);
            plot(l, cols(iadc,:));
            title('Pre-Cal: Fractional Timing Offsets');
            xlabel('Iteration (Unsorted)');
            hold on;
            ylim([-0.5 0.5]);
            c = sum(exp(1j*2*pi*l));
            c = angle(c);
            c = c /(2*pi);
            sdrRx.calDelayADC(iadc) = (1)*c;
        elseif (expType == 2)
            figure(3);
            subplot(6,1,2);
            plot(l, cols(iadc));
            title('Post-Cal: Fractional Timing Offsets')
            xlabel('Iteration (Unsorted)');
            hold on;
            ylim([-0.5 0.5]);
        end
        
        % Integer
        l = intPos(iadc, :) - intPos(1, :);
        l = reshape(l, 1, []);
        l = sort(l);
        if (expType == 2)
            figure(3);
            subplot(6,4,8+iadc);
            plot(l, cols(iadc,:));
            title('Pre-Cal: Integer Timing Off.');
            hold on;
            ylim([-10 10]); grid on;
            medianIndex = int16(length(l) / 2);
            sdrRx.calDelayADC(iadc) = sdrRx.calDelayADC(iadc) + l(medianIndex);
        elseif (expType == 3)
            figure(3);
            subplot(6,4,16+iadc);
            plot(l, cols(iadc,:));
            title('Post-Cal: Integer Timing Off.');
            hold on;
            ylim([-10 10]); grid on;
        end
        
    end % rxIndex
end % expType



% Stop transmitting and do a dummy read on both nodes
txtd = zeros(nFFT, sdrTx.nch);
sdrTx.send(txtd);
sdrRx.send(txtd);
sdrTx.recv(nread,nskip,ntimes);
sdrRx.recv(nread,nskip,ntimes);

% Clear workspace variables
clear constellation expType iter maxPos maxVal nFFT niter rxtd scIndex;
clear scMin scMax txfd txIndex txtd m nread nskip nsamp ntimes;
clear ans corrfd corrtd diff iiter itimes ito nto pos rxfd rxtdShifted;
clear to tos val cols diffMatrix resTimingErrors toff vec medianIndex;
clear intPeakPos intpos c lRef lTx pk ar intPos l ph lRx rxIndex;
clear iadc txtdMod;