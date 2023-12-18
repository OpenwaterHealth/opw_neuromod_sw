function mask = mask_focus(coords, focus, distance, options)
    % MASK_FOCUS - mask points within a distance from the focus
    %   mask = fus.bf.mask_focus(coords, focus, distance, options)
    %
    % Creates a mask for points within a (scaled) distance from the focus point. Additionally,
    % points with a z value less than zmin are masked out, when provided.
    %
    % Inputs:
    %   coords (1,3) fus.Axis - axis object
    %   focus (1,:) fus.Point - focus point
    %   distance (1,1) double - distance from focus
    %
    % Optional Parameters:
    %   'units' (string): distance units. Default: coords.get_units
    %   'operation' (string): operation to perform. Default: "<="
    %   'aspect_ratio' (1,3) double: aspect ratio for calculating distance. Default: [1 1 10]
    %   'zmin' (1,1) double: minimum z value. Default: -inf
    arguments
        coords (1,3) fus.Axis
        focus (1,:) fus.Point
        distance (1,1) double {mustBePositive}
        options.units (1,1) string {fus.util.mustBeDistance} = coords.get_units
        options.operation (1,1) string {mustBeMember(options.operation, [">",">=","<","<="])} = "<="
        options.aspect_ratio (1,3) double {mustBeInteger, mustBePositive} = [1 1 10]
        options.zmin (1,1) double = -inf
    end
    coords = coords.rescale(options.units);
    focus = focus.rescale(options.units);
    args = fus.util.struct2args(rmfield(options, {'zmin','operation'}));
    switch options.operation
        case ">"
            op = @gt;
        case ">="
            op = @ge;
        case "<"
            op = @lt;
        case "<="
            op = @le;
    end
    m = arrayfun(@(f)op(fus.bf.calc_dist_from_focus(coords, f, args{:}),distance), focus, 'UniformOutput', false);
    m = cell2mat(reshape(m,1,1,1,[]));
    mask = any(m,4);
    if options.zmin > -inf
        xyz = coords.ndgrid("units", options.units);
        zmask = xyz{3} > options.zmin;
        mask = mask & zmask;
    end
end