function ogrid = offset_grid(coords, focus, options)
    % OFFSET_GRID - calculate offset from focus
    %   ogrid = fus.bf.offset_grid(coords, focus, "param", val)
    %
    % Calculates the distance from the focus point for each point in the coordinate system.
    % Distances are returned from a coordinate system rotated in azimuth,
    % then elevation, so that the z'' axis points at the focus.
    %
    % Inputs:
    %   coords (1,3) fus.Axis - axis object
    %   focus (1,1) fus.Point - focus point
    %
    % Optional Parameters:
    %   'units' (string): distance units. Default: coords.get_units
    %
    % Returns
    %   ogrid (1,3) cell {dx'', dy'', dz''}
    arguments 
        coords (1,3) fus.Axis
        focus (1,1) fus.Point
        options.units (1,1) string {fus.util.mustBeDistance} = coords.get_units
    end
    coords = coords.rescale(options.units);
    m = fus.bf.get_focus_matrix(focus, "units", options.units);
    xyz = coords.ndgrid('vectorize', true);
    XYZ = [xyz{:}, ones(size(xyz{1}))].';
    XYZp = inv(m) * XYZ;
    XYZc = mat2cell(XYZp(1:3,:), ones(1,3), size(XYZp,2))';
    ogrid = cellfun(@(x)reshape(x,[coords.length]), XYZc, "UniformOutput", false);
end