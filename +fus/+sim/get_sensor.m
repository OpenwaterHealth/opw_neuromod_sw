function sensor = get_sensor(kgrid, varargin)
    % GET_SENSOR get sensor mask for kWave
    %
    % INPUTS
    %   kgrid: [kWaveGrid]
    %   
    % OPTIONAL KEY, VALUE PAIRS
    %   record: cell array of records to use
    %
    % OUTPUTS:
    %   sensor: [kWaveSensor]
    options = struct(...
        'record', {{'p_max', 'p_min'}});
    options = fus.util.parseargs('skip', options, varargin{:});
    sensor.mask = ones(kgrid.Nx, kgrid.Ny, kgrid.Nz);
    sensor.record = {options.record{:}};
end