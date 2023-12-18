classdef DelayMethod < fus.DataClass
    %Abstract class for Delay Calculation Methods
    methods (Abstract)
        delays = calc_delays(self, trans, focus, params)
    end
    methods
        function s = to_struct(self)
            %STRUCT convert to struct
            %   s = delay_method.to_struct()
            %
            % Returns
            %   s (struct): structure representation of the object.
            %      the 'class' field encodes the subclass name.
            s = to_struct@fus.DataClass(self);
            cdef = split(class(self),'.');
            s.class = string(cdef{end}); 
        end
        
        function get_table(self)
            error('DelayMethod is an abstract class')
        end
    end
    methods (Static)
        function self = from_struct(s)
            %FROM_STRUCT create from struct
            %   delay_method = fus.bf.DelayMethod.from_struct(s)
            %
            % Inputs:
            %   s (struct): structure with fields matching the constructor
            %
            % Returns:
            %   delay_method (fus.bf.DelayMethod): object constructed from
            %      struct.
            arguments
                s struct
            end
            constructor = str2func(sprintf("fus.bf.delaymethods.%s", s.class));
            args = fus.util.struct2args(rmfield(s, 'class'));
            self = constructor(args{:});
        end
    end
end