function [source, karray] = get_pressure_source(kgrid, trans, params, delays, apod, varargin)
    % GET_PRESSURE_SOURCE Generate kWave source structure
    % source = get_pressure_source(kgrid, karray, delays, options)
    % Computes the source object for the kWave pressure simulation. The
    % karray is repositioned for computation of the binary mask, but
    % reset after computation is complete.
    %
    % INPUTS
    %   kgrid: kWaveGrid
    %   trans: Transducer
    %   params: param maps struct
    %   delays: [Nx1] array of time delays (s)
    %   apod: [Nx1] array of apodization or single value
    %
    % OPTIONAL KEY, VALUE PAIRS
    %       BLITolerance: Scalar value controlling where the spatial extent
    %                      of the BLI at each point is trunctated as a
    %                      portion of the maximum value (default = 0.05)
    %       UpsamplingRate: Oversampling used to distribute the off-grid
    %                      points compared to the equivalent number of
    %                      on-grid points (default = 20).
    %       source_strength: strength of source (Pa)
    %       tone_burst_freq: center frequenecy (Hz)
    %       tone_burst_cycles: length of tone burst
    %       t_end: length of simulation (s)
    %
    % OUTPUTS
    %   source: source struct
    %   karray: kWaveArray
    %
    % Version History
    % Created 2022-06-09
    % Modified to use Transducer 2023-05-24
    import fus.sim.*
    options = struct('BLITolerance', 0.05, ...
                     'UpsamplingRate', 5, ...
                     'SinglePrecision', true, ...
                     'source_strength', 1e6, ...
                     'tone_burst_freq', 400.6e3, ...
                     'tone_burst_cycles', 6);
    options = fus.util.parseargs('skip', options, varargin{:}); 
    coords = params.get_coords();
    translation = -cellfun(@mean,coords.extent);
    rotation = zeros(1,3);
    karray = get_karray(...
        trans,...
        'BLITolerance', options.BLITolerance, ...
        'UpsamplingRate', options.UpsamplingRate, ...
        'translation', translation, ...
        'rotation', rotation);
    
%      kgrid.makeTime(options.sound_speed, [], options.t_end);

    if length(apod) == 1
        apod = repmat(apod, karray.number_elements, 1);
    end

    input_signal = options.source_strength*toneBurst(1/kgrid.dt, ...
        options.tone_burst_freq, ...
        options.tone_burst_cycles,...
        'Envelope','Rectangular', ...
        'SignalOffset', round(delays(:)/kgrid.dt));

    input_signal = input_signal .* apod(:);
    for i = 1:trans.numelements
        output_signal(i,:) = trans.elements(i).calc_output(input_signal(i,:), kgrid.dt);
    end

    % shift karray to [0,0,0] (offset in kgrid coords)
    affine_transform = karray.array_transformation;
    
    % assign binary mask
    source.p_mask = karray.getArrayBinaryMask(kgrid);
    source.p = karray.getDistributedSourceSignal(kgrid, output_signal);
    
    % reset array position
    karray.setAffineTransform(affine_transform);
end