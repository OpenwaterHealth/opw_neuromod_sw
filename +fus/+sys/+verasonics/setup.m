function config = setup(solution, options)
    % SETUP Configure Verasonics system for a given solution
    %
    % config = fus.sys.verasonics.setup(solution, "param", value, ...)
    %
    % Inputs:
    %   solution (fus.treatment.Solution)
    %
    % Optional name-value pairs:
    %   simulate (logical) Run in simulation mode. Default = false
    %   fake_scanhead (logical) Run in fake scanhead mode. Default = false
    %   system_type (string) System type. Default = "HIFU"
    %   comport (string) COM port for HIFU power supply. Default = "auto"
    %   use_thermistor (logical) Enable thermistor monitoring. Default = true
    %   connector (double) Connector number. Default = 2
    %   channels (double) Number of channels. Default = 256
    %   log (fus.util.Logger) Logger object. Default is active logger
    %
    % NOTICE
    % This project is licensed under the terms of the Verasonics Permissive
    % License. Please refer to LICENSE for the full terms.
    % 
    % Verasonics Permissive License Copyright (c) 2013 – 2023 Verasonics,
    % Inc. 
    % 
    % Permission is hereby granted, free of charge, to any person
    % obtaining a copy of this software (the “Software”), to deal in the
    % Software without restriction, including without limitation the rights
    % to use, copy, modify, merge, publish, distribute, sublicense, and/or
    % sell copies of the Software, and to permit persons to whom the
    % Software is furnished to do so, subject to the following conditions:
    %
    % The above copyright notice and this permission notice shall be
    % included in all copies or substantial portions of the Software. For
    % the avoidance of doubt, Verasonics documentation that is associated
    % with the Software is not covered by this license. THE SOFTWARE IS
    % PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
    % INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    % FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT
    % SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
    % DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
    % OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
    % THE USE OR OTHER DEALINGS IN THE SOFTWARE.

    arguments
        solution fus.treatment.Solution
        options.simulate (1,1) logical = false;
        options.fake_scanhead (1,1) logical = false;
        options.system_type (1,1) string {mustBeMember(options.system_type, ["LF","HIFU"])} = "HIFU";
        options.comport (1,1) string = "auto";
        options.use_thermistor (1,1) logical = true;
        options.connector (1,:) double {mustBeMember(options.connector, [1,2])} = 2;
        options.channels (1,1) double {mustBeMember(options.channels, [128, 256])} = 256;
        options.log fus.util.Logger = fus.util.Logger.get;
    end

    import fus.sys.verasonics.get_hvsupply_comport
    import fus.sys.verasonics.compute_trans

    log = options.log;    
    log.info('Configuring Verasonics...')
    log.debug('Computing Transducer...')
    Trans = compute_trans(solution.transducer);
    nfoc = length(solution.focus);
    
    log.debug('Checking Pattern...')
    seq_params = solution.sequence.to_struct();
    seq_params.pattern_length = nfoc;
    if seq_params.pulse_train_interval == 0
        seq_params.pulse_train_interval = (seq_params.pulse_count * seq_params.pulse_interval);
    elseif seq_params.pulse_train_interval < (seq_params.pulse_count * seq_params.pulse_interval)
        log.throw_error("Pulse train interval must at least Pulse Count x Pulse Interval. Set to 0 to use no cooldown.")
    end
    seq_params.burst_cooldown = seq_params.pulse_train_interval - (seq_params.pulse_count * seq_params.pulse_interval);
    seq_params.description = solution.description;

    %% Specify system parameters
    log.debug('Configuring Resource Parameters...')
    Resource.Parameters.Connector = options.connector; % 2=right connector
    Resource.Parameters.numTransmit = options.channels;      % no. of transmit channels (1 brd).
    Resource.Parameters.numRcvChannels = options.channels;    % no. of receive channels (1 brd).
    Resource.Parameters.speedOfSound = 1480;    % speed of sound in m/sec
    Resource.Parameters.verbose = 2;
    Resource.Parameters.initializeOnly = 0;
    Resource.Parameters.simulateMode = options.simulate;       % runs script in simulate mode
    Resource.Parameters.fakeScanhead = options.fake_scanhead;  

    switch upper(options.system_type)
        case 'LF'
            Resource.System.Frequency = 'LF'; % for simulation 
        case 'HIFU'
            Resource.HIFU.externalHifuPwr = 1;
            Resource.HIFU.verbose = 1;
            Resource.HIFU.extPwrConnection = 'parallel';

           Resource.HIFU.extPwrComPortID = lower(options.comport);             
%            switch lower(options.comport)
%                case 'auto'
%                    try
%                         Resource.HIFU.extPwrComPortID = get_hvsupply_comport('log', log, 'simulate', options.simulate);
%                    catch me
%                        if ~options.simulate
%                             log.throw_error(me.message)
%                        end
%                    end
%                otherwise
%                    Resource.HIFU.extPwrComPortID = lower(options.comport);
%            end

        otherwise
            msg = log.error('unrecognized system type %s', options.system_type);
            error(msg);
    end

    %% Enable Temperature Measurement
    if options.use_thermistor
        % Set ProbeThermistor to all zeros (this duplicates what VSX would have
        % done by default, but it allows us to set individual values as desired in
        % the lines that follow)
        log.debug('Enabling Thermistor...')
        Resource.Parameters.ProbeThermistor = repmat(...
            struct(...
                'enable', 0, ...
                'threshold', 0, ...
                'reportOverThreshold', 0),...
            1, 2);
        % the following three lines will enable monitoring on thermistor 1, with an
        % automatic shutdown if the A/D reading is ever less than 40 (equivalent to
        % approximately 20 Ohms), so if you jumper pin cc4 to thermistor return at
        % cc8 the system will exit with an over-temperature error
        Resource.Parameters.ProbeThermistor(1).enable = 1;
        Resource.Parameters.ProbeThermistor(1).threshold = 40;
        Resource.Parameters.ProbeThermistor(1).reportOverThreshold = 0;
        Resource.Parameters.ProbeThermistor(2).enable = 1;
        Resource.Parameters.ProbeThermistor(2).threshold = 40;
        Resource.Parameters.ProbeThermistor(2).reportOverThreshold = 0;
        % 0 directs the system to shut down if the thermistor value goes under the
        % threshold value; to reverse this and shut down for values over the threshold,
        % use reportOverThreshold = 1
    end
    seq_params.use_thermistor = options.use_thermistor;

    %% Specify TW structure array.
    log.debug('Specifying Waveform...')
    TW.type = 'parametric';
    pulse_interval_half_cycles = round(solution.pulse.frequency*solution.pulse.duration*2); % 4000 half cycles for 5ms at 400kHz
    TW.Parameters = [solution.pulse.frequency*1e-6,0.5,pulse_interval_half_cycles,1]; % 1 half-cycles

    %% Set TPC structure
    log.debug('Specifying TPC...')
    if isfield(Trans, 'maxHighVoltage')
        TPC(5).maxHighVoltage = Trans.maxHighVoltage; % max output voltage
    end
    TPC(5).hv = solution.pulse.amplitude; % Set starting Voltage to 5V in profile 5

    log.info('Specifying Transmits...')
    clear TX
    for i = 1:nfoc
        %% Specify TX structure array (could be event specific)
        TX(i).waveform = 1;            % use 1st TW structure.
        TX(i).Origin = [0.0,0.0,0.0];  % flash transmit origin at (0,0,0).
        TX(i).focus = 0;
        TX(i).Steer = [0.0,0.0];       % theta, alpha = 0.
        TX(i).Apod = ones(1,Trans.numelements); % all the array elements on
        TX(i).Delay = zeros(1,Trans.numelements);
        % %% used to calculate and time delays (in wavelengths)
        TdelayD = solution.delays(i,:); %this Tdelay, is for all elements to fire at nominal focus
        Tdelay = TdelayD - min(TdelayD); % shift so all positive and start at zero
        WaveLdelay = Tdelay*Trans.frequency*1e6; % puts the time delay into number of wavelengths
        Delay = WaveLdelay; 
        TX(i).Delay = Delay; 
        TX(i).Apod = solution.apodizations(i,:);
    end
    %% Specify External Processing Functions
    n=1;
    EXT_LOG_XMIT = n;
    Process(n).classname = 'External';
    Process(n).method = 'fus.sys.verasonics.vsx_log_xmit';
    Process(n).Parameters = {...
        'srcbuffer','none',...
        'dstbuffer','none'};
    n = n+1;

    EXT_SEQ_CONTROL = n;
    Process(n).classname = 'External';
    Process(n).method = 'fus.sys.verasonics.vsx_sequencer';
    Process(n).Parameters = {...
        'srcbuffer','none',...
        'dstbuffer','none'};

    %% Specify SeqControl structure arrays.
    log.debug('Specifying SeqControl...')
    n = 1;
    ACQ_PERIOD = n;
    SeqControl(ACQ_PERIOD).command = 'timeToNextAcq';% time between synthetic aperture acquisitions
    SeqControl(ACQ_PERIOD).argument =  round(seq_params.pulse_interval / 1e-6);  % 1 = 1 usec
    n = n+1;
    EXTENDED_BURST_PERIOD = n;
    SeqControl(EXTENDED_BURST_PERIOD).command = 'timeToNextEB';  % time between frames
    SeqControl(EXTENDED_BURST_PERIOD).argument = round(seq_params.pulse_interval / 1e-6);  % 20 ms % Sets the PRF 20:50Hz
    n = n+1;
    SET_TPC5 = n;
    SeqControl(SET_TPC5).command = 'setTPCProfile';
    SeqControl(SET_TPC5).condition = 'immediate';
    SeqControl(SET_TPC5).argument = 5;
    n = n+1;
    WAIT_20_ms = n;
    SeqControl(WAIT_20_ms).command = 'noop'; % delay for transition to profile 5
    SeqControl(WAIT_20_ms).condition = 'Hw&Sw';
    SeqControl(WAIT_20_ms).argument = round(20e-3 / (200e-9)); % value*200nsec 5000=1ms
    n = n+1;
    RETMAT = n;
    SeqControl(RETMAT).command = 'returnToMatlab';
    n = n+1;
    TRIGOUT = n;
    SeqControl(TRIGOUT).command = 'triggerOut';
    n = n+1;
    SET_NUM_XMIT = n;
    SeqControl(SET_NUM_XMIT).command = 'loopCnt';
    SeqControl(SET_NUM_XMIT).condition = 'counter1'; 
    SeqControl(SET_NUM_XMIT).argument = (seq_params.pulse_count/nfoc)-1; %300 % 10 times per second for 30 seconds
    n = n+1;
    TEST_NUM_XMIT = n;
    SeqControl(TEST_NUM_XMIT).command = 'loopTst';
    SeqControl(TEST_NUM_XMIT).condition = 'counter1'; 
    SeqControl(TEST_NUM_XMIT).argument = []; % which event to jump to if nz (not zero)
    n = n+1;
    SYNC=n;
    SeqControl(SYNC).command = 'sync';
    SeqControl(SYNC).argument = seq_params.pulse_train_interval*1.5 / 1e-6;
    n = n+1;
    WAIT_XMIT = n;
    SeqControl(WAIT_XMIT).command = 'noop'; % delay for 0.1 second pause
    SeqControl(WAIT_XMIT).argument = max(round((seq_params.pulse_interval - solution.pulse.duration - .015)/(200e-9)), 1); % 
    n = n+1;
    JUMP_SEQ_CTRL = n;
    SeqControl(JUMP_SEQ_CTRL).command = 'jump';
    SeqControl(JUMP_SEQ_CTRL).condition = 'exitAfterJump'; % jump to outer loop.
    SeqControl(JUMP_SEQ_CTRL).argument = [];

    %% Event loop
    log.debug('Specifying Event Loop...')
    n = 1; % n counts the Events

    % Initialize TPC profile 5
    Event(n).info = 'select TPC profile 5';
    Event(n).tx = 0;
    Event(n).rcv = 0;
    Event(n).recon = 0;
    Event(n).process = 0;
    Event(n).seqControl = [SET_TPC5,WAIT_20_ms]; % set TPC profile command, noop.
    n = n+1;

    % Configure App
    SeqControl(JUMP_SEQ_CTRL).argument = n;
    Event(n).info = 'Check Sequence Controls';
    Event(n).tx = 0;
    Event(n).rcv = 0;
    Event(n).recon = 0;
    Event(n).process = EXT_SEQ_CONTROL;
    Event(n).seqControl = RETMAT; % set TPC profile command, noop.
    n = n+1;

    Event(n).info = 'sync';
    Event(n).tx = 0;
    Event(n).rcv = 0;
    Event(n).recon = 0;
    Event(n).process = 0;
    Event(n).seqControl = SYNC;
    n = n+1;

    Event(n).info = 'Set loop count for number of repeats (30sec)';
    Event(n).tx = 0;
    Event(n).rcv = 0;
    Event(n).recon = 0;
    Event(n).process = 0;
    Event(n).seqControl = [SET_NUM_XMIT, RETMAT];
    n = n+1;

    SeqControl(TEST_NUM_XMIT).argument = n;

    for i = 1:nfoc
        Event(n).info = 'Transmit and Receive';
        Event(n).tx = i;         % TX structure.
        Event(n).rcv = 0;        % Rcv structure
        Event(n).recon = 0;      % no Recon
        Event(n).process = EXT_LOG_XMIT;    % no processing
        Event(n).seqControl = [TRIGOUT, ACQ_PERIOD, EXTENDED_BURST_PERIOD, RETMAT]; % time between acqs.
        n = n+1; 

        if options.simulate 
            % The hardware won't be there to enforce the timing, so we can 
            % approximate it with a noop.
            Event(n).info = 'pause';
            Event(n).tx = 0;
            Event(n).rcv = 0;
            Event(n).recon = 0;
            Event(n).process = 0;
            Event(n).seqControl = WAIT_XMIT;
            n = n+1;
        end

        Event(n).info = 'sync';
        Event(n).tx = 0;
        Event(n).rcv = 0;
        Event(n).recon = 0;
        Event(n).process = 0;
        Event(n).seqControl = SYNC;
        n = n+1;
    end

    Event(n).info = 'Check for burst complete';
    Event(n).tx = 0;
    Event(n).rcv = 0;
    Event(n).recon = 0;
    Event(n).process = 0;
    Event(n).seqControl = [TEST_NUM_XMIT, RETMAT];
    n = n+1;

    Event(n).info = 'Loop back to sequence control';
    Event(n).tx = 0;        % no TX
    Event(n).rcv = 0;       % no Rcv
    Event(n).recon = 0;     % no Recon
    Event(n).process = 0; 
    Event(n).seqControl = JUMP_SEQ_CTRL; % jump command

    log.info('Configuration Complete')
    config = struct(...
        'Trans', Trans, ...
        'Resource', Resource, ...
        'TW', TW, ...
        'TPC', TPC, ...
        'TX', TX, ...
        'Process', Process, ...
        'SeqControl', SeqControl, ...
        'Event', Event, ...
        'Mcr_GuiHide', 1, ...
        'seq_params', seq_params, ...
        'start_flag', 0);
end