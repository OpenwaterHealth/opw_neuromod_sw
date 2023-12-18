classdef BeamformingPlan < fus.DataClass
    %BEAMFORMINGPLAN Specification of Beamforming Options
    %  bf_plan = fus.bf.BeamformingPlan("param", value, ...)
    properties
        id (1,1) string {mustBeValidVariableName} = "bfplan" % plan ID
        name (1,1) string = "" % plan name
        delay_method (1,1) fus.bf.DelayMethod = fus.bf.Direct() % Delay computation method
        apod_method (1,1) fus.bf.ApodMethod = fus.bf.apodmethods.Uniform() % Apodization method
        seg_method (1,1) string {mustBeMember(seg_method, ["water", "tissue", "segmented"])} = "water" % Segmentation method
        materials (1,:) fus.seg.MaterialReference = fus.seg.MaterialReference.load_default("all") % Material references
    end
    
    methods
        function self = BeamformingPlan(options)
            % BEAMFORMINGPLAN Plan Constructor
            %   bf_plan = fus.bf.BeamformingPlan("param", value, ...)
            % 
            % Optional Parameters:
            %   'id' (string) - plan ID
            %   'name' (string) - plan name
            %   'delay_method' (fus.bf.DelayMethod) - Delay computation method
            %   'apod_method' (fus.bf.ApodMethod) - Apodization method  
            %   'seg_method' (string) - Segmentation method
            %   'materials' (fus.seg.MaterialReference) - Material references
            arguments
                options.?fus.bf.BeamformingPlan
            end
            self.parse_props(options)
        end
        
        function params = segment(self, volume, options)
            % SEGMENT Segment Volume
            %   params = bf_plan.segment(volume, "param", value, ...)
            %
            % SEGMENT invokes the segmentation method to compute an array
            %   of Volumes, each containing a voxel-wise map of a material
            %   property. The number of Volumes in the array is equal to
            %   the number of materials in the plan.
            %
            % Inputs:
            %   volume (fus.Volume) - Volume to segment
            %
            % Optional Parameters:
            %   'standoff_mask' (logical) - voxel-wise mask of standoff region
            arguments
                self fus.bf.BeamformingPlan
                volume fus.Volume
                options.standoff_mask logical
            end
            args = fus.util.struct2args(options);
            segs = fus.seg.segment(volume, ...
                self.materials, ...
                "method", self.seg_method, ...
                args{:});
            params = fus.seg.map_params(segs, self.materials);
        end
        
        function params = get_ref_volumes(self, coords, material_id)
            % GET_REF_VOLUMES Get Reference Volumes
            %   params = bf_plan.get_ref_volumes(coords, material_id)
            %
            % GET_REF_VOLUMES generates reference volumes of material 
            %   properties for each material in the plan. The number 
            %   of Volumes in the array is equal to the number of 
            %   materials in the plan.
            %
            % Inputs:
            %   coords (1,3) fus.Axis - fus.Axis of reference volumes
            %   material_id (1,1) string - Material ID
            %
            % Returns:
            %   params (1,:) fus.Volume - Material property maps
            arguments
                self fus.bf.BeamformingPlan
                coords (1,3) fus.Axis
                material_id (1,1) string = "water"
            end
            seg_index = self.materials.get_index_map();
            if ~isfield(seg_index, material_id)
                error("No material '%s' found in index", material_id);
            end
            ref_index = seg_index.(material_id);
            ref_seg = fus.Volume(...
                ref_index*ones(coords.length), ...
                coords, ...
                "attrs", struct("ref_material", self.materials(ref_index)));
            params = fus.seg.map_params(ref_seg, self.materials);
        end
              
        function [delays, apod] = beamform(self, trans, focus, params)
            % BEAMFORM Compute Delays and Apodizations
            %  [delays, apod] = bf_plan.beamform(trans, focus, params)
            %
            % Inputs:
            %   trans (fus.xdc.Transducer) - Transducer to beamform with
            %   focus (fus.Point) - Point to focus on
            %   params (1,:) fus.Volume - Material property maps
            %
            % Returns:
            %   delays (1,:) double - Delay values
            %   apod (1,:) double - Apodization values
            arguments
                self fus.bf.BeamformingPlan
                trans fus.xdc.Transducer
                focus fus.Point
                params (1,:) fus.Volume
            end
            delays = self.delay_method.calc_delays(trans, focus, params);
            apod = self.apod_method.calc_apod(trans, focus.position, params);            
        end
        
        function tab = get_table(self)
            % GET_TABLE Get Table Representation
            %   tab = bf_plan.get_table()
            %
            % Returns:
            %   tab (table) - Table representation of plan
            tab = struct2table([...
                table2struct(self.delay_method.get_table)',...
                table2struct(self.apod_method.get_table)',...
                struct(...
                    "Name", "Segmentation", ...
                    "Value", fus.util.sanitize(self.seg_method, "title"), ...
                    "Units", "")]);
        end
    end
    
    methods (Static)
        function self = from_struct(s)
            % FROM_STRUCT Construct BeamformingPlan from Struct
            %   bf_plan = fus.bf.BeamformingPlan.from_struct(s)
            %
            % Inputs:
            %   s (struct) - Struct of property-value pairs
            %
            % Returns:
            %   bf_plan (fus.bf.BeamformingPlan) - BeamformingPlan object
            arguments
                s struct
            end
            if numel(s)>1
                self = arrayfun(@fus.bf.BeamformingPlan.from_struct, s);
                return
            end
            if isfield(s, 'materials')
                s.materials = fus.seg.MaterialReference.from_struct(s.materials);
            end
            s.delay_method = fus.bf.DelayMethod.from_struct(s.delay_method);
            s.apod_method = fus.bf.ApodMethod.from_struct(s.apod_method);
            args = fus.util.struct2args(s);
            self = fus.bf.BeamformingPlan(args{:});
        end
    end
end