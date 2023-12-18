function varargout = run_acoustic_sim(trans, params, delays, apod, options)
    % RUN_ACOUSTIC_SIM Run K-Wave simulation
    %
    % USAGE
    %   outputs = run_acoustic_sim(trans, params, delays, apod, varargin)
    %   [outputs, inputs] = run_acoustic_sim(trans, params, delays, apod, varargin)
    %
    % RUN_ACOUSTIC_SIM takes the transducer, parameter maps, delays, and
    % apodization, and runs an acoustic simulation to extract, by default,
    % peak positive and peak negative pressure. A variety of configuration
    % options are available
    %
    % INPUTS
    %   trans: [struct or char] transducer or transducer ID
    %   params: [struct] parameter maps
    %   delays: [1xN] array of delays
    %   apod: [1xN] array of apodizations
    %   
    % OPTIONAL KEY-VALUE PAIRS
    %   BLITolerance: [float] Scalar value controlling where the spatial 	
    %       extent of the BLI at each point is trunctated as a portion of 	
    %       the maximum value Default 0.05	
    %   UpsamplingRate: [int] Oversampling used to distribute the off-grid 	
    %       points compared to the equivalent number of on-grid points 	
    %       Default 5.   	
    %   SinglePrecision: [bool] Use single precision in calculating source.
    %       Default true (only available on k-Wave 1.4+)
    %   source_strength: [float] strength of source (Pa). Default 1e6	
    %   tone_burst_freq: [float] frequency for computing attenuation.	
    %       Default 4e5	
    %   tone_burst_cycles: [float] length of tone burst. Default 6	
    %   alpha_power: [float] power coefficient for attenuation 	
    %       db/cm/MHz^alpha. Default 0.9	
    %   t_end: [float] length of simulation (s). Default 1e-4.	
    %   sound_speed_ref: [float] nominal speed of sound (m/s) for makeTime.	
    %       Default 1500	
    %   record: [1xN] cell array of records to report. Default {'p_max',
    %       'p_min'}. See k-wave documentation for details.
    %   data_cast: [char] precision to cast data to. Default 'single'
    %   log: [fus.util.Logger or struct] logger config
    %   gpu: [bool] try to use GPU
    %
    % OUTPUTS
    %   outputs: [struct] simulation output
    %   inputs: [struct] structure of generated K-Wave objects
    %
    arguments
        trans (1,1) fus.xdc.Transducer
        params (1,:) fus.Volume
        delays (1,:) double
        apod (1,:) double
        options.BLITolerance (1,1) double {mustBePositive} = 0.05
        options.UpsamplingRate (1,1) double {mustBePositive, mustBeInteger}= 4
        options.SinglePrecision (1,1) logical = true
        options.source_strength (1,1) double = 1e6
        options.tone_burst_freq (1,1) double = 1e6
        options.tone_burst_cycles (1,1) double = 20
        options.PMLSize = 'auto'
        options.alpha_power (1,1) double = 0.9
        options.t_end (1,1) double = 0
        options.dt (1,1) double = 0
        options.sound_speed_ref (1,1) double = 1500
        options.record (1,:) string = ["p_max", "p_min"]
        options.data_cast (1,1) string = "single"
        options.log fus.util.Logger = fus.util.Logger.get()
        options.gpu (1,1) logical = true
    end    
    log = options.log;
    kwave_path = fus.sim.get_path();
    if isempty(kwave_path)
        log.throw_error("Cannot find K-Wave")
    else
        addpath(kwave_path);
    end
    log.info('Setting up simulation...')
    in_units = params.get_units();
    params = params.rescale("m");
    trans = trans.rescale("m");
    kgrid = fus.sim.get_kgrid(params, options);
    medium = fus.sim.get_acoustic_medium(params, options);
    sensor = fus.sim.get_sensor(kgrid, options);
    log.info('Generating source...')
    source_gen_start = tic;
    [source, karray] = fus.sim.get_pressure_source(...
        kgrid, ...
        trans, ...
        params, ...
        delays, ...
        apod, ...
        options);
    source_gen_time = toc(source_gen_start);
    PMLSize = options.PMLSize;
    
    input_args = {...
        'DisplayMask', 'off', ...
        'PlotSim', false, ...
        'PMLInside', false, ...
        'PMLSize',PMLSize, ...
        'DataCast', 'single', ...
        'DataRecast', true};
        log.info('Launching simulation...')
     % C++/CUDA GPU
    if isempty(options.gpu)
        try
            gpuArray(0);
            options.gpu = 1;
            log.info('Using GPU')
        catch ME
            switch ME.identifier
                case 'parallel:gpu:device:CouldNotLoadDriver'
                    log.warning('Unable to load CUDA driver. Using CPU version')
                    options.gpu = 0;
                case 'MATLAB:UndefinedFunction'
                    log.warning('Could not instantiate test gpuArray. Check Parallel Computing Toolbox installation. Using CPU Version.')
                    options.gpu = 0;
                otherwise
                    rethrow(ME)
            end
        end
    end             
    if options.gpu
        try
            t0 = tic;
            sensor_data = kspaceFirstOrder3DG(...
                kgrid, ...
                medium, ...
                source, ...
                sensor, ...
                input_args{:});
            sim_time = toc(t0);

        catch me
            switch me.identifier
                case 'MATLAB:imagesci:hdf5io:resourceNotFound'
                    log.warning('options.gpu was selected, but the simulation failed in a way that suggests no GPU is available. Retrying with CPU...')
                    t0 = tic;
                    sensor_data = kspaceFirstOrder3DC(...
                        kgrid, ...
                        medium, ...
                        source, ...
                        sensor, ...
                        input_args{:});
                    sim_time = toc(t0);
                otherwise
                    rethrow(me)
            end
        end
    else
        t0 = tic;
        sensor_data = kspaceFirstOrder3DC(...
            kgrid, ...
            medium, ...
            source, ...
            sensor, ...
            input_args{:});
        sim_time = toc(t0);
    end
    log.info('Simulation complete');
    %%
    sz = [kgrid.Nx, kgrid.Ny, kgrid.Nz];
    for i = 1:length(options.record)
        record = options.record{i};
        switch record
            case 'p_max'
                data = reshape(sensor_data.(record), sz);
                units = "Pa";
            case 'p_min'
                data = -1*reshape(sensor_data.(record), sz);
                units = "Pa";
            otherwise
                error('Unsupported record type %s', record);
        end
        outputs(i) = fus.Volume(...
            data, ...
            params.get_coords, ...
            "id", record, ...
            "units", units, ...
            "matrix", params.get_matrix);
    
    end
    outputs.rescale(in_units);
    run_time.source_gen_time = source_gen_time;
    run_time.sim_time = sim_time;
    if nargout > 0
        varargout{1} = outputs;
    end
    inputs = struct(...
        'kgrid', kgrid, ...
        'karray', karray, ...
        'medium', medium, ...
        'sensor', sensor, ...
        'source', source, ...
        'options', options, ...
        'run_time', run_time);
    if nargout > 1
        varargout{2} = inputs;
    end
end