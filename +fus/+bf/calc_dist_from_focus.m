function dist_from_focus = calc_dist_from_focus(coords, focus, options)
    % CALC_DIST_FROM_FOCUS - calculate nonlinear distance from focus
    %   dist_from_focus = fus.bf.calc_dist_from_focus(coords, focus, options)
    %
    % Calculates the distance from the focus point for each point in the coordinate system.
    % When an aspect ratio is provided (default [1, 1, 1]), the linear distances are divided by the aspect ratio.
    % The distance is calculated by first transforming the coordinate system so that the focus point is on
    % the z' axis, adjusting the x and y axes to be orthogonal to the z' axis, and then calculating the distance
    % e.g. d = sqrt(((x'-x0')/ax)^2 + ((y'-y0')/ay)^2 + ((z'-z0')/az)^2). This is useful for calculating how far 
    % away from an oblong focal spot each point is.
    %
    % Inputs:
    %   coords (1,3) fus.Axis - axis object
    %   focus (1,1) fus.Point - focus point
    %
    % Optional Parameters:
    %   'units' (string): distance units. Default: coords.get_units
    %   'aspect_ratio' (1,3) double: aspect ratio for calculating distance. Default: [1 1 1]
    arguments 
        coords (1,3) fus.Axis
        focus (1,1) fus.Point
        options.units (1,1) string {fus.util.mustBeDistance} = coords.get_units
        options.aspect_ratio (1,3) double {mustBeInteger, mustBePositive} = [1 1 1]
    end
    ogrid = fus.bf.offset_grid(coords, focus, "units", options.units);
    dist_from_focus = sqrt(sum((cell2mat(reshape(ogrid,1,1,1,3)).*(1./reshape(options.aspect_ratio,1,1,1,3))).^2,4));
end