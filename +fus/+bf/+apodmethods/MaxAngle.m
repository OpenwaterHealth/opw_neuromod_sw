classdef MaxAngle < fus.bf.ApodMethod
    %MAXANGLE Binary apodization based on angle
    %  apod_method = fus.bf.apodmethods.MaxAngle("param", value, ...)  
    properties
        max_angle (1,1) double {mustBePositive} = 90 % max acceptance angle
        units (1,1) string {mustBeMember(units, ["rad", "deg"])} = "deg" % units of max_angle
    end
    methods 
        function self = MaxAngle(options)
            % MAXANGLE Apodization Method Constructor
            %   apod_method = fus.bf.apodmethods.MaxAngle("param", value, ...)
            %
            % Optional Parameters:
            %   'max_angle' (double): maximum acceptance angle
            %   'units' (string): units of max_angle, either "rad" or "deg"
            %
            % Returns:
            %   apod_method (fus.bf.apodmethods.MaxAngle): apodization method
            arguments
                options.?fus.bf.apodmethods.MaxAngle
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
                self fus.bf.apodmethods.MaxAngle
                trans fus.xdc.Transducer
                position (3,1) double
                params (1,:) fus.Volume = fus.Volume.empty
            end
            angles = trans.elements.angle_to_point(position, "units", self.units);
            apod = double(angles<self.max_angle);
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
                    "Value", "Max Angle", ...
                    "Units", ""),...
                struct(...
                    "Name", "Max Angle", ...
                    "Value", sprintf('%g', rad2deg(self.max_angle)), ...
                    "Units", self.units)]);
        end
    end
end