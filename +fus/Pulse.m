classdef Pulse < fus.DataClass
    %PULSE Class for defining an ultrasonic pulse
    % An ultrasonic pulse is defined by its frequency, amplitude, and 
    % duration. The pulse is assumed to be sinusoidal.
    properties
        frequency (1,1) double {mustBePositive} = 1 % Hz
        amplitude (1,1) double {mustBeNonnegative} = 1 % Pa
        duration (1,1) double {mustBePositive} = 1 % s
    end
    
    methods
        function self = Pulse(options)
            %PULSE Pulse Constructor
            %   pulse = fus.Pulse("param", value, ...) creates a Pulse object
            %   with the specified parameters. 
            %
            % Optional Parameters:
            %   'frequency' (1,1) double: Frequency of the pulse in Hz. Default: 1
            %   'amplitude' (1,1) double: Amplitude of the pulse in Pa. Default: 1
            %   'duration' (1,1) double: Duration of the pulse in s. Default: 1
            %
            % Returns:
            %   pulse (1,1) fus.Pulse: Pulse object
            arguments
                options.?fus.Pulse
            end
            self.parse_props(options);
        end
        
        function p = calc_pulse(self, t)
            %CALC_PULSE Calculate the pulse signal at the specified times
            %   p = calc_pulse(t) calculates the pulse at the specified
            %   times t. 
            %
            % Inputs:
            %   t (1,:) double: Times at which to calculate the pulse (s)
            %
            % Returns:
            %   p (1,:) double: Pulse signal at the specified times (Pa)
            arguments
                self fus.Pulse
                t (1,:) double
            end
            p = self.amplitude * sin(2*pi*self.frequency * t);
        end
        
        function t = calc_time(self, dt)
            %CALC_TIME Calculate the time vector for the pulse
            %   t = calc_time(dt) calculates the time vector for the pulse
            %   with the specified time step dt.
            %
            % Inputs:
            %   dt (1,1) double: Time step (s)
            %
            % Returns:
            %   t (1,:) double: Time vector for the pulse (s)
            arguments
                self fus.Pulse
                dt (1,1) double {mustBePositive}
            end
            t = (0:dt:self.duration);
        end
        
        function tab = get_table(self)
            %GET_TABLE Get a table of the pulse properties
            %   tab = get_table() returns a table of the pulse properties.
            %
            % Returns:
            %   tab (1,1) table: Table of pulse properties
            tab = struct2table([...
                struct(...
                    "Name", "Frequency", ...
                    "Value", sprintf("%0.0f", self.frequency*1e-3), ...
                    "Units", "kHz"), ...
                struct(...
                    "Name", "Duration", ...
                    "Value", sprintf("%0.3g", self.duration), ...
                    "Units", "s")]);
        end
        
        function s = to_struct(self)
            %TO_STRUCT Convert the pulse to a struct
            %   s = to_struct() converts the pulse to a struct.
            %
            % Returns:
            %   s (1,1) struct: Struct representation of the pulse
            s = to_struct@fus.DataClass(self);
            cdef = split(class(self),'.');
            s.class = string(cdef{end}); 
        end
        
    end
    
    methods (Static)
        function self = from_struct(s)
            %FROM_STRUCT Create a pulse from a struct
            %   pulse = from_struct(s) creates a pulse from the struct s.
            %
            % Inputs:
            %   s (1,1) struct: Struct representation of the pulse
            %
            % Returns:
            %   pulse (1,1) fus.Pulse: Pulse object
            arguments
                s struct
            end
            constructor = str2func(sprintf("fus.%s", s.class));
            args = fus.util.struct2args(rmfield(s, 'class'));
            self = constructor(args{:});
        end
    end
end