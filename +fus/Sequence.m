classdef Sequence < fus.DataClass
    %SEQUENCE Class for specifying a pulse sequence
    properties
        pulse_interval (1,1) double {mustBePositive} = 1 % Pulse Interval (s)
        pulse_count (1,1) double {mustBeInteger, mustBePositive} = 10 % Pulse Count
        pulse_train_interval (1,1) double {mustBeNonnegative} = 100 % Pulse Train Interval (s)
        pulse_train_count (1,1) double {mustBeInteger, mustBePositive} = 1 % Pulse Train Count
    end
    
    methods
        function self = Sequence(options)
            % SEQUENCE Construct a Sequence object
            %
            % seq = fus.Sequence("param1", value1, "param2", value2, ...)
            %
            % Optional Parameters:
            %   pulse_interval (double): Pulse Interval in s. Default = 1
            %   pulse_count (int): Pulse Count. Default = 10
            %   pulse_train_interval (double): Pulse Train Interval in s. Default = 100
            %   pulse_train_count (int): Pulse Train Count. Default = 1
            %
            % Returns:
            %   seq (fus.Sequence): Sequence object
            arguments
                options.?fus.Sequence
            end
            self.parse_props(options)
        end
        
        function tab = get_table(self)
            % GET_TABLE Get a table of the sequence parameters
            %
            % tab = seq.get_table()
            %
            % Returns:
            %   tab (table): Table of sequence parameters
            arguments
                self fus.Sequence
            end
            tab = struct2table([...
                struct(...
                    "Name", "PRI", ...
                    "Value", sprintf("%0.3g", self.pulse_interval), ...
                    "Units", "s"),...
                struct(...
                    "Name", "Pulse Count", ...
                    "Value", sprintf("%g", self.pulse_count), ...
                    "Units", ""),...
                struct(...
                    "Name", "PTRI", ...
                    "Value", sprintf("%0.3g", self.pulse_train_interval), ...
                    "Units", "s"),...
                struct(...
                    "Name", "Pulse Trains", ...
                    "Value", sprintf("%0.3g", self.pulse_train_count), ...
                    "Units", "")]);
        end
    end
    
    methods (Static)
        function self = from_struct(s)
            % FROM_STRUCT Construct a Sequence object from a struct
            %
            % seq = fus.Sequence.from_struct(s)
            %
            % Inputs:
            %   s (struct): Struct with Sequence properties
            %
            % Returns:
            %   seq (fus.Sequence): Sequence object
            arguments
                s struct
            end
            if numel(s)>1
                self = arrayfun(@fus.Sequence.from_struct, s);
                return
            end
            if isfield(s, "class")
                constructor = str2func(sprintf("fus.%s", s.class));
                args = fus.util.struct2args(rmfield(s, 'class'));
                self = constructor(args{:});
            else
                args = fus.util.struct2args(s);
                self = fus.Sequence(args{:});
            end
        end
    end
end