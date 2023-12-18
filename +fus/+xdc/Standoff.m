classdef Standoff < fus.DataClass
    % STANDOFF class: contains information about the standoff
    properties
        id (1,1) string {mustBeValidVariableName} = "standoff"; % ID of the standoff
        offset_matrix (4,4) double {mustBeReal, mustBeFinite} = eye(4); % Offset matrix
        x (1,:) double {mustBeReal, mustBeFinite} = []; % 1xM Anchor points in the x direction
        y (1,:) double {mustBeReal, mustBeFinite} = []; % 1xN Anchor points in the y direction
        Z (:,:) double {mustBeReal, mustBeFinite} = []; % NxM Anchor points in the z direction
        H (:,:) double {mustBeReal, mustBeFinite} = []; % NxM Height Transducer
        units (1,1) string {fus.util.mustBeDistance} = "mm"; % Units of the standoff
        material_properties (1,1) fus.seg.MaterialReference = fus.seg.MaterialReference.load_default("water"); % Material properties
    end
    methods
        function self = Standoff(options)
            %STANDOFF constructor
            %  self = Standoff("param", value)
            %
            % Optional Parameters:
            %   'id' (string): ID of the standoff
            %   'offset_matrix' (4x4 double): Offset matrix
            %   'x' (1xM double): Anchor points in the x direction
            %   'y' (1xN double): Anchor points in the y direction
            %   'Z' (NxM double): Anchor points in the z direction
            %   'H' (NxM double): Height Transducer
            %   'material_properties' (fus.seg.MaterialReference): Material properties
            %
            % Returns:
            %   self (Standoff): The standoff object
            arguments
                options.?fus.xdc.Standoff
            end
            self.parse_props(options) 
            if ~isequal(size(self.H), [numel(self.y), numel(self.x)])
                error("Standoff:InvalidDimensions", "Standoff dimensions do not match x and y dimensions")
            end
            if isempty(self.Z)
                self.Z = zeros(size(self.H));
            end
        end

        function mask = get_mask(self, coords, options)
            % GET_MASK returns a mask for the standoff
            %  mask = self.get_mask(coords)
            %  mask = self.get_mask(coords, "param", value, ...)
            %
            % Input:
            %   coords (1,3) fus.Axis: Axis to get the mask for
            %
            % Optional Parameters:
            %   'matrix' (4x4 double): Transformation matrix. Default identity
            %   'backing' (double): How far behind the base of standoff to project the 
            %     mask backward. Prevents the transducer source from being at the numeric
            %     edge of the standoff when positive. Default inf (project all the way to
            %     the edge of the coordinates - reasonable for simulation grids.
            %   'units' (string): Units to rescale to. Default is the units of the coords
            %
            % Returns:
            %   mask (MxNxP logical): Mask for the standoff in the coords ndgrid
            arguments
                self fus.xdc.Standoff
                coords (1,3) fus.Axis
                options.matrix (4,4) double {mustBeReal, mustBeFinite} = eye(4);
                options.backing (1,1) double = inf;
                options.units (1,1) string {fus.util.mustBeDistance} = coords.get_units
            end
            X = coords.ndgrid("units", options.units, "vectorize", true);
            s = self.rescale(options.units);
            n = numel(X{1});
            X1 = [cell2mat(X)';ones(1,n)];
            Xf = options.matrix \ X1;
            Xf = mat2cell(Xf(1:3,:), ones(3,1), n);
            Xf = cellfun(@(x)reshape(x, coords.length), Xf, 'UniformOutput', false);
            Zf = interp2(s.x, s.y, s.Z, Xf{1}, Xf{2}, 'makima', nan);
            Hf = interp2(s.x, s.y, s.H, Xf{1}, Xf{2}, 'makima', nan);
            DZ = Xf{3};
            mask = (((DZ-Zf)>(-1*options.backing)) & (DZ-Zf)<=0) | ((DZ./Zf)>=1 & (DZ./(Zf + Hf))<=1);
        end

        function [hull, ngrid] = get_hull(self, coords, options)
            % GET_HULL returns a convex hull for the standoff
            %  hull = self.get_hull(coords)
            %  hull = self.get_hull(coords, "param", value, ...)
            %
            % Input:
            %   coords (1,3) fus.Axis: Axis to get the mask for
            %
            % Optional Parameters:
            %   'matrix' (4x4 double): Transformation matrix. Default identity
            %   'backing' (double): How far behind the base of standoff to project the 
            %     mask backward. Prevents the transducer source from being at the numeric
            %     edge of the standoff when positive. Default inf (project all the way to
            %     the edge of the coordinates - reasonable for simulation grids.
            %   'units' (string): Units to rescale to. Default is the units of the coords
            %   'simplify' (logical): Whether to simplify the mask. Default true
            %
            % Returns:
            %   hull (Px3 double): Convex hull for the standoff in the coords ndgrid
            %   ngrid (1x3 cell): Meshgrid for the standoff in the coords ndgrid
            arguments
                self fus.xdc.Standoff
                coords (1,3) fus.Axis
                options.matrix (4,4) double {mustBeReal, mustBeFinite} = eye(4);
                options.backing (1,1) double = 2;
                options.units (1,1) string {fus.util.mustBeDistance} = coords.get_units
                options.simplify (1,1) logical = true
            end
            mask = self.get_mask(coords, "backing", options.backing, "units", options.units);
            mgrid0 = coords.ndgrid("units", options.units, "matrix", options.matrix);
            ngrid = cellfun(@(x)double(x(mask)), mgrid0, 'UniformOutput', false);
            hull = convhull(ngrid{:}, "simplify", options.simplify);
        end
        
        function varargout = rescale(self, units)
            % RESCALE rescales the standoff
            %  self = self.rescale(units)
            %
            % Input:
            %   units (string): Units to rescale to
            %
            % Returns:
            %   self (Standoff): The rescaled standoff. If no output is requested,
            %     the object is rescaled in place.
            arguments
                self fus.xdc.Standoff
                units (1,1) string {fus.util.mustBeDistance}
            end
            if nargout > 0
                self = self.copy();
                varargout{1} = self;
            end
            scl = fus.util.getunitconversion(self.units, units);
            self.x = self.x * scl;
            self.y = self.y * scl;
            self.Z = self.Z * scl;  
            self.H = self.H * scl;
            self.offset_matrix(1:3,4) = self.offset_matrix(1:3,4) * scl;
            self.units = units;
        end

    end
    methods (Static)
        function obj = from_struct(s)
            %FROM_STRUCT creates a standoff object from a struct
            %  obj = Standoff.from_struct(s)
            %
            % Input:
            %   s (struct): Struct with the properties of the standoff
            %
            % Returns:
            %   obj (Standoff): The standoff object
            arguments
                s struct;
            end
            if isfield(s, 'material_properties')
                s.material_properties = fus.seg.MaterialReference.from_struct(s.material_properties);
            end
            args = fus.util.struct2args(s);
            obj = fus.xdc.Standoff(args{:});
        end

        function obj = from_file(filename)
            %FROM_FILE creates a standoff object from a JSON file
            %  obj = Standoff.from_file(filename)
            %
            % Input:
            %   filename (string): Path to the JSON file
            %
            % Returns:
            %   obj (Standoff): The standoff object
            arguments
                filename string {mustBeFile};
            end
            s = jsondecode(fileread(filename));
            obj = fus.xdc.Standoff.from_struct(s);
        end
    end
end