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
classdef FullyDigital < matlab.System
	properties
		ip;				% IP address
		mem;			% mem type: 'bram' or 'dram'
		socket;			% TCP socket to control the Pi-Radio platform
		fpga;			% FPGA object
		isDebug;		% if 'true' print debug messages
        figNum;         % Figure number to plot waveforms for this SDR
		
		nadc;
		ndac;
        nch;
		nread = 0;		% ADC flow control parameters.
		nskip = 0;		% 
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
			obj.fpga = piradio.fpga.RFSoC('ip', obj.ip, 'mem', obj.mem, ...
				'nadc', obj.nadc, 'ndac', obj.ndac, 'nch', obj.nch, ...
                'isDebug', obj.isDebug);
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
				data = reshape(data,[],(nsamp/16)/(obj.nread*2),obj.nadc);
			end
		end
		
		function send(obj, data)
			obj.fpga.send(data);
		end
		
		function ctrlFlow(obj)
			% Control the reading flow 
			write(obj.socket, sprintf("+ %d %d",obj.nread,obj.nskip));
			pause(0.1);
        end
        
        function configLMX(obj, file)
            filestr = fileread(file);
            filebyline = regexp(filestr, '\n', 'split');
            filebyline( cellfun(@isempty,filebyline) ) = [];
            filebyfield = regexp(filebyline, '\t', 'split');
            
            for i=1:numel(filebyfield)
                pause(0.01)
                a = filebyfield(i);
                b = a{1}{1};
                if (strcmp(b(1:1), '%') == 1)
                    % Ignore the comment line in the commands file
                else
                    %fprintf('LMX configuration: Line %d: ', i);
                    %fprintf('.');
                    c = a{1}{2};
                    s = sprintf('%s%s%s', '1', c(3:8), '8');
                    fprintf('%s\n', s);
                    write(obj.socket, s)
                end
            end
            fprintf('\n');
        end
        
        function obj = configHMC6300(obj, txIndex, file)           
            filestr = fileread(file);
            filebyline = regexp(filestr, '\n', 'split');
            filebyline( cellfun(@isempty,filebyline) ) = [];
            filebyfield = regexp(filebyline, '\t', 'split');
            
            for i=1:numel(filebyfield)
                pause(0.01)
                a = filebyfield(i);
                b = a{1}{1};
                if (strcmp(b(1:1), '%') == 1)
                    % Ignore the comment line in the commands file
                else
                    %fprintf('HMC TX configuration: Line %d: \n', i);
                    fprintf('.');
                    c = a{1}{1};
                    
                    if ((txIndex == 1) || (txIndex == 9))
                        s = sprintf('%s%s%s', '0', c(1:6), '4');
                        write(obj.socket, s);
                        pause (0.01);
                    end
                    if ((txIndex == 2) || (txIndex == 9))
                        s = sprintf('%s%s%s', '0', c(1:6), '5');
                        write(obj.socket, s);
                        pause (0.01);
                    end
                    
                    if ((txIndex == 3) || (txIndex == 9))
                        s = sprintf('%s%s%s', '0', c(1:6), '6');
                        write(obj.socket, s)
                        pause (0.01);
                    end
                    
                    if ((txIndex == 4) || (txIndex == 9))
                        s = sprintf('%s%s%s', '0', c(1:6), '7');
                        write(obj.socket, s)
                        pause (0.01);
                    end
                end
            end
            fprintf('\n');
        end
        
         function obj = configHMC6301(obj, rxIndex, file)           
            filestr = fileread(file);
            filebyline = regexp(filestr, '\n', 'split');
            filebyline( cellfun(@isempty,filebyline) ) = [];
            filebyfield = regexp(filebyline, '\t', 'split');
            
            for i=1:numel(filebyfield)
                pause(0.01)
                a = filebyfield(i);
                b = a{1}{1};
                if (strcmp(b(1:1), '%') == 1)
                    % Ignore the comment line in the commands file
                else
                    %fprintf('HMC RX configuration: Line %d: \n', i);
                    fprintf('.');
                    c = a{1}{1};
                    
                    if ((rxIndex == 1) || (rxIndex == 9))
                        s = sprintf('%s%s%s', '0', c(1:6), '0');
                        write(obj.socket, s);
                        pause (0.01);
                    end
                    if ((rxIndex == 2) || (rxIndex == 9))
                        s = sprintf('%s%s%s', '0', c(1:6), '1');
                        write(obj.socket, s);
                        pause (0.01);
                    end
                    
                    if ((rxIndex == 3) || (rxIndex == 9))
                        s = sprintf('%s%s%s', '0', c(1:6), '2');
                        write(obj.socket, s)
                        pause (0.01);
                    end
                    
                    if ((rxIndex == 4) || (rxIndex == 9))
                        s = sprintf('%s%s%s', '0', c(1:6), '3');
                        write(obj.socket, s)
                        pause (0.01);
                    end
                end
            end
            fprintf('\n');
         end % end configHMC6301
        
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

