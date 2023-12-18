function segments = segment(volume, materials, options)
    % SEGMENT segment a volume into material indices
    %   segments = fus.seg.segment(volume, materials, "param", value, ...)
    %
    % Inputs:
    %   volume (fus.Volume): volume to segment
    %   materials (MaterialReference): material reference to use
    %
    % Optional Parameters:
    %   'method' (string): segmentation method, one of "water", "tissue", or "segmented"
    %       "water" - Assign all voxels as water (and standoff)
    %       "tissue" - Assign all voxels as tissue (and standoff)
    %       "segmented" - Use a segmentation algorithm to segment the volume (not implemented)
    %   'standoff_mask' (logical): mask of voxels to set as standoff
    %
    % Returns:
    %   segments (fus.Volume): segmented volume, with material indices as voxel values
    arguments
        volume fus.Volume
        materials (1,:) fus.seg.MaterialReference = fus.seg.MaterialReference.load_default("all")
        options.method (1,1) string {mustBeMember(options.method, ["water", "tissue", "segmented"])} = "water"
        options.standoff_mask logical = []
    end
    segments = volume.copy();
    sz = volume.shape();
    if isequal(size(options.standoff_mask), sz)
        standoff_mask = options.standoff_mask;
    elseif isempty(options.standoff_mask)
        standoff_mask = false(sz);
    else
        error('standoff mask must be same size as volume')
    end
    seg_index = materials.get_index_map();
    switch options.method
        case "water"
            seg_data = seg_index.water * ones(sz);
            ref_index = seg_index.water;
            seg_data(standoff_mask) = seg_index.standoff;
        case "tissue"
            seg_data = seg_index.tissue * ones(sz);
            ref_index = seg_index.tissue;
            seg_data(standoff_mask) = seg_index.standoff;
        case "segmented"
            error("Not Implemented")
        otherwise
            error("Unknown method %s", options.method);
    end
    segments.data = seg_data;
    segments.attrs.ref_material = materials(ref_index);
    segments.attrs.seg_method = options.method;
end