% We expect the sample clocks of the I and Q channels to be aligned. But
% sometimes they are not. Power cycling the RFSoC can lead to a different
% timing offset. This needs to be measured and fixed.

sdrTx = sdr0;
sdrRx = sdr1;

nFFT = 1024;
nread = nFFT;
nskip = nFFT*1;
ntimes = 30;
constellation =[1+1j 1-1j -1+1j -1-1j];

nto = 51;
niter = 5;

figure(3); clf;

for expType = 1:1
    sup = zeros(sdrRx.nch, nto, niter, ntimes);
    for iter=1:niter
        fprintf('\n');
        
        txfd = zeros(nFFT, 1);
        scMin = 1;
        scMax = 450;
        for scIndex = scMin:scMax
            txfd(nFFT/2 + 1 + scIndex) = constellation(randi(4));
        end % scIndex
        txfd = fftshift(txfd);
        txtd = ifft(txfd);
        m = max(abs(txtd));
        txtd = txtd / m * 30000;
        txtdMod = zeros(nFFT, sdrTx.nch);
        txtdMod(:,4) = txtd;
        
        sdrTx.send(txtdMod);
        rxtd = sdrRx.recv(nread,nskip,ntimes);
        
        for rxIndex=1:sdrRx.nch

            tos = linspace(-0.5, 0.5, nto);
            for ito = 1:nto
                to = tos(ito);
                fprintf('.');
                for itimes=1:ntimes

                    td = rxtd(:,itimes,rxIndex);
                    re = real(td);
                    im = imag(td);
                    re = sdrRx.fracDelay(re, 0, nFFT);
                    im = sdrRx.fracDelay(im, to, nFFT);
                    td = re + 1j*im;

                    rxfd = fftshift(fft(td));
                    lb = sum(abs(rxfd(nFFT/2 + 1 - scMax : nFFT/2 + 1)));
                    ub = sum(abs(rxfd(nFFT/2 + 1 : nFFT/2 + 1 + scMax)));
                    sup(rxIndex, ito, iter, itimes) = lb / ub;
                    
                end % itimes
            end % ito
        end % rxIndex
    end % iter
    
    % Plot things
    met = zeros(nto,1);
    cols = 'mrgb';
    figure(3);
    subplot(2,1,1);
    for rxIndex=1:sdrRx.nch
        for ito = 1:nto
            l = sup(rxIndex, ito, :, :);
            l = reshape(l, 1, []);
            l = mean(l);
            met(ito) = l;
        end % ito
        plot(tos, mag2db(met), cols(rxIndex)); hold on;
        grid on;
    end % rxIndex
end % expType


% Stop transmitting, do a dummy read, and clear workspace variables.
txtd = zeros(nFFT, sdrTx.nch);
%sdrTx.send(txtd);
%sdrRx.recv(nread, nskip, ntimes);
%sdrTx.recv(nread, nskip, ntimes);


clear ans cols constellation expType fs im iter itimes ito l lb m met;
clear nFFT niter nread nskip ntimes nto pdpStore re rxfd rxIndex rxfd;
clear rxtd scIndex scMin scMax td to tos txfd txtdMod ub;