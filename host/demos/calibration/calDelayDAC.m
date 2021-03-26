% This script calibrates the TX-side DAC timing offsets. The TX under
% calibration is sdrTx, and the reference RX is sdrRx.

% Configure the RX number of samples, etc
nFFT = 1024;    % num of FFT points
nread = nFFT;   % Number of samples to read
nskip = nFFT*1;  % Number of samples to skip
ntimes = 200;    % Number of batches to receive

% Generate the TX waveform
scMin = -450;
scMax = 450;
niter =  1;
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

pdpStore = zeros(sdrTx.ndac, 3, niter, ntimes, nFFT);
sdrTx.calDelayDAC = zeros(1, sdrTx.ndac);

for expType = 1:1
    
    maxPos = zeros(sdrTx.ndac, niter, ntimes);
    maxVal = zeros(sdrTx.ndac, niter, ntimes);
    intPos = zeros(sdrTx.ndac, niter, ntimes);
        
    for iter = 1:niter
        fprintf('\n');
                
        dacfd = zeros(nFFT, sdrTx.ndac);
        dactd = zeros(nFFT, sdrTx.ndac);
        
        for idac=1:1%sdrTx.ndac
            for scIndex = scMin:scMax
                if scIndex ~= 0
                    %txfd(nFFT/2 + 1 + scIndex, 1) = sdrTx.refConstellation(nFFT/2 + 1 + scIndex, 1);
                    dacfd(nFFT/2 + 1 + scIndex, idac) = constellation(randi(4));
                end
            end % scIndex
            dacfd(:,idac) = fftshift(dacfd(:,idac));
            dactd(:,idac) = ifft(dacfd(:,idac));
            %dactd(:,idac) = real(dactd(:,idac));
            %dacfd(:,idac) = fft(dactd(:,idac));    
        end
        
        m = max(max(dactd));
       
        % Scale and send the signal from sdrTx
        dactd = dactd/m*25000;
        sdrTx.send(dactd);
        pause(0.1);
        
        % Receive the signal from sdrRx
        refRxIndex = 1;
        rxtd = sdrRx.recv(nread,nskip,ntimes);
        rxtd = sdrRx.applyCalDelayADC(rxtd);
        pause(0.1);
                
        tos = linspace(-0.5, 0.5, nto);
        for ito = 1:nto
            to = tos(ito);
            fprintf('.');
            for itimes=1:ntimes
                if (expType == 1)
                    rxtdShifted = fracDelay(rxtd(:,itimes,refRxIndex), to, nFFT);
                end
                rxfd = fft(rxtdShifted);
                
                for idac=1:sdrTx.ndac
                    corrfd = rxfd .* conj(dacfd(:,idac));
                    corrtd = ifft(corrfd);

                    [~, pos] = max(abs(corrtd));
                    val = corrtd(pos);
                    if abs(val) > abs(maxVal(idac, iter, itimes))
                        % We have bound a "better" timing offset
                        maxVal(idac, iter, itimes) = abs(val);
                        maxPos(idac, iter, itimes) = tos(ito);
                        intPos(idac, iter, itimes) = pos;

                        % Measure the phase at the "best" to
                        pdpStore(idac, expType, iter, itimes,:) = corrtd;

                    end % if abs(val) > ...
                end % idac
            end % itimes
        end % ito
            
    end % iter
    
    % Calculate the fractional and integer timing offsets
    cols = ['m-*'; 'm-o'; 'r-o'; 'r-*'; 'g-o'; 'b-o'; 'g-*'; 'b-*'; ]; % Based on the mapping from ich to idac
    figure(3);
    for idac=1:sdrTx.ndac
        
        % Fractional
        l = maxPos(idac, :, :) - maxPos(1, :, :);
        l = maxPos(idac, :, :);
        l = reshape(l, [], 1);
        l = (wrapToPi(l*2*pi))/(2*pi);
        if (expType == 1)
            figure(3);
            subplot(8,4,idac);
            plot(l, cols(idac,:));
            title('Pre-Cal: Frac Timing');
            xlabel('Iteration (Unsorted)');
            hold on; grid on;
            ylim([-0.5 0.5]);
            c = sum(exp(1j*2*pi*l));
            c = angle(c);
            c = c /(2*pi);
            sdrTx.calDelayDAC(idac) = (1)*c;
        elseif (expType == 2)
            figure(3);
            subplot(8,1,2);
            plot(l, cols(idac, :));
            title('Post-Cal: Fractional Timing Offsets')
            xlabel('Iteration (Unsorted)');
            hold on;
            ylim([-0.5 0.5]);
        end
        
        % Integer
        l = intPos(idac, :, :) - intPos(1, :, :);
        l = reshape(l, 1, []);
        l = sort(l);
        if (expType == 2)
            figure(3);
            subplot(6,4,8+idac);
            plot(l, cols(idac,:));
            title('Pre-Cal: Integer Timing Off.');
            hold on;
            ylim([-10 10]); grid on;
            medianIndex = int16(length(l) / 2);
            sdrTx.calDelayDAC(idac) = sdrTx.calDelayDAC(idac) + l(medianIndex);
        elseif (expType == 3)
            figure(3);
            subplot(6,4,16+idac);
            plot(l, cols(idac,:));
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
clear iadc txtdMod dacfd dactd idac refRxIndex;