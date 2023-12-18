classdef TargetConstraint < fus.DataClass
    % TARGETCONSTRAINT A class for storing target constraints. 
    %  Target constraints are used to define the acceptable range of
    %  positions for a target. For example, a target constraint could
    %  be used to define the acceptable range of values for the x position
    %  of a target.
    properties
        dim (1,1) string {mustBeValidVariableName} = "x" % The dimension ID being constrained
        name string = string.empty % The name of the dimension being constrained
        units (1,1) string = "m" % The units of the dimension being constrained
        fstr (1,1) string = "%g" % The format string used to display the dimension value
        min (1,1) double = -inf % The minimum value of the dimension
        max (1,1) double = inf % The maximum value of the dimension
    end
    
    methods
        function self = TargetConstraint(options)
            % TARGETCONSTRAINT Construct a TargetConstraint object
            %   tc = fus.treatment.TargetConstraint("param1", value1, "param2", value2, ...)
            %
            % Optional Parameters:
            %   'dim' (string): The dimension ID being constrained. Default: 'x'
            %   'name' (string): The name of the dimension being constrained. Default: dim
            %   'units' (string): The units of the dimension being constrained. Default: 'm'
            %   'fstr' (string): The format string used to display the dimension value. Default: '%g'
            %   'min' (double): The minimum value of the dimension. Default: -inf
            %   'max' (double): The maximum value of the dimension. Default: inf
            %
            % Returns:
            %   tc (fus.treatment.TargetConstraint): The TargetConstraint object
            arguments
                options.?fus.treatment.TargetConstraint
            end
            self.parse_props(options)
            if isempty(self.name)
                self.name = self.dim;
            end
        end
        
        function islow = is_low(self, val, options)
            % IS_LOW Check if a dimension value is below the minimum
            %   islow = tc.is_low(val)
            %   islow = tc.is_low(val, "units", units)
            %
            % Inputs:
            %   val (double): The dimension value to check
            % Optional Parameters:
            %   units (string): The units of the dimension value. Default: tc.units
            %
            % Returns:
            %   islow (logical): True if the dimension value is below the minimum
            arguments
                self fus.treatment.TargetConstraint
                val double
                options.units (1,1) string {fus.util.mustBeDistance} = self.units
            end
            islow = (self.scale(val, options.units) < self.min);
        end
        
        function ishigh = is_high(self, val, options)
            % IS_HIGH Check if a dimension value is above the maximum
            %   ishigh = tc.is_high(val)
            %   ishigh = tc.is_high(val, "units", units)
            %
            % Inputs:
            %   val (double): The dimension value to check
            % Optional Parameters:
            %   units (string): The units of the dimension value. Default: tc.units
            %
            % Returns:
            %   ishigh (logical): True if the dimension value is above the maximum
            arguments
                self fus.treatment.TargetConstraint
                val double
                options.units (1,1) string {fus.util.mustBeDistance} = self.units
            end
            ishigh = (self.scale(val, options.units) > self.max);
        end
        
        function isok = is_ok(self, val, options)
            % IS_OK Check if a dimension value is within the acceptable range
            %   isok = tc.is_ok(val)
            %   isok = tc.is_ok(val, "units", units)
            %
            % Inputs:
            %   val (double): The dimension value to check
            % Optional Parameters:
            %   units (string): The units of the dimension value. Default: tc.units
            %
            % Returns:
            %   isok (logical): True if the dimension value is within the acceptable range            
            arguments
                self fus.treatment.TargetConstraint
                val double
                options.units (1,1) string {fus.util.mustBeDistance} = self.units
            end
            isok = ~(self.is_high(val, "units", options.units) | self.is_low(val, "units", options.units));
        end
        
        function status = get_status(self, val, options)
            % GET_STATUS Get the status of a dimension value
            %   status = tc.get_status(val)
            %   status = tc.get_status(val, "units", units)
            %
            % Inputs:
            %   val (double): The dimension value to check
            % Optional Parameters:
            %   units (string): The units of the dimension value. Default: tc.units
            %
            % Returns:
            %   status (struct): A struct with the following fields:
            %       id (string): The status ID ('ok', 'lo', or 'hi')
            %       ok (logical): True if the dimension value is within the acceptable range
            %       msg (string): A message describing the status
            arguments
                self fus.treatment.TargetConstraint
                val (1,:) double
                options.units (1,1) string {fus.util.mustBeDistance} = self.units
            end
            if numel(val) > 1
                status = arrayfun(@(x)self.get_status(x, "units", options.units), val);
                return
            end
            if any(self.is_high(val, 'units', options.units))
                status_id = 'hi';
                status_ok = false;
                msg = string(sprintf('%s=%s (%s>%s%s)', ...
                        self.name, ...
                        sprintf(self.fstr, self.scale(val, options.units)), ...
                        self.name, ...
                        sprintf(self.fstr, self.max), ...
                        self.units));
            elseif any(self.is_low(val, 'units', options.units))
                status_id = 'lo';
                status_ok = false;
                msg = string(sprintf('%s=%s (%s<%s%s)', ...
                        self.name, ...
                        sprintf(self.fstr, self.scale(val, options.units)), ...
                        self.name, ...
                        sprintf(self.fstr, self.min), ...
                        self.units));
            else
                status_id = 'ok';
                status_ok = true;
                msg = "";
            end
            status = struct('state', status_id, 'ok', status_ok, 'message', msg);
        end     
    end
    
    methods (Access=protected)
        function val_scale = scale(self, val, units)
            % SCALE Scale a dimension value to the specified units
            %   val_scale = tc.scale(val)
            %   val_scale = tc.scale(val, "units", units)
            %
            % Inputs:
            %   val (double): The dimension value to scale
            % Optional Parameters:
            %   units (string): The units to scale to. Default: tc.units
            %
            % Returns:
            %   val_scale (double): The scaled dimension value
            arguments
                self fus.treatment.TargetConstraint
                val double
                units (1,1) string {fus.util.mustBeDistance}
            end
            
            val_scale = val*fus.util.getunitconversion(units, self.units);
        end        
        
        function msg = get_message(self, val, options)
            % GET_MESSAGE Get a message describing the status of a dimension value
            %   msg = tc.get_message(val)
            %   msg = tc.get_message(val, "units", units)
            %
            % Inputs:
            %   val (double): The dimension value to check
            % Optional Parameters:
            %   units (string): The units of the dimension value. Default: tc.units
            %
            % Returns:
            %   msg (string): A message describing the status of the dimension value
            arguments
                self fus.treatment.TargetConstraint
                val double
                options.units (1,1) string {fus.util.mustBeDistance} = self.units
            end
            status = self.get_status(val, 'units', options.units);
            msg = status.message;
        end   
    end

    methods (Static)
        function self = from_struct(s)
            % FROM_STRUCT Create a TargetConstraint from a struct
            %   tc = fus.treatment.TargetConstraint.from_struct(s)
            %
            % Inputs:
            %   s (struct): A struct with the following fields:
            %       name (string): The name of the dimension
            %       dim (string): The dimension to constrain
            %       min (double): The minimum value of the dimension
            %       max (double): The maximum value of the dimension
            %       units (string): The units of the dimension
            %
            % Returns:
            %   tc (fus.treatment.TargetConstraint): The TargetConstraint object
           arguments
               s struct
           end
           if numel(s) ~= 1
               self = arrayfun(@fus.treatment.TargetConstraint.from_struct, s);
               return
           end
           if isempty(fieldnames(s)) || isempty(s.dim)
                self = fus.treatment.TargetConstraint.empty;
                return
           end
           if isempty(s.min) || isnan(s.min)
               s.min = -inf;
           end
           if isempty(s.max) || isnan(s.max)
               s.max = inf;
           end
           args = fus.util.struct2args(s);
           self = fus.treatment.TargetConstraint(args{:});
        end
    end
end