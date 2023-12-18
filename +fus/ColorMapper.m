classdef ColorMapper < fus.DataClass
    % ColorMapper - A class for mapping data to colors
    %   cmap = fus.ColorMapper('param',value, ...)
    properties
        id (1,1) string {mustBeValidVariableName} = "cmap" % The ID of the colormap
        cmap (:,3) double {mustBeNumeric} = gray(256) % The colormap data
        clim_in (1,2) double {mustBeNumeric} = [0 1] % The input data color limits
        clim_out (1,2) double {mustBeNumeric, mustBeInRange(clim_out, 0, 1)} = [0 1] % the output range
        amap (:,1) double {mustBeNumeric} = linspace(0, 1, 256)' % The alpha map
        alim_in (1,2) double {mustBeNumeric} = [-inf inf] % The alpha input limits
        alim_out (1,2) double {mustBeNumeric, mustBeInRange(alim_out, 0, 1)} = [1 1] % The alpha output range
    end
    methods
        function self = ColorMapper(options)
            % COLORMAPPER - Create a new ColorMapper object
            %  cmap = fus.ColorMapper('param',value, ...) 
            %
            % A COLORMAPPER object defines a mapping between scalar
            % values and colors.  The mapping is defined by a colormap
            % and a set of limits.  The colormap is a Nx3 matrix of
            % RGB values.  clim_in defines the limits of the scalar values
            % that map to the bottom and top of the colormap. clim_out 
            % defines the output range of the colormap (and does not need
            % to be monotonic).  alim_in and alim_out similarly define the
            % mapping of scalars to the alpha channel. By default, the amap
            % is a linear ramp between 0 and 1, but it can be set to any
            % mapping.
            %
            % Optional Parameters:
            %   'id' (string): The ID of the colormap
            %   'cmap' (double): The colormap data
            %   'clim_in' (double): The input data color limits
            %   'clim_out' (double): the output range
            %   'amap' (double): The alpha map
            %   'alim_in' (double): The alpha input limits
            %   'alim_out' (double): The alpha output range
            arguments
                options.?fus.ColorMapper
                    options.id (1,1) string {mustBeValidVariableName} = "cmap" % The ID of the colormap
                    options.cmap (:,3) double {mustBeNumeric} = gray(256) % The colormap data
                    options.clim_in (1,2) double {mustBeNumeric} = [0 1] % The input data color limits
                    options.clim_out (1,2) double {mustBeNumeric, mustBeInRange(options.clim_out, 0, 1)} = [0 1] % the output range
                    options.amap (:,1) double {mustBeNumeric} = linspace(0, 1, 256)' % The alpha map
                    options.alim_in (1,2) double {mustBeNumeric} = [-inf inf] % The alpha input limits
                    options.alim_out (1,2) double {mustBeNumeric, mustBeInRange(options.alim_out, 0, 1)} = [1 1] % The alpha output range

            end
            self.id = options.id;
            self.cmap = options.cmap;
            self.clim_in = options.clim_in;
            self.clim_out = options.clim_out;
            self.amap = options.amap;
            self.alim_in = options.alim_in;
            self.alim_out = options.alim_out;
            %self.parse_props(options) 
            self.alim_in(isinf(self.alim_in)) = self.clim_in(isinf(self.alim_in));
                
        end
        
        function cmap = by_id(self, id)
            % BY_ID - Get a colormap by ID from an array
            %
            % Inputs:
            %   id (string): The ID of the colormap
            %
            % Returns:
            %   cmap (fus.ColorMapper): The colormap(s) with the given ID(s)
            arguments
                self (1,:) fus.ColorMapper
                id (1,:) string {fus.util.mustBeID(id, self)}
            end
            cmap = arrayfun(@(id)self(strcmp(id, [self.id])), id);
        end
        
        function [R,G,B] = map_color(self, in)
            % MAP_COLOR - Map data to R,G,B values
            %   [R,G,B] = cmap.map_color(in)
            %
            % Inputs:
            %   in (double): The input data
            %
            % Returns:
            %   R (double): Red Channel Values
            %   G (double): Green Channel Values
            %   B (double): Blue Channel Values
            arguments
                self fus.ColorMapper
                in double
            end
            sz = size(in);
            n = size(self.cmap,1);
            in_clip = min(self.clim_in(end), max(self.clim_in(1), in));
            if isequal(diff(self.clim_in),0)
                in_norm = self.clim_out(1)+diff(self.clim_out)*(in>=self.clim_in(1));
            else
                in_norm = interp1(self.clim_in, self.clim_out, in_clip(:), 'linear', 'extrap');
            end
            index = min(n, max(1, round(in_norm * (n-1)) + 1));
            R = reshape(self.cmap(index,1),sz);
            G = reshape(self.cmap(index,2),sz);
            B = reshape(self.cmap(index,3), sz);
        end 
        
        function A = map_alpha(self, in)
            % MAP_ALPHA - Map data to alpha values
            %   A = cmap.map_alpha(in)
            % 
            % Inputs:
            %   in (double): The input data
            %
            % Returns:
            %   A (double): Alpha Channel Values
            arguments
                self fus.ColorMapper
                in double
            end
            sz = size(in);
            n = length(self.amap);
            in_clip = max(self.alim_in(1), min(self.alim_in(end), in));
            da = diff(self.alim_in);
            if isequal(da, 0)
                in_norm = self.alim_out(1)+diff(self.alim_out)*(in>=self.alim_in(1));
            else
                in_norm = interp1(self.alim_in, self.alim_out, in_clip(:), 'linear', 'extrap');
            end
            index = max(1, min(n, round(in_norm * (n-1)) + 1));
            A = reshape(self.amap(index), sz);
            A(isnan(in)) = 0;
        end
        
        function RGB = map_RGB(self, in, dim)
            % MAP_RGB - Map data to RGB matrix
            %  RGB = cmap.map_RGB(in)
            %
            % Inputs:
            %   in (double): The input data
            %   dim (int): The dimension to concatenate the RGB values. 
            %              Default is the last dimension.
            %
            % Returns:
            %   RGB (double): The RGB values. Default size is [size(in), 3]
            arguments
                self fus.ColorMapper
                in double
                dim (1,1) double {mustBeInteger} = -1
            end
            if dim == -1
                dim = length(size(in))+1;
            end
            [R, G, B] = self.map_color(in);
            RGB = cat(dim, R, G, B);
        end
        
        function RGBA = map_RGBA(self, in, dim)
            % MAP_RGBA - Map data to RGBA matrix
            %  RGBA = cmap.map_RGBA(in)
            %
            % Inputs:
            %   in (double): The input data
            %   dim (int): The dimension to concatenate the RGBA values.
            %              Default is the last dimension.
            %
            % Returns:
            %   RGBA (double): The RGBA values. Default size is [size(in), 4]
            arguments
                self fus.ColorMapper
                in double
                dim (1,1) double {mustBeInteger} = -1
            end
            if dim == -1
                dim = length(size(in))+1;
            end
            [R, G, B] = self.map_color(in);
            A = self.map_alpha(in);
            RGBA = cat(dim, R, G, B, A);
        end
        
        function cmap = get_colormap(self, options)
            % GET_COLORMAP - Get the colormap as an image
            %  cmap = cmap.get_colormap('param', value, ...)
            %
            % Optional Parameters:
            %   'clim' (double): The color limits. Default is [-inf inf]
            %             If either limit is inf, it is replaced by
            %             the corresponding limit of the reference colormap
            %   'N' (int): The number of colors. Default is 256
            % 
            % Returns:
            %   cmap (double): The colormap (Nx1x3)
            arguments
                self fus.ColorMapper
                options.clim (1,2) double = [-inf inf]
                options.N (1,1) double {mustBeInteger} = 256
            end
            mask = isinf(options.clim);
            clim_ref = self.clim_in([1 end]);
            options.clim(mask) = clim_ref(mask);
            clim = options.clim;
            N = options.N;
            cmap = self.map_RGB(linspace(clim(1), clim(end), N)', 3);
        end
        
        function amap = get_alphamap(self, options)
            % GET_ALPHAMAP - Get the alphamap values
            %  amap = cmap.get_alphamap('param', value, ...)
            %
            % Optional Parameters:
            %   'alim' (double): The alpha limits. Default is [-inf inf]
            %             If either limit is inf, it is replaced by
            %             the corresponding limit of the reference colormap
            %   'N' (int): The number of alpha values. Default is 256
            %
            % Returns:
            %   amap (double): The alphamap (Nx1)
            arguments
                self fus.ColorMapper
                options.alim (1,2) double = [-inf inf]
                options.N (1,1) double {mustBeInteger} = 256
            end
            mask = isinf(options.alim);
            alim_ref = self.alim_in([1 end]);
            options.alim(mask) = alim_ref(mask);
            alim = options.alim;
            N = options.N;
            amap = self.map_alpha(linspace(alim(1), alim(end), N)');
        end
    end
    
    methods (Static)
        function self = from_volume(vol, options)
            % FROM_VOLUME - Create a ColorMapper from a volume object
            %  cmap = fus.ColorMapper.from_volume(vol, 'param', value, ...)
            %
            % Inputs:
            %  vol (fus.Volume): The volume
            %
            % Optional Parameters:
            %   'cmap' (string or Nx3 double): The colormap. Default is "turbo"
            %   'amap' (Nx1 double): The alphamap. Default is linspace(0, 1, 256)'
            %   'n' (int): The number of colors. Default is 256
            %   'clim_pct' (1x2 double): The color limits in percentiles. Default is [0, 1]
            %   'alim_pct' (1x2 double): The alpha limits in percentiles. Default is [0, 1]
            %   'alim_out' (1x2 double): The output alpha limits. Default is [1, 1]
            %   'clim_out' (1x2 double): The output color limits. Default is [1, 1]
            %
            % Returns:
            %   cmap (fus.ColorMapper): The colormap
            arguments
                vol (1,:) fus.Volume
                options.?fus.ColorMapper
                options.cmap = "turbo"
                options.amap (:,1) double {mustBeNumeric} = linspace(0, 1, 256)'
                options.n (1,1) double {mustBeInteger, mustBePositive} = 256
                options.clim_pct (1,2) double {mustBeNumeric} = [0, 1];
                options.alim_pct (1,2) double {mustBeNumeric} = [0, 1];
                options.alim_out (1,2) double {mustBeNumeric} = [1, 1];
                options.clim_out (1,2) double {mustBeNumeric} = [0, 1];
                options.agg (1,1) string {mustBeMember(options.agg, ["max","mean","min","none"])} = "none";
            end
            switch class(options.cmap)
                case {"string","char"}
                    options.cmap = string(options.cmap);
                    cmaps = arrayfun(@(x)parse_colormap(x,options.n), options.cmap, 'UniformOutput', false);
                case "cell"
                    cmaps = cellfun(@(x)parse_colormap(x,options.n), options.cmap, 'UniformOutput', false);
                case {"single", "double"}
                    cmaps = {parse_colormap(options.cmap)};
            end
            clim = vol.percentile(options.clim_pct, "agg", options.agg);    
            alim = vol.percentile(options.alim_pct, "agg", options.agg);    
            args = fus.util.struct2args(rmfield(options, ["n", "clim_pct", "alim_pct", "agg", "cmap"]));
            if iscell(clim)
                for i = 1:numel(clim)                
                    cmap = cmaps{mod(i-1,length(cmaps))+1};
                    self(i) = fus.ColorMapper(...
                        "cmap", cmap, ...
                        "clim_in", snap_limits(clim{i}), ...
                        "alim_in", snap_limits(alim{i}), ...
                        "clim_out", options.clim_out, ...
                        "alim_out", options.alim_out, ...
                        args{:});
                end
            else
                cmap = cmaps{1};
                self = fus.ColorMapper(...
                    "cmap", cmap, ...
                    "clim_in", snap_limits(clim), ...
                    "alim_in", snap_limits(alim), ...
                    "clim_out", options.clim_out, ...
                    "alim_out", options.alim_out, ...
                    args{:});
            end
        end
        
        function self = from_struct(s)
            % FROM_STRUCT - Create a ColorMapper from a struct
            %  cmap = fus.ColorMapper.from_struct(s)
            %
            % Inputs:
            %  s (struct): struct with ColorMapper properties
            %
            % Returns:
            %   cmap (fus.ColorMapper): The colormapper
            arguments
                s struct
            end
            if isempty(s.id)
                self = fus.ColorMapper.empty;
            elseif numel(s) ~= 1
                self = arrayfun(@Colormapper.from_struct, s);
            else
                args = fus.util.struct2args(s);
                self = fus.ColorMapper(args{:});
            end
        end
    end
end

function cmap = parse_colormap(map, n)
    % PARSE_COLORMAP - Parse a colormap
    %  cmap = parse_colormap(map, n)
    %
    % Inputs:
    %  map (string, char, Nx3 double): The colormap, either
    %    - a string or char array with the name of a colormap function
    %    - a Nx3 double array with the colormap
    %  n (int): The number of colors. Default is 256
    %
    % Returns:
    %   cmap (Nx3 double): The colormap
    arguments
        map
        n (1,1) double {mustBeInteger, mustBePositive} = 256;
    end
    switch class(map)
        case {"string", "char"}
            map = string(map);
            if ~isvarname(map)
                error('Invalid Colormap')
            end
            cmap = feval(map, n);
        case {"double", "single"}
            if size(map, 2) ~= 3
                error('Invalid Colormap')
            end
            cmap = map;
        otherwise
            error('Invalid Colormap')
    end
end

function lim = snap_limits(lim, options)
    % SNAP_LIMITS - Snap limits to zero and equal ratios
    %  lim = snap_limits(lim, options)
    %
    % Inputs:
    %  lim (1x2 double): The limits
    %
    % Optional Parameters:
    %   'zero_ratio' (1x1 double): The ratio of the smaller 
    %       limit to the larger limit that will be considered zero.
    %       Default is 10
    %   'equal_ratio' (1x1 double): The ratio of the smaller
    %       limit to the larger limit that will be considered equal.
    %       Default is 0.1
    %
    % Returns:
    %   lim (1x2 double): The snapped limits
    arguments
        lim (1,2) double {mustBeNumeric}
        options.zero_ratio (1,1) double = 10
        options.equal_ratio (1,1) double = 0.1
    end
    zero_ratio = options.zero_ratio;
    eq_lo = (1-options.equal_ratio);
    eq_hi = (1+options.equal_ratio);
    if (-lim(2)/lim(1)) > eq_lo && ((-lim(2)/lim(1))) < eq_hi
        lim(1) = -1*lim(2);
    elseif abs(lim(2)) > abs(zero_ratio*lim(1))
        lim(1) = 0;
    elseif abs(lim(1)) > abs((zero_ratio*lim(2)))
        lim(2) = 0;
    end
end