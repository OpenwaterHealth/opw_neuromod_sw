classdef Direct < fus.bf.DelayMethod
    %DIRECTDELAYS Basic speed-of-sound-based delay computation method
    % delay_method = fus.bf.Direct()
    properties
        c0 (1,1) double = 1540 % Speed of sound (m/s)
    end

    methods 
        function self = Direct(options)
            % DIRECT Construct an instance of this class
            %   delay_method = fus.bf.Direct()
            %
            % Optional Parameters:
            %   c0 (1,1) double - Speed of sound (m/s). Default: 1540
            %
            % Returns:
            %   delay_method (1,1) fus.bf.delaymethods.Direct - Delay
            %       method object
            arguments
                options.?fus.bf.delaymethods.Direct
            end
            self.parse_props(options);
        end

        function delays = calc_delays(self, trans, focus, params)
            % CALC_DELAYS Calculate delays for a given focus
            %   delays = delay_method.calc_delays(trans, focus, params)
            %
            % Inputs:
            %   trans (fus.xdc.Transducer) - Transducer array
            %   focus (1,1) fus.Point - Focus point
            %   params (1,:) fus.Volume - Material Properties. Must contain
            %       sound_speed, which must have a ref_material attribute
            %
            % Returns:
            %   delays (1xN) double - Time delays for each element (s)
            arguments
                self fus.bf.delaymethods.Direct
                trans fus.xdc.Transducer
                focus (1,1) fus.Point
                params (1,:) fus.Volume = fus.Volume.empty
            end
            if isempty(params)
                c = self.c0;
            else
                sound_speed = params.by_id("sound_speed");
                c = sound_speed.attrs.ref_material.sound_speed;
            end
            tof = vecnorm(focus.get_position("units", "m") - trans.elements.get_position("units","m"), 2, 1)/c;
            delays = max(tof)-tof;
        end
        
        function tab = get_table(self)
            % GET_TABLE Get a table representation of the object
            %   tab = delay_method.get_table()
            %
            % Returns:
            %   tab (table) - Table representation of the object
            tab = struct2table(...
                [struct(...
                    "Name", "Delays", ...
                    "Value", "Direct", ...
                    "Units", ""),...
                struct(...
                    "Name", "Speed of Sound", ...
                    "Value", self.c0, ...
                    "Units", "m/s")]);
        end
    end
end