nFFT = 1024;
constellation = [1+1j 1-1j -1+1j -1-1j];

txfd = zeros(1,nFFT);
for scIndex = -450:450
    if scIndex ~= 0
        txfd(nFFT/2 + 1 + scIndex) = constellation(randi(4));
    end
end
txfd = fftshift(txfd);
corrfd = txfd .* conj(txfd);
corrtd = ifft(corrfd);
corrtd = fftshift(corrtd);
figure(1);
plot(mag2db(abs(corrtd)));
ylim([-60 20]);
xlim([1 nFFT]);
grid on; grid minor;

