%
% Company:	New York University
%			Pi-Radio
%
% Engineer: Panagiotis Skrimponis
%			Aditya Dhananjay
%
% Description:
%	HMC6300 is a 60 GHz millimeter wave transmitter from Analog Devices. 
%	This device operates in the 57-64 GHz band.
%
% Date: Last update on Mar. 3, 2021
%
% Copyright @ 2021
%
classdef HMC6300 < matlab.System
	properties
		socket;
	end
	
	methods
		function obj = HMC6300(varargin)
			% Constructor
			
            % Set parameters from constructor arguments.
			if nargin >= 1
				obj.set(varargin{:});
			end
		end
		
		function configure(obj, file)          
            filestr = fileread(file);
            filebyline = regexp(filestr, '\n', 'split');
            filebyline( cellfun(@isempty,filebyline) ) = [];
            filebyfield = regexp(filebyline, '\t', 'split');
            
            for i = 1:numel(filebyfield)
                pause(0.01)
                a = filebyfield(i);
                b = a{1}{1};
				
				if (b(1:1) ~= '%')
					fprintf(1, '%s\n', tline);
					obj.sendCmd(tline)
                else
                    % Use comments in the file to create pauses that allow
                    % the PLLs to stabilize, etc.
                    pause(0.2);
				end
				
                if (strcmp(b(1:1), '%') == 1)
                    % Ignore the comment line in the commands file
                else
                    % fprintf('HMC TX configuration: Line %d: \n', i);
                    % fprintf('.');
                    c = a{1}{1};
                    
					hmcTx = '4567';
					if (txIndex == 9)
						for ihmc = hmcTx
							write(obj.socket, sprintf('%s%s%s', '0', c(1:6), ihmc));
							pause (0.01);
						end
					else
						write(obj.socket, sprintf('%s%s%s', '0', c(1:6), hmcTx(txIndex)));
						pause (0.01);
					end
                end
            end
            fprintf('\n');
		end
		
		function powerDown(obj)
			for ihmc = '4567'
				write(obj.socket, sprintf('%s%s%s', '0', 'ff22c0', ihmc));
				pause(0.1);
			end
		end
		
		function attn(obj, ifAttn, rfAttn)
			
            switch ifAttn
                case 00
                    val = 'f0e2c0';
                case 05
                    val = 'f2e2c0';
                case 10
                    val = 'f1e2c0';
                case 15
                    val = 'f3e2c0';
                case 20
                    val = 'ffe2c0';
				otherwise
					val = '000000';
            end
            
			for idx = '4567'
				write(obj.socket, sprintf('%s%s%s', '0', val, idx));
				pause(0.01);
			end
            
            switch rfAttn
                case 00
                    val = 'c0d2c0';
                case 04
                    val = 'c2d2c0';
                case 08
                    val = 'c1d2c0';
                case 12
                    val = 'c3d2c0';
                case 15
                    val = 'cfd2c0';
				otherwise
					val = '000000';
            end
            
			for idx = '4567'
				write(obj.socket, sprintf('%s%s%s', '0', val, idx));
				pause(0.01);
			end
		end
	end
	
	methods (Access = protected)
		
		function stepImpl(obj, data)
			
		end
	end
end

