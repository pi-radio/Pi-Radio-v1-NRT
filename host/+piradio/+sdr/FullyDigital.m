%
% Company:	New York University
%           Pi-Radio
%
% Engineer: Panagiotis Skrimponis
%           Aditya Dhananjay
%
% Description: This class creates a fully-digital SDR with 8-channels. This
% class establish a communication link between the host and the Pi-Radio
% TCP server running on the ARM. The server configures the RF front-end and
% the ADC flow control.
%
% Last update on Mar. 5, 2021
%
% Copyright @ 2021
%
classdef FullyDigital < matlab.System
    properties
        ip;				% IP address
        socket;			% TCP socket to control the Pi-Radio platform
        fpga;			% FPGA object
        lo;             % LO object (LMX2595)
        rffeTx;         % Object for the HMC6300 chips
        rffeRx;         % Object for the HMC6301 chips
        isDebug;		% if 'true' print debug messages
        fc = 60e9;      % carrier frequency of the SDR in Hz
        figNum;         % Figure number to plot waveforms for this SDR
        name;           % Unique name for this transceiver board
        calTxDelay;
        calRxDelay;
        calTxPhase;
        calRxPhase;
        calRxIQa;
        calRxIQv;
        calTxIQa;
        calTxIQv;
        
        refConstellation;   % Used only for debug
    end
    
    properties (Dependent)
        nch;    % num of channels
        ndac;   % num of D/A converters
        nadc;   % num of A/D converters
        fs;     % post-decimation/pre-interpolation sample frequency
    end
    
    methods
        function obj = FullyDigital(varargin)
            % Constructor
            
            % Set parameters from constructor arguments.
            if nargin >= 1
                obj.set(varargin{:});
            end
            
            % Establish connection with the Pi-Radio TCP Server.
            obj.connect();
            
            % Create the RFSoC object
            obj.fpga = piradio.fpga.RFSoC('ip', obj.ip, 'isDebug', obj.isDebug);
            
            obj.lo = piradio.rffe.LMX2595('socket', obj.socket, 'name', obj.name);
            obj.rffeTx = piradio.rffe.HMC6300('socket', obj.socket);
            obj.rffeRx = piradio.rffe.HMC6301('socket', obj.socket);
            
            figure(obj.figNum);
            clf;
            
            obj.calTxDelay = zeros(1, obj.nch);
            obj.calRxDelay = zeros(1, obj.nch);
            obj.calTxPhase = zeros(1, obj.nch);
            obj.calRxPhase = zeros(1, obj.nch);
            obj.calRxIQa   = zeros(1, obj.nch);
            obj.calRxIQv   = zeros(1, obj.nch);
            obj.calTxIQa   = zeros(1, obj.nch);
            obj.calTxIQv   = zeros(1, obj.nch);
            
            % This is used only for debug
            N = 2048;
            constellation = [1+1j 1-1j -1+1j -1-1j];
            obj.refConstellation = zeros(N, obj.nch);
            for txIndex = 1:obj.nch
                for n=1:N
                    obj.refConstellation(n, txIndex) = constellation(randi(4));
                end
            end
        end
        
        function delete(obj)
            % Destructor.
            clear obj.fpga obj.lo obj.rffeTx obj.rffeRx;
            
            % Close TCP connection.
            obj.disconnect();
        end
        
        function data = recv(obj, nread, nskip, nbatch)
            % Calculate the total number of samples to read:
            % (# of batch) * (samples per batch) * (# of channel) * (I/Q)
            nsamp = nbatch * nread * obj.nch * 2;
            
            write(obj.socket, sprintf("+ %d %d %d", nread/obj.fpga.npar, ...
                nskip/obj.fpga.npar, nsamp*2));
            
            % Read data from the FPGA
            data = obj.fpga.recv(nsamp);
            
            % Process the data (i.e., calibration, flow control)
            data = reshape(data, nread, nbatch, obj.nch);
            
            % Demove DC Offsets
            for ich = 1:obj.nch
                for ibatch = 1:nbatch
                    data(:,ibatch,ich) = data(:,ibatch,ich) - mean(data(:,ibatch,ich));
                end
            end
            
            % Plot the RX waveform for the first batch
            figure(obj.figNum);
            for rxIndex=1:obj.nch
                subplot(4, 4, rxIndex+8);
                plot(real(data(:,1,rxIndex)), 'r'); hold on;
                plot(imag(data(:,1,rxIndex)), 'b'); hold off;
                ylim([-35000 35000]);
                grid on;
                
                n = size(data,1);
                scs = linspace(-n/2, n/2-1, n);
                subplot(4,4,rxIndex+12);
                plot(scs, mag2db(abs(fftshift(fft(data(:,1,rxIndex))))));
                ylim([60 140]);
                grid on;
            end
        end
        
        function send(obj, data)
            obj.fpga.send(data);
            
            % Plot the TX waveforms
            figure(obj.figNum);
            for txIndex=1:obj.nch
                subplot(4, 4, txIndex);
                plot(real(data(:,txIndex)), 'r'); hold on;
                plot(imag(data(:,txIndex)), 'b'); hold off;
                ylim([-35000 35000]);
                grid on;
                
                n = size(data,1);
                scs = linspace(-n/2, n/2-1, n);
                subplot(4,4,txIndex+4);
                plot(scs, abs(fftshift(fft(data(:,txIndex)))));
                grid on;
            end
        end
        
        function blob = applyCalRxArray(obj, rxtd)
            blob = zeros(size(rxtd));
            for rxIndex=1:obj.nch
                for itimes=1:size(rxtd, 2)
                    td = rxtd(:, itimes, rxIndex);
                    td = obj.fracDelay(td, obj.calRxDelay(rxIndex), size(td, 1));
                    td = td * exp(1j * obj.calRxPhase(rxIndex));
                    blob(:, itimes, rxIndex) = td;
                end % itimes
            end % rxIndex
        end % function applyCalRxArray
        
        function blob = applyCalRxIQ(obj, rxtd)
            blob = zeros(size(rxtd));
            for rxIndex=1:obj.nch
                for itimes=1:size(rxtd, 2)
                    td = rxtd(:, itimes, rxIndex);
                    reOld = real(td);
                    imOld = imag(td);
                    a = obj.calRxIQa(rxIndex);
                    v = obj.calRxIQv(rxIndex);                    
                    re = reOld/a;
                    im =  (-1)*(tan(v))*reOld/a + imOld/(cos(v));
                    td = re + 1j*im;
                    blob(:,itimes,rxIndex) = td;
                end % itimes
            end % rxIndex
        end % function applyCalRxIQ
        
        function blob = applyCalTxIQ(obj, txtd)
            blob = zeros(size(txtd));
            for txIndex=1:obj.nch
                td = txtd(:,txIndex);
                reOld = real(td);
                imOld = imag(td);
                a = obj.calTxIQa(txIndex);
                v = obj.calTxIQv(txIndex);                    
                re = reOld/a;
                im =  (-1)*(tan(v))*reOld/a + imOld/(cos(v));
                td = re + 1j*im;
                blob(:,txIndex) = td;                    
            end % txIndex
        end % function applyCalTxIQ
        
        % Create some helper functions
        function nch = get.nch(obj)
            % Return the FPGA number of channels
            nch = obj.fpga.nch;
        end
        
        function nadc = get.nadc(obj)
            % Return the FPGA number of A/D converters
            nadc = obj.fpga.nadc;
        end
        
        function ndac = get.ndac(obj)
            % Return the FPGA number of D/A converters
            ndac = obj.fpga.ndac;
        end
        
        function fs = get.fs(obj)
            % Return the FPGA sample rate
            fs = obj.fpga.fs;
        end
        
        function opBlob = fracDelay(obj, ipBlob,fracDelayVal,N)
            taps = zeros(0,0);
            for index=-100:100
                delay = index + fracDelayVal;
                taps = [taps sinc(delay)];
            end
            x = [ipBlob; ipBlob];
            x = x';
            y = conv(taps, x);
            opBlob = y(N/2 : N/2 + N - 1);
            opBlob = opBlob';
        end % fracDelay

    end % methods
    
    methods (Access = 'protected')
        function connect(obj)
            % Establish connection with the Pi-Radio TCP Server.
            if (isempty(obj.socket))
                obj.socket = tcpclient(obj.ip, 8083, "Timeout", 5);
            end
        end
        
        function disconnect(obj)
            % Close the Pi-Radio TCP socket
            if (~isempty(obj.socket))
                flush(obj.socket);
                write(obj.socket, 'disconnect');
                pause(0.1);
                clear obj.socket;
            end
        end
    end
end