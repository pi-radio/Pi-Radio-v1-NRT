% This script calibrates the RX-side timing and phase offsets. The RX under
% calibration is sdrRx, and the reference TX is sdrTx.

% Configure the RX number of samples, etc
nFFT = 1024;    % num of FFT points
nread = nFFT;   % Number of samples to read
nskip = 768*4;  % Number of samples to skip
ntimes = 30;    % Number of batches to receive

% Generate the TX waveform
scMin = -450;
scMax = 450;
niter =  3;
constellation = [1+1j 1-1j -1+1j -1-1j];

% expType = 1: Make initial measurements of the fractional timing offset
%
% expType = 2: Correct the fractional offsets and see if the residual
% errors are close to 0. Also measure the integer timing offsets. We do not
% expect integer timing offsets with ~2GHz sampling rate. So we just
% measure the integer timing offsets, make sure it's zero, but do not
% present code to correct it (this would be extremely simple to do). Also,
% measure the per-channel phase offset.
%
% expType = 3: Also correct the phase offsets, and make sure that the
% errors are now close to 0.

% How many unique fractional timing offsets are we going to search through?
nto = 31;
figure(3); clf;

for expType = 1:3
    
    maxPos = zeros(sdrRx.nch, niter, ntimes);
    maxVal = zeros(sdrRx.nch, niter, ntimes);
    intPos = zeros(sdrRx.nch, niter, ntimes);
    pk     = zeros(sdrRx.nch, niter, ntimes);
        
    for iter = 1:niter
        fprintf('\n');
        txfd = zeros(nFFT, 1);
        txtd = zeros(nFFT, sdrTx.nch);
        m = 0;

        for scIndex = scMin:scMax
            if scIndex ~= 0
                %txfd(nFFT/2 + 1 + scIndex, 1) = sdrTx.refConstellation(nFFT/2 + 1 + scIndex, 1);
                txfd(nFFT/2 + 1 + scIndex, 1) = constellation(randi(4));
            end
        end % scIndex
        txfd(:,1) = fftshift(txfd(:,1));
        txtd(:,1) = ifft(txfd(:,1));

        m = max(abs(txtd(:,1)));
       
        % Scale and send the signal from sdrTx
        txtd = txtd/m*15000;
        sdrTx.send(txtd);
        
        % Receive the signal from sdrRx
        rxtd = sdrRx.recv(nread,nskip,ntimes);
        size(rxtd);
        
        for rxIndex=1:sdrRx.nch
            tos = linspace(-0.5, 0.5, nto);
            for ito = 1:nto
                to = tos(ito);
                fprintf('.');
                for itimes=1:ntimes
                    if (expType == 1)
                        rxtdShifted = fracDelay(rxtd(:,itimes,rxIndex), to, nFFT);
                    elseif (expType == 2)
                        rxtdShifted = fracDelay(rxtd(:,itimes,rxIndex), to + sdrRx.calRxDelay(rxIndex), nFFT);
                    elseif (expType == 3)
                        rxtdShifted = fracDelay(rxtd(:,itimes,rxIndex), to + sdrRx.calRxDelay(rxIndex), nFFT);
                        rxtdShifted = rxtdShifted * exp(j*sdrRx.calRxPhase(rxIndex));
                    end
                    rxfd = fft(rxtdShifted);
                    corrfd = txfd .* conj(rxfd);
                    corrtd = ifft(corrfd);
                    
                    [~, pos] = max(abs(corrtd));
                    val = corrtd(pos);
                    if abs(val) > abs(maxVal(rxIndex, iter, itimes))
                        % We have bound a "better" timing offset
                        maxVal(rxIndex, iter, itimes) = val;
                        maxPos(rxIndex, iter, itimes) = tos(ito);
                        intPos(rxIndex, iter, itimes) = pos;
                        
                        % Measure the phase at the "best" to
                        pk(rxIndex, iter, itimes) = val;
                        
                    end % if abs(val) > ...
                end % itimes
            end % ito
        end % rxIndex        
    end % iter
    
    % Calculate the fractional and integer timing offsets
    cols = 'mrgb'; % Colors for the plots
    %maxPos(1,:,:) = maxPos(1,:,:) - maxPos(1,:,:); % For rxIndex=1, everything should be 0
    figure(3);
    for rxIndex=1:sdrRx.nch
        
        % Fractional
        l = maxPos(rxIndex, :, :) - maxPos(1,:,:);
        l = reshape(l, 1, []);
        l = (wrapToPi(l*2*pi))/(2*pi);
        if (expType == 1)
            figure(3);
            subplot(5,1,1);
            plot(l, cols(rxIndex));
            title('Pre-Cal: Fractional Timing Offsets');
            xlabel('Iteration (Unsorted)');
            hold on;
            ylim([-0.5 0.5]);
            c = sum(exp(1j*2*pi*l));
            c = angle(c);
            c = c /(2*pi);
            sdrRx.calRxDelay(rxIndex) = c;
        elseif (expType == 2)
            figure(3);
            subplot(5,1,2);
            plot(l, cols(rxIndex));
            title('Post-Cal: Fractional Timing Offsets')
            xlabel('Iteration (Unsorted)');
            hold on;
            ylim([-0.5 0.5]);
        end
        
        % Integer
        l = intPos(rxIndex, :, :) - intPos(1, :, :);
        l = reshape(l, 1, []);
        l = sort(l);
        if (expType == 2)
            figure(3);
            subplot(5,1,3);
            plot(l, cols(rxIndex));
            title('Post-Cal: Integer Timing Offsets');
            hold on;
            %ylim([-2 2]);
            xlabel('Iteration (sorted). Consider only the middle (median) iteration. Should be 0.');
        end
        
        % Phase
        lRef = pk(1, :, :);
        lRef = reshape(lRef, 1, []);
        lRx = pk(rxIndex, :, :);
        lRx = reshape(lRx, 1, []);
        
        if (expType == 2)
            subplot(5,1,4);
            ph = wrapToPi(angle(lRx) - angle(lRef));
            plot(ph, cols(rxIndex)); hold on;
            ylim([-pi pi]);
            title('Pre-Cal: LO Phase Offsets');
            l = angle(sum(exp(1j*ph)));
            sdrRx.calRxPhase(rxIndex) = l;
        elseif (expType == 3)
            subplot(5,1,5);
            ph = wrapToPi(angle(lRx) - angle(lRef));
            plot(ph, cols(rxIndex)); hold on;
            ylim([-pi pi]);
            title('Post-Cal: LO Phase Offsets');
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
clear to tos val cols diffMatrix resTimingErrors toff vec;
clear intPeakPos intpos c lRef lTx pk ar intPos l ph lRx rxIndex;