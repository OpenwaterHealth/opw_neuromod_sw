classdef Wheel < fus.bf.FocalPattern
    % Wheel - A pattern of foci arranged in a radial pattern
    % focal_pattern = fus.bf.focalpatterns.Wheel("param", value, ...)
    properties
        center (1,1) logical = true % include the center focus
        num_spokes (1,1) double {mustBeInteger, mustBePositive} = 4 % number of spokes
        spoke_radius (1,1) double {mustBeNonnegative} = 1e-3 % spoke radius
        units (1,1) string {fus.util.mustBeDistance} = "m" % units of spoke radius
    end
    methods
        function self = Wheel(options)
            % RADIALPATTERN - Radial Pattern Constructor
            %  focal_pattern = fus.bf.focalpatterns.Wheel("param", value, ...)
            %
            % Optional Parameters:
            %   'center' (logical): include the center focus
            %   'num_spokes' (double): number of spokes
            %   'spoke_radius' (double): spoke radius
            %   'units' (string): units of spoke radius
            %
            % Returns:
            %   focal_pattern (fus.bf.focalpatterns.Wheel) - the radial pattern
            arguments
                options.?fus.bf.focalpatterns.Wheel
            end
            self.parse_props(options)
        end
        
        function targets = get_targets(self, target, options)
            % GET_TARGETS - Get the targets for a given focus
            %   targets = focal_pattern.get_targets(target, 'param', value, ...)
            %
            % Inputs:
            %   target fus.Point: the target focus
            %
            % Optional Parameters:
            %   'units' (string): units of the target. Defaults to target.units
            %
            % Returns:
            %   targets (1xN fus.Point): the target foci arranged around the target
            arguments
                self fus.bf.focalpatterns.Wheel
                target (1,1) fus.Point
                options.units (1,1) string {fus.util.mustBeDistance} = target.units
            end
            if self.center
                targets = target.copy();
            else
                targets = fus.Point.empty;
            end
            th = linspace(0, 2*pi, self.num_spokes+1);
            th = th(1:end-1);
            scl = fus.util.getunitconversion(self.units, options.units);
            r = self.spoke_radius * scl;
            dx = r*cos(th);
            dy = r*sin(th);
            for i = 1:length(th)
                focus = target.copy();
                focus.rescale(options.units);
                focus.id = sprintf("%s_%d", target.id, i);
                offset = [dx(i); dy(i); 0];
                focus.position = focus.position + offset;
                targets(i+self.center) = focus;
            end
        end
        
        function tab = get_table(self)
            % GET_TABLE - Get a table of the pattern properties
            %   tab = focal_pattern.get_table()
            %
            % Returns:
            %   tab (table): table of pattern properties
            tab = struct2table([...
                struct(...
                    "Name", "Type",...
                    "Value", "Radial", ...
                    "Units", ""), ...
                table2struct(get_table@fus.bf.FocalPattern(self))',...
                struct(...
                    "Name", "Spokes", ...
                    "Value", sprintf("%g", self.num_spokes), ...
                    "Units", ""), ...
                struct(...
                    "Name", "Center", ...
                    "Value", self.center, ...
                    "Units", ""), ...
                struct(...
                    "Name", "Radius", ...
                    "Value", sprintf("%0.2f", self.spoke_radius), ...
                    "Units", self.units)]);
        end
        
        function n = num_foci(self)
            % NUM_FOCI - Get the number of foci in the pattern
            %   n = focal_pattern.num_foci()
            %
            % Returns:
            %   n (double): number of foci
            arguments
                self fus.bf.focalpatterns.Wheel
            end
            n = self.num_spokes + double(self.center);
        end
    end
end