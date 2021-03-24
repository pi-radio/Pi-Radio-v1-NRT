addpath('../helper');

nFFT = 1024;
scMin = -450;
scMax = 450;
constellation = [1+1j 1-1j -1+1j -1-1j];
txfd = zeros(nFFT,1);
for scIndex=scMin:scMax
    txfd(nFFT/2 + 1 + scIndex) = constellation(randi(4));
end
txfd = fftshift(txfd);
txtd = ifft(txfd);


re = real(txtd);
im = imag(txtd);
re = fracDelay(re, 0, nFFT);
im = fracDelay(im, 0, nFFT);
rxtd = re + 1j*im;


% We have done the "ground truth" fractional delay of the imag channel with
% respect to the real channel

rxfd = fft(rxtd);
corrfd = txfd .* conj(rxfd);
corrtd = ifft(corrfd);
figure(1);
plot(mag2db(abs(fftshift(corrtd))));
ylim([-40 0]);