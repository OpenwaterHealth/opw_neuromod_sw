classdef FocalPattern < fus.DataClass
    %Abstract class for focal patterns
    properties
        target_pressure (1,1) double {mustBeNonnegative}
    end
    methods 
        function targets = get_targets(self, target)
            error('FocalPattern is an Abstract Class');
        end
        function n = num_foci(self)
            error('FocalPattern is an Abstract Class');
        end
    end
    methods
        function s = to_struct(self)
            % TO_STRUCT - convert to struct
            %   s = focal_pattern.to_struct() converts the object to a struct.
            %
            % Returns:
            %   s (struct) - struct representation of the object
            s = to_struct@fus.DataClass(self);
            cdef = split(class(self),'.');
            s.class = string(cdef{end}); 
        end
        
        function tab = get_table(self)
            % GET_TABLE - get table represetation
            %   tab = fus.bf.get_table() returns a table representation of the
            %   object.
            %
            % Returns:
            %   tab (table) - table representation of the object
            tab = struct2table([...
                struct(...
                    "Name", "PNP", ...
                    "Value", sprintf("%0.0f", self.target_pressure*1e-3), ...
                    "Units", "kPa"), ...
                struct(...
                    "Name", "Count", ...
                    "Value", sprintf("%g", self.num_foci), ...
                    "Units", "")]);
        end

        
    end
    methods (Static)
        function focal_pattern = from_struct(s)
            % FROM_STRUCT - create FocalPattern from struct
            %   focal_pattern = fus.bf.FocalPattern.from_struct(s) creates a pattern object from a struct.
            %
            % Inputs:
            %   s (struct) - struct with FocalPattern fields
            %
            % Returns:
            %   focal_pattern (fus.bf.FocalPattern) - focal pattern object
            arguments
                s struct
            end
            constructor = str2func(sprintf("fus.bf.focalpatterns.%s", s.class));
            args = fus.util.struct2args(rmfield(s, 'class'));
            focal_pattern = constructor(args{:});
        end       
    end
end