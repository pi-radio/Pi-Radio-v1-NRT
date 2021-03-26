nFFT = 1024;
nread = nFFT;
nskip = nFFT*101;
ntimes = 200;
constellation = [1+1j 1-1j -1+1j -1-1j];

txfd = zeros(nFFT, 1);
scMin = -450; scMax = 450;


magStore = zeros(sdrTx.nch, sdrRx.nch);
niter = 2;

for expType = 1:2
    for iter=1:niter
        
        for scIndex = scMin:scMax
            if (scIndex ~= 0)
                txfd(nFFT/2 + 1 + scIndex) = constellation(randi(4));
            end
        end
        txfd = fftshift(txfd);
        txtd = ifft(txfd);
        txtd = txtd * 200000;
        
        for txIndex = 1:sdrTx.nch
            txtdMod = zeros(nFFT, sdrTx.nch);
            if (expType == 1)
                txtdMod(:,txIndex) = txtd;
            elseif (expType == 2)
                txtdMod(:,txIndex) = txtd * sdrTx.calMagTx(txIndex);
            end
            sdrTx.send(txtdMod);
            pause(0.1);

            rxtd = sdrRx.recv(nread, nskip, ntimes);
            for rxIndex = 1:sdrRx.nch
                a = 0;
                for itimes=1:ntimes
                    if (expType == 1)
                        td = rxtd(:, itimes, rxIndex);
                    elseif (expType == 2)
                        td = rxtd(:, itimes, rxIndex) * sdrRx.calMagRx(rxIndex);
                    end
                    a = a + rms(abs(td));
                end % itimes
                magStore(txIndex, rxIndex) = magStore(txIndex, rxIndex) + a;
            end % rxIndex
        end % txIndex
    end %iter
    
    % Plot and Calculate
    figure(3);
    if (expType == 1)
        for txIndex = 1:sdrTx.nch
            x = sum(magStore(1,:)) / sum(magStore(txIndex,:));
            sdrTx.calMagTx(txIndex) = x;
        end
        for rxIndex = 1:sdrRx.nch
            x = sum(magStore(:,1)) / sum(magStore(:,rxIndex));
            sdrRx.calMagRx(rxIndex) = x;
        end
        
        subplot(2,1,1)
        imagesc(magStore / max(max(magStore)));
        caxis([0.5 1]);
        colorbar;
    elseif (expType == 2)
        subplot(2,1,2);
        imagesc(magStore / max(max(magStore)));
        caxis([0.5 1]);
        colorbar;
    end
end % expType

% Stop transmitting, and clear workspace variables
txtd = zeros(nFFT, sdrTx.nch);
sdrTx.send(txtd);
sdrRx.send(txtd);
sdrTx.recv(nread, nskip, ntimes);
sdrRx.recv(nread, nskip, ntimes);

clear a constellation magStore nread scMin scMax x expType iter;
clear scMax scMin txIndex itimes nFFT niter nskip ntimes refRxIndex;
clear rxIndex rxtd scIndex ans td txfd txtd txtdMod;