nFFT = 1024;
txfd = zeros(1, nFFT);
scIndex = 1;
constellation = [1+1j 1-1j -1+1j -1-1j];
% constellation = [1+0j 1+0j 1+0j 1+0j];
txfd(nFFT/2 + 1 + scIndex) = constellation(randi(4));
txfd(nFFT/2 + 1 - scIndex) = real(txfd(nFFT/2 + 1 + scIndex)) - 1j*imag(txfd(nFFT/2 + 1 + scIndex));
txfd = fftshift(txfd);
txtd = ifft(txfd);
figure(1); clf;
plot(real(txtd), 'r'); hold on;
plot(imag(txtd), 'b'); hold off;