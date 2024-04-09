classdef UltrasoundSystem < fus.DataClass
    %UltrasoundSystem An abstract class for ultrasound systems
    properties (Abstract)
        id (1,1) string {mustBeValidVariableName}
        name (1,1) string
    end
    
    methods
        function s = to_struct(self)
            s = to_struct@fus.DataClass(self);
            classname = string(split(class(self),'.'));
            s.class = join(classname(3:end),'.'); 
        end
        
        function sys_info = info(self)
            class_info = split(string(class(self)),'.');
            class_name= join(class_info(3:end), '.');
            sys_info = struct(...
                'id', self.id, ...
                'name', self.name, ...
                'class', class_name);
        end
    end
    
    methods (Abstract)
        run(self, solution)
    end
    
    methods (Static)
        function self = from_struct(s)
            arguments
                s struct
            end
            constructor = str2func(sprintf("fus.sys.%s", s.class));
            args = fus.util.struct2args(rmfield(s, 'class'));
            self = constructor(args{:});
        end
    end
end