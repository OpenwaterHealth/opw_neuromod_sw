classdef Element < fus.DataClass
    % ELEMENT a rectangular element in an array
    %   Each ELEMENT has a position, orientation, and size, as well as an
    %   optional impulse response
    %   el = fus.xdc.Element('param',value, ...)
    %   el = fus.xdc.Element("x", x, "y", y, "z", z, ...)
    %   el = fus.xdc.Element("matrix", m, ...)
    properties
        index (1,1) double {mustBeInteger} = 1 % Element index
        x (1,1) double % X Position (m)
        y (1,1) double % Y Position (m)
        z (1,1) double % Z Position (m)
        az (1,1) double = 0  % Azimuthal rotation about the y-axis (rad)
        el (1,1) double = 0 % Elevation rotation about the x'-axis (rad)
        roll (1,1) double = 0 % Elevation rotation about the z''-axis (rad)
        w (1,1) double {mustBeNonnegative} % Element Width in the X-direction (m)
        l (1,1) double {mustBeNonnegative} % Element Length in the Y-direction (m)
        impulse_response (:,1) double = 1 % Time domain impulse response. Convolved with input signals.
        impulse_dt (1,1) double {mustBePositive} = 1 % Impulse response time-step (s). Specifies the sampling of the impulse response.
        pin (1,1) {mustBeInteger} = -1 % Element Pin Mapping. A value of -1 will be converted to the index
        units (1,1) string {fus.util.mustBeDistance} = "m";
    end
        
    methods
        function self = Element(options)
            % Create Element object
            %   el = fus.xdc.Element('param',value, ...)
            %   el = fus.xdc.Element("x", x, "y", y, "z", z, ...)
            %   el = fus.xdc.Element("matrix", m, ...)
            %
            % Optional Parameters:
            %  'index' (double) - Element index
            %  'x' (double) - X Position
            %  'y' (double) - Y Position
            %  'z' (double) - Z Position
            %  'az' (double) - Azimuthal rotation about the y-axis (rad)
            %  'el' (double) - Elevation rotation about the x'-axis (rad)
            %  'roll' (double) - Roll rotation about the z''-axis (rad)
            %  'w' (double) - Element Width in the X-direction
            %  'l' (double) - Element Length in the Y-direction
            %  'impulse_response' (double) - Time domain impulse response. Convolved with input signals.
            %       If impulse_response is length 1, it is assumed to be a constant gain. In order to 
            %       scale an impulse response correctly to match measured pressure p0 for a narrowband 
            %       center frequency f0 at voltage v0, normalize the response y(t) by 
            %       (p0/v0)/(abs(sum(y*exp(-1i*2*pi*f0*t)))). This will ensure that an input voltage of 
            %       y1[t] = v0*sin(2*pi*f0*t) produces a pressure of p0.
            %       
            %  'impulse_dt' (double) - Impulse response time-step (s). Specifies the sampling of the impulse response.
            %  'pin' (double) - Element Pin Mapping. A value of -1 will be converted to the index
            %  'units' (string) - Units of the element parameters. Default is 'm'
            arguments
                options.index (1,1) double {mustBeInteger} = 1 % Element index
                options.x (1,1) double % X Position (m)
                options.y (1,1) double % Y Position (m)
                options.z (1,1) double % Z Position (m)
                options.az (1,1) double = 0  % Azimuthal rotation about the y-axis (rad)
                options.el (1,1) double = 0 % Elevation rotation about the x'-axis (rad)
                options.roll (1,1) double = 0 % Elevation rotation about the z''-axis (rad)
                options.w (1,1) double {mustBeNonnegative} % Element Width in the X-direction (m)
                options.l (1,1) double {mustBeNonnegative} % Element Length in the Y-direction (m)
                options.impulse_response (:,1) double = 1 % Time domain impulse response. Convolved with input signals.
                options.impulse_dt (1,1) double {mustBePositive} = 1 % Impulse response time-step (s). Specifies the sampling of the impulse response.
                options.pin (1,1) {mustBeInteger} = -1 % Element Pin Mapping. A value of -1 will be converted to the index
                options.units (1,1) string {fus.util.mustBeDistance} = "m";
                options.matrix (4,4) double
            end
            if isfield(options, "matrix")
                if any(isfield(options, ["x","y","z","az","el","roll"]))
                    error('Cannot specify both matrix and position/rotation');
                end
                [x,y,z,az,el,roll] = fus.xdc.Element.matrix2xyz(options.matrix);
                options.x = x;
                options.y = y;
                options.z = z;
                options.az = az;
                options.el = el;
                options.roll = roll;
                self.parse_props(rmfield(options, "matrix"));
            else
                self.parse_props(options);
            end
            if self.pin == -1
                self.pin = self.index;
            end
        end 
        
        function output_signal = calc_output(self, input_signal, dt)
            % Calculate the output signal of the element
            %   output_signal = el.calc_output(input_signal, dt)
            %
            % Inputs:
            %   input_signal (Nx1 double) - Input signal to the element
            %   dt (double) - Time-step of the input signal (s)
            %
            % Returns:
            %   output_signal (Nx1 double) - Output signal of the element
            arguments
                self fus.xdc.Element
                input_signal (:,1) double
                dt (1,1) double {mustBeNonnegative}
            end
            if numel(self) > 1
                output_signal = arrayfun(@(x)x.calc_output(input_signal, dt), self, 'UniformOutput', false);
            else
                if length(self.impulse_response) == 1
                    output_signal = input_signal * self.impulse_response;
                else
                    impulse = self.interp_impulse_response(dt);
                    output_signal = convn(input_signal, impulse, 'full')*dt/self.impulse_dt;
                end
            end
        end
        
        function el_copy = copy(self)
            % COPY Make Copy of Element
            %  el_copy = el.copy()
            if numel(self) ~= 1
                el_copy = arrayfun(@(x)x.copy(), self);
            else
                el_copy = fus.xdc.Element(...
                    "index", self.index, ...
                    "x", self.x, ...
                    "y", self.y, ...
                    "z", self.z, ...
                    "az", self.az, ...
                    "el", self.el, ...
                    "roll", self.roll, ...
                    "w", self.w, ...
                    "l", self.l, ...
                    "impulse_response", self.impulse_response, ...
                    "impulse_dt", self.impulse_dt, ...
                    "pin", self.pin, ...
                    "units", self.units);
            end 
        end
        
        function rescale(self, units)
            % RESCALE Rescale the element
            %   el.rescale(units)
            %
            % Inputs:
            %   units (string) - Units to rescale to
            if ~(self.units == units)
                scl = fus.util.getunitconversion(self.get_units, units);
                self.x = self.x*scl;
                self.y = self.y*scl;
                self.z = self.z*scl;
                self.w = self.w*scl;
                self.l = self.l*scl;
                self.units = units;
            end
        end
        
        function pos = get_position(self, options)
            % GET_POSITION Get the position of the element
            %   pos = el.get_position('param',value, ...)
            %
            % Optional Parameters:
            %   'units' (string) - Units of the output position. Default is el.units
            %   'matrix' (4x4 double) - Transformation matrix to apply to the position. Default is identity
            %
            % Returns:
            %   pos (3xN double) - Position of the element(s)
            arguments
                self
                options.units (1,1) string {fus.util.mustBeDistance} = self.get_units;
                options.matrix (4,4) double = eye(4)
            end
            scl = fus.util.getunitconversion(self.get_units, options.units);
            pos = [self.x;self.y;self.z]*scl;
            pos(4,:) = 1;
            pos = options.matrix*pos;
            pos = pos(1:3,:);
        end
        
        function [ele_width, ele_length] = get_size(self, options)
            % GET_SIZE Get the size of the element
            %   [ele_width, ele_length] = el.get_size('param',value, ...)
            %
            % Optional Parameters:
            %   'units' (string) - Units of the output size. Default is el.units
            %
            % Returns:
            %   ele_width (1xN double) - Width of the element(s)
            %   ele_length (1xN double) - Length of the element(s)
            arguments
                self
                options.units (1,1) string {fus.util.mustBeDistance} = self.get_units;
            end
            scl = fus.util.getunitconversion(self.get_units, options.units);
            ele_width = [self.w]*scl;
            ele_length = [self.l]*scl;
        end
        
        function a = get_area(self, options)
            % GET_AREA Get the area of the element
            %   a = el.get_area('param',value, ...)
            %
            % Optional Parameters:
            %   'units' (string) - Units of the output area. Default is el.units^2
            %
            % Returns:
            %   a (1xN double) - Area of the element(s)
            arguments
                self
                options.units (1,1) string {fus.util.mustBeDistance} = self.get_units;
            end
            args = fus.util.struct2args(options);
            [ele_width, ele_length] = self.get_size(args{:});
            a = ele_width.*ele_length;
        end
        
        function c = get_corners(self, options)
            % GET_CORNERS Get the corners of the element
            %   c = el.get_corners('param',value, ...)
            %
            % Optional Parameters:
            %   'units' (string) - Units of the output corners. Default is el.units
            %   'matrix' (4x4 double) - Transformation matrix to apply to the corners. Default is identity
            %
            % Returns:
            %   c (1x3 cell of 4xN double) Corners of the element(s).
            arguments
                self
                options.units (1,1) string {fus.util.mustBeDistance} = self.get_units;
                options.matrix (4,4) double = eye(4)
            end
            c = cell(1,3);
            for i = 1:length(self)
                ele = self(i);
                scl = fus.util.getunitconversion(ele.units, options.units);
                rect = [...
                    [-1, -1,  1,  1]*0.5*ele.w;
                    [-1,  1,  1, -1]*0.5*ele.l,;
                    [ 0,  0,  0,  0,];...
                    [ 1,  1,  1,  1]];
                xyz = ele.get_matrix()*rect;
                xyz1 = options.matrix*xyz;
                for j = 1:3
                    c{j}(:,i) = xyz1(j,:)' * scl;
                end
            end         
        end
        
        function m = get_matrix(self)
            % GET_MATRIX Get the transformation matrix of the element
            %   m = el.get_matrix()
            %
            % Returns:
            %   m (4x4 double) - Transformation matrix of the element
            arguments
                self (1,1) fus.xdc.Element
            end
             Raz = [...
                  cos(self.az), 0, sin(self.az);
                  0, 1, 0;
                  -sin(self.az), 0, cos(self.az)];
             Rel = [1 0 0;
                 0, cos(self.el), -sin(self.el);
                 0, sin(self.el), cos(self.el)];
            Rroll = [cos(self.roll), -sin(self.roll), 0;
                     sin(self.roll) cos(self.roll) 0;
                     0 0 1];
            m = [Raz*Rel*Rroll [self.x;self.y;self.z];[0,0,0,1]]; 
        end
        
        function [az, el] = get_angle(self, options)
            % GET_ANGLE Get the angle of the element
            %   [az, el] = el.get_angle('param',value, ...)
            %
            % Optional Parameters:
            %   'units' (string) - Units of the output angle ("rad" or "deg"). Default is "rad"
            %
            % Returns:
            %   az (1xN double) - Azimuth angle of the element(s)
            %   el (1xN double) - Elevation angle of the element(s)
            arguments
                self (1,:) fus.xdc.Element
                options.units string {mustBeMember(options.units, ["rad", "deg"])} = "rad";
            end
            switch options.units
                case "rad"
                    az = [self.az];
                    el = [self.el];
                case "deg"
                    az = rad2deg([self.az]);
                    el = rad2deg([self.el]);
            end
        end
        
        function units = get_units(self)
            % GET_UNITS Get the units of the element
            %   units = el.get_units()
            %
            % Returns:
            %   units (string) - Units of the element(s)
            arguments
                self (1,:) fus.xdc.Element
            end
            self_units = [self.units];
            if length(unique(self_units)) > 1
                error('Units do not all match');
            end
            units = self_units{1};
        end
        
        function [impulse_response, impulse_t] = interp_impulse_response(self, dt)
            % INTERP_IMPULSE_RESPONSE Interpolate the impulse response of the element
            %   [impulse_response, impulse_t] = el.interp_impulse_response(dt)
            %
            % Inputs:
            %   dt (double): Time step to interpolate the impulse response to
            %
            % Returns:
            %   impulse_response (MxN double): Interpolated impulse response of the element(s)
            %   impulse_t (Mx1 double): Time vector of the impulse response
            arguments
                self
                dt (1,1) double {mustBePositive} = min(self.impulse_dt)
            end         
            ir_cell = cell(1,length(self));
            for i = 1:length(self)
                ele = self(i);
                n0 = length(ele.impulse_response);
                if n0 == 1
                    ir_cell{i} = ele.impulse_response;
                else
                    t0 = ele.impulse_dt * (0:n0-1);
                    t1 = 0:dt:t0(end);
                    ir_cell{i} = interp1(t0, ele.impulse_response, t1);
                end
            end 
            sz = max(cellfun(@length, ir_cell));
            impulse_response = zeros(sz, length(self));
            impulse_t = (0:sz-1)*dt;
            impulse_t = (impulse_t-mean(impulse_t))';
            for i = 1:length(ir_cell)
                ir = ir_cell{i};
                start = floor((sz-length(ir))/2);
                impulse_response(start+(1:length(ir)),i) = ir;
            end
        end
        
        function amplitude = frequency_response(self, freq)
            % FREQUENCY_RESPONSE Get the frequency response of the element
            %   amplitude = el.frequency_response(freq)
            %
            % Inputs:
            %   freq (Mx1 double): Frequency vector
            %
            % Returns:
            %   amplitude (MxN double): Frequency response of the element(s)
            arguments
                self
                freq (:,1) double
            end
            if numel(self) > 1
                amplitude = arrayfun(@(x)x.frequency_response(freq), self, 'UniformOutput', false);
            else
                if numel(self.impulse_response) == 1
                    amplitude = self.impulse_response;
                else
                    [ir, t] = self.interp_impulse_response();
                    amplitude = abs(sum(ir'.*exp(-1i*2*pi*freq.*t')));
                end
            end
        end
        

        
        function dist = distance_to_point(self, point, options)
            % DISTANCE_TO_POINT compute distance from element to point
            %   dist = el.distance_to_point(point, 'param', value, ...)
            %
            % Inputs:
            %   point (1x3 double): Target point
            %
            % Optional Parameters:
            %   'units' (string): Units of the output distance. Default is el.get_units
            %
            % Returns:
            %   dist (1xN double): Distance from element(s) to point
            arguments
                self (1,:) fus.xdc.Element % element
                point (1,3) double % target point [m]
                options.units (1,1) string {fus.util.mustBeDistance} = self.get_units; % output units
                options.matrix (4,4) double = eye(4) % global transformation matrix
            end
            if numel(self) > 1
                args = fus.util.struct2args(options);
                dist = arrayfun(@(x) x.distance_to_point(point, args{:}), self);
            else
                prev_units = self.get_units;
                self.rescale(options.units);
                pos = [self.x;self.y;self.z;ones(1,numel(self))];
                m = self.get_matrix();
                gm = options.matrix*m;
                gpos = options.matrix*pos;
                vec = point(:)-gpos(1:3,:);
                s = sign(dot(vec, gm(1:3,3)));
                dist = vecnorm(vec,2,1);
                self.rescale(prev_units);
            end
        end
        
        function theta = angle_to_point(self, point, options)
            % ANGLE_TO_POINT compute angle from element to point
            %   theta = el.angle_to_point(point, 'param', value, ...)
            %
            % Inputs:
            %   point (1x3 double): Target point
            %
            % Optional Parameters:
            %   'units' (string): Units of the output angle ("rad" or "deg"). Default is "rad"
            %
            % Returns:
            %   theta (1xN double): Angle from element(s) to point
            arguments
                self (1,:) fus.xdc.Element % element
                point (1,3) double % target point [m]
                options.units string {mustBeMember(options.units, ["rad", "deg"])} = "rad"; % output units
                options.matrix (4,4) double = eye(4) % global transformation matrix
            end
            if numel(self) > 1
                args = fus.util.struct2args(options);
                theta = arrayfun(@(x) x.angle_to_point(point, args{:}), self);
            else
                m = self.get_matrix();
                gm = options.matrix*m;
                v1 = (point(:)-gm(1:3,4));
                v2 = gm(1:3,3);
                v1 = v1/norm(v1,2);
                v2 = v2/norm(v2,2);
                vcross = cross(v1,v2);
                theta = asin(norm(vcross,2));
                scl = fus.util.getunitconversion("rad", options.units);
                theta = theta*scl;
            end
        end

        function varargout = set_matrix(self, matrix, options)
            % SET_MATRIX Set the transformation matrix of the element
            %   el.set_matrix(matrix, 'param',value, ...)
            %
            % Inputs:
            %   matrix (4x4 double) - Transformation matrix to apply to the position. 
            %
            % Optional Parameters:
            %   'units' (string) - Units of the input matrix. Default is el.units
            %
            % Returns:
            %   el (1x1 fus.xdc.Element) - Element with updated matrix. If no output is specified, the element is updated in place.
            arguments
                self (1,1) fus.xdc.Element
                matrix (4,4) double {mustBeFinite}
                options.units (1,1) string {fus.util.mustBeDistance} = self.get_units;
            end
            if nargout > 0
                self = self.copy()
                varargout{1} = self;
            end
            self.rescale(options.units)
            [x,y,z,az,el,roll] = fus.xdc.Element.matrix2xyz(matrix);
            self.x = x;
            self.y = y;
            self.z = z;
            self.az = az;
            self.el = el;
            self.roll = roll;
        end
    end    
    
    methods (Static)
        function self = from_struct(s)
            % FROM_STRUCT Create an array of elements from a struct
            %   self = fus.xdc.Element.from_struct(s)
            %
            % Inputs:
            %   s (1xN struct): Struct with element properties
            %
            % Returns:
            %   self (1xN fus.xdc.Element): Transducer of elements
            arguments
                s (1,:) struct
            end
            args = arrayfun(@fus.util.struct2args,s, 'UniformOutput', false);
            self = cellfun(@(x)fus.xdc.Element(x{:}),args);
        end
        
        function [x,y,z,az,el,roll] = matrix2xyz(matrix)
            x = matrix(1,4);
            y = matrix(2,4);
            z = matrix(3,4);
            az = atan2(matrix(1,3), matrix(3,3));
            el = -atan2(matrix(2,3), sqrt(matrix(3,3)^2 + matrix(1,3)^2));
            Raz = [cos(az), 0, sin(az); ...
                   0, 1, 0;...
                   -sin(az), 0, cos(az)];
            Rel = [1 0 0;
                   0, cos(el), -sin(el);
                   0, sin(el), cos(el)];
            Razel = Raz*Rel;
            xv = matrix(1:3,1);
            xyp = dot(xv, Razel(1:3,2));
            xxp = dot(xv, Razel(1:3,1));
            roll = atan2(xyp, xxp);
        end
    end
end