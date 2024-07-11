classdef DataClass < handle
    % DATACLASS Abstract base class for objects to be passed by reference
    %   DATACLASS provides a set of convenience structures for objects that
    %   are _in general_, json-serializable. As a subclass of HANDLE,
    %   DATACLASS objects are passed by reference, requiring explicit copy
    %   operations in their implementation to create new objects. This
    %   allows for objects to contain and operate on reasonably large
    %   volumetric datasets without bloating memory usage. 
    methods
        function s = to_struct(obj, options)
            % TO_STRUCT convert DATACLASS to struct
            % s = TO_STRUCT(obj)
            % TO_STRUCT recursively convert a DataClass and all of its
            % properties into a struct. Certain subclasses may use
            % altervative versions of this conversion to handle specific
            % properties differently.
            %
            % INPUTS:
            %   obj: object
            % OPTIONAL PARAMTER-VALUE PAIRS
            %   datefmt (1,1) string. Format for parsing datetime objects.
            %       Default is "yyyy-mm-dd HH:MM:SS"
            arguments
                obj
                options.datefmt (1,1) string = "yyyy-mm-dd HH:MM:SS"
            end
            if numel(obj) > 1
                s = arrayfun(@(x)x.to_struct(), obj);
                return
            end
            s = struct();
            if isempty(obj)
                s = struct.empty;
                return
            end
            propnames = properties(obj);
            cls = metaclass(obj);
            clsprops = string({cls.PropertyList.Name});
            for i = 1:length(propnames)
                propname = propnames{i};
                p = cls.PropertyList(find(propname == clsprops));
                vdx = p.Validation;
                prop = [obj.(propname)];
                try
                    s.(propname) = prop.to_struct();
                catch
                    if ~isempty(vdx) && ~isempty(vdx.Class) && vdx.Class.Name=="string" && any(arrayfun(@(x) isa(x, "meta.UnrestrictedDimension"), [vdx.Size]))
                        s.(propname) = cellstr(prop);
                    elseif isa(prop, "datetime")
                        s.(propname) = datestr(prop, options.datefmt);
                    else
                        s.(propname) = prop;
                    end
                end
            end
        end
        
        function obj_copy = copy(obj)
            % COPY Create a copy of a DATACLASS object
            if ismethod(obj, 'from_struct')
                obj_copy = obj.from_struct(obj.to_struct);
            else
                constructor = str2func(sprintf('%s', class(obj)));
                args = fus.util.struct2args(obj.to_struct);
                obj_copy = constructor(args{:});
            end
        end
        

        function json = to_json(obj)
            % TO_JSON Convert DATACLASS to JSON string
            json = jsonencode(obj.to_struct(), 'PrettyPrint', true);
        end
        
        function to_file(obj, filename)
            % TO_FILE Write DATACLASS to json file
            arguments
                obj (1,1) fus.DataClass
                filename (1,1) string
            end
            json = obj.to_json();
            pth = fileparts(filename);
            if (pth ~= "") && ~exist(pth, 'dir')
                [~] = mkdir(pth);
            end
            f = fopen(filename, 'wt');
            if isequal(f, -1)
                error('Could not open file %s', filename);
            end
            fwrite(f, json);
            fclose(f);
        end
        
        function to_mat(obj, filename)
            % TO_MAT Write DATACLASS to .mat file
            arguments
                obj (1,1) fus.DataClass
                filename (1,1) string
            end
            data = obj.to_struct();
            pth = fileparts(filename);
            if ~exist(pth, 'dir')
                warning("Target path %s does not exist. Creating it.", pth);
                [~] = mkdir(pth);
            end
            save(filename, '-struct', 'data');
        end
        

    end
    
    methods (Access=protected)
        function parse_props(self, props, filter)
            % PARSE_PROPS Parse properties
            arguments
                self
                props (1, 1) struct
                filter (1,:) string = string.empty
            end
            specified_props = fieldnames(props);
            if isempty(filter)
                filtered_props = specified_props;
            else
                filtered_props = filter;
            end
            for i = 1:length(specified_props)
                if ismember(specified_props{i}, filtered_props)
                    self.set_protected(specified_props{i},props.(specified_props{i})); 
                end
            end
        end
        
        function set_protected(self, prop, value)
            % SET_PROTECTED set a protected property (This method is
            % itself protected)
            self.(prop) = value;
        end

    end
    
end
