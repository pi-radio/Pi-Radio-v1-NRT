%
% Company:	New York University
%			Pi-Radio
%
% Engineer: Panagiotis Skrimponis
%			Aditya Dhananjay
%
% Description:
%
% Date: Last update on Mar. 3, 2021
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
			write(obj.sockData, sprintf("ReadDataFromMemory 0 0 %d 0\r\n", 2*nsamp));
			rxtd = read(obj.sockData, nsamp, 'int16'); % read ADC samples
			pause(0.1);
			% Read response from the Data TCP Socket
			rsp = read(obj.sockData);
			if (obj.isDebug)
				fprintf(1, "%s", rsp);
			end
            rxtd = rxtd';
            
            wf_len = size(rxtd,1)/(obj.nch*2);      % Waveform length
            adc_data = zeros(wf_len, obj.nch*2);
            
            % Rearrange the incoming data as (wf_len x nadc), noting that
            % in each clock cycle, there are 4 ADC samples that get read in
            % and sent to the memory
            for wf_ind = 1:wf_len/4
                for iadc = 1:obj.nadc
                    rxtd_startind = (wf_ind-1)*32 + (iadc-1)*4 + 1;
                    adc_startind = (wf_ind-1)*4 + 1;
                    adc_data(adc_startind:adc_startind+3, iadc) = rxtd(rxtd_startind:rxtd_startind+3);
                end
            end
            
            % Remove the DC Offset (Not strictly necessary)
            for iadc=1:obj.nadc
                adc_data(:,iadc) = adc_data(:,iadc) - mean(adc_data(:,iadc));
            end
            
            % Assign signals from each ADC to the appropriate channel
            rxtd = zeros(wf_len, obj.nch);
            rxtd(:,1) = adc_data(:,1) - 1j*adc_data(:,2);
            rxtd(:,2) = adc_data(:,3) + 1j*adc_data(:,4);
            rxtd(:,3) = adc_data(:,6) - 1j*adc_data(:,8);
            rxtd(:,4) = adc_data(:,5) - 1j*adc_data(:,7);
		end
		
		function send(obj, txtd)
			% First, we need to process the data from the DACs. The
			% expected input to this function is a matrix with dimension 
			% (nsamp x nch). All inputs are complex.
            
			% Map the signals to the appropriate DAC
            dac_data = zeros(size(txtd,1), obj.nch*2);
            dac_data(:,1) = (+1) * int16(imag(txtd(:, 1)));
            dac_data(:,2) = (+1) * int16(real(txtd(:, 1)));
            dac_data(:,3) = (+1) * int16(real(txtd(:, 2)));
            dac_data(:,4) = (-1) * int16(imag(txtd(:, 2)));
            dac_data(:,5) = (-1) * int16(real(txtd(:, 3)));
            dac_data(:,6) = (-1) * int16(real(txtd(:, 4)));
            dac_data(:,7) = (-1) * int16(imag(txtd(:, 3)));
            dac_data(:,8) = (-1) * int16(imag(txtd(:, 4)));
            
            txblob = zeros(1,size(txtd,1)*obj.ndac);
			for isamp=1:4:size(txtd,1)
				for idac=1:obj.ndac
				txblob( (isamp*8-7)+((idac-1)*4) : (isamp*8-7)+((idac-1)*4+3) ) ...
					= dac_data(isamp:isamp+3, idac);
				end
			end
			
% 			tmp = reshape(dac_data, 4, [], obj.ndac);
% 			
%             txblob0 = zeros(4, size(dac_data,1)/4);
% 			for idac = 1:obj.ndac
% 				txblob0(:, idac:obj.ndac:end) = reshape(tmp(:,:,idac),4,[]);
% 			end
			% Finally, we flatten the tx vector;
% 			txblob = reshape(txblob,[],1);
            
			nsamp = length(txblob);	% num of samples
			nbytes = 2*nsamp;		% num of bytes (since int16)
            			
			% Send the data over TCP with the necessary commands in the
			% control and data channel
			obj.sendCmd("LocalMemInfo 1");
			obj.sendCmd(sprintf("LocalMemTrigger 1 0 0 0x0000"));
			write(obj.sockData, sprintf("WriteDataToMemory 0 0 %d 0\r\n", nbytes));
			write(obj.sockData, txblob, 'int16');
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

				% We are going to parse a simplified version of
				% the file with only the necessary commands.
				if (tline(1) ~= '%')
					fprintf(1, '%s\n', tline);
					obj.sendCmd(tline)
                else
                    % Use comments in the file to create pauses that allow
                    % the PLLs to stabilize, etc.
                    pause(0.2);
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
