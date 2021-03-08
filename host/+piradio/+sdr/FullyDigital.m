%
% Company:	New York University
%			Pi-Radio
%
% Engineer: Panagiotis Skrimponis
%			Aditya Dhananjay
%
% Description:
%
%
% Date: Last update on Mar. 3, 2021
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
        figNum;         % Figure number to plot waveforms for this SDR
		
		nadc;
		ndac;
        nch;
		nread = 0;		% ADC flow control parameters.
		nskip = 0;		% 
		nbytes = 0;
        
        calTxDelay;
        calRxDelay;
        calTxPhase;
        calRxPhase;
        
        refConstellation;   % Used only for debug
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
			obj.fpga = piradio.fpga.RFSoC('ip', obj.ip, ...
				'nadc', obj.nadc, 'ndac', obj.ndac, 'nch', obj.nch, ...
                'isDebug', obj.isDebug);
            
            obj.lo = piradio.rffe.LMX2595('socket', obj.socket);
            obj.rffeTx = piradio.rffe.HMC6300('socket', obj.socket);
            obj.rffeRx = piradio.rffe.HMC6301('socket', obj.socket);
            
            figure(obj.figNum);
            clf;
            
            obj.calTxDelay = zeros(1, obj.nch);
            obj.calRxDelay = zeros(1, obj.nch);
            obj.calTxPhase = zeros(1, obj.nch);
            obj.calRxPhase = zeros(1, obj.nch);
            
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
			clear obj.fpga;
			
			% Close TCP connection.
			obj.disconnect();
		end
		
		function data = recv(obj, nsamp)			
			% Read data from the FPGA
			data = obj.fpga.recv(nsamp);
			% Process the data (i.e., calibration, flow control)
			if (obj.nread ~= 0)
				data = reshape(data,[],nsamp/obj.nadc/obj.nread/4,obj.nch);
            end
            
            % Demove DC Offsets
            nt = size(data,2); %ntimes
            for ich=1:obj.nch
                for it=1:nt
                    data(:,it,ich) = data(:,it,ich) - mean(data(:,it,ich));
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
		
		function ctrlFlow(obj)
			% Control the reading flow 
			write(obj.socket, sprintf("+ %d %d %d", obj.nread, obj.nskip, obj.nbytes));
			pause(0.1);
        end
               
	end
	
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
				write(obj.socket, 'disconnect');
				pause(0.1);
				clear obj.socket;
			end	
		end
	end
end

