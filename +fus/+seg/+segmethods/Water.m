classdef Water < fus.seg.SegMethod
    methods
        function segments = segment(self, volume, materials, options)
            arguments
                self fus.seg.segmethods.Water
                volume (1,1) fus.Volume
                materials (1,:) fus.seg.MaterialReference
                options.standoff_mask logical
            end
            args = fus.util.struct2args(options);
            segments = fus.seg.segment(volume,...
                materials, ...
                "method", "water", ...
                args{:});
        end
    end
end