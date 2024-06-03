classdef Scene < fus.DataClass
% SCENE A collection of volumes, targets, and markers
%  SCENE is a collection of volumes, targets, and markers. It also
%  contains a transducer array and a set of colormaps. SCENE is the
%  fundamental data structure for the ultrasound simulation toolbox.
    properties
        id (1,1) string {mustBeValidVariableName} = "scene"
        name (1,1) string = ""
        targets (1,:) fus.Point
        markers (1,:) fus.Point
        volumes (1,:) fus.Volume
        colormaps (1,:) fus.ColorMapper
        transducer fus.xdc.Transducer
        attrs (1,1) struct
    end
    
    methods
        function self = Scene(options)
            % SCENE Construct a new Scene object
            % scene = fus.Scene("param", value, ...) creates a new Scene object
            % with the specified parameters. 
            %
            % Optional Parameters:
            %   'id' (1,1) string: The name of the scene. Default: "scene"
            %   'name' (1,1) string: A human-readable name for the scene.
            %       Default: ""
            %   'targets' (1,:) fus.Point: A list of targets in the scene.
            %       Default: fus.Point.empty
            %   'markers' (1,:) fus.Point: A list of markers in the scene.
            %       Default: fus.Point.empty
            %   'volumes' (1,:) fus.Volume: A list of volumes in the scene.
            %       Default: fus.Volume.empty
            %   'colormaps' (1,:) fus.ColorMapper: A list of colormaps in the
            %       scene. Default: fus.ColorMapper.empty
            %   'transducer' (1,1) fus.xdc.Transducer: The transducer array in the
            %       scene. Default: fus.xdc.Transducer.empty
            %   'attrs' (1,1) struct: A struct containing any additional
            %       attributes to be stored with the scene. Default: struct
            %       with no fields.
            %
            % Returns:
            %   scene (1,1) fus.Scene: The newly created Scene object.
            arguments
                options.?fus.Scene
            end
            self.parse_props(options);
        end
        
        function scene = by_id(self, id)
            % BY_ID Get a scene by its ID
            % scene = scene.by_id(id) returns the scene with the specified
            % ID(s). If no scene with the specified ID exists, an error is
            % thrown.
            %
            % Inputs:
            %   id (1,:) string: The ID(s) of the scene to return.
            %
            % Returns:
            %   scene (1,:) fus.Scene: The scene with the specified ID(s).
            arguments
                self (1,:) fus.Scene
                id (1,:) string {fus.util.mustBeID(id, self)}
            end
            scene = arrayfun(@(id)self(strcmp(id, [self.id])), id);
        end
        
        function scene = copy(self, options)
            % COPY Copy a scene
            % scene = scene.copy() creates a copy of the scene.
            %
            % Optional Parameters:
            %   'deepcopy' (1,1) logical: If true, the scene is deep-copied
            %       (i.e., all objects in the scene are copied). If false,
            %       the scene is shallow-copied (i.e., all objects in the
            %       scene are copied by reference). Default: false
            %   'keep_colormaps' (1,1) logical: If true, the colormaps in
            %       the scene are copied. If false, the colormaps in the
            %       scene are not copied. This parameter is only used when
            %       'deepcopy' is true. Default: true
            %
            % Returns:
            %   scene (1,1) fus.Scene: The copied scene.
            arguments
                self fus.Scene
                options.deepcopy (1,1) logical = false
                options.keep_colormaps (1,1) logical = true
            end
            if options.deepcopy
                scene = copy@fus.DataClass(self);
                if options.keep_colormaps
                    scene.colormaps = self.colormaps;
                end
            else
                scene = fus.Scene(...
                    "id", self.id, ...
                    "name", self.name, ...
                    "targets", self.targets, ...
                    "markers", self.markers, ...
                    "volumes", self.volumes, ...
                    "colormaps", self.colormaps, ...
                    "transducer", self.transducer, ...
                    "attrs", self.attrs);
            end
        end
        
        function [f, trans_handle] = four_up(self, options)
            % FOUR_UP Display the scene in a four-up figure
            % f = scene.four_up() displays the scene in a four-up figure.
            %
            % Optional Parameters:
            %   'parent': parent graphics object to create axes in (if axes
            %       are not provided).
            %   'axes' (1,4) axes: The axes in which to display the scene.
            %   'xdim' (1,3) string: The dimensions to display on the x
            %       axis. 
            %   'ydim' (1,3) string: The dimensions to display on the y
            %       axis. 
            %   'zdim' (1,3) string: The dimensions to display on the z
            %       axis (out-of-plane). 
            %   'volume_ids' (1,:) string: The IDs of the volumes to
            %       display in the four-up figure. Default: All volumes in
            %       the scene.
            %   'values' (1,:) double: The values to display in the
            %       four-up figure. Default: []
            %   'axes_props' (1,1) struct: A struct containing any
            %       additional properties to set on the axes. Default:
            %       struct with no fields.
            %   'line_props' (1,1) struct: A struct containing any
            %       additional properties to set on the borders of the
            %       slices
            %   'fig_props' (1,1) struct: A struct containing any
            %       additional properties to set on the figure. Default:
            %       struct with no fields.
            %   'padding' (1,1) double: The padding between the axes in
            %       pixels. Default: 40
            %   'spacing' (1,1) double: The spacing between the axes and
            %       the figure in pixels. Default: 40
            %   'on_update' (1,1) function_handle: A function handle to
            %       call when the scene is updated. Default: function
            %       handle with no arguments
            %   'colorbar' (1,1) double: draw colorbar. Default: False
            %   'colorbar_width' (1,1) double: width of colorbar relative
            %       to other axes. Default: 0.3
            %   'point_props' (1,1) struct: A struct containing any
            %       additional properties to set on the points. Default:
            %       struct with fields "EdgeAlpha" = 0.5 and "FaceAlpha" =
            %       0.3.
            %   'transducer_props' (1,1) struct: A struct containing any
            %       additional properties to set on the transducer. Default:
            %       struct with fields "EdgeAlpha" = 0.3 and "FaceAlpha" =
            %       0.1.
            %
            % Returns:
            %   f (1,1) fus.ui.FourUp: The four-up object.
            %   trans_handle (1,N) transducer patches.
            arguments
                self fus.Scene
                options.parent = []
                options.axes (1,4) {fus.util.mustBeAxes}
                options.axes_arrangement double {mustBeInteger, mustBeInRange(options.axes_arrangement, 0, 4)}= [1 2; 3 4];
                options.xdim (1,3) string
                options.ydim (1,3) string
                options.zdim (1,3) string
                options.volume_ids (1,:) string = [self.volumes.id]
                options.values (1,:) double = []                
                options.colorbar (1,1) logical = false
                options.colorbar_width (1,1) double {mustBePositive} = 0.3;
                options.axes_props (1,1) struct = struct("Color","k");
                options.line_props (1,1) struct = struct;
                options.fig_props (1,1) struct = struct;
                options.padding (1,1) double = 40
                options.spacing (1,1) double = 40
                options.on_update function_handle = function_handle.empty
                options.point_props (1,1) struct = struct("EdgeAlpha", 0.5, "FaceAlpha", 0.3)
                options.transducer_props (1,1) struct = struct("EdgeAlpha", 0.3, "FaceAlpha", 0.1);
            end
            args = fus.util.struct2args(rmfield(options, ["volume_ids", "transducer_props"]));
            indices = arrayfun(@(id)find(id==[self.volumes.id],1),options.volume_ids);
            cmap_indices = mod(indices-1, length(self.colormaps))+1;
            f = fus.ui.FourUp(self.volumes(indices), self.colormaps(cmap_indices), "points", self.targets, args{:});
            targs = fus.util.struct2args(options.transducer_props);
            trans_handle = self.transducer.draw("ax", f.axes(end), targs{:});
        end
        
        function varargout = rescale(self, units)
            % RESCALE Rescale the scene
            % scene = scene.rescale(units) 
            % scene.rescale(units)
            %
            % RESCALE rescales the scene to the scene coordinates
            % to the specified units. The scene is rescaled in-place if no output
            % is assigned. A copy of the scene is returned if an output is
            % assigned.
            %
            % Optional Parameters:
            %   'units' (1,1) string: The units to which to rescale the
            %       scene. Default: "mm"
            %
            % Returns:
            %   scene (1,1) fus.Scene: The rescaled scene. 
            arguments
                self fus.Scene
                units (1,1) string {fus.util.mustBeDistance}
            end
            if nargout == 1
                scene = self.copy("deepcopy", true);
                varargout{1} = scene;
            else
                scene = self;
            end
            scene.volumes.rescale(units);
            scene.targets.rescale(units);
            scene.markers.rescale(units);
            scene.transducer.rescale(units);
        end
        
        function scene = transform_base(self, options)
            % TRANSFORM_BASE Transform the scene to the base coordinate system
            % scene = scene.transform_base("param", value, ...) 
            % TRANSFORM_BASE transforms the scene to the base
            % coordinate system. 
            %
            % Optional Parameters:
            %   'dx' (1,1) double: The spacing between the points in the
            %       transformed scene. Default: 1
            %   'units' (1,1) string: The units of the transformed scene.
            %       Default: "mm"
            %   'method' (string): interpolation method for interpn. Default "linear".
            %
            % Returns:
            %   scene (1,1) fus.Scene: The transformed scene.
            arguments
                self fus.Scene
                options.dx (1,1) = 1
                options.units (1,1) string {fus.util.mustBeDistance} = "mm"
                options.method (1,1) string {mustBeMember(options.method, ["linear", "nearest", "spline", "cubic", "makima"])} = "linear"
            end
            x_vecs = cellfun(@(x)[min(x(:)):options.dx:max(x(:))],self.volumes.get_edges("transform",true, "units",options.units),'UniformOutput',false);
            coords_lps = cellfun(@(x,id)fus.Axis(x, id, 'units', options.units), x_vecs, {'L','P','S'});
            matrix = eye(4);
            scene = self.transform(coords_lps, matrix, "method", options.method);
        end
        
        function scene = transform(self, coords, matrix, options)
            % TRANSFORM Transform the scene
            % scene = scene.transform(coords, matrix, "param", value, ...)
            % TRANSFORM transforms the scene to the coordinate system
            % specified by the coordinate system object coords.
            %
            % Inputs:
            %   coords (1,3) fus.Axis: The coordinate system to which to
            %       transform the scene.
            %   matrix (4,4) double: The transformation matrix to apply to
            %       the scene.
            %
            % Optional Parameters:
            %   'id' (1,1) string {mustBeValidVariableName}: The id of the
            %       transformed scene. Default: self.id
            %   'name' (1,1) string: The name of the transformed scene.
            %       Default: self.name
            %   'method' (string): interpolation method for interpn. Default "linear".
            %
            % Returns:
            %   scene (1,1) fus.Scene: The transformed scene.
            arguments
                self fus.Scene
                coords (1,3) fus.Axis
                matrix (4,4) double
                options.id (1,1) string {mustBeValidVariableName} = self.id
                options.name (1,1) string = self.name
                options.method (1,1) string {mustBeMember(options.method, ["linear", "nearest", "spline", "cubic", "makima"])} = "linear"
            end
            transform_volumes = self.volumes.transform(coords, matrix, "method", options.method);
            transform_targets = self.targets.transform(matrix, "dims", [coords.id], "units", coords.get_units);
            transform_markers = self.markers.transform(matrix, "dims", [coords.id], "units", coords.get_units);
            transform_array = self.transducer.transform(matrix, "units", coords.get_units);
            scene = fus.Scene(...
                "id", options.id,...
                "name", options.name, ...
                "targets", transform_targets, ...
                "markers", transform_markers, ...
                "volumes", transform_volumes, ...
                "colormaps", self.colormaps, ...
                "transducer",transform_array,...
                "attrs", self.attrs);
        end
    end

    methods (Static)
        function scene = from_struct(s)
            % FROM_STRUCT Create a scene from a struct
            % scene = fus.Scene.from_struct(s)
            %
            % Inputs:
            %   s (1,1) struct: The struct from which to create the scene.
            %
            % Returns:
            %   scene (1,1) fus.Scene: The scene created from the struct.
            arguments
                s struct
            end
            if numel(s) ~= 1
                scene = arrayfun(@fus.Scene.from_struct, s);
            else
                s.targets = fus.Point.from_struct(s.targets);
                s.markers = fus.Point.from_struct(s.markers);
                s.volumes = fus.Volume.from_struct(s.volumes);
                s.colormaps = fus.ColorMapper.from_struct(s.colormaps);
                s.transducer = fus.xdc.Transducer.from_struct(s.transducer);
                args = fus.util.struct2args(s);
                scene = fus.Scene(args{:});
            end
        end
    end
    
end