classdef Transducer < fus.DataClass
    %Transducer transducer array
    %  array = Transducer("param", value, ...)
    properties
        id string = "transducer" % Transducer ID
        name string = "" % Transducer Name
        elements (1,:) fus.xdc.Element % Element array
        frequency (1,1) double {mustBePositive} = 400.6e3; % Nominal center frequency
        units (1,1) string {fus.util.mustBeDistance} = "m" % Spatial units
        matrix (4,4) double = eye(4); % Spatial transformation matrix
        attrs struct = struct()
    end

    methods
        function self = Transducer(props)
            %Transducer Transducer Constructor
            %  trans = fus.xdc.Transducer("param", value, ...)
            % 
            % Optional Parameters:
            %   'id' (string): Transducer ID
            %   'name' (string): Transducer Name
            %   'elements' (Element): Element array
            %   'frequency' (double): Nominal center frequency
            %   'units' (string): Spatial units
            %   'matrix' (double): Spatial transformation matrix
            %   'attrs' (struct): Additional attributes
            %
            % Returns:
            %   trans (fus.xdc.Transducer): Transducer object
            arguments
                props.?fus.xdc.Transducer
            end
            parse_props(self, props);
            if self.name == ""
                self.name = self.id;
            end
            for i = 1:self.numelements
                self.elements(i).rescale(self.units);
            end
        end
        
        function trans = by_id(self, id)
            % BY_ID get transducer by ID
            %   trans = trans.by_id(id)
            %
            % Inputs:
            %   id (string): Transducer ID
            %
            % Returns:
            %   trans (fus.xdc.Transducer) Transducer with matching ID
            arguments
                self (1,:) fus.xdc.Transducer
                id (1,1) string {fus.util.mustBeID(id, self)}
            end
            trans = self(id == [self.id]);
        end
        
        function trans_copy = copy(self)
            % COPY Make copy of transducer
            %    trans_copy = trans.copy()
            if numel(self) ~= 1
                trans_copy = arrayfun(@(x)x.copy(), self);
            else
                trans_copy = fus.xdc.Transducer(...
                    "id", self.id, ...
                    "name", self.name, ...
                    "elements", self.elements.copy(), ....
                    "frequency", self.frequency, ...
                    "units", self.units, ...
                    "matrix", self.matrix, ...
                    "attrs", self.attrs);
            end
        end
        
        function h = draw(self, options)
            % DRAW draw transducer
            %   h = trans.draw(options)
            %
            % Optional Parameters:
            %   'transform' (logical): Draw in global coordinates. Default: true
            %   'units' (string): Spatial units. Default: trans.units
            %   'color' (string): Color. Default: 'c'
            %   'ax' (axes): Axes to draw on. Default: gca
            %   'FaceAlpha' (double): Face alpha. Default: 0.1
            %   'EdgeColor' (string): Edge color. Default: 'c'
            %   additional inputs to PATCH are also accepted
            %
            % Returns:
            %   h (patch): Patch object
            arguments
                self fus.xdc.Transducer
                options.?matlab.graphics.primitive.Patch
                options.ax = gca
                options.transform (1,1) double {mustBeNumericOrLogical} = true
                options.units (1,1) {fus.util.mustBeDistance}
                options.color = 'c'
            end
            if numel(self) ~= 1
                args = fus.util.struct2args(options);
                h = arrayfun(@(x)x.draw(args{:}), self);
            else
                if ~isfield(options, "units")
                    options.units = self.units;
                end
                if ~isfield(options, 'EdgeColor')
                    try
                        edgecolor = validatecolor(options.color);
                    catch me
                        edgecolor = "None";
                    end
                    options.EdgeColor = edgecolor;
                end
                if ~isfield(options, 'FaceAlpha')
                    options.FaceAlpha = 0.1;
                end
                args = fus.util.struct2args(rmfield(options, {'transform', 'units','color','ax'}));
                corners = self.get_corners("transform", options.transform, "units", options.units);
                h = patch(options.ax, corners{:}, options.color,args{:}, 'DisplayName', self.name);
            end
        end
        
        function area = get_area(self, options)
            % GET_AREA get the array of the array's elements
            %   area = trans.get_area("param", value, ...)
            %
            % Optional Parameters:
            %   'units' (string): Spatial units. Default: trans.units
            %
            % Returns:
            %   area (double): Total area of the array's elements
            arguments
                self fus.xdc.Transducer
                options.units (1,1) string {fus.util.mustBeDistance} = self.units;
            end
            [widths, lengths] = self.elements.get_size("units", options.units);
            area = sum(widths.*lengths);
        end
        
        function corners = get_corners(self, options)
            % GET_CORNERS get the corners of the array
            %    corners = trans.get_corners("param", value, ...)
            %
            % Optional Parameters:
            %   'transform' (logical): transform to global coordinates. Default: true
            %   'units' (string): Spatial units. Default: trans.units
            %
            % Returns:
            %   corners (cell): Cell array of corner matrices
            arguments
                self fus.xdc.Transducer
                options.transform (1,1) double {mustBeNumericOrLogical} = true
                options.units (1,1) {fus.util.mustBeDistance} = self.units
            end
            prev_units = self.units;
            self.rescale(options.units);
            corners = self.elements.get_corners;
            if options.transform       
                A1 = reshape(cell2mat(reshape(corners,[1,1,3])),[],3)';
                A1(4,:) = 1;
                B1 = self.matrix*A1;
                B = {reshape(B1(1,:),size(corners{1})), ...
                     reshape(B1(2,:),size(corners{3})), ...
                     reshape(B1(3,:),size(corners{3}))};
                corners = B;
            end
            self.rescale(prev_units);
        end
        
        function positions = get_positions(self, options)
            % GET_POSITIONS get the positions of the array's elements
            %    position = trans.get_positions("param", value, ...)
            %
            % Optional Parameters:
            %   'transform' (logical): transform to global coordinates. Default: true
            %   'units' (string): Spatial units. Default trans.units
            %
            % Returns:
            %    positions (3xN double): Array of element positions
            arguments
                self fus.xdc.Transducer
                options.transform (1,1) double {mustBeNumericOrLogical} = true
                options.units (1,1) string {fus.util.mustBeDistance} = self.units
            end
            if options.transform
                m = self.get_matrix("units", options.units);
            else
                m = eye(4);
            end
            positions = self.elements.get_position("matrix", m, "units", options.units);
        end
        
        function matrix = get_matrix(self, options)
            % GET_MATRIX get the spatial transformation matrix
            %    matrix = trans.get_matrix("param", value, ...)
            %
            % Optional Parameters:
            %    'units' (string): Spatial units. Default: trans.units
            %
            % Returns:
            %    matrix (4x4 double): Spatial transformation matrix
            arguments
                self fus.xdc.Transducer
                options.units (1,1) string {fus.util.mustBeDistance} = self.units
            end
            matrix = self.matrix;
            matrix(1:3,4) = matrix(1:3,4) * fus.util.getunitconversion(self.units, options.units);
        end
        
        function unit_vectors = get_unit_vectors(self, options)
            % GET_UNIT_VECTORS get the unit vectors of the array
            %    unit_vectors = trans.get_unit_vectors("param", value, ...)
            % GET_UNIT_VECTORS returns a cell array of the unit vector of the Transducer
            %   object. Each unit vector is a two points: the origin and the origin 
            %   + the unit vector.
            %
            % Optional Parameters:
            %   'transform' (logical): transform to global coordinates. Default: true
            %   'scale' (double): scale the unit vectors. Default: 1
            %    'units' (string): Spatial units. Default: trans.units
            %
            % Returns:
            %    unit_vectors (1x3 cell): Cell array of 2x3 unit vector matrices
            arguments
                self fus.xdc.Transducer
                options.transform (1,1) double {mustBeNumericOrLogical} = true
                options.scale (1,1) double = 1
                options.units (1,1) {fus.util.mustBeDistance} = self.units
            end
            prev_units = self.units;
            self.rescale(options.units);
            unit_vectors = {[0 0 0;1 0 0],[0 0 0; 0 1 0],[0 0 0; 0 0 1]};
            unit_vectors = cellfun(@(x)x*options.scale, unit_vectors, "UniformOutput", false);
            if options.transform       
                A1 = reshape(cell2mat(reshape(unit_vectors,[1,1,3])),[],3)';
                A1(4,:) = 1;
                B1 = self.matrix*A1;
                B = {reshape(B1(1,:),size(unit_vectors{1})), ...
                     reshape(B1(2,:),size(unit_vectors{3})), ...
                     reshape(B1(3,:),size(unit_vectors{3}))};
                unit_vectors = B;
            end
            self.rescale(prev_units);
        end
        
        function merged_array = merge(self, options)
            % MERGE merge multiple Transducers
            % merged_array = trans.merge()
            % merged_array = trans.merge("reference", "first")
            % merged_array = trans.merge("reference", "average")
            %
            % MERGE combines the elements of multiple arrays into a single array by 
            %  transforming the elements of each array into a target coordinate system.
            %  The target coordinate system is defined either by the first array in the list, 
            %  or by the average coordinate system of all the arrays in the list if the 'reference'
            %  parameter is set to 'average'.
            %
            % Optional Parameters:
            %   'reference' (string): Reference Matrix method. Must be "first" or "average". Default: "first"
            %
            % Returns:
            %   merged_array (fus.xdc.Transducer): Merged Transducer
            arguments
                self (1,:) fus.xdc.Transducer    
                options.reference (1,1) string {mustBeMember(options.reference, ["first", "average"])} = "first"
            end
            if numel(self) == 1
                merged_array = self;
                return
            end
            switch options.reference
                case "first"
                    ref_matrix = self(1).get_matrix();
                case "average"
                    matrices = arrayfun(@(x)x.get_matrix(), self, 'UniformOutput', false);
                    matrices = cell2mat(reshape(matrices,1,1,[]));
                    ref_matrix = mean(matrices,3);
                    ref_matrix(1:3,2) = ref_matrix(1:3,2) - ref_matrix(1:3,1)*dot(ref_matrix(1:3,1),ref_matrix(1:3,2));
                    ref_matrix(1:3,3) = cross(ref_matrix(1:3,1), ref_matrix(1:3,2));
                    ref_matrix(:,1:3) = ref_matrix(:,1:3)./vecnorm(ref_matrix(:,1:3),2,1);
            end
            xform_arrays = arrayfun(@(x)x.transform(inv(x.get_matrix())*ref_matrix, "transform_elements", true), self);
            merged_array = xform_arrays(1).copy();
            for i = 2:length(xform_arrays)
                merged_array.elements = [merged_array.elements, xform_arrays(i).elements];
            end
            merged_array.matrix = ref_matrix;
        end

        function n = numelements(self)
            % NUMELEMENTS number of elements
            %    n = trans.numelements()
            %
            % Returns:
            %    n (double): Number of elements in the Transducer
            n = length(self.elements);
        end
        
        function varargout = rescale(self, units)
            % RESCALE rescale the spatial units
            %    rescaled_array = trans.rescale(units)
            %    trans.rescale(units)
            %
            % Inputs:
            %   units (string): Spatial units. Default: trans.units
            %
            % Returns:
            %   rescaled_array (fus.xdc.Transducer): Rescaled array.
            %       If no output is requested, the array is rescaled in place.
            arguments
                self fus.xdc.Transducer
                units string {fus.util.mustBeDistance}
            end
            if nargout == 1
                self = self.copy();
                varargout{1} = self;
            end
            if ~(self.units == units)
                for i = 1:self.numelements
                    self.elements(i).rescale(units);
                end
                scl = fus.util.getunitconversion(self.units, units);
                self.matrix(1:3,4) = self.matrix(1:3,4)*scl;
                self.units = units;
            end
        end
        
        function [trans, trans_ok] = select(self, options)
            % SELECT Choose among transducer Transducers
            %  [trans, trans_ok] = arrays.select("param", value, ...)
            %
            % Optional Parameters:
            %   'figure' (double): parent figure for graphical selection
            %
            % Returns:
            %   trans (fus.xdc.Transducer): Selected Transducer
            %   trans_ok (logical): true if a transducer was selected
            arguments
                self (1,:) fus.xdc.Transducer
                options.figure = -1
            end
            n = numel(self);
            switch n
                case 0
                    trans = fus.xdc.Transducer.empty;
                    trans_ok = false;
                case 1
                    trans = self;
                    trans_ok = 1;
                otherwise
                    for i = 1:n
                        t(i) = struct(...
                            'id', self(i).id, ...
                            'name', self(i).name, ...
                            'frequency', self(i).frequency, ...
                            'frequency_kHz', self(i).frequency*1e-3, ...
                            'numelements', self(i).numelements);
                    end
                    T = struct2table(t, 'AsArray', true);
                    data = T(:,{'id', 'name', 'frequency_kHz', 'numelements'});
                    names = {'ID', 'Name', 'Frequency (kHz)', 'Elements'};
                    row = fus.util.TableSelector.select(...
                        data, ...
                        'column_names', names, ...
                        'font_size', 14, ...
                        'title', 'Select a Transducer', ...
                        'position', [0.25, 0.25, 0.5, 0.5], ...
                        'parent', options.figure);
                    if size(row,1) == 0
                        trans = fus.xdc.Transducer.empty;
                        trans_ok = 0;
                    else
                        trans = self.by_id(row.id{1});
                        trans_ok = 1;
                    end
            end
        end
     
        function trans = transform(self, matrix, options)
            % TRANSFORM transform the Transducer
            %   trans_tranformed = trans.transform(matrix, "param", value, ...)
            %
            % Inputs:
            %   matrix (4,4) double: Transformation matrix
            %
            % Optional Parameters:
            %    'units' (string): Spatial Units. Defaut: trans.units
            %    'transform_elements' (logical): Transform the elements themselves. Default: false
            %
            % Returns:
            %   trans_transformed (fus.xdc.Transducer): Transformed Transducer
            arguments
                self fus.xdc.Transducer
                matrix (4,4) double
                options.units (1,1) string {fus.util.mustBeDistance} = self.units
                options.transform_elements (1,1) logical = false
            end
            if isempty(self)
                trans = fus.xdc.Transducer.empty;
                return
            end
            trans = self.rescale(options.units);
            if options.transform_elements
                for i = 1:trans.numelements
                    ele = trans.elements(i);
                    ele.set_matrix(inv(matrix)*ele.get_matrix());
                end
            else
                trans.matrix = trans.matrix/matrix;
            end
        end
    end
    
    methods (Static)
        function trans = from_file(filename)
            % FROM_FILE load Transducer from file
            %   trans = fus.xdc.Transducer.from_file(filename)
            %
            % Inputs:
            %   filename (string): JSON file
            %
            % Returns:
            %    trans (fus.xdc.Transducer): Transducer loaded from file
            arguments
                filename (1,1) string {mustBeFile}
            end
            s = jsondecode(fileread(filename));
            trans = fus.xdc.Transducer.from_struct(s);
        end
        
        function trans = from_struct(s, options)
            % FROM_STRUCT load Transducer from struct
            %  trans = fus.xdc.Transducer.from_struct(s, "param", value, ...)
            %
            % Inputs:
            %   s (1,:) struct: struct with Transducer properties
            %
            % Optional Parameters:
            %   'bad_props' (string): How to handle bad properties. Default: "as_attrs"
            %       "as_attrs": treat bad properties as attributes
            %       "error": throw an error
            %       "skip": skip bad properties
            %
            % Returns:
            %   trans (fus.xdc.Transducer): Transducer loaded from struct
            arguments
                s (1,:) struct
                options.bad_props (1,1) string {mustBeMember(options.bad_props, ["as_attrs","error","skip"])} = "as_attrs"
            end
            if numel(s) > 1 
                trans = arrayfun(@(x)fus.xdc.Transducer.from_struct(x, args{:}), s);
                return
            end
            if isempty(s.id)
                trans = fus.xdc.Transducer.empty;
                return
            end
            s.elements = fus.xdc.Element.from_struct(s.elements);
            metadata = ?fus.xdc.Transducer;
            valid_args = {metadata.PropertyList.Name};
            fn = fieldnames(s);
            for i = 1:length(fn)
                if ~ismember(fn{i}, valid_args)
                    switch options.bad_props
                        case "as_attrs"
                            warning("from_struct:bad_prop", "%s is not a valid Property. Converting to an attribute.", fn{i});
                            s.attrs.(fn{i}) = s.(fn{i});
                            s = rmfield(s, fn{i});
                        case "error"
                            error("from_struct:bad_prop", "%s is not a valid Property", fn{i});
                        case "skip"
                            warning("from_struct:bad_prop", "%s is not a valid Property. Skipping.", fn{i});
                            s = rmfield(s, fn{i});
                    end
                end
            end 
            sargs = fus.util.struct2args(s);
            trans = fus.xdc.Transducer(sargs{:});
        end
        
        function trans = gen_matrix_array(options)
            % GEN_MATRIX_ARRAY generate a simple matrix array
            %   trans = fus.xdc.Transducer.gen_matrix_array("param", value, ...)
            %
            % Optional Parameters:
            %  'nx' (1,1) double: Number of elements in x direction. Default: 2
            %  'ny' (1,1) double: Number of elements in y direction. Default: 2
            %  'pitch' (1,:) double: Element pitch. Can be [pitchx pitchy]. Default: 1
            %  'kerf' (1,1) double: Element kerf. Default: 0
            %  'units' (1,1) string: Spatial units. Default: "mm"
            %  'impulse_response' (:,1) double: Time domain impulse response. Convolved with input signals. Default: 1
            %  'impulse_dt' (1,1) double: Impulse response time-step (s). Specifies the sampling of the impulse response. Default: 1
            %  additional arguments are passed to fus.xdc.Transducer
            %
            % Returns:
            %  trans (fus.xdc.Transducer) the constructed Transducer
            arguments
                options.?fus.xdc.Transducer
                options.nx (1,1) double {mustBeInteger, mustBePositive} = 2
                options.ny (1,1) double {mustBeInteger, mustBePositive} = 2
                options.pitch (1,:) double {mustBePositive} = 1
                options.kerf (1,1) double {mustBeNonnegative} = 0
                options.units (1,1) string {fus.util.mustBeDistance} = "mm"
                options.impulse_response (:,1) double = 1 % Time domain impulse response. Convolved with input signals.
                options.impulse_dt (1,1) double {mustBePositive} = 1 % Impulse response time-step (s). Specifies the sampling of the impulse response.
            end
            if length(options.pitch)<1 || length(options.pitch)>2
                error("pitch must have 1 or 2 elements");
            end
            N = options.nx * options.ny;
            xpos = [0:options.nx-1]*options.pitch(1);
            xpos = xpos - mean(xpos);
            ypos = [0:options.ny-1]*options.pitch(end);
            ypos = ypos - mean(ypos);
            [Xpos, Ypos] = meshgrid(xpos, ypos);
            for i = 1:N
                elements(i) = fus.xdc.Element(...
                    index=i, ...
                    x=Xpos(i), ...
                    y=Ypos(i), ...
                    z=0, ... 
                    az=0, ...
                    el=0,...
                    w=options.pitch(1)-options.kerf, ...
                    l=options.pitch(end)-options.kerf, ...
                    impulse_response=options.impulse_response, ...
                    impulse_dt=options.impulse_dt, ...
                    units=options.units);
            end
            options.elements = elements;
            args = fus.util.struct2args(rmfield(options, {'nx', 'ny', 'pitch', 'kerf','impulse_response','impulse_dt'}));
            trans = fus.xdc.Transducer(args{:});  
        end
    end
end
