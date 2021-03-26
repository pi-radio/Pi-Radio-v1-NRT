nFFT = 2048;
nread = nFFT;
nskip = nFFT*1;
ntimes = 100;
scMin = 1;
scMax = 950;
constellation = [1+1j 1-1j -1+1j -1-1j];
figure(3); clf;

dactd = zeros(nFFT, sdrTx.ndac);
dacfd = zeros(nFFT, sdrTx.ndac);
for idac = 1:sdrTx.ndac
    fd = zeros(nFFT,1);
    for scIndex = scMin:scMax
        if scIndex ~= 0
            fd(nFFT/2 + 1 + scIndex) = constellation(randi(4));
        end
    end
    fd = fftshift(fd);
    td = ifft(fd);
    m = max(abs(td));
    td = td / m * 10000;
    td = real(td);
    fd = fft(td);
    dactd(:,idac) = td;
    dacfd(:,idac) = fd;
end % idac
sdrTx.sendDAC(dactd);
rxtd = sdrRx.recv(nread, nskip, ntimes);
nto = 31;
tos = linspace(-0.5, 0.5, nto);
dactos = zeros(sdrTx.ndac, 1);

for expType = 1:2
    maxVal = zeros(sdrTx.ndac, ntimes);
    maxPos = zeros(sdrTx.ndac, ntimes);
    
    for itimes = 1:ntimes
        for ito=1:nto
            for idac = 1:sdrTx.ndac
                
                to = tos(ito);
                td = rxtd(:, itimes, 1);
                if (expType == 1)
                    td = fracDelay(td, to, nFFT);
                elseif (expType == 2)
                    td = fracDelay(td, to + sdrTx.calDACto(idac), nFFT);
                end
                fd = fft(td);
                corrfd = fd .* conj(dacfd(:,idac));
                corrtd = abs(ifft(corrfd));
                [val, pos] = max(corrtd);
                
                if (idac == 1) && (to==0)
                    figure(1);
                    plot(mag2db(corrtd));
                    ylim([150 190]);
                end
                
                if (val > maxVal(idac, itimes))
                    % We have found a "better" timing offset
                    maxVal(idac, itimes) = val;
                    maxPos(idac, itimes) = tos(ito);
                end
                
            end % idac
        end % ito
    end % itimes
    
    % Plot
    
    figure(3);
    cols = ['m.-'; 'r.-'; 'g.-'; 'b.-'; 'm*-'; 'r*-'; 'g*-'; 'b*-'];
    for idac=1:sdrTx.ndac
        
        if (expType == 1)
            subplot(3,1,1);
            l = maxPos(idac,:) - maxPos(1,:);
            l = wrapToPi(l*2*pi);
            l = l / (2*pi);
            plot(l, cols(idac, :));
            hold on;
            c = sum(exp(j*2*pi*l));
            c = angle(c);
            c = c / (2*pi);
            sdrTx.calDACto(idac) = c;
        elseif (expType == 2)
            subplot(3,1,2);
            l = maxPos(idac,:) - maxPos(1,:);
            l = wrapToPi(l*2*pi);
            l = l / (2*pi);
            plot(l, cols(idac, :));
            hold on;
            c = sum(exp(j*2*pi*l));
            c = angle(c);
            c = c / (2*pi);
            dactos(idac) = c;
        end
    end
end % expType

dactos

% Stop transmitting and chear all workspace variables
txtd = zeros(nFFT, sdrTx.nch);
sdrTx.send(txtd);
sdrRx.send(txtd);
sdrRx.recv(nread, nskip, ntimes);
sdrTx.recv(nread, nskip, ntimes);

clear  ans c cols constellation corrfd corrtd dacfd dactd expType idac;
clear itimes ito l m maxPos maxVal nFFT nread nskip ntimes nto pos rxtd;
clear scIndex scMin scMax td to tos txtd val;