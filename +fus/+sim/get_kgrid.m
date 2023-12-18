function kgrid = get_kgrid(params, varargin)
    % GET_KGRID get the k wave grid for a Scene
    % 
    % USAGE:
    %   kgrid = get_kgrid(params)
    % 
    % GET_KGRID constructs a kWaveGrid from a cell of coordinates.
    %
    % INPUTS
    %   params: parameter map structure
    %
    % OPTIONAL KEY, VALUE PAIRS
    %   sound_speed_ref: reference sound speed for dt calculation (default
    %       1500)
    %
    % OUTPUTS
    %   kgrid: kWaveGrid
    %
    % See also: kWaveGrid
        
    % Version History
    % Created 2022-06-09
    options = struct(...
        'sound_speed_ref', 1500, ...
        't_end', [], ...
        'dt', []);
    options = fus.util.parseargs('skip', options, varargin{:});
    coords = params.get_coords;
    array_size = [coords.length];
    dx = arrayfun(@(x)diff(x.values(1:2)), coords);
    kgrid = kWaveGrid(...
        array_size(1), dx(1), ...
        array_size(2), dx(2), ...
        array_size(3), dx(3));
    if ~any(options.dt) || ~any(options.t_end)
        kgrid.makeTime(options.sound_speed_ref);
    else
        Nt = round(options.t_end/options.dt);
        kgrid.setTime(Nt, options.dt)
    end
end