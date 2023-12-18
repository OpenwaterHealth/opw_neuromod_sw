classdef SegMethod < fus.DataClass
    % Abstract class for segmentation methods
    methods (Abstract)
        segments = segment(self, volume, materials, varargin)
    end

    methods
        function params = segment_params(self, volume, materials, varargin)
            arguments
                self fus.seg.SegMethod
                volume (1,:) fus.Volume
                materials (1,:) fus.seg.MaterialReference    
            end
            arguments (Repeating)
                varargin
            end
            segs = self.segment(volume, ...
                materials, ...
                varargin{:});
            params = fus.seg.map_params(segs, materials);
        end

        function s = to_struct(self)
            arguments
                self fus.seg.SegMethod
            end
            s = to_struct@fus.DataClass(self);
            cdef = split(class(self),'.');
            s.class = string(cdef{end});
        end

        function tab = get_table(self)
            s = self.to_struct();
            tab = struct2table(struct(...
                    "Name", "Segmentation", ...
                    "Value", s.class, ...
                    "Units", ""));
        end
    end

    methods (Static)
        function self = from_struct(s)
            arguments
                s struct
            end
            constructor = str2func(sprintf("fus.seg.segmethods.%s", s.class));
            args = fus.util.struct2args(rmfield(s, "class"));
            self = constructor(args{:});
        end
    end
end