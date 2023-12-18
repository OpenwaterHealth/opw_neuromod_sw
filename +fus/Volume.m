classdef Volume < fus.DataClass
    % VOLUME 3D data with coordinates
    % vol = Volume(data, coords, "param", value, ...)
    properties
        id (1,1) string {mustBeValidVariableName} = "volume" % Volume ID
        name (1,1) string = "volume" % Volume name
        data {mustBeNumeric} = [] % Volumetric Data
        coords (1,3) fus.Axis % Coordinates of data
        matrix double {mustBeNumeric, fus.util.mustBe4x4} = eye(4) % Transformation matrix
        attrs struct = struct() % Additional Attributes
        units string = "" % Units of data
    end
    
    properties(GetAccess=private, SetAccess=immutable)
        newobj = @fus.Volume.new
    end
    
    methods
        function self = Volume(data, coords, options)
            % VOLUME Constructor for Volume
            % vol = Volume(data, coords, "param", value, ...)
            % A VOLUME is a 3D data object with sptial coordinates and orientation.
            % This class allows for access and operations on the volume data to be
            % specified based on the coordinate IDs and values, without having to 
            % perform complex indexing/slicing operations. Methods are provided for 
            % data slicing, introspection, transformation, plotting, and more.
            %
            % Inputs:
            %   data (numeric) - 3D array of data
            %   coords (fus.Axis) - (1x3) array of fus.Axis objects, matching the size of data
            %
            % Optional Parameters:
            %   'id' (string): ID of volume. Default: 'volume'
            %   'name' (string): Name of volume. Default: ID
            %   'matrix' (double): 4x4 transformation matrix. Default: eye(4)
            %   'attrs' (struct): Additional attributes. Default: struct()
            %   'units' (string): Units of data. Default: ''
            %
            % Returns:
            %   vol (fus.Volume): Volume object
            arguments
                data {mustBeNumeric} = []
                coords (1,3) fus.Axis = [fus.Axis, fus.Axis, fus.Axis]
                options.id string {mustBeValidVariableName}
                options.name string
                options.matrix double {mustBeNumeric, fus.util.mustBe4x4} = eye(4)
                options.attrs struct
                options.units string {}
            end
            self.data = data;
            self.coords = coords;
            self.parse_props(options);
            if ~isfield(options, "id") && isfield(options, "name")
                self.id = genvarname(fus.util.sanitize(options.name, 'snake'));
            end
            if ~isfield(options, "name") && isfield(options, "id")
                self.name = options.id;
            end
        end
        
        function ids = all_ids(self)
            % ALL_IDS Return all IDs of Volume array
            % ids = vol.all_ids()
            %
            % Returns:
            %   ids (1,:) string: IDs of Volumes
            arguments
                self (1,:) fus.Volume
            end
            ids = [self.id];
        end
        
        function agg_obj = agg(self, func, options)
            % AGG Aggregate data across Volume array
            % agg_obj = vol.agg(func, "param", value, ...)
            % Aggregate data across a Volume array using a function handle.
            % The function handle must accept a 1D array as input, and return a
            % scalar value. The function will be applied to each voxel across the
            % array, and the result will be returned as a new Volume object.
            %
            % Inputs:
            %   func (function_handle): Function to apply to data
            %
            % Optional Parameters:
            %   'args' (cell): Additional arguments to pass to function
            %   'id' (string): ID of new Volume. Default: 'agg'
            %   'name' (string): Name of new Volume. Default: ID of function
            %
            % Returns:
            %   agg_obj (fus.Volume): Aggregated Volume
            arguments
                self (1,:) fus.Volume
                func function_handle
                options.args (1,:) cell = {}
                options.id (1,1) string {mustBeValidVariableName}
                options.name (1,1) string
            end
            if ~isfield(options, 'id')
                if isfield(options, 'name')
                    options.id = fus.util.sanitize(options.name, 'snake');
                else
                    s = functions(func);
                    options.id = genvarname(fus.util.sanitize(s.function, 'snake'));
                    options.name = s.function;
                end
            elseif ~isfield(options.name)
                options.name = options.id;
            end
            agg_obj = self(1).copy();
            data_cell = {self.data};
            data_mat = cat(4, data_cell{:});
            sz = self.shape;
            for i = 1:sz(1)
                for j = 1:sz(2)
                    for k = 1:sz(3)
                        agg_obj.data(i,j,k) = func(data_mat(i,j,k,:), options.args{:});
                    end
                end
            end
            agg_obj.id = options.id;
            agg_obj.name = options.name;
        end
        
        function vol = by_id(self, id)
            % BY_ID Return Volume by ID(s)
            % vol = vol.by_id(id)
            %
            % Inputs:
            %   id (string): ID(s) of Volume
            %
            % Returns:
            %   vol (fus.Volume): Volume with matching ID(s)
            arguments
                self (1,:) fus.Volume
                id (1,:) string {fus.util.mustBeID(id, self)}
            end
            vol = arrayfun(@(id)self(strcmp(id, [self.id])), id);
        end
        
        function obj = copy(self)
            % COPY Copy Volume
            % obj = vol.copy()
            %
            % Returns:
            %   obj (fus.Volume): Copy of Volume
            if numel(self) > 1
                obj = arrayfun(@(x)x.copy(), self);
            else
                obj = fus.Volume.from_struct(self.to_struct());
            end
        end
               
        function id = dim_id(self, dim)
            % DIM_ID Return ID of Volume dimension
            % id = vol.dim_id(dim)
            %
            % Inputs:
            %   dim (string, numeric): Dimension ID or index
            %
            % Returns:
            %   id (string): ID of dimension
            if isempty(dim)
                id = [];
            elseif isnumeric(dim)
                id = self.dims(dim);
            elseif ismember(dim, self.dims)
                id = dim;
            else
                error('No matching dim');
            end
        end
        
        function vol = crop(self, dim, range)
            % CROP Crop Volume along dimension
            % vol = vol.crop(dim, range)
            %
            % Inputs:
            %   dim (string): Dimension ID
            %   range (1,2) double: Range of values to keep
            %
            % Returns:
            %   vol (fus.Volume): Cropped Volume
            arguments
                self fus.Volume
                dim (1,1) string {fus.util.mustBeDim(dim,self)}
                range (1,2) double
            end
            coord = self.coords.by_id(dim);
            idx = find(coord.values>=range(1) & coord.values<=range(2));
            vol = self.isel(dim, idx);
        end
        
        function index = dim_index(self, dim)
            % DIM_INDEX Return index of Volume dimension
            % index = vol.dim_index(dim)
            %
            % Inputs:
            %   dim (string, numeric): Dimension ID or index
            %
            % Returns:
            %   index (1,1) double: Index of dimension
            if isnumeric(dim)
                index = self.ndim.*(dim<=0) + dim;
                if any(index <=0) || any(index > self.ndim)
                    error('Invalid dim %0.0f', dim);
                end
            else
                index = find(strcmp(self.dims, dim));
                if isempty(index)
                    error('Invalid dim "%s"', dim);
                end
            end
        end
        
        function d = dims(self, index)
            % DIMS Return Volume dimensions
            % d = vol.dims(index)
            %
            % Inputs:
            %   index (1,:) double: Dimension index. Default: 1:3 (all dims)
            %
            % Returns:
            %   d (1,:) string: Dimension IDs
            arguments
                self fus.Volume
                index (1,:) double {mustBeInteger} = 1:3
            end
            if numel(self) > 1
                d = arrayfun(@(x)x.dims(index), self, 'UniformOutput', false);
                if all(cellfun(@(x) isequal(x, d{1}), d))
                    d = d{1};
                else
                    error('Volumes do not share dimensions');
                end 
            else
                d = [self.coords(index).id];
            end
        end
               
        function [h, cb] = draw_image(self, mapper, options)
            % DRAW_IMAGE Draw Volume as image
            % [h, cb] = vol.draw_image(mapper, "param", value, ...)
            % DRAW_IMAGE Draws a volume that has been sliced to a single plane
            % as an image, according to the specified ColorMapper.
            %
            % Inputs:
            %   mapper (fus.ColorMapper): 1xN ColorMapper object (the same length as the Volume)
            %
            % Optional Parameters:
            %   'xdim' (string): Dimension ID to use for x-axis. Default: "" (auto)
            %   'ydim' (string): Dimension ID to use for y-axis. Default: "" (auto)
            %   'ax' (axes): Axes to draw on
            %   'colorbar_ax' (axes): Axes to draw colorbar on
            %   'colorbar' (logical): Whether to draw colorbar
            %   'colorbar_index' (double): Index of ColorMapper to use for colorbar
            %   'colorbar_width' (double): Width of colorbar
            %   'colorbar_range' (double): Range of colorbar
            %
            % Returns:
            %   h (image): Image handle
            %   cb (colorbar): Colorbar handle
            arguments 
                self (1,:) fus.Volume
                mapper (1,:) fus.ColorMapper = self.auto_colormap()
                options.xdim string {fus.util.mustBeDimOrEmpty(options.xdim, self)} = ""
                options.ydim string {fus.util.mustBeDimOrEmpty(options.ydim, self)} = ""
                options.ax  = []
                options.colorbar_ax = []
                options.colorbar logical = true
                options.colorbar_index double {mustBeInteger} = 1
                options.colorbar_width double {mustBeInRange(options.colorbar_width, .0001, .9)} = 0.05
                options.colorbar_range double = []
            end
            if options.colorbar
                [ax, cbax] = self.get_axes(options.ax, options.colorbar_ax, options.colorbar_width);
            else
                if isempty(options.ax)
                    ax = gca();
                else
                    ax = options.ax;
                end
            end
            [xdim, ydim] = self.get_xy("xdim", options.xdim, "ydim", options.ydim);
            [rgb, alpha] = self.get_image(mapper, "xdim", options.xdim, "ydim", options.ydim);
            x = self.get_coord(xdim);
            y = self.get_coord(ydim);
            h = image(ax, x.values, y.values, rgb, 'AlphaData', alpha, 'AlphaDataMapping', 'None');
            xlabel(ax, x.label);
            ylabel(ax, y.label);
            axes(ax);
            if options.colorbar
                cb = self(mod(options.colorbar_index-1, length(self))+1).draw_colorbar(ax, cbax, mapper(mod(options.colorbar_index-1, length(self))+1), options.colorbar_range);
                hlink = linkprop([ax, cbax], 'Color');
                cb.UserData.hlink = hlink;
            else
                cb = [];
            end
        end
        
        function [h, cb] = draw_surface(self, mapper, options)
            % DRAW_SURFACE Draw Volume as surface
            % [h, cb] = vol.draw_surface(mapper, "param", value, ...)
            % DRAW_SURFACE Draws a volume that has been sliced to a single plane
            % as a surface, according to the specified ColorMapper.
            %
            % Inputs:
            %   mapper (fus.ColorMapper): 1xN ColorMapper object (the same length as the Volume)
            %
            % Optional Parameters:
            %   'xdim' (string): Dimension ID to use for x-axis. Default: "" (auto)
            %   'ydim' (string): Dimension ID to use for y-axis. Default: "" (auto)
            %   'zdim' (string): Dimension ID to use for z-axis. Default: "" (auto)
            %   'dim' (string): Dimension ID to use for slicing. Defaults to the smallest dimension.
            %   'ax' (axes): Axes to draw on
            %   'colorbar_ax' (axes): Axes to draw colorbar on
            %   'colorbar' (logical): Whether to draw colorbar
            %   'colorbar_index' (double): Index of ColorMapper to use for colorbar
            %   'colorbar_width' (double): Width of colorbar
            %   'colorbar_range' (double): Range of colorbar
            %
            % Returns:
            %   h (surface): Surface handle
            %   cb (colorbar): Colorbar handle
            arguments
                self fus.Volume
                mapper (1,:) fus.ColorMapper = self.auto_colormap() % Color-transparency map
                options.xdim string {fus.util.mustBeDimOrEmpty(options.xdim, self)} = "" % X dimension
                options.ydim string {fus.util.mustBeDimOrEmpty(options.ydim, self)} = "" % Y dimension
                options.zdim string {fus.util.mustBeDimOrEmpty(options.zdim, self)} = "" % Z dimension
                options.dim string {fus.util.mustBeDimOrEmpty(options.dim, self)} = "" % slicing dimension
                options.ax = [] % Existing axes
                options.transform {mustBeNumericOrLogical} = false % Transform to global coordinates
                options.colorbar {mustBeNumericOrLogical} = true % Draw colorbar
                options.colorbar_index double {mustBeInteger} = 1 % fus.Volume index to use for colobar
                options.colorbar_ax = [] % Existing colorbar axes
                options.colorbar_width double {mustBeNumeric, mustBePositive} = 0.05 %Relative width of colorbar axis
                options.colorbar_range double {mustBeNumeric} = [] % Colorbar extent
                options.outline = "None" % Controls EdgeColor
                options.legend_format string = "%g" % Format for legend numbers
            end
            if options.colorbar
                [ax, cbax] = self.get_axes(options.ax, options.colorbar_ax, options.colorbar_width);
            elseif isempty(options.ax)
                ax = gca();
            else
                ax = options.ax;
            end 
            isheld = ishold(ax);
            if length(self.dims) < 3
                error('Data must have at least 3-dimensions')
            end
            [xdim, ydim, zdim] = self.get_xyz(...
                "xdim", options.xdim, ...
                "ydim", options.ydim, ...
                "zdim", options.zdim);
            if isempty(options.dim) || options.dim==""
                options.dim = self.dims(find(self.shape==min(self.shape),1));
            end
            xyzdims = [xdim, ydim, zdim];
            dimi = arrayfun(@self.dim_index, xyzdims);
            for slice_index = 1:self.shape(options.dim)
                vx = self.isel(options.dim, slice_index);
                [rgb, alpha] = vx.get_image_3d(...
                    mapper, ...
                    "xdim", options.xdim, ...
                    "ydim", options.ydim, ...
                    "zdim", options.zdim); 
                Xe = vx.get_edges('order', dimi, 'transform', options.transform);
                all_coords = vx.get_coords;
                x = all_coords(dimi);
                coord = x(x.length==1);
                h(slice_index) = surf(ax, Xe{:}, squeeze(rgb), ...
                    'FaceColor', 'texturemap', ...
                    'EdgeColor', options.outline, ...
                    'FaceAlpha', 'texturemap', ...
                    'AlphaData', squeeze(alpha), ...
                    'AlphaDataMapping', 'None', ...
                    'DisplayName', coord.to_string("format", options.legend_format));
                hold(ax,'all')
            end
            if ~options.transform
                xlabel(ax, x(1).label);
                ylabel(ax, x(2).label);
                zlabel(ax, x(3).label);
            end
            if options.colorbar
                cb = self(mod(options.colorbar_index-1, length(self))+1).draw_colorbar(ax, cbax, mapper(mod(options.colorbar_index-1, length(self))+1), options.colorbar_range);
                hlink = linkprop([ax, cbax], 'Color');
                cb.UserData.hlink = hlink;
            else
                cb = [];
            end
            if ~isheld
                hold(ax,'off')
            end
        end
        
        function attrs = get_attrs(self)
            % GET_ATTRS Get attributes of Volume
            % attrs = vol.get_attrs()
            %
            % Returns:
            %   attrs (struct): Attributes of Volume
            arguments
                self fus.Volume
            end
            attrs = [self.attrs];
        end
        
        function coord = get_coord(self, dim)
            % GET_COORD Get coordinates of Volume
            % coord = vol.get_coord(dim)
            % GET_COORD retruns a Coord object for the given dimension.
            % If the Volume is an array, the coordinates must be the same
            % for all elements.
            %
            % Inputs:
            %   dim (string or index): Dimension ID
            %
            % Returns:
            %   coord (fus.Axis): Coordinates of Volume
            arguments
                self fus.Volume
                dim
            end
            if numel(self) > 1
                c = arrayfun(@(x)x.get_coord(dim), self, 'UniformOutput', false);
                if all(cellfun(@(x) isequal(x, c{1}), c))
                    coord = c{1};
                else
                    error('Volumes do not share coordinates');
                end
            else                
                coord = self.coords.by_id(dim);
            end
        end
        
        function coords = get_coords(self, dims)
            arguments
                self fus.Volume
                dims (1,:) string {fus.util.mustBeDim(dims, self)} = self.dims
            end
            % GET_COORDS Get coordinates of Volume
            % coords = vol.get_coords()
            % coords = vol.get_coords(dims)
            % GET_COORDS retruns a Coord object for each dimension of the
            % Volume. If the Volume is an array, the coordinates must be
            % the same for all elements.
            %
            % Inputs:
            %   dims (1,N) string: Dimension IDs. Default all dims
            %
            % Returns:
            %   coords (fus.Axis): Coordinates of Volume
            coords = self.get_coord(dims);
        end

        function Xe = get_edges(self, options)
            % GET_EDGES Get edges of Volume
            % Xe = vol.get_edges()
            % Xe = vol.get_edges("param", value)
            %
            % Optional Parameters:
            %   'order' (double): Order of dimensions. Default: [1, 2, 3]
            %   'transform' (logical): Transform to global coordinates. Default: false
            %   'units' (string): Units of edges. Default: vol.get_units()
            %
            % Returns:
            %   Xe (cell): Cell array with NDgrid of edge bounds
            arguments
                self fus.Volume
                options.order (1,:) {mustBeMember(options.order, [1,2,3])} = [1, 2, 3]
                options.transform (1,1) logical = false
                options.units (1,1) string = self.get_units
            end
            all_coords = self.get_coords().rescale(options.units);
            xdata = {all_coords(options.order).values};
            xedges = cell(1,length(xdata));
            for j = 1:length(xdata)
                xj = xdata{j};
                if length(xj)>1
                    dxi = diff(xj);
                    dx = mean(dxi);
                    xedges{j} = [xj(1)-dx/2 xj(end)+dx/2];
                else
                    xedges{j} = xj;
                end
            end
            Xe = cell(1,length(xdata));
            [Xe{:}] = ndgrid(xedges{:});
            Xe = cellfun(@squeeze, Xe, 'UniformOutput', false);
            sz = num2cell(size(Xe{1}));
            if options.transform
                Xe1 = cell2mat(reshape(Xe, 1, 1, 1, 3));
                Xe1 = reshape(Xe1,[],3)';
                Xe1(4,:) = 1;
                Xtf = self.get_matrix("units", options.units) * Xe1;
                Xtf = reshape(Xtf(1:3,:)', [sz{:} 3]);
                Xe = reshape(mat2cell(Xtf, sz{:}, ones(1,3)),1,3);
            end
        end
        
        function [rgb, alpha] = get_image(self, mapper, options)
            % GET_IMAGE Get image data of Volume
            % [rgb, alpha] = vol.get_image(mapper)
            % [rgb, alpha] = vol.get_image(mapper, "param", value, ...)
            %
            % Inputs:
            %   mapper (fus.ColorMapper): ColorMapper to use for mapping data to color.
            %       must be same length as Volume.
            %
            % Optional Parameters:
            %   'xdim' (string): Dimension ID for x-axis. Default: "" (auto)
            %   'ydim' (string): Dimension ID for y-axis. Default: "" (auto)
            %
            % Returns:
            %   rgb (double): RGB image data
            %   alpha (double): Alpha image data
            arguments
                self (1,:) fus.Volume
                mapper (1,:) fus.ColorMapper = self.auto_colormap()
                options.xdim string {fus.util.mustBeDimOrEmpty(options.xdim, self)} = ""
                options.ydim string {fus.util.mustBeDimOrEmpty(options.ydim, self)} = ""
            end
            [xdim, ydim] = self.get_xy("xdim", options.xdim, "ydim", options.ydim);
            dimi = arrayfun(@self.dim_index, [ydim, xdim]);
            order = 1:self.ndim;
            order(dimi) = [];
            if ~isempty(order) && any(shape(self, order)~=1)
                error('Data must be singleton in all non-axis dimensions');
            end
            order = [dimi, order];
            
            for i = 1:numel(self)
                cdata = permute(self(i).data, order);
                rgb_cell{i} = mapper(mod(i-1, numel(mapper))+1).map_RGB(cdata);
                alpha_cell{i} = mapper(mod(i-1, numel(mapper))+1).map_alpha(cdata);
            end
            
            rgb = rgb_cell{1};
            alpha = alpha_cell{1};
            for j = 2:length(rgb_cell)
                fg = alpha_cell{j};
                bg = alpha .* (1-alpha_cell{j});
                rgb = ((rgb .* bg)./(fg + bg)) + ...
                      (rgb_cell{j} .* (fg ./ (fg + bg)));
                alpha = alpha .* (1-alpha_cell{j}) + (alpha_cell{j});
            end
        end
        
        function [rgb, alpha] = get_image_3d(self, mapper, options)
            % GET_IMAGE_3D Get 3D image data of Volume
            % [rgb, alpha] = vol.get_image_3d(mapper)
            % [rgb, alpha] = vol.get_image_3d(mapper, "param", value, ...)
            %
            % Inputs:
            %   mapper (fus.ColorMapper): ColorMapper to use for mapping data to color.
            %       must be same length as Volume.
            %
            % Optional Parameters:
            %   'xdim' (string): Dimension ID for x-axis. Default: "" (auto)
            %   'ydim' (string): Dimension ID for y-axis. Default: "" (auto)
            %   'zdim' (string): Dimension ID for z-axis. Default: "" (auto)
            %
            % Returns:
            %   rgb (double): RGB image data (MxNxPx3)
            %   alpha (double): Alpha image data (MxNxP)
            arguments
                self (1,:) fus.Volume
                mapper (1,:) fus.ColorMapper = self.auto_colormap()
                options.xdim string {fus.util.mustBeDimOrEmpty(options.xdim, self)} = ""
                options.ydim string {fus.util.mustBeDimOrEmpty(options.ydim, self)} = ""
                options.zdim string {fus.util.mustBeDimOrEmpty(options.zdim, self)} = ""
                
            end
            [xdim, ydim, zdim] = self.get_xyz(...
                "xdim", options.xdim, ...
                "ydim", options.ydim, ...
                "zdim", options.zdim);
            dimi = arrayfun(@self.dim_index, [xdim, ydim, zdim]);
            order = 1:self.ndim;
            order(dimi) = [];
            if ~isempty(order) && any(shape(self, order)~=1)
                error('Data must be singleton in all non-axis dimensions');
            end
            order = [dimi, order];
            
            for i = 1:numel(self)
                cdata = permute(self(i).data, order);
                rgb_cell{i} = mapper(mod(i-1, numel(mapper))+1).map_RGB(cdata,4);
                alpha_cell{i} = mapper(mod(i-1, numel(mapper))+1).map_alpha(cdata);
            end
            
            rgb = rgb_cell{1};
            alpha = alpha_cell{1};
            for j = 2:length(rgb_cell)
                fg = alpha_cell{j};
                bg = alpha .* (1-alpha_cell{j});
                rgb = ((rgb .* bg)./(fg + bg)) + ...
                      (rgb_cell{j} .* (fg ./ (fg + bg)));
                alpha = alpha .* (1-alpha_cell{j}) + (alpha_cell{j});
            end
        end
        
        function text = get_label(self)
            % GET_LABEL Get label for Volume
            % text = vol.get_label()
            % GET_LABEL Returns a label in the format of "name (units)".
            %
            % Returns:
            %   text (string): Label for Volume
            if numel(self)>1
                text = string(arrayfun(@(x)x.get_label(), self, 'UniformOutput', false));
            else
                if isempty(char(self.units))
                    text = self.name;
                else
                    text = sprintf('%s (%s)', self.name, self.units);
                end
            end
        end
        
        function matrix = get_matrix(self, options)
            % GET_MATRIX Get transform matrix for Volume
            % matrix = vol.get_matrix()
            % matrix = vol.get_matrix("param", value, ...)
            %
            % Optional Parameters:
            %   'units' (string): Units to return matrix in. Default: self.get_units
            %
            % Returns:
            %   matrix (double): 4x4 transform matrix
            arguments
                self fus.Volume
                options.units (1,1) string = self.get_units;
            end
            if numel(self) > 1
                M = {self.matrix};
                if all(cellfun(@(x)isequal(x, M{1}), M))
                    matrix = M{1};
                else
                    error('Volumes do not share transform matrix')
                end
            else
                matrix = self.matrix;
            end 
            scl = fus.util.getunitconversion(self.get_units, options.units);
            matrix(1:3,4) = matrix(1:3,4)*scl;
        end
                        
        function units = get_units(self)
            % GET_UNITS Get units for Volume coordinates
            % units = vol.get_units()
            %
            % Returns:
            %   units (string): Units of Volume coordinates
            if numel(self) > 1
                u = arrayfun(@(x)x.get_units(), self, 'UniformOutput', false);
                if all(cellfun(@(x) isequal(x, u{1}), u))
                    units = u{1};
                else
                    error("Volumes' coordinates do not share units");
                end
            else
                units = self.coords.get_units();
            end
        end
        
        function [xdim,ydim] = get_xy(self, options)
            %GET_XY get the squeezed X and and Y dims of a sliced Volume
            % [xdim, ydim] = vol.get_xy()
            % [xdim, ydim] = vol.get_xy("param", value, ...)
            % GET_XY looks for the first two dimensions that are non-singleton
            % and returns their dimension IDs. If either dimension is provided, 
            % only the other is inferred.
            %
            % Optional Parameters:
            %   'xdim' (string): Dimension ID for x-axis. Default: "" (auto)
            %   'ydim' (string): Dimension ID for y-axis. Default: "" (auto)
            %
            % Returns:
            %   xdim (string): Dimension ID for x-axis
            %   ydim (string): Dimension ID for y-axis
            arguments
                self fus.Volume
                options.xdim string {fus.util.mustBeDimOrEmpty(options.xdim, self)} = ""
                options.ydim string {fus.util.mustBeDimOrEmpty(options.ydim, self)} = ""
            end
             if length(self.dims) < 2
                error('Data must have at least 2-dimensions')
            end
            xydims = [options.xdim, options.ydim];
            listed_dims = xydims(arrayfun(@(x)~isequal(x,""),xydims));
            if length(unique(listed_dims)) < length(listed_dims)
                error('Must specify unique dimensions')
            end
            order = 1:self.ndim;
            order(cellfun(@self.dim_index, listed_dims)) = [];
            nonsingleton = self.get_coords.length > 1;
            if length(order) > 2 && sum(nonsingleton) > 1
                order = order(nonsingleton);
            end 
            for i = 1:length(xydims)
                if isempty(xydims{i})
                    xydims{i} = self.dims{order(1)};
                    order(1) = [];
                end
            end
            xdim = xydims(1);
            ydim = xydims(2);
        end
        
        function [xdim,ydim,zdim] = get_xyz(self, options)
            %GET_XY get the squeezed X and and Y coordinates of a sliced Volume
            % [xdim, ydim, zdim] = vol.get_xyz()
            % [xdim, ydim, zdim] = vol.get_xyz("param", value, ...)
            % GET_XY returns the dimensions in order if none are provided. If dimensions
            % are provided, the remaining dimension is inferred.
            %
            % Optional Parameters:
            %   'xdim' (string): Dimension ID for x-axis. Default: "" (auto)
            %   'ydim' (string): Dimension ID for y-axis. Default: "" (auto)
            %   'zdim' (string): Dimension ID for z-axis. Default: "" (auto)
            %
            % Returns:
            %   xdim (string): Dimension ID for x-axis
            %   ydim (string): Dimension ID for y-axis
            %   zdim (string): Dimension ID for z-axis
            arguments
                self fus.Volume
                options.xdim string {fus.util.mustBeDimOrEmpty(options.xdim, self)} = ""
                options.ydim string {fus.util.mustBeDimOrEmpty(options.ydim, self)} = ""
                options.zdim string {fus.util.mustBeDimOrEmpty(options.zdim, self)} = ""
                
            end
             if length(self.dims) < 3
                error('Data must have at least 3-dimensions')
            end
            xyzdims = [options.xdim, options.ydim, options.zdim];
            listed_dims = xyzdims(arrayfun(@(x)~isequal(x,""),xyzdims));
            if length(unique(listed_dims)) < length(listed_dims)
                error('Must specify unique dimensions')
            end
            order = 1:self.ndim;
            order(cellfun(@self.dim_index, listed_dims)) = [];
            for i = 1:length(xyzdims)
                if isempty(xyzdims{i})
                    xyzdims{i} = self.dims{order(1)};
                    order(1) = [];
                end
            end
            xdim = xyzdims(1);
            ydim = xyzdims(2);
            zdim = xyzdims(3);
        end
        
        function h = imagesc(self, clim, options)
            % IMAGESC Display Volume as scaled image
            % h = vol.imagesc()
            % h = vol.imagesc(clim)
            % h = vol.imagesc(clim, "param", value, ...)
            % IMAGESC displays the Volume as a scaled image. If no clim is provided,
            % the image is scaled to the 0th and 100th percentiles of the data.
            %
            % Inputs:
            %   clim (1,2) double: Color limits for image scaling
            %
            % Optional Parameters:
            %   'colorbar' (logical): Display colorbar. Default: true
            %   'title' (logical): Display title. Default: true
            %   'xlabel' (logical): Display xlabel. Default: true
            %   'ylabel' (logical): Display ylabel. Default: true
            %   'xdim' (string): Dimension ID for x-axis. Default: "" (auto)
            %   'ydim' (string): Dimension ID for y-axis. Default: "" (auto)
            %
            % Returns:
            %   h (1,1) handle: Handle to image
            arguments
                self (1,1) fus.Volume
                clim (1,2) double = self.percentile([0, 1])
                options.colorbar (1,1) logical = true
                options.title (1,1) logical = true
                options.xlabel (1,1) logical = true
                options.ylabel (1,1) logical = true
                options.xdim string {fus.util.mustBeDimOrEmpty(options.xdim, self)} = ""
                options.ydim string {fus.util.mustBeDimOrEmpty(options.ydim, self)} = ""
            end
            [xdim, ydim] = self.get_xy("xdim", options.xdim, "ydim", options.ydim);
            dimi = arrayfun(@self.dim_index, [ydim, xdim]);
            order = 1:self.ndim;
            order(dimi) = [];
            if ~isempty(order) && any(shape(self, order)~=1)
                error('Data must be singleton in all non-axis dimensions');
            end
            order = [dimi, order];
            x = self.coords.by_id(xdim);
            y = self.coords.by_id(ydim);
            cdata = permute(self.data, order);
            h = imagesc(...
                x.values,...
                y.values,...
                cdata, clim);
            if options.xlabel
                xlabel(fus.util.auto_tex(x.label));
            end
            if options.ylabel
                ylabel(fus.util.auto_tex(y.label));
            end
            if options.title
                title(fus.util.auto_tex(self.name))
            end
            if options.colorbar
                cb = colorbar();
                ylabel(cb, fus.util.auto_tex(self.units));
            end
            axis image;
        end
        
        function data = interp(self, X, Y, Z, options)
            %INTERP Interpolate Volume data
            % data = vol.interp(X, Y, Z)
            % data = vol.interp(X, Y, Z, "param", value, ...)
            % INTERP interpolates the Volume data to the specified coordinates.
            %
            % Inputs:
            %   X (double): X coordinates
            %   Y (double): Y coordinates
            %   Z (double): Z coordinates
            %
            % Optional Parameters:
            %   'transform' (logical): transform data for X,Y,Z provided in global coordinates. Default: false
            %   'units' (string): Units of input coordinates. Default: self.units
            %
            % Returns:
            %   data (size(X), size(Y), size(Z)) double: Interpolated data
            arguments
                self fus.Volume
                X double
                Y double
                Z double
                options.transform (1,1) logical = false
                options.units (1,1) string = self.get_units
            end
            XYZ = {X,Y,Z};
            if options.transform
                sz = num2cell(size(XYZ{1}));
                XYZ1 = cell2mat(reshape(XYZ, 1, 1, 1, 3));
                XYZ1 = reshape(XYZ1,[],3)';
                XYZ1(4,:) = 1;
                Xtf = self.get_matrix("units", options.units) \ XYZ1;
                Xtf = reshape(Xtf(1:3,:)', [sz{:} 3]);
                XYZ = reshape(mat2cell(Xtf, sz{:}, ones(1,3)),1,3);
            end
            Xv = self.ndgrid("units", options.units);
            if numel(self)>1
                data = arrayfun(@(x)interpn(Xv{:}, double(x.data), XYZ{:}), self, "UniformOutput", false);
            else
                data = interpn(Xv{:}, double(self.data), XYZ{:});
            end
        end
        
        function sobj = isel(self, dim, index)
            % ISEL Select a slice along a dimension
            % sobj = vol.isel(dim, index)
            % ISEL selects a slice along the specified dimension and returns a new
            % Volume object.
            %
            % Inputs:
            %   dim (string): Dimension ID
            %   index (double): Index of slice
            %
            % Returns:
            %   sobj (1,1) Volume: Slice along dimension
            if numel(self) > 1
                sobj = arrayfun(@(x)x.isel(dim, index), self);
            else
                subs = repmat({':'}, 1, self.ndim);
                didx = self.dim_index(dim);
                subs{didx} = index;
                s0 = struct('type','()','subs', {subs});
                slice_data = subsref(self.data, s0);
                s = self.to_struct();
                s.data = slice_data;
                s.coords(didx).values = s.coords(didx).values(index);
                sobj = self.from_struct(s);
            end
        end
        
        function max_obj = max(self)
            % MAX Maximum across Volume array
            % max_obj = vol.max()
            % MAX returns a new Volume object containing the maximum across the
            % Volume array. This is _not_ the maximum along a dimension (the maximum
            % along a dimension would not have a valid resulting coordinate).
            %
            % Returns:
            %   max_obj (1,1) fus.Volume: Maximum across fus.Volume array
            arguments
                self (1,:) fus.Volume
            end
            max_obj = self(1).copy();
            max_obj.data = max(cell2mat(reshape({self.data},1,1,1,[])),[],4);
        end
        
        function mean_obj = mean(self)
            % MEAN Mean across Volume array
            % mean_obj = vol.mean()
            % MEAN returns a new Volume object containing the mean across the
            % Volume array. This is _not_ the mean along a dimension (the mean
            % along a dimension would not have a valid resulting coordinate).
            %
            % Returns:
            %   mean_obj (1,1) fus.Volume: Mean across Volume array
            arguments
                self (1,:) fus.Volume;
            end
            mean_obj = self.sum();
            mean_obj.data = mean_obj.data/numel(self);
        end
        
        function min_obj = min(self)
            % MIN Minimum across Volume array
            % min_obj = vol.min()
            % MIN returns a new Volume object containing the minimum across the
            % Volume array. This is _not_ the minimum along a dimension (the minimum
            % along a dimension would not have a valid resulting coordinate).
            %
            % Returns:
            %   min_obj (1,1) Volume: Minimum across Volume array
            arguments
                self (1,:) fus.Volume
            end
            min_obj = self(1).copy();
            min_obj.data = min(cell2mat(reshape({self.data},1,1,1,[])),[],4);
        end
        
        function grid = meshgrid(self, options)
            % MESHGRID Meshgrid of Volume coordinates
            % grid = vol.meshgrid()
            % grid = vol.meshgrid("param", value, ...)
            % MESHGRID returns a meshgrid of the Volume coordinates.
            %
            % Optional Parameters:
            %   'dims' (1xN string): dimensions
            %   'transform' (logical): return the meshgrid in global coordinates
            %       instead of local coordinates. Default: false
            %   'units' (string): Units of output coordinates. Default: self.units
            %
            % Returns:
            %   grid (cell): (1x3) Meshgrid of Volume coordinates (each MxNxP)
            arguments
                self fus.Volume
                options.dims (1,:) string {fus.util.mustBeDim(options.dims, self)} = self.dims
                options.units (1,1) string = self.get_units
                options.transform (1,1) {mustBeNumericOrLogical} = false
            end
            if options.transform
                M = self.get_matrix();
            else
                M = eye(4);
            end
            c = self.get_coords(options.dims).rescale(options.units);
            grid = c.meshgrid("units", options.units, "matrix", M);
        end
        
        function grid = ndgrid(self, options)
            % NDGRID NDgrid of Volume coordinates
            % grid = vol.ndgrid()
            % grid = vol.ndgrid("param", value, ...)
            % NDGRID returns a ndgrid of the Volume coordinates.
            %
            % Optional Parameters:
            %   'dims' (1xN string): dimensions
            %   'transform' (logical): return the ndgrid in global coordinates
            %       instead of local coordinates. Default: false
            %   'units' (string): Units of output coordinates. Default: self.units
            %
            % Returns:
            %   grid (cell): (1x3) NDgrid of Volume coordinates (each MxNxP)
            arguments
                self fus.Volume
                options.dims (1,:) string {fus.util.mustBeDim(options.dims, self)} = self.dims
                options.units (1,1) string = self.get_units
                options.transform (1,1) {mustBeNumericOrLogical} = false
            end
            if options.transform
                M = self.get_matrix();
            else
                M = eye(4);
            end
            c = self.get_coords(options.dims).rescale(options.units);
            grid = c.ndgrid("units", options.units, "matrix", M);
        end
        
        function n = ndim(self)
            % NDIM Number of dimensions. Should always be 3.
            if numel(self) > 1
                N = arrayfun(@(x)x.ndim, self);
                if length(unique(N)) == 1
                    n = N(1);
                else
                    error('Volumes do not share dimensionality');
                end
            else
                n = numel(self.coords);
            end
        end
        
        function p = percentile(self, pct, options)
            % PERCENTILE Percentile of Volume data
            % p = vol.percentile(pct)
            % p = vol.percentile(pct, "param", value, ...)
            % PERCENTILE returns the percentile of the Volume data.
            %
            % Inputs:
            %   pct (double): (1xN) Percentile to compute
            %
            % Optional Parameters:
            %   'agg' (string): Aggregation method for multiple Volumes. Default: "none"
            %       "min": Minimum across Volumes
            %       "max": Maximum across Volumes
            %       "mean": Mean across Volumes
            %       "none": Return a cell array of percentiles
            %
            % Returns:
            %   p (double): Percentile of Volume data
            arguments
                self fus.Volume
                pct double {mustBeNonnegative, mustBeLessThanOrEqual(pct,1)} = [0 1]
                options.agg (1,1) string {mustBeMember(options.agg, ["min","max","mean","none"])} = "none";
            end
            if numel(self) > 1
                p = arrayfun(@(x)x.percentile(pct), self, 'UniformOutput', false);
                switch options.agg
                    case "min"
                        p = min(cell2mat(reshape(p,1,1,[])),[],3);
                    case "max"
                        p = max(cell2mat(reshape(p,1,1,[])),[],3);
                    case "mean"
                        p = mean(cell2mat(reshape(p,1,1,[])),3);
                    case "none"    
                end
            else
                y = double(reshape(self.data, [], 1));
                p = fus.util.percentile(y, pct*100);
            end
        end
                
        function obj = permute(self, dims)
            % PERMUTE Permute Volume dimensions
            % obj = vol.permute(dims)
            % PERMUTE permutes the Volume dimensions according to the order
            % specified in dims.
            %
            % Inputs:
            %   dims (double): (1xN) Permutation order
            %
            % Returns:
            %   obj (fus.Volume): Permuted fus.Volume
            if numel(self) > 1
                obj = arrayfun(@(x)x.permute(dims), self);
            else
                switch class(dims)
                    case 'cell'
                        dims = cellfun(@(x)self.dim_index(x), dims);
                    case 'string'
                        dimstr = dims;
                        dims = ones(1,length(dims));
                        for i = 1:length(dimstr)
                            dims(i) = self.dim_index(dimstr(i));
                        end
                    case 'char'
                        dims = self.dim_index(dims);    
                end 
                dims = dims(:)';
                dimorder = (1:self.ndim);
                dimorder(dims) = [];
                dimorder = [dims dimorder];
                obj = self.copy();
                obj.data = permute(self.data, dimorder);
                obj.coords = self.coords(dimorder);
                obj.matrix = self.matrix(:,[dimorder, size(self.matrix,2)]);
            end
        end
         
        function varargout = rescale(self, units)
            % RESCALE Rescale Volume coordinates and matrix
            % obj = vol.rescale(units)
            % vol.rescale(units)
            %
            % RESCALE rescales the Volume coordinates and matrix to the
            % specified units. If no output is specified, the Volume
            % coordinates and matrix are rescaled in-place.
            %
            % Inputs:
            %   units (string): Units to rescale to
            %
            % Returns:
            %   obj (fus.Volume): Rescaled Volume
            arguments
                self fus.Volume
                units (1,1) string {fus.util.mustBeDistance}
            end
            if nargout == 1
                self = self.copy();
                varargout{1} = self;
            end
            for vol_index = 1:length(self)
                vol = self(vol_index);
                if ~isequal(vol.coords.get_units, units)
                    scl = fus.util.getunitconversion(vol.coords.get_units, units);
                    for i = 1:3
                        vol.coords(i).rescale(units);
                    end
                    vol.matrix(1:3,4) = vol.matrix(1:3,4)*scl;
                end
            end
        end
        
        function varargout = rescale_data(self, units)
            % RESCALE_DATA Rescale Volume data
            % obj = vol.rescale_data(units)
            % vol.rescale_data(units)
            %
            % RESCALE_DATA rescales the Volume data to the specified units.
            % If no output is specified, the Volume data is rescaled
            % in-place.
            %
            % Inputs:
            %   units (string): Units to rescale to
            %
            % Returns:
            %   obj (fus.Volume): Rescaled Volume
            arguments
                self fus.Volume
                units (1,1) string
            end
            if nargout == 1
                self = self.copy();
                varargout{1} = self;
            end
            for vol_index = 1:length(self)
                vol = self(vol_index);
                scl = fus.util.getunitconversion(vol.units, units);
                vol.data = vol.data*scl;
                vol.units = units;
            end
        end
        
        function h = slice(self, x, y, z, options)
            % SLICE Plot Volume cross-sections
            % h = vol.slice(x, y, z)
            % h = vol.slice(x, y, z, "param", value,...)
            %
            % SLICE plots cross-sections of the Volume data at the
            % specified coordinates. The coordinates are specified in the
            % Volume coordinate system.
            %
            % Inputs:
            %   x (double): (1xN) 1st-dim coordinates to slice though
            %   y (double): (1xM) 2nd-dim coordinates to slice through
            %   z (double): (1xP) 3rd-dim coordinates to slice through
            %
            % Optional Parameters:
            %   "cmap" (string, nx3 colormap or fus.ColorMapper): Colormap. Default "turbo"
            %   "ax": axis to draw into. Default gca
            %   "colorbar" (logical): draw colobar. Default false.
            %   "transform" (logical) transform to global coordinates.
            %       Default false
            %
            % Returns:
            %   h: Handle to surface objects
            
            arguments
                self fus.Volume
                x (1,:) double
                y (1,:) double
                z (1,:) double
                options.cmap {fus.util.mustBeStringOrColorMapper} = "turbo"
                options.colorbar (1,1) logical = true
                options.ax {fus.util.mustBeAxes} = gca % Existing axes
                options.transform (1,1) logical = false % Transform to global coordinates
            end
            if isa(options.cmap, "fus.ColorMapper")
                cmap = options.cmap;
            else
                cmap = self.auto_colormap("cmap", options.cmap);
            end
            slices = {x,y,z};
            h = [];
            for i = 1:3
                dim = self.dims(i);
                v = self.sel(dim, slices{i});
                h = [h, v.draw_surface(...
                    cmap, ...
                    "dim", dim, ...
                    "ax", options.ax, ...
                    "transform", options.transform, ...
                    "colorbar", options.colorbar)];
                hold all
            end
            axis(options.ax, 'equal');
        end
                
        function sobj = sel(self, dim, value, options)
            % SEL Slice Volume to along dim to value
            % sobj = vol.sel(dim, value)
            % sobj = vol.sel(dim, value, "param", value,...)
            %
            % SEL slices the Volume along the specified dimension to the
            % specified value. The value is specified in the Volume
            % coordinate system.
            %
            % Inputs:
            %   dim (string): Dimension to slice along
            %   value (double): Value to slice to
            %
            % Optional Parameters:
            %   "units" (string): Units of value. Default: self.get_units
            %
            % Returns:
            %   sobj (fus.Volume): Sliced Volume
            arguments
                self fus.Volume
                dim
                value (:,1) double
                options.units (1,1) string = self.get_units
            end
            z = self.get_coord(dim);
            z_val = fus.util.getunitconversion(options.units, self.get_units)*value;
            idx = interp1(z.values, 1:length(z), z_val);
            nanidx = isnan(idx);
            idx0 = floor(idx);
            idx1 = floor(idx)+1;
            idx0(nanidx) = 1;
            idx1(nanidx) = 1;
            e0 = z_val - z.values(idx0);
            e0(nanidx) = nan;
            e1 = z.values(idx1) - z_val;
            e1(nanidx) = nan;
            if ~any(e0)
                sobj = self.isel(dim, idx0);
            else
                didx = self.dim_index(dim);
                sz = ones(1, self.ndim);
                sz(didx) = length(value);
                e0 = reshape(e0,sz);
                e1 = reshape(e1,sz);
                w0 = (e1./(e0+e1));
                w1 = (e0./(e0+e1));
                sobj0 = self.isel(dim, idx0);
                sobj1 = self.isel(dim, idx1);
                sobj = sobj0;
                for i = 1:numel(sobj)
                    sobj(i).data = (double(sobj0(i).data) .* w0) + (double(sobj1(i).data) .* w1);
                    sobj(i).coords(didx).values = z_val;
                end
            end   
        end
        
        function sz = shape(self, dim)
            % SHAPE Get Volume shape
            % sz = vol.shape()
            % sz = vol.shape(dim)
            %
            % SHAPE returns the shape of the Volume data. If dim is
            % specified, the shape of the specified dimension is returned.
            %
            % Inputs:
            %   dim (string): Dimension to get shape of. Default: all
            %
            % Returns:
            %   sz (1xN) double: Shape of Volume data
            if numel(self) > 1
                if exist('dim','var')
                    Sz = arrayfun(@(x)x.shape(dim), self, 'UniformOutput', false);
                else
                    Sz = arrayfun(@(x)x.shape(), self, 'UniformOutput', false);
                end
                if all(cellfun(@(x)isequal(x, Sz{1}), Sz))
                    sz = Sz{1};
                else
                    error('Volumes do not share shapes')
                end
            else
                if ~exist('dim', 'var')
                    sz = size(self.data, [1, 2, 3]);
                else
                    sz = size(self.data, self.dim_index(dim));
                end
            end
        end
        
        function sum_obj = sum(self)
            % SUM Sum across Volume array
            % sum_obj = vol.sum()
            %
            % SUM returns a new Volume object containing the sum
            % across the Volume array. This is _not_ the same as
            % summing along a dimension. 
            %
            % Returns:
            %   sum_obj (fus.Volume): Summed Volume
            arguments
                self (1,:) fus.Volume
            end
            sum_obj = self(1).copy();
            sum_obj.data = sum(cell2mat(reshape({self.data},1,1,1,[])),4);
        end
        
        function to_nifti(self, filename)
            arguments
                self (1,1) fus.Volume
                filename (1,1) string
            end
            dx = (arrayfun(@(x)mean(diff(x.values)), self.coords));
            x0 = arrayfun(@(x)x.values(1), self.coords);
            affine = ([dx,1].*[self.matrix(:,1:3) self.matrix * [x0(:);1]]).*[-1;-1;1;1];
            transform = affine3d(affine');
            switch self.units
                case "mm"
                    spaceunits = 'Millimeter';
                case "m"
                    spaceunits = 'Meter';
                otherwise
                    error("invalid units");
            end
            description = sprintf('%s|%s',self.id, self.name);
            if length(description) > 80
                warning("Length of volume ID + volume Name > 79 characters. Description will be truncated");
                description = [description(1:77) '...'];
            end
            metadata = struct(...
                "Version", 'NIfTI1', ...
                "Description", description, ...
                "ImageSize", self.shape,...
                "PixelDimensions", abs(dx), ...
                "Datatype", class(self.data), ...
                "SpaceUnits", spaceunits, ...
                "TimeUnits", 'Second', ...
                "SliceCode", 'Unknown', ...
                "FrequencyDimension", 0, ...
                "PhaseDimension", 0, ...
                "SpatialDimension", 0, ...
                "DisplayIntensityRange", [0, 0], ...
                "TransformName", 'Sform', ...
                "Transform", transform, ...
                "Qfactor", 1);
            [base, fname, ext] = fileparts(filename);
            if ~(base=="") && ~isfolder(base)
                [success, msg, mid] = mkdir(base);
                if ~success
                    error("Could not create directory %s. %s (%s)", base, msg, mid);
                end
            end
            switch ext
                case ""
                    ext = ".nii";
                case ".nii"
                otherwise
                    error("Invalid extension %s. Only .nii is supported", ext);
            end
            filename = fullfile(base, sprintf("%s%s",fname, ext));
            niftiwrite(self.data, filename, metadata);
        end
        
        function obj = transform(self, coords, matrix)
            % TRANSFORM Transform Volume
            % obj = vol.transform(coords, matrix)
            %
            % TRANSFORM transforms the Volume data to the coordinate
            % system specified by coords using the transformation matrix
            %
            % Inputs:
            %   coords (1,3) fus.Axis: fus.Axis object specifying the coordinates to 
            %       transform to.
            %   matrix (4,4) double: Transformation matrix (in the coords units)
            %
            % Returns:
            %   obj (fus.Volume): Transformed Volume
            arguments
                self fus.Volume
                coords (1,3) fus.Axis
                matrix (4,4) double
            end
            switch numel(self)
                case 0
                    obj = fus.Volume.empty;
                case 1
                    prev_units = self.get_units();
                    self.rescale(coords.get_units())
                    Xp = coords.ndgrid();
                    Xp1 = cellfun(@(x)x(:), Xp, 'UniformOutput', false);
                    XP = [Xp1{:} ones(numel(Xp1{1}),1)]';
                    inv_matrix = (self.matrix'*self.matrix)\(self.matrix');
                    X1 = inv_matrix * (matrix * XP);
                    X1 = mat2cell(X1, ones(size(X1,1),1), size(X1,2));
                    X1 = X1(1:end-1);
                    X1 = cellfun(@(x)reshape(x,size(Xp{1})), X1, 'UniformOutput', false);
                    pdata = self.interp(X1{:});
                    obj = self.newobj(pdata, coords, ...
                        "id", self.id, ...
                        "name", self.name, ...
                        "matrix", matrix, ...
                        "attrs", self.attrs, ...
                        "units", self.units);
                    self.rescale(prev_units);
                otherwise
                    obj = arrayfun(@(x)x.transform(coords, matrix), self);
            end
        end
    end
    
    methods (Access=protected)
        function cbar = auto_colormap(self, varargin)
            % AUTO_COLORBAR Create colorbar from Volume
             cbar = fus.ColorMapper.from_volume(self, varargin{:});
        end

        function cb = draw_colorbar(self, ax, cbax, mapper, crange)
            % DRAW_COLORBAR Draw colorbar
            % cb = vol.draw_colorbar(ax, cbax, mapper, crange)
            %
            % Inputs:
            %   ax (axes): Axes link colorbar to
            %   cbax (axes): Axes to draw colorbar in
            %   mapper (fus.ColorMapper): Mapper to use for colorbar
            %   crange (1,2) double: Colorbar range
            if isempty(crange)
                crange = [min(mapper.alim_in(1), mapper.clim_in(1)), ...
                    max(mapper.alim_in(end), mapper.clim_in(end))];
            end
            cmap_rgb = mapper.get_colormap('clim', crange);
            cmap_alpha = mapper.get_alphamap('alim', crange);
            cla(cbax);
            cb = image(cbax, [0, 1], crange, cmap_rgb);
            set(cb, 'AlphaData', cmap_alpha, 'AlphaDataMapping', 'None');
            axis(cbax, 'xy');
            xlabel(cbax, '')
            set(cbax, 'XTick', {}, 'YAxisLocation', 'right')
            ylabel(cbax, self.units);
            if isempty(ax.UserData)
                ax.UserData = struct('colorbar',cbax);
            else
                ax.UserData.colorbar = cbax;
            end
            subplot(ax);
        end
    end
    
    methods (Static)
        
        function vol = from_dicom_dir(dirname)
            % FROM_DICOM_DIR Create Volume from DICOM directory
            % vol = fus.Volume.from_dicom_dir(dirname)
            %
            % Inputs:
            %   dirname (string): Path to DICOM directory
            %
            % Returns:
            %   vol (fus.Volume): Volume object
            arguments
                dirname string {mustBeFolder}
            end
            dcm_index = dicomCollection(dirname);
            vol = fus.Volume.from_dicom(dcm_index);
        end
        
        function vol = from_dicom(dcm_index, options)
            % FROM_DICOM Create Volume from DICOM collection
            % vol = fus.Volume.from_dicom(dcm_index)
            %
            % Inputs:
            %   dcm_index (table): DICOM collection
            %
            % Optional Parameters:
            %   'id': volume ID. Default empty (take from metadata)
            %   'name' volume name. Default empty (take from metadata)
            %
            % Returns:
            %   vol (fus.Volume): Volume object
            arguments
                dcm_index table
                options.id string = string.empty
                options.name string = string.empty
            end
            switch size(dcm_index,1)
                case 1
                    [V_raw, spat, ~] = dicomreadVolume(dcm_index, 'MakeIsotropic', false);
                    V = permute(squeeze(V_raw),[3,2,1]);
                    origin = spat.PatientPositions(1,:)';
                    unit_vectors = {cross(spat.PatientOrientations(1,:,1), spat.PatientOrientations(2,:,1)),...
                        spat.PatientOrientations(1,:,1), ...
                        spat.PatientOrientations(2,:,1)};
                    dx = [unit_vectors{1}(:)' * diff(spat.PatientPositions(1:2,:))'; ...
                          spat.PixelSpacings(1,1); ...
                          spat.PixelSpacings(1,1)];
                    dims = {'x','y','z'};
                    x = cell(1,3);
                    x{1} = cumsum([0, unit_vectors{1}(:)' * diff(spat.PatientPositions)']);
                    for i = 2:3
                        x{i} = (0:(size(V,i)-1))*dx(i);
                    end    
                    for i = 1:length(dims)
                        coords(i) = fus.Axis(x{i}, dims{i}, 'name', upper(dims{i}), 'units', 'mm');
                    end
                    if isempty(options.id)
                        id = fus.util.sanitize(dcm_index.SeriesDescription, 'snake');
                    else
                        id = option.id;
                    end
                    if isempty(options.name)
                        name = dcm_index.SeriesDescription;
                    else
                        name = options.name;
                    end
                    attrs = struct(...
                        'id', id, ...
                        'name', name, ...
                        'study_datetime', dcm_index.StudyDateTime, ...
                        'series_datetime', dcm_index.SeriesDateTime, ...
                        'modality', dcm_index.Modality, ...
                        'rows', dcm_index.Rows, ...
                        'columns', dcm_index.Columns, ...
                        'channels', dcm_index.Channels, ...
                        'frames', dcm_index.Frames, ...
                        'study_description', dcm_index.StudyDescription, ...
                        'series_description', dcm_index.SeriesDescription, ...
                        'study_uid', dcm_index.StudyInstanceUID, ...
                        'series_uid', dcm_index.SeriesInstanceUID, ...
                        'filenames', dcm_index.Filenames, ...
                        'format', "DICOM");
                    matrix = [cell2mat(cellfun(@(uv)uv(:),unit_vectors,'UniformOutput',false)) origin(:); 0 0 0 1];
                    vol = fus.Volume(V, coords, ...
                        'id', id, ...
                        'name', name, ...
                        'matrix', matrix, ...
                        'units', "mm", ...
                        'attrs',attrs);   
                otherwise
                    error('Volume:InvalidIndex','%d volumes found. Must provide a single DICOM volume', size(dcm_index,1))
            end
        end
        
        function vol = from_file(filename)
            % FROM_FILE Create Volume from MAT file
            % vol = fus.Volume.from_file(filename)
            %
            % Inputs:
            %   filename (string): Path to MAT file
            %
            % Returns:
            %   vol (fus.Volume): Volume object
            arguments
                filename (1,1) string {mustBeFile}
            end
            s = load(filename);
            if isfield(s.coords,'data')
                warning("Coordinates use the old 'data' convention")
                for i = 1:3
                    s.coords(i).values = s.coords(i).data;
                end
                s.coords = rmfield(s.coords, 'data');
            end
            vol = fus.Volume.from_struct(s);
        end
        
        function vol = from_nifti(filename, options)
            % FROM_NIFTI Create Volume from NIfTI file
            % vol = fus.Volume.from_nifti(filename)
            % vol = fus.Volume.from_nifti(filename, "param", value, ...)
            %
            % Inputs:
            %   filename (string): Path to NIfTI file
            %
            % Optional parameters:
            %   'units' (string): Units of spatial dimensions
            %       (Default: 'mm')
            %
            % Returns:
            %   vol (fus.Volume): Volume object
            arguments
                filename string {mustBeFile}
                options.id string = string.empty
                options.name string = string.empty
                options.units string = "mm"
                options.dims (1,3) string = ["x","y","z"]
                options.dim_names (1,:) string = string.empty
                options.attrs struct = struct()
            end
            [~, fname] = fileparts(filename);
            index = niftiinfo(filename);
            T = repmat([-1 -1 1 1],4,1) .* index.Transform.T;
            V = niftiread(index.Filename);
            switch index.SpaceUnits
                case 'Unknown'
                    scl = 1;
                case 'Millimeter'
                    scl = fus.util.getunitconversion("mm", options.units);
                case 'Meter'
                    scl = fus.util.getunitconversion("m", options.units);
                otherwise
                    scl = fus.util.getunitconversion(lower(index.SpaceUnits), options.units);
            end
            matrix = [...
                (T(1,1:3)/index.PixelDimensions(1))',...
                (T(2,1:3)/index.PixelDimensions(2))',...
                (T(3,1:3)/index.PixelDimensions(3))',...
                T(4,1:3)'*scl; ...
                [0 0 0 1]];
            dx = index.PixelDimensions(1:3)' * scl;
            x = cell(1,3);
            for i = 1:3
                x{i} = ((0:(size(V,i)-1))*dx(i));
            end
            dims = options.dims;
            if isempty(options.dim_names)
                dim_names = arrayfun(@(dim)string(fus.util.sanitize(dim,'title')), dims);
            else
                dim_names = options.dim_names;
            end
            for i = 1:length(dims)
                coords(i) = fus.Axis(x{i}, dims(i), 'name', dim_names(i), 'units', options.units);
            end
            if ~isempty(options.id)
                id = options.id;
                if isempty(options.name)
                    name = fus.util.sanitize(strrep(id,"_"," "), 'title');    
                else
                    name = options.name;
                end
            elseif ~isempty(options.name)
                name = options.name;
                id = fus.util.sanitize(options.name, 'snake');
            elseif isempty(index.Description)
                id = fname;
                name = fus.util.sanitize(strrep(fname,"_"," "), 'title');
            else
                idmatch = string(regexp(index.Description, "^\w+(?=\|\S+)", "match", "once"));
                if isempty(idmatch) || ismissing(idmatch)
                    id = fus.util.sanitize(index.Description, "snake");
                    name = index.Description;
                else
                    id = string(idmatch);
                    name = string(index.Description(length(char(idmatch))+2:end));
                end
            end
            id = char(id);
            id = string(id(1:min(length(id), namelengthmax)));
            vol = fus.Volume(V, coords, ...
                'matrix', matrix, ...
                'id', id, ...
                'name', name, ...
                'units', options.units, ...
                'attrs', options.attrs);
        end
        
        function vol = from_struct(data_struct)
            % FROM_STRUCT Create Volume from struct
            % vol = fus.Volume.from_struct(data_struct)
            %
            % Inputs:
            %   data_struct (struct): Struct with fields:
            %       data (array): Volume data
            %       coords (struct): valid inputs to fus.Axis.from_struct
            %       name (string): Name of volume
            %       attrs (struct): Attributes of volume
            %
            % Returns:
            %   vol (fus.Volume): Volume object
            arguments
                data_struct (1,:) struct
            end
            if numel(data_struct) > 1
                vol = arrayfun(@fus.Volume.from_struct, data_struct);
            else
                if isfield(data_struct.coords,'data')
                    warning("Coordinates use the old 'data' convention")
                    for i = 1:3
                        data_struct.coords(i).values = data_struct.coords(i).data;
                    end
                    data_struct.coords = rmfield(data_struct.coords, 'data');
                end
                if isempty(data_struct.id)
                    vol = fus.Volume.empty;
                else
                    data = data_struct.data;
                    coords = arrayfun(@(coord)fus.Axis.from_struct(coord), data_struct.coords);
                    options = rmfield(data_struct, {'data', 'coords'});
                    args = fus.util.struct2args(options);
                    vol = fus.Volume(data, coords, args{:});
                end
            end
        end
        
        function vol = new(obj, varargin)
            switch class(obj)
                case 'struct'
                    vol = fus.Volume.from_struct(obj);
                case 'fus.Volume'
                    vol = fus.Volume.from_struct(obj.to_struct());
                otherwise
                    vol = fus.Volume(obj, varargin{:});
            end
        end        
    end
    
    methods (Static, Access = private)
        function [ax, cbax] = get_axes(ax, cbax, cbw)
            % GET_AXES Get axes and colorbar axes
            if isempty(ax)
                ax = gca();
            end
            if isempty(cbax)
                if ~isempty(ax.UserData) && isfield(ax.UserData, 'colorbar')
                    cbax = ax.UserData.colorbar;
                else
                    pos = ax.Position;
                    margin = cbw/3;
                    axw = 1-cbw-margin;
                    ax.Position = pos .* [1,1,axw, 1];
                    cbax = subplot('position',...
                        pos .* [1, 1, cbw, 1] + ...
                        [pos(3)*axw + margin, 0, 0, 0]);
                end
            end 
        end
    end
    
end



