classdef Axis < fus.DataClass
    % AXIS class for storing coordinate data
    %   axis = AXIS(values, id, 'param', value, ...)
    %   AXIS is a subclass of DataClass for storing coordinate data. It
    %   provides methods for converting between different coordinate
    %   systems and for plotting.
    properties
        values (:,1) double {mustBeNumeric} = [] % Coordinate data
        id string = "" % Coordinate ID
        name string = "" % Coordinate name
        units string = "m" % Coordinate units
    end
    
    methods (Access = public)
        function self = Axis(values, id, props)
            % AXIS create Axis object
            % axis = fus.Axis(values, id, 'param', value, ...)
            %
            % Inputs:
            %    values (1xN double): Coordinate data
            %    id (string): Coordinate ID
            %
            % Optional Parameters:
            %    'name' (string): Coordinate name. Default: ID
            %    'units' (string): Coordinate units. Default: "m"
            %
            % Returns:
            %    axis (fus.Axis): fus.Axis object
            arguments
                values = []
                id string = ""
                props.name string
                props.units string = ""
            end
             if isa(values, 'fus.Axis')
                 self = values;
             else
                self.values = values;
                self.id = id;
                if ~isfield(props, 'name')
                    props.name = id;
                end
                self.parse_props(props)
             end
        end
    
        function add_labels(self, ax)
            % ADD_LABELS add labels to axis
            % axis.add_labels(ax)
            %
            % Inputs:
            %    ax (Axes): Axes to add labels to
            arguments
                self (1,3) fus.Axis
                ax (1,1) {fus.util.mustBeAxes} = gca
            end
            labels = arrayfun(@(x)x.label, self, 'UniformOutput', false);
            xlabel(ax, labels{1});
            ylabel(ax, labels{2});
            zlabel(ax, labels{3});
        end


        function s = to_string(self, props)
            % TO_STRING describe fus.Axis as string
            % s = axis.to_string('param', value, ...)
            %
            % Optional Parameters:
            %    'format' (string): Format string for values. Default: "%g"
            %
            % Returns:
            %    s (string): String description of fus.Axis
            arguments
                self fus.Axis
                props.format string = "%g"
            end
            if self.units == ""
                unit_str = "";
            else
                unit_str = sprintf(" %s", self.units);
            end
            if self.length == 1
                num_str = sprintf(props.format, self.values);
            else
                num_str = join(arrayfun(@(x) sprintf(props.format, x), self.extent), ':');
            end
            s = sprintf('%s = %s%s', self.name, num_str, unit_str);
        end
        
        function ext = extent(self, options)
            % EXTENT get Coordinate extent
            % ext = axis.extent()
            % ext = axis.extent("units", units)
            %
            % Optional Parameters:
            %    'units' (string): Units to use for extent. Default: Coordinate units
            %
            % Returns:
            %    ext (1x2 double): [min, max]
            arguments
                self (1,:) fus.Axis
                options.units (1,1) string {fus.util.mustBeDistance} = self.get_units
            end
            if numel(self) > 1
                ext = arrayfun(@(x)x.extent("units", options.units), self, 'UniformOutput', false);
            else
                scl = fus.util.getunitconversion(self.get_units, options.units);
                ext = [min(self.values);max(self.values)]*scl;
            end
        end
        
        function coord = by_id(self, id)
            % BY_ID get Axis by ID
            % coord = axis.by_id(id)
            %
            % Inputs:
            %    id (string): Coordinate ID(s)
            %
            % Returns:
            %    coord (fus.Axis): Axis with matching ID(s)
            arguments
                self (1,:) fus.Axis
                id (1,:) string {fus.util.mustBeID(id, self)}
            end
            coord = arrayfun(@(id)self(strcmp(id, [self.id])), id);
        end
        
        
        function units = get_units(self)
            % GET_UNITS get Coordinate units
            % units = axis.get_units()
            % GET_UNITS returns the units of the Coordinate. If the
            % Coordinate is an array with multiple units, an error is raised.
            %
            % Returns:
            %    units (string): Coordinate units
            arguments
                self (1,:) fus.Axis
            end
            self_units = [self.units];
            if length(unique(self_units)) > 1
                error('Units do not all match');
            end
            units = self_units{1};
        end
        
        function grid = ndgrid(self, options)
            % NDGRID create ndgrid from Axis
            % grid = axis.ndgrid('param', value, ...)
            %
            % Optional Parameters:
            %    'dims' (string): Coordinate IDs to include in grid. Default: all
            %    'units' (string): Units to use for grid. Default: Coordinate units
            %    'matrix' (4x4 double): Transformation matrix to apply to grid. Default: identity
            %    'vectorize' (logical): Vectorize grid. Default: false
            %
            % Returns:
            %    grid (1x3 cell): cell array of ndgrid matrices
            arguments
                self (1,:) fus.Axis
                options.dims (1,:) string {fus.util.mustBeID(options.dims, self)} = [self.id]
                options.units (1,1) string = self.get_units
                options.matrix (4,4) double = eye(4)
                options.vectorize (1,1) logical = false;
            end
            prev_units = self.units;
            self.rescale(options.units);
            xvecs = {self.values};
            grid = cell(1, numel(self));
            [grid{:}] = ndgrid(xvecs{:});
            if ~isequal(options.matrix, eye(4))
                XYZ = cellfun(@(x)x(:), grid, "UniformOutput", false);
                XYZ = [XYZ{:}]';
                XYZ(4,:) = 1;
                XYZt = options.matrix*XYZ;
                for i = 1:numel(self)
                    grid{i}(:) = XYZt(i,:);
                end
            end
            grid = grid(ismember([self.id],options.dims));
            if options.vectorize
                grid = cellfun(@(x)reshape(x,[],1), grid, 'UniformOutput', false);
            end
            self.rescale(prev_units);
        end
        
        function grid = meshgrid(self, options)
            % MESHGRID create meshgrid from fus.Axis
            % grid = axis.meshgrid('param', value, ...)
            %
            % Optional Parameters:
            %    'dims' (string): Coordinate IDs to include in grid. Default: all
            %    'units' (string): Units to use for grid. Default: Coordinate units
            %    'matrix' (4x4 double): Transformation matrix to apply to grid. Default: identity
            %    'vectorize' (logical): Vectorize grid. Default: false
            %
            % Returns:
            %    grid (1x3 cell): cell array of meshgrid matrices
            arguments
                self (1,:) fus.Axis
                options.dims (1,:) string {fus.util.mustBeID(options.dims, self)} = [self.id]
                options.units (1,1) string = self.get_units
                options.matrix (4,4) double = eye(4)
                options.vectorize (1,1) logical = false;
            end
            prev_units = self.units;
            self.rescale(options.units);
            xvecs = {self.values};
            grid = cell(1, numel(self));
            [grid{:}] = meshgrid(xvecs{:});
            if ~isequal(options.matrix, eye(4))
                XYZ = cellfun(@(x)x(:), grid, "UniformOutput", false);
                XYZ = [XYZ{:}]';
                XYZ(4,:) = 1;
                XYZt = options.matrix*XYZ;
                for i = 1:numel(self)
                    grid{i}(:) = XYZt(i,:);
                end
            end
            grid = grid(ismember([self.id],options.dims));
            if options.vectorize
                grid = cellfun(@(x)reshape(x,[],1), grid, 'UniformOutput', false);
            end
            self.rescale(prev_units);
        end
        
        function text = label(self)
            % LABEL get formatted Coordinate label
            % text = axis.label()
            %
            % Returns:
            %    text (string): Formatted Coordinate label
            if isempty(char(self.units))
                text = self.name;
            else
                text = sprintf('%s (%s)', self.name, self.units);
            end
        end
        
        function len = length(self)
            % LENGTH get Coordinate length
            % len = axis.length()
            %
            % Returns:
            %    len (double): Coordinate length
            len = arrayfun(@(x)length(x.values), self);
        end
        
        function iseq = isequal(coord1, coord2)
            % ISEQUAL check Coordinate equality
            % iseq = axis.isequal(coord1, coord2)
            %
            % Inputs:
            %    coord1 (Coordinate): Coordinate to compare
            %    coord2 (Coordinate): Coordinate to compare
            %
            % Returns:
            %    iseq (logical): true if Coordinates are equal
            iseq = isequal({coord1.values}, {coord2.values}) && isequal(coord1.get_units, coord2.get_units);
        end

       function s = string(coord)
           % STRING get string representation of Coordinate.
           % s = axis.string(coord)
           %
           % Returns:
           %    s (string): string representation of Coordinate
           s = sprintf('[%dx1 coordinate, %s (%s)]', coord.length, coord.name, coord.units);
        end
        
        function varargout = rescale(self,units)
            %RESCALE Convert Coordinate units
            % rescaled_axis = axis.rescale(units)
            % axis.rescale(units)
            %
            % Inputs:
            %   units (string): Units to convert to
            %
            % Returns:
            %   rescaled_axis (Coordinate): rescaled Coordinate. If no output is specified,
            %   the Coordinate is modified in place.
            arguments
                self (1,:) fus.Axis
                units string {fus.util.mustBeDistance}
            end
            if nargout == 1
                self = self.copy();
                varargout{1} = self;
            end
            if numel(self) > 1
                for i = 1:numel(self)
                    coord = self(i);
                    coord.rescale(units)
                end
            else
                if isempty(char(self.units))
                    self.units = units;
                else
                    scl = fus.util.getunitconversion(self.get_units,units);
                    self.units = units;
                    self.values = self.values*scl;
                end
            end
        end
    end
    
    methods (Static)
        function coord = from_struct(s)
            % FROM_STRUCT create Coordinate from struct
            % coord = axis.from_struct(s)
            %
            % Inputs:
            %    s (struct): struct with fields 'values', 'id', and optional fields
            %
            % Returns:
            %    coord (Coordinate): Coordinate
            arguments
                s struct
            end
            if numel(s) > 1
                coord = arrayfun(@(x)fus.Axis.from_struct(x), s);
            else
                values = s.values;
                id = s.id;
                props = rmfield(s, {'values', 'id'});
                args = fus.util.struct2args(props);
                coord = fus.Axis(values, id, args{:});
            end
        end
    end
end