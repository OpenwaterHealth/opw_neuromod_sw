classdef ParameterConstraint < fus.DataClass
    % PARAMETERCONSTRAINT A class for storing parameter constraints
    properties
        id (1,1) string {mustBeValidVariableName} = "var" % id of the parameter
        name (1,1) string = "" % name of the parameter
        units (1,1) string = "" % units of the parameter
        fstr (1,1) string = "%g" % format string for displaying the parameter
        array_agg (1,1) string {mustBeMember(array_agg, ["max","min","mean","median","none"])} = "max" % function for aggregating array values
        scale_func function_handle % function to scale the parameter
        warn_func function_handle % function to warn about the parameter
        error_func function_handle % function to error about the parameter
    end
    
    methods
        function self = ParameterConstraint(options)
            % PARAMETERCONSTRAINT Construct a ParameterConstraint object
            %   pc = fus.treatment.ParameterConstraint("param1", val1, "param2", val2, ...)
            %
            % Optional Parameters:
            %   'id' (string): ID of the parameter. Default is "var".
            %   'name' (string): Name of the parameter. Default is "".
            %   'units' (string): Units of the parameter. Default is "".
            %   'fstr' (string): Format string for displaying the parameter.
            %       Default is "%g".
            %   'array_agg' (string): Function for aggregating array values.
            %       Default is "max".
            %   'scale_func' (function_handle): Function to scale the parameter.
            %   'warn_func' (function_handle): Function to warn about the parameter.
            %   'error_func' (function_handle): Function to raise an error about the parameter.
            %
            % Returns:
            %   self (fus.treatment.ParameterConstraint): Constructed object
            arguments
                options.?fus.treatment.ParameterConstraint
            end
            self.parse_props(options)
        end
        
        function s = to_struct(self)
            % STRUCT Convert to struct
            %   s = pc.to_struct()
            % 
            % Returns:
            %   s (struct): Struct with valid fields for a ParameterConstraint
            if numel(self)>1
                s = arrayfun(@(x)x.to_struct(), self);
                return
            end
            s = to_struct@fus.DataClass(self);
            fids = {'scale_func', 'warn_func', 'error_func'};
            for i = 1:length(fids)
                fid = fids{i};
                if ~isempty(s.(fid))
                    s.(fid) = func2str(s.(fid));
                else
                    s.(fid) = [];
                end
            end
        end
        
        function warn = is_warn(self, val)
            % IS_WARN Check if the parameter is in the warning range
            %  warn = pc.is_warn(val)
            % 
            % Input:
            %   val (double): value of the parameter
            %
            % Returns:
            %   warn (logical): true if the parameter is in the warning range
            arguments
                self fus.treatment.ParameterConstraint
                val
            end
            if isempty(self.warn_func)
                warn = false;
            else
                warn = self.warn_func(self.scale(val));
            end
        end
        
        function err = is_error(self, val)
            % IS_ERROR Check if the parameter is in the error range
            %  err = pc.is_error(val)
            %
            % Input:
            %   val (double): value of the parameter
            %
            % Returns:
            %   err (logical): true if the parameter is in the error range
            arguments
                self fus.treatment.ParameterConstraint
                val
            end
            if isempty(self.error_func)
                err = false;
            else
                err = self.error_func(self.scale(val));
            end
        end
        
        function val_scale = scale(self, val)
            % SCALE Scale the parameter
            %  val_scale = pc.scale(val)
            %
            % Input:
            %   val (double): value of the parameter
            %
            % Returns:
            %   val_scale (double): scaled value of the parameter
            arguments
                self fus.treatment.ParameterConstraint
                val
            end
            if numel(val) > 1
                switch self.array_agg
                    case 'max'
                        val = max(val);
                    case 'min'
                        val = min(val);
                    case 'mean'
                        val = mean(val);
                    case 'median'
                        val = median(val);
                    case 'none'
                        val = val;
                end
            end
            if isempty(self.scale_func)
                val_scale = val;
            else
                val_scale = self.scale_func(val);
            end
        end
        
        function valstr = format(self, val)
            % FORMAT Format the parameter
            %  valstr = pc.format(val)
            %
            % Input:
            %   val (double): value of the parameter
            %
            % Returns:
            %   valstr (string): formatted value of the parameter
            valstr = sprintf(self.fstr, self.scale(val));
        end
        
        function status = get_status(self, val)
            % GET_STATUS Get the status of the parameter
            %  status = pc.get_status(val)
            %
            % Input:
            %   val (double): value of the parameter
            %
            % Returns:
            %   status (string): status of the parameter            
            if self.is_error(val)
                status = 'error';
            elseif self.is_warn(val)
                status = 'warning';
            else
                status = 'ok';
            end
        end
                
        function msg = get_message(self, val)
            % GET_MESSAGE Get the message for the parameter
            %  msg = pc.get_message(val)
            %
            % Input:
            %   val (double): value of the parameter
            %
            % Returns:
            %   msg (string): message for the parameter
            status = self.get_status(val);
            switch status
                case 'error'
                    funcstr = func2str(self.error_func);
                    m = regexp(funcstr,'@\([^()]+\)', 'end');
                    if m
                        funcstr = funcstr(m+1:end);
                    end
                    msg = string(sprintf('%s=%s (%s%s)', ...
                        self.name, ...
                        self.format(val), ...
                        funcstr, ...
                        self.units));    
                case 'warning'
                    funcstr = func2str(self.warn_func);
                    m = regexp(funcstr,'@\([^()]+\)', 'end');
                    if m
                        funcstr = funcstr(m+1:end);
                    end
                    msg = string(sprintf('%s=%s (%s%s)', ...
                        self.name, ...
                        self.format(val), ...
                        funcstr, ...
                        self.units)); 
                case 'ok'
                    msg = "";
            end
        end        
    end
    
    methods (Static)
        function self = from_struct(s)
            % FROM_STRUCT Construct a ParameterConstraint object from a struct
            %   pc = fus.treatment.ParameterConstraint.from_struct(s)
            %
            % Input:
            %   s (struct): struct with valid fields for a ParameterConstraint
            %
            % Returns:
            %   pc (fus.treatment.ParameterConstraint): Constructed object
            arguments
                s struct
            end
            if numel(s) ~= 1
                self = arrayfun(@fus.treatment.ParameterConstraint.from_struct, s);
                return
            end
            if isempty(fieldnames(s)) || isempty(s.id)
                self = fus.treatment.ParameterConstraint.empty;
                return
            end
            fids = {'scale_func', 'warn_func', 'error_func'};
            for i = 1:length(fids)
                fid = fids{i};
                if isempty(s.(fid)) || isequal(s.(fid),"")
                    s.(fid) = function_handle.empty;
                else
                    s.(fid) = str2func(s.(fid));
                end
            end
            args = fus.util.struct2args(s);
            self = fus.treatment.ParameterConstraint(args{:});
        end
    end
end