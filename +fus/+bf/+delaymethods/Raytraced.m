classdef Raytraced < fus.bf.DelayMethod
    %RAYTRACEDELAYS Delay method using raytracing
    %  delay_method = fus.bf.delaymethods.Raytraced("param", value, ...)
    properties
        interp_method (1,1) string {mustBeMember(interp_method, ["linear", "nearest", "spline", "cubic", "makim"])} = "nearest" % Interpolation method
        interp_spacing (1,1) double {mustBePositive} = 1e-5 % Spacing (m)
    end
    methods 
        function self = Raytraced(options)
            %RAYTRACEDELAYS Delay Method Constructor
            %  delay_method = fus.bf.delaymethods.Raytraced("param", value, ...)
            % 
            % Optional Parameters:
            %  'interp_method' (string). Interpolation method. Default: 'nearest'. 
            %      Options: 'linear', 'nearest', 'spline', 'cubic', 'makim'
            %  'interp_spacing' (double). Spacing (m). Default: 1e-5
            %
            % Returns:
            %  delay_method (fus.bf.delaymethods.Raytraced). Delay method object
            arguments
                options.?fus.bf.delaymethods.Raytraced
            end
            self.parse_props(options);
        end
       
        function delays = calc_delays(self, trans, focus, params)
            %CALC_DELAYS Calculate the delays for a given position
            %  delays = delay_method.calc_delays(trans, position, params)
            %
            % Inputs:
            %   trans (fus.xdc.Transducer). Transducer array
            %   position (3x1 double). Position of the target
            %   params (1xN fus.Volume). Material properties. Must include
            %       'sound_speed' volume
            %
            % Returns:
            %   delays (1xN double). Delays for each element
            arguments
                self fus.bf.delaymethods.Raytraced
                trans fus.xdc.Transducer
                focus (1,1) fus.Point
                params (1,:) fus.Volume
            end
            c = params.by_id("sound_speed");
            nElement = trans.numelements;
            % calculate the distance from each element to the target
            distances = vecnorm(focus.get_position("units","m") - trans.elements.get_position("units", "m"), 2, 1);
            coords = {c.coords.values};
            % Generate a interpolant for upsampling the sos data
            F = griddedInterpolant(coords, c.values, self.interp_method);
            delays = zeros(1, nElement);
            focus_m = focus.get_position("units", "m");
            for i = 1:nElement
                src = trans.elements(i).get_position("units", "m");
                r = distances(i);
                nr = ceil(r/self.interp_spacing);
                w = linspace(0, 1, nr);
                % generate a vector of points between the source and the target
                xyz = (src * (1-w)) + (focus_m(:) * w);
                % interpolate the sos along the vector
                sos_select = F(xyz(1,:)', xyz(2,:)', xyz(3,:)');
                % calculate the delay
                t_sos = r/((sum(sos_select)/length(sos_select))-00);
                delays(i) = -t_sos;
            end
            delays = delays - min(delays);
        end
        
        function tab = get_table(self)
            %GET_TABLE Get a table representation of the object
            %  tab = delay_method.get_table()
            %
            % Returns:
            %   tab (table). Table representation
            tab = struct2table(...
                struct(...
                    "Name", "Delays", ...
                    "Value", "Raytraced", ...
                    "Units", ""));
        end
    end
end