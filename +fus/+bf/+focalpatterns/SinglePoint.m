classdef SinglePoint < fus.bf.FocalPattern
    %SINGLEFOCUS A single focus
    %  focal_pattern = fus.bf.focalpatterns.SinglePoint()
    methods
        function self = SinglePoint(options)
            % SINGLEFOCUS Single Focus Pattern Constructor
            %   focal_pattern = fus.bf.focalpatterns.SinglePoint()
            %
            % SINGLEFOCUS is the default focal fus.bf. It is a
            %   pass-through pattern that sets a single focus at the nominal
            %   target location.
            %
            % Returns:
            %   focal_pattern (fus.bf.focalpatterns.SinglePoint): Single focus pattern
            arguments
                options.?fus.bf.focalpatterns.SinglePoint
            end
            self.parse_props(options)
        end
        
        function targets = get_targets(self, target)
            % GET_TARGETS Get targets for a single focus
            %   targets = focal_pattern.get_targets(target)
            %
            % Inputs:
            %   target fus.Point: Target point
            %
            % Returns:
            %   targets (1x1) fus.Point: Target point
            arguments
                self fus.bf.focalpatterns.SinglePoint
                target (1,1) fus.Point
            end
            targets = target.copy();
        end
        
        function n = num_foci(self)
            % NUM_FOCI Number of foci
            %   n = focal_pattern.num_foci()
            %
            % Returns:
            %   n (1x1) double: Number of foci (1)
            arguments
                self fus.bf.focalpatterns.SinglePoint
            end
            n = 1;
        end
        
        function tab = get_table(self)
            % GET_TABLE Get table of properties
            %   tab = focal_pattern.get_table()
            %
            % Returns:
            %   tab (table): Table of properties
            tab = struct2table([...
                struct(...
                    "Name", "Type",...
                    "Value", "Single", ...
                    "Units", ""), ...
                table2struct(get_table@fus.bf.FocalPattern(self))']);
        end
    end
end