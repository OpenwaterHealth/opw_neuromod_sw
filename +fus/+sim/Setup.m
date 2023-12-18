classdef Setup < fus.DataClass
    % Setup - Class for defining the simulation options
    properties
        dims (1,3) string = ["lat","ele","ax"]
        names (1,3) string = ["Lateral", "Elevation", "Axial"]
        spacing (1,1) double {mustBePositive} = 1
        units (1,1) string {fus.util.mustBeDistance} = "mm"
        x_extent (1,2) double = [-30, 30]
        y_extent (1,2) double = [-30, 30]
        z_extent (1,2) double = [-4, 60]
        dt (1,1) double {mustBeNonnegative} = 0 %Simulation time end (s)
        t_end (1,1) double {mustBeNonnegative} = 0 %Simulation time end (s)
        options (1,1) struct = struct() % Additional Simulation Options
    end
    methods
        function self = Setup(options)
            arguments
                options.?fus.sim.Setup
            end
            self.parse_props(options);
        end
        
        function coords = get_coords(self, dims, options)
            arguments
                self fus.sim.Setup
                dims (1,:) string {fus.util.mustBeDim(dims, self)} = self.dims
                options.units (1,1) string {fus.util.mustBeDistance} = self.units
            end
            if numel(dims)>1
                args = fus.util.struct2args(options);
                coords = arrayfun(@(dim)self.get_coords(dim, args{:}), dims);
                return
            end
            dim_index = find(dims == self.dims);
            switch dim_index
                case 1
                    extent = self.x_extent;
                case 2
                    extent = self.y_extent;
                case 3
                    extent = self.z_extent;
            end
            values = extent(1):self.spacing:extent(2);
            coords = fus.Axis(values, self.dims(dim_index), name=self.names(dim_index), units=self.units);
            coords.rescale(options.units);
        end 
        
        function corners = get_corners(self, options)
            arguments
                self fus.sim.Setup
                options.id (1,1) string {mustBeValidVariableName} = "corners"
                options.units (1,1) string {fus.util.mustBeDistance} = self.units
            end
            [X,Y,Z] = ndgrid(self.x_extent, self.y_extent, self.z_extent);
            corners = fus.Point(...
                id=options.id,...
                name=sprintf("Corners of Simluation Grid"), ...
                position = [X(:) Y(:) Z(:)]', ...
                units=self.units, ...
                dims=self.dims);
            corners.rescale(options.units);
            
        end
        
        function max_distance = get_max_distance(self, trans, options)
            arguments
                self fus.sim.Setup
                trans fus.xdc.Transducer
                options.units (1,1) string {fus.util.mustBeDistance} = self.units
            end
            corners = self.get_corners("units", trans.units);
            for i = 1:size(corners.position,2)
                distances(i,:) = trans.elements.distance_to_point(corners.position(:,i));
            end
            max_distance = max(distances,[],"all");
            scl = fus.util.getunitconversion(trans.units, options.units);
            max_distance = max_distance*scl;
        end
        
        function sim_scene = transform_scene(self, scene, options)
            arguments 
                self fus.sim.Setup
                scene fus.Scene
                options.units (1,1) string {fus.util.mustBeDistance} = self.units
                options.id (1,1) string {mustBeValidVariableName} = scene.id
                options.name (1,1) string = scene.name
            end
            sim_coords = self.get_coords(units=options.units);
            sim_matrix = scene.transducer.get_matrix(units=options.units);
            sim_scene = scene.transform(sim_coords, sim_matrix, "id", options.id, "name", options.name);
        end        
    end
    
    methods (Static)
        function self = from_struct(s)
            arguments
                s struct
            end
            args = fus.util.struct2args(s);
            self = fus.sim.Setup(args{:});
        end
    end
end