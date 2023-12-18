function params = map_params(segmentation, materials)
    % MAP_PARAMS Map material parameters to segmentation indices
    %   params = fus.seg.map_params(segmentation, materials)
    %
    % Inputs:
    %   segmentation (fus.Volume): Segmentation volume with material indices
    %   materials (1xN MaterialReference): Material reference objects
    %
    % Returns:
    %   params (1xN fus.Volume): Material parameter volumes
    arguments
        segmentation fus.Volume
        materials (1,:) fus.seg.MaterialReference = fus.seg.MaterialReference.load_default("all")
    end
    param_ids = materials.get_param_ids();
    for i = 1:length(param_ids)
        p = param_ids{i};
        param_info = materials.get_param_info(p);
        lut = [materials.(p)];
        params(i) = fus.Volume(...
            lut(segmentation.data), ...
            segmentation.coords, ...
            "matrix", segmentation.matrix, ...
            "id", p, ...
            "name", param_info.name, ...
            "units", param_info.units, ...
            "attrs", segmentation.attrs);
    end
end
