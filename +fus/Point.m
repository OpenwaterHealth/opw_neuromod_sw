classdef Point < fus.DataClass
    %POINT A spherical point (or points) in 3D space
    properties
        id string = "point" % A unique identifier for the point
        name string = "" % A human-readable name for the point
        color (1,3) double {mustBeNonnegative, mustBeLessThanOrEqual(color, 1)} = [1, 0, 0] % The color of the point
        radius (1,1) double {mustBeNonnegative} = 1 % The radius of the point
        position (3,:) double = [0;0;0] % The position of the point
        dims (1,3) string {mustBeValidVariableName} = ["x","y","z"] % The dimension IDs of the point
        units string = "mm" % The units of the point
    end
    
    methods
        function self = Point(options)
            % POINT Construct a point
            %   pt = fus.Point("param", value) constructs a point with the
            %   specified parameters. The parameters are:
            %
            % Optional Parameters:
            %    'id' (string): A unique identifier for the point
            %    'name' (string): A human-readable name for the point
            %    'color' (float): 3-Element color of the point
            %    'radius' (float): The radius of the point
            %    'position' (float): 3xN position of the point
            %    'dims' (string): 3-Element dimension IDs of the point
            %    'units' (string): The units of the point
            %
            % Returns:
            %    fus.Point: A Point object
            arguments
                options.?fus.Point
                options.position double = [0;0;0]
            end
            if isequal(size(options.position),[1 3])
                options.position = options.position(:);
            end
            parse_props(self, options);
        end
        
        function ids = all_ids(self)
            % ALL_IDS Get all point IDs
            %  ids = pt.all_ids() returns a list of all point IDs
            %
            % Returns:
            %    ids: A string array of all point IDs
            arguments
                self (1,:) fus.Point
            end
            ids = [self.id];
        end
        
        function pt = by_id(self, id)
            % BY_ID Get a point by ID
            %  pt = pt.by_id(id) returns the point with the specified ID
            %
            % Inputs:
            %    'id' (string): The ID of the point to return
            %
            % Returns:
            %    pt: The point with the specified ID
            arguments
                self (1,:) fus.Point
                id (1,:) string {fus.util.mustBeID(id, self)}
            end
            pt = arrayfun(@(x)self(strcmp(x, self.all_ids)), id);
        end
        
        function section = get_crossection(self, dim, value, options)
            % GET_CROSSSECTION Get a cross-section of the point
            %  section = pt.get_crossection(dim, value) returns a
            %  cross-section of the point at the specified value along the
            %  specified dimension. 
            %
            % Inputs:
            %    'dim' (string): The dimension to slice along
            %    'value' (float): The value to slice at
            %
            % Optional Parameters:
            %    'units' (string): The units of the value
            %    'extent' (cell): The 3D extent of the volume to which to
            %        crop the cross-section
            %    'tail_length' (float): The length of the tail (as a
            %        fraction of the radius)
            %
            % Returns:
            %    section: A cell array of the cross-section coordinates
            arguments
                self fus.Point
                dim (1,1) string {fus.util.mustBeDim(dim, self)}
                value (1,1) double
                options.units (1,1) string {fus.util.mustBeDistance} = self.get_units
                options.extent (1,3) cell = {[-inf inf],[-inf inf],[-inf inf]}
                options.tail_length (1,1) double {mustBePositive} = 0.1
            end
            p = self.rescale(options.units);
            xydims = p.dims(p.dims ~= dim); 
            xyext = options.extent(p.dims ~= dim); 
            dz = abs(value - p.get_position(dim));
            rz = sqrt(max(0,p.radius^2 - dz^2));
            rz1 = p.radius*(1+options.tail_length);
            x = [];
            y = [];
            th = [0, linspace(0, pi/2, 18), pi/2];
            x0 = p.get_position(xydims{1});
            y0 = p.get_position(xydims{2});
            for q = (0:3)*pi/2
                thq = th + q;
                xq = x0+rz*cos(thq);
                xq(1) = x0+rz1*cos(thq(1));
                xq(end) = x0+rz1*cos(thq(end));
                yq = y0+rz*sin(thq);
                yq(1) = y0+rz1*sin(thq(1));
                yq(end) = y0+rz1*sin(thq(end));
                x = [x, xq];
                y = [y, yq];
            end 
            s.(xydims{1}) = x;
            s.(xydims{2}) = y;
            s.(dim) = value*ones(size(x));
            inbounds = true(size(x));
            for i = 1:2
                x = s.(xydims{i});
                ext = xyext{i};
                inbounds(x<ext(1) | x>ext(2)) = false;
            end
            section = arrayfun(@(dim)s.(dim)(inbounds), p.dims, 'UniformOutput', false);
        end
        
        function units = get_units(self)
            % GET_UNITS Get the units of the point
            %  units = pt.get_units() returns the units of the point
            %
            % Returns:
            %    units: The units of the point
            arguments
                self (1,:) fus.Point
            end
            self_units = [self.units];
            if length(unique(self_units)) > 1
                error('Units do not all match');
            end
            units = self_units{1};
        end
        
        function pos = get_position(self, dim, options)
            % GET_POSITION Get the position of the point
            %  pos = pt.get_position(dim) returns the position of the point
            %  along the specified dimension
            %
            % Inputs:
            %    'dim' (string): The dimension to get the position along
            %
            % Optional Parameters:
            %    'units' (string): The units of the position
            %
            % Returns:
            %    pos: The position of the point along the specified
            %        dimension
            arguments
                self fus.Point
                dim (1,:) string {fus.util.mustBeDim(dim, self)} = self.dims
                options.units (1,1) string {fus.util.mustBeDistance} = self.get_units
            end
            index = arrayfun(@(x)find(self.dims == x), dim);
            scl = fus.util.getunitconversion(self.units, options.units);
            pos = [self.position(index,:)]*scl;
        end
                
        function varargout = rescale(self, units)
            % RESCALE Rescale the point
            %  pt = pt.rescale(units) rescales the point to the specified
            %  units
            %
            % Inputs:
            %    'units' (string): The units to rescale to
            %
            % Returns:
            %    pt: The rescaled point
            arguments
                self fus.Point
                units (1,1) string {fus.util.mustBeDistance}
            end
            if nargout == 1
                self = self.copy();
                varargout{1} = self;
            end
            for i = 1:length(self)
                point = self(i);
                if isempty(point.units)
                    point.units = units;
                else
                    scl = fus.util.getunitconversion(point.units, units);
                    point.units = units;
                    point.position = point.position*scl;
                    point.radius = point.radius*scl;
                end
            end
        end
        
        function t = transform(self, matrix, options)
            % TRANSFORM Transform the point
            %  t = pt.transform(matrix) transforms the point by the
            %      specified matrix
            %
            % Inputs:
            %    'matrix' (4,4) double: The transformation matrix
            %
            % Optional Parameters:
            %    'units' (string): The units of the point
            %    'dims' (1,3) string: The dimensions of the point
            %
            % Returns:
            %    t: The transformed point
            arguments
                self fus.Point
                matrix (4,4) double
                options.units (1,1) string {fus.util.mustBeDistance} = self.get_units
                options.dims (1,3) string = self.dims
            end
            switch numel(self)
                case 0
                    t = fus.Point.empty;
                case 1
                    t = self.copy();
                    t.rescale(options.units);
                    transformed_position = matrix \ [t.position;ones(1, size(t.position,2))];
                    t.position = transformed_position(1:3,:);
                    t.dims = options.dims;
                otherwise
                    args = fus.util.struct2args(options);
                    t = arrayfun(@(x)x.transform(matrix, args{:}), self);
            end
        end
        
        function h = draw(self, options)
            % DRAW Draw the point
            %  h = pt.draw("param1", val1,...) draws the point
            %
            % Optional Parameters:
            %    'ax' (axes): The axes to draw in
            %    'N' (int): The precision of the sphere. Default: 64
            %    'scale' (double): The scale of the sphere. Default: 1
            %    'units' (string): units to rescale to
            %    *args: Any additional arguments are passed to the
            %        SURF function
            %
            % Returns:
            %    h: The handle to the drawn point
            arguments
                self fus.Point
                options.?matlab.graphics.chart.primitive.Surface
                options.ax = gca
                options.N (1,1) double {mustBeInteger, mustBeGreaterThan(options.N, 4)} = 64
                options.scale (1,1) double = 1;
                options.units (1,1) string {fus.util.mustBeDistance} = self.units
            end
            if length(self)>1
                args = fus.util.struct2args(options);
                h = arrayfun(@(x) x.draw(args{:}), self, "UniformOutput", false);
                h = cat(1,h{:})';
            else
                self = self.rescale(options.units);
                [X0,Y0,Z0] = sphere(options.N);
                X = X0*self.radius*options.scale;
                Y = Y0*self.radius*options.scale;
                Z = Z0*self.radius*options.scale;
                if ~isfield(options, 'FaceColor')
                    options.FaceColor = self.color;
                end
                if ~isfield(options, 'EdgeColor')
                    options.EdgeColor = 'None';
                end
                if ~isfield(options, 'DisplayName')
                    options.DisplayName = self.name;
                end
                args = fus.util.struct2args(rmfield(options, {'N', 'scale', 'ax', 'units'}));
                for i = 1:size(self.position,2)
                    h(i) = surf(...
                        options.ax, ...
                        X + self.position(1,i),...
                        Y + self.position(2,i),...
                        Z + self.position(3,i),...
                        args{:});
                end
            end
        end
        
        function h = plot(self, options)
            % PLOT Plot the point
            %  h = pt.plot("param1", val1,...) plots the point
            %
            % Optional Parameters:
            %    'ax' (axes): The axes to draw in
            arguments
                self fus.Point
                options.?matlab.graphics.chart.primitive.Line
                options.ax = gca
            end
            args = fus.util.struct2args(rmfield(options, "ax"));
            if length(self)>1
                h = arrayfun(@(x) x.plot("ax", options.ax, args{:}), self, "UniformOutput", false);
                h = cat(1,h{:})';
            else
                h = plot3(options.ax, self.position(1,:), self.position(2,:), self.position(3,:), args{:});
            end
        end
       
    end
    
    methods (Static)
        function p = from_struct(s)
            % FROM_STRUCT Create a point from a struct
            %  p = fus.Point.from_struct(s) creates a point from a struct
            %
            % Inputs:
            %    's' (1,:) struct: The struct to create the point from
            %
            % Returns:
            %    p: The created Point
            arguments
                s (1,:) struct
            end
            if numel(s) > 1
                p = arrayfun(@fus.Point.from_struct, s);
            else
                if isempty(s.id)
                    p = fus.Point.empty;
                else
                    args = fus.util.struct2args(s);
                    p = fus.Point(args{:});
                end
            end
        end
    end
end