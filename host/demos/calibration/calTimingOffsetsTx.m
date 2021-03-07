% This script calibrates the TX-side timing offsets. The TX under
% calibration is sdrA, and the reference receiver is sdrB.

% Set up the RF components on the sdrA as the TX under calibration. Note
% that we will use all 4 TX channels
sdrA.rffeTx.powerDown();
sdrA.rffeRx.powerDown();
sdrA.lo.configure('../../config/lmx_registers_58ghz.txt');
sdrA.rffeTx.configure(9, '../../config/hmc6300_registers.txt');

% Set up the RF components on sdrB as the Reference RX. Note that we will
% use only one RX channel
sdrB.rffeTx.powerDown();
sdrB.rffeRx.powerDown();
sdrB.lo.configure('../../config/lmx_registers_58ghz.txt');
sdrB.rffeRx.configure(1, '../../config/hmc6301_registers.txt');
% 
% % Configure the RX number of samples, etc
nFFT = 1024;
nread = nFFT/4; % read ADC data for 256 cc (4 samples per cc)
nskip = 768;   % skip ADC data for this many cc
ntimes = 20;    % Number of batches to receive
nsamp = ntimes*nFFT*nadc;
sdrB.set('nread', nread, 'nskip', nskip, 'nbytes', nsamp*2);
sdrB.ctrlFlow();

% Generate the TX waveform
scMin = -450;
scMax = 450;
niter =  5;
constellation = [1+1j 1-1j -1+1j -1-1j];

% expType = 1: Make initial measurements of the fractional timing offset
% expType = 2: Correct the fractional offsets and see if the residual
% errors are close to 0. Also measure the integer timing offsets.

% How many unique fractional timing offsets are we going to search through?
nto = 101;

% Used for debug
ar = zeros(niter, ntimes, nto);
figure(3); clf;

for expType=1:2
    maxPos = zeros(sdrA.nch, niter, ntimes);
    maxVal = zeros(sdrA.nch, niter, ntimes);
    intPeakPos = zeros(sdrA.nch, niter, ntimes);

        
    for iter=1:niter
        txfd = zeros(nFFT, sdrA.nch);
        txtd = zeros(nFFT, sdrA.nch);
        
        m = 0;
        for txIndex=1:sdrA.nch
            for scIndex = scMin:scMax
                if scIndex ~= 0
                    %txfd(nFFT/2 + 1 + scIndex, txIndex) = sdrA.refConstellation(nFFT/2 + 1 + scIndex, txIndex);
                    txfd(nFFT/2 + 1 + scIndex, txIndex) = constellation(randi(4));
                end
            end % scIndex
            txfd(:,txIndex) = fftshift(txfd(:,txIndex));
            txtd(:,txIndex) = ifft(txfd(:,txIndex));
            
            m = max( max(abs(txtd(:,txIndex))), m);
            
            if (expType == 2)
                txtd(:,txIndex) = fracDelay(txtd(:,txIndex), sdrA.calTxDelay(txIndex), nFFT);
            end
        end % txIndex
        
        % Scale and send the signal from sdrA
        txtd = txtd/m*15000;
        sdrA.send(txtd);
        
        % Receive the signal from sdrB

        rxtd = sdrB.recv(nsamp);
        size(rxtd);
          
        % Try different timing offsets
        tos = linspace(-0.5, 0.5, nto);
        for ito = 1:nto
            to = tos(ito);
            fprintf('.');
            for itimes=1:ntimes
                rxtdShifted = fracDelay(rxtd(:,itimes,1), to, nFFT);
                rxfd = fft(rxtdShifted);
                corrfd = zeros(nFFT, sdrA.nch);
                corrtd = zeros(nFFT, sdrA.nch);

                for txIndex = 1:sdrA.nch

                    corrfd(:,txIndex) = txfd(:,txIndex) .* conj(rxfd);
                    corrtd(:,txIndex) = ifft(corrfd(:,txIndex));
                    ar(iter, itimes, ito) = max(mag2db(abs(corrtd(:,txIndex))));
                    
                    if ((expType == 2) && (to == 0))
                        % Measure the integer timing location of the peak
                        [~, intpos] = max(abs(corrtd(:,txIndex)));                
                        intPeakPos(txIndex, iter, itimes) = intpos;
                    end

                    [~, pos] = max(abs(corrtd(:,txIndex)));                
                    val = corrtd(pos, txIndex);
                    if abs(val) > abs(maxVal(txIndex, iter, itimes))
                        % We have bound a "better" timing offset
                        maxVal(txIndex, iter, itimes) = val;
                        maxPos(txIndex, iter, itimes) = tos(ito);
                    end        
                end % txIndex
            end %itimes
        end % ind_to
    end % iter
    
    figure(3);
    subplot(3,1,expType);
    cols = 'yrgb'; % Colors for the plots
    diffMatrix = zeros(sdrA.nch, niter, ntimes);
    for txIndex=1:sdrA.nch
        for iter=1:niter
            for itimes=1:ntimes
                diffMatrix(txIndex, iter, itimes) = maxPos(txIndex, iter, itimes) - maxPos(1, iter, itimes);
                if diffMatrix(txIndex, iter, itimes) > 0.5
                    diffMatrix(txIndex, iter, itimes) = diffMatrix(txIndex, iter, itimes) - 1;
                end
                if diffMatrix(txIndex, iter, itimes) < -0.5
                    diffMatrix(txIndex, iter, itimes) = diffMatrix(txIndex, iter, itimes) + 1;
                end
            end %itimes
        end % iter
        
        l = diffMatrix(txIndex, :, :);
        l = reshape(l, [], 1);
        plot(l, cols(txIndex)); hold on;
        ylim([-0.5 0.5]);
        xlabel('Iteration (UnSorted)');
        
        if (expType == 1)
            title('Pre-cal: Fractional Timing offsets');
        elseif (expType == 2)
            title('Post-Cal: Fractional Timing Offsets');
        end
        
    end % txIndex
    
    resTimingErrors = zeros(1, sdrA.nch);
    for txIndex=1:sdrA.nch
        l = diffMatrix(txIndex,:,:);
        l = reshape(l, 1, []);
        vec = 0 + 0*j;
        for iter=1:length(l)
            vec = vec + exp(1j*2*pi*l(iter));
        end
        toff = angle(vec) / (2*pi);
        resTimingErrors(txIndex) = toff;
    end
    
    if (expType == 1)
        sdrA.calTxDelay = resTimingErrors;
    end
    
    resTimingErrors % If we want to print this out
    
end % expType

figure(3);
subplot(3,1,3);
for txIndex = 1:sdrA.nch
    lRef = intPeakPos(1,:,:);
    lRef = reshape(lRef,1,[]);
    lTx  = intPeakPos(txIndex,:,:);
    lTx  = reshape(lTx, 1, []);
    plot(sort(lTx - lRef), cols(txIndex)); hold on;
    title('Integer Timing Offsets');
    ylim([-2 2]);
    xlabel('Iteration (Sorted). Consider only the median (middle) iteration, which should be 0');
end

% Clear workspace variables
clear constellation expType iter maxPos maxVal nFFT niter rxtd scIndex;
clear scMin scMax txfd txIndex txtd m nread nskip nsamp ntimes;
clear ans corrfd corrtd diff iiter itimes ito nto pos rxfd rxtdShifted;
clear to tos val l ar cols diffMatrix resTimingErrors toff vec;
clear intPeakPos lRef lTx intpos;