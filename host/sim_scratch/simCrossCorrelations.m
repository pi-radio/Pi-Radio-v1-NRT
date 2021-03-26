% This will study the cross-correlation between nSeq sets of randomly
% chosen QPSK sequences

nseq = 4;
nFFT = 1024;
constellation = [1+1j 1-1j -1+1j -1-1j];
scMin = -450;
scMax = +450;
niter = 100;

figure(3);

for iter=1:niter
    
    fd = zeros(nFFT, nseq);
    for iseq=1:nseq
        for scIndex = scMin:scMax
            if scIndex ~= 0
                fd(nFFT/2 + 1 + scIndex,iseq) = constellation(randi(4));
            end
        end % scIndex
        fd(:,iseq) = fftshift(fd(:,iseq));
    end % iseq

    for aseq=1:nseq
        for bseq = 1:nseq
            corrfd = fd(:,aseq) .* conj(fd(:,bseq));
            corrtd = mag2db(abs(ifft(corrfd)));
            subplot(nseq, nseq, (aseq-1)*nseq + bseq);
            plot(fftshift(corrtd));
            grid on;
            ylim([-50 10]);
        end
    end
    
    pause(0.1);
    
end