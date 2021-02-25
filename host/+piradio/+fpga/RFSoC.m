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
% Date: Last update on Feb. 15, 2021
%
% Copyright @ 2021
%
classdef RFSoC < matlab.System
    %RFSOC Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
		ip;				% IP address
		nadc;			% num of A/D converters
		ndac;			% num of D/A converters
        nch;            % num of channels
		mem;			% mem type: 'bram' or 'dram'
		sockData;		% data TCP connection
		sockCtrl;		% ctrl TCP connection
		isDebug;		% if 'true' print debug messages
    end
    
    methods
        function obj = RFSoC(varargin)
			% Constructor
			
            % Set parameters from constructor arguments.
			if nargin >= 1
				obj.set(varargin{:});
			end
			
			% Establish TCP connections.
			obj.connect();
			
			obj.sendCmd("TermMode 1");
		end
		
		function delete(obj)
			% Destructor.
			
			% Close TCP connections.
			obj.disconnect();
		end
		
		function rxtd = recv(obj, nsamp)
			% Send over TCP with the necessary commands in the control and 
			% data channel
			obj.sendCmd(sprintf("SetLocalMemSample 0 0 0 %d", nsamp));
			obj.sendCmd("LocalMemInfo 0");
			obj.sendCmd(sprintf("LocalMemTrigger 0 4 %d 0x0001", nsamp));
			write(obj.sockData, sprintf("ReadDataFromMemory 0 0 %d 0\r\n", 2*nsamp));
			rxtd = read(obj.sockData, nsamp, 'int16'); % read ADC samples
			pause(0.1);
			% Read response from the Data TCP Socket
			rsp = read(obj.sockData);
			if (obj.isDebug)
				fprintf(1, "%s", rsp);
			end
			
			% Transform the received data to a column vector
			rxtd = reshape(rxtd,[],1);
			
			% Initialize a temporary buffer
			tmp = zeros(2,size(rxtd,1)/32,8);
			
			% Convert data to 'double' from 'int16'. We reshape the data
			% since the ADCs generate 2-samples per clock cycle.
			rxtd = double(reshape(rxtd,2,[]));
			
			% Create the complex samples for each ADC. 
			for iadc = 1:obj.nadc
				tmp(:,:,iadc) = rxtd(:,(2*iadc-1):2*obj.nadc:end) + ...
					1j*rxtd(:,2*iadc:2*obj.nadc:end);
			end
			
			% Return a matrix of nsamp x nadc
			rxtd = reshape(tmp, [], obj.nadc);
		end
		
		function send(obj, txtd)
			% First, we need to process the data from the DACs. The
			% expected input to this function is a matrix with dimension 
			% (nsamp x nch). All inputs are complex.
            
			% Map the signals to the appropriate DAC
            dac_data = zeros(size(txtd,1), obj.nch*2);
            dac_data(:,1) = int16(real(txtd(:, 1)));
            dac_data(:,2) = int16(imag(txtd(:, 1)));
            dac_data(:,3) = int16(real(txtd(:, 2)));
            dac_data(:,4) = int16(imag(txtd(:, 2)));
            dac_data(:,5) = int16(real(txtd(:, 3)));
            dac_data(:,6) = int16(imag(txtd(:, 3)));
            dac_data(:,7) = int16(real(txtd(:, 4)));
            dac_data(:,8) = int16(imag(txtd(:, 4)));
            
            txblob = zeros(1,size(txtd,1)*obj.ndac);
            for isamp=1:4:size(txtd,1)
                for idac=1:obj.ndac
                    txblob( (isamp*8-7)+((idac-1)*4) : (isamp*8-7)+((idac-1)*4+3) ) ...
                        = dac_data(isamp:isamp+3, idac);
                end
            end
            
			nsamp = length(txblob);	% num of samples
			nbytes = 2*nsamp;		% num of bytes (since int16)
            			
			% Send the data over TCP with the necessary commands in the
			% control and data channel
			obj.sendCmd("LocalMemInfo 1");
			obj.sendCmd(sprintf("LocalMemTrigger 1 0 0 0x0000"));
			write(obj.sockData, sprintf("WriteDataToMemory 0 0 %d 0\r\n", nbytes));
			write(obj.sockData, txtd, 'int16');
			pause(0.1);

			% Read response from the Data TCP Socket
			rsp = read(obj.sockData);
			if (obj.isDebug)
				fprintf(1, "%s", rsp);
			end
			
			obj.sendCmd(sprintf("SetLocalMemSample 1 0 0 %d", nsamp));
			obj.sendCmd("LocalMemTrigger 1 2 0 0x0001");
			obj.sendCmd("LocalMemInfo 1");
		end
		
		function configure(obj, file)
			% Parse the output file from the RFDC.
			fid = fopen(file,'r');
			while ~feof(fid)
				tline = fgetl(fid);
				% The following lines parse a file generated from the 
				% Xilinx RFDC Windows application:
				%
				% tmp = regexp(tline, '\t', 'split');
				% fprintf(1, '%s\n',tmp{4})
				% obj.sendCmd(tmp{4});
				%
				% However, we are going to parse a simplified version of
				% the file with only the necessary commands.
				if (tline(1) ~= '%')
					fprintf(1, '%s\n', tline);
					obj.sendCmd(tline)
				end
			end
			fclose(fid);
		end
	end
	
	methods (Access = 'protected')
		function connect(obj)
			% This function establishes communication between a host and
			% an RFSoC device.
			if (isempty(obj.sockData))
				obj.sockData = tcpclient(obj.ip, 8082, "Timeout", 5);
			end
            
			if (isempty(obj.sockCtrl)) 
				obj.sockCtrl = tcpclient(obj.ip, 8081, "Timeout", 5);
			end
			
		end
		
		function disconnect(obj)
			% This function disbands the communication sockets between the
			% host and an RFSoC device.
			
			if (~isempty(obj.sockData))
				flush(obj.sockData);
				clear obj.sockData;
			end
			
			if (~isempty(obj.sockCtrl)) 
				flush(obj.sockCtrl);
				clear obj.sockCtrl;
			end			
		end
		
		function sendCmd(obj, cmd)
			
            % Flush the input/output buffer
			flush(obj.sockCtrl);
			
			% Send a command to the FPGA
            write(obj.sockCtrl, sprintf("%s\r\n",cmd));
			
			% Wait for the FPGA to process the command
			pause(0.1);
			
			% Read response and print in debug mode
			rsp = read(obj.sockCtrl);
			if (obj.isDebug)
				fprintf(1, "%s", rsp);
			end
		end
	end
end
