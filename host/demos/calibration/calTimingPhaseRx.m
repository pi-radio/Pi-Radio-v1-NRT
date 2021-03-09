% This script calibrates the RX-side timing and phase offsets. The RX under
% calibration is sdrA, and the reference TX is sdrB.

% Configure the RX number of samples, etc
nFFT = 1024;    % num of FFT points
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

% WORK IN PROGRESS