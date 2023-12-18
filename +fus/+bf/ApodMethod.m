classdef ApodMethod < fus.DataClass
    %Abstract class for Apodization Methods
    methods (Abstract)
        apod = calc_apod(self, trans, position, params)        
    end
    methods
        function s = to_struct(self)
            % STRUCT convert to struct
            %   s = apod_method.to_struct()
            %
            % Returns:
            %   s (struct): struct with all properties
            s = to_struct@fus.DataClass(self);
            cdef = split(class(self),'.');
            s.class = string(cdef{end}); 
        end
        
        function get_table(self)
            error('ApodMethod is an abstract class')
        end
    end
    methods (Static)
        function self = from_struct(s)
            % FROM_STRUCT create ApodMethod from struct
            %   self = fus.bf.ApodMethod.from_struct(s)
            %
            % Inputs:
            %   s (struct): struct with ApodMethod properties.
            %       The 'class' field defines which subclass to use.
            % 
            % Returns:
            %   self (fus.bf.ApodMethod): ApodMethod object
            arguments
                s struct
            end
            constructor = str2func(sprintf("fus.bf.apodmethods.%s", s.class));
            args = fus.util.struct2args(rmfield(s, 'class'));
            self = constructor(args{:});
        end
    end
end