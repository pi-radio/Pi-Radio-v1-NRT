% This script calibrates the TX-side timing and phase offsets. The TX under
% calibration is sdrTx, and the reference RX is sdrRx.


% Configure the RX number of samples, etc
nFFT = 1024;
nread = nFFT; % read ADC data for 256 cc (4 samples per cc)
nskip = 768*4;   % skip ADC data for this many cc
ntimes = 20;    % Number of batches to receive
% Generate the TX waveform
scMin = -450;
scMax = 450;
niter =  10;
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
nto = 21;

% Used for debug
ar = zeros(niter, ntimes, nto);
figure(3); clf;

for expType=1:3
    maxPos = zeros(sdrTx.nch, niter, ntimes);
    maxVal = zeros(sdrTx.nch, niter, ntimes);
    intPos = zeros(sdrTx.nch, niter, ntimes);
    pk     = zeros(sdrTx.nch, niter, ntimes);
    
    for iter=1:niter
        fprintf('\n');
        txfd = zeros(nFFT, sdrTx.nch);
        txtd = zeros(nFFT, sdrTx.nch);
        
        m = 0;
        for txIndex=1:sdrTx.nch
            for scIndex = scMin:scMax
                if scIndex ~= 0
                    %txfd(nFFT/2 + 1 + scIndex, txIndex) = sdrTx.refConstellation(nFFT/2 + 1 + scIndex, txIndex);
                    txfd(nFFT/2 + 1 + scIndex, txIndex) = constellation(randi(4));
                end
            end % scIndex
            txfd(:,txIndex) = fftshift(txfd(:,txIndex));
            txtd(:,txIndex) = ifft(txfd(:,txIndex));
            
            m = max( max(abs(txtd(:,txIndex))), m);
            
            if (expType == 2)
                txtd(:,txIndex) = fracDelay(txtd(:,txIndex), sdrTx.calTxDelay(txIndex), nFFT);
            elseif (expType == 3)
                txtd(:,txIndex) = exp(1j*sdrTx.calTxPhase(txIndex)) * fracDelay(txtd(:,txIndex), sdrTx.calTxDelay(txIndex), nFFT);
            end
        end % txIndex
        
        % Scale and send the signal from sdrTx
        txtd = txtd/m*15000;
        sdrTx.send(txtd);
        
        % Receive the signal from sdrRx
        rxtd = sdrRx.recv(nread,nskip,ntimes);
        size(rxtd);
        
        for txIndex=1:sdrTx.nch
            tos = linspace(-0.5, 0.5, nto);
            for ito = 1:nto
                to = tos(ito);
                fprintf('.');
                for itimes=1:ntimes
                    
                    if (txIndex == 1)
                        rxtdShifted = fracDelay(rxtd(:,itimes,1), to, nFFT);
                    else
                        rxtdShifted = fracDelay(rxtd(:,itimes,1), to + maxPos(1, iter, itimes), nFFT);
                    end
                    
                    rxfd = fft(rxtdShifted);
                    corrfd = zeros(nFFT, sdrTx.nch);
                    corrtd = zeros(nFFT, sdrTx.nch);
                    
                    corrfd(:,txIndex) = txfd(:,txIndex) .* conj(rxfd);
                    corrtd(:,txIndex) = ifft(corrfd(:,txIndex));
                    
                    [~, pos] = max(abs(corrtd(:,txIndex)));
                    val = corrtd(pos, txIndex);
                    if abs(val) > abs(maxVal(txIndex, iter, itimes))
                        % We have bound a "better" timing offset
                        maxVal(txIndex, iter, itimes) = val;
                        maxPos(txIndex, iter, itimes) = tos(ito);
                        intPos(txIndex, iter, itimes) = pos;
                        
                        % Measure the phase at the "best" to
                        pk(txIndex, iter, itimes) = val;
                        
                    end % if abs(val) > ...
                end % itimes
            end % ito
        end % txIndex
    end % iter
    
    
    % Calculate the fractional and integer timing offsets
    cols = 'yrgb'; % Colors for the plots
    maxPos(1,:,:) = maxPos(1,:,:) - maxPos(1,:,:); % For txIndex=1, everything should be 0
    figure(3);
    for txIndex=1:sdrTx.nch
        
        % Fractional
        l = maxPos(txIndex, :, :);
        l = reshape(l, 1, []);
        if (expType == 1)
            figure(3);
            subplot(5,1,1);
            plot(l, cols(txIndex));
            title('Pre-Cal: Fractional Timing Offsets');
            xlabel('Iteration (Unsorted)');
            hold on;
            ylim([-0.5 0.5]);
            c = sum(exp(1j*2*pi*l));
            c = angle(c);
            c = c /(2*pi);
            sdrTx.calTxDelay(txIndex) = c;
        elseif (expType == 2)
            figure(3);
            subplot(5,1,2);
            plot(l, cols(txIndex));
            title('Post-Cal: Fractional Timing Offsets')
            xlabel('Iteration (Unsorted)');
            hold on;
            ylim([-0.5 0.5]);
        end
        
        % Integer
        l = intPos(txIndex, :, :) - intPos(1, :, :);
        l = reshape(l, 1, []);
        l = sort(l);
        if (expType == 2)
            figure(3);
            subplot(5,1,3);
            plot(l, cols(txIndex));
            title('Post-Cal: Integer Timing Offsets');
            hold on;
            ylim([-2 2]);
            xlabel('Iteration (sorted). Consider only the middle (median) iteration. Should be 0.');
        end
        
        % Phase
        lRef = pk(1, :, :);
        lRef = reshape(lRef, 1, []);
        lTx = pk(txIndex, :, :);
        lTx = reshape(lTx, 1, []);
        
        if (expType == 2)
            subplot(5,1,4);
            ph = wrapToPi(angle(lTx) - angle(lRef));
            plot(ph, cols(txIndex)); hold on;
            ylim([-pi pi]);
            title('Pre-Cal: LO Phase Offsets');
            l = angle(sum(exp(1j*ph)));
            sdrTx.calTxPhase(txIndex) = l;
        elseif (expType == 3)
            subplot(5,1,5);
            ph = wrapToPi(angle(lTx) - angle(lRef));
            plot(ph, cols(txIndex)); hold on;
            ylim([-pi pi]);
            title('Post-Cal: LO Phase Offsets');
        end
        
    end % txIndex
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
clear intPeakPos intpos c lRef lTx pk ar intPos l ph;