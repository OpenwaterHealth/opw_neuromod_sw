function M = get_focus_matrix(focus, options)
    %GET_FOCUS_MATRIX Get the transformation matrix for a focus point
    %   M = GET_FOCUS_MATRIX(FOCUS) returns the transformation matrix for
    %   the focus point FOCUS. The transformation matrix is a 4x4 matrix
    %   that transforms points in the coordinate system of the focus point
    %   to the global coordinate system.
    %
    % Inputs:
    %   focus (1,1) fus.Point
    %   options.units (1,1) string {fus.util.mustBeDistance} = focus.units
    %
    % Returns:
    %   M (4,4) double transformation matrix
    arguments
        focus (1,1) fus.Point
        options.units (1,1) string {fus.util.mustBeDistance} = focus.units
        options.center_on (1,1) string {mustBeMember(options.center_on, ["focus", "origin"])} = "focus"
    end
    focus = focus.rescale(options.units);
    zvec = focus.position(:);
    zvec = zvec/norm(zvec);
    az = -atan2(zvec(1),zvec(3));
    xvec = [cos(az);0;sin(az)];
    yvec = cross(zvec,xvec);
    uv = {xvec,yvec,zvec};
    switch options.center_on
        case "focus"
            origin = focus.position(:);
        case "origin"
            origin = zeros(3,1);
    end
    M = [[uv{:}],origin;[0 0 0 1]];
end