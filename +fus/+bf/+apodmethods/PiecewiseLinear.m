classdef PiecewiseLinear < fus.bf.ApodMethod
    %PIECEWISELINEAR Piecewise-Linear apodization based on angle
    %  apod_method = fus.bf.apodmethods.PiecewiseLinear("param", value, ...)  
    properties
        zero_angle (1,1) double {mustBeNonnegative} = 90 % angle above which apodization is 0
        rolloff_angle (1,1) double {mustBeNonnegative} = 45 % angle below which apodization is 1
        units (1,1) string {mustBeMember(units, ["rad", "deg"])} = "deg" % units of max_angle
    end
    methods 
        function self = PiecewiseLinear(options)
            % PIECEWISELINEAR Apodization Method Constructor
            %   apod_method = fus.bf.apodmethods.PiecewiseLinear("param", value, ...)
            %
            % Optional Parameters:
            %   'zero_angle' (double): angle above which apodization is 0
            %   'rolloff_angle' (double): angle below which apodization is 1
            %   'units' (string): units of max_angle, either "rad" or "deg"
            %
            % Returns:
            %   apod_method (fus.bf.apodmethods.PiecewiseLinear): apodization method
            arguments
                options.?fus.bf.apodmethods.PiecewiseLinear
            end
            self.parse_props(options);
        end
       
        function apod = calc_apod(self, trans, position, params)
            % CALC_APOD Calculate apodization
            %   apod = apod_method.calc_apod(trans, position, params)
            %
            % Inputs: 
            %   trans (fus.xdc.Transducer): transducer array
            %   position (3,1) double: position of point to apodize
            %   params (1,:) fus.Volume: volume of points to apodize (unused)
            %
            % Returns:
            %   apod (1,:) double: apodization vector
            arguments
                self fus.bf.apodmethods.PiecewiseLinear
                trans fus.xdc.Transducer
                position (3,1) double
                params (1,:) fus.Volume = fus.Volume.empty
            end
            angles = trans.elements.angle_to_point(position, "units", self.units);
            f = ((self.zero_angle - angles) / (self.zero_angle - self.rolloff_angle));
            apod = max(0, min(1, f));
        end
        
        function tab = get_table(self)
            % GET_TABLE Get table representation
            %   tab = apod_method.get_table()
            %
            % Returns:
            %   tab (table): table representation
            tab = struct2table([...
                struct(...
                    "Name", "Apodization", ...
                    "Value", "Piecewise-Linear", ...
                    "Units", ""),...
                struct(...
                    "Name", "100% Angle", ...
                    "Value", sprintf('%g', rad2deg(self.rolloff_angle)), ...
                    "Units", self.units),...    
                struct(...
                    "Name", "Zero Angle", ...
                    "Value", sprintf('%g', rad2deg(self.zero_angle)), ...
                    "Units", self.units)]);
        end
    end
end