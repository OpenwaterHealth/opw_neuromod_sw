function vsx_sequencer()
    % VSX_SEQUENCER sequence handler for Verasonics
    %
    % VSX_SEQUENCER is called from the Event sequence as an external
    % Process call. It will generate a VSX_PROGRESS_GUI application on its
    % first execution, and update the gui on subsequent calls. This
    % function will check the status of flags in the base workspace to
    % wait for activity from the gui or VSX when determine what actions to
    % take at what time. The sequencer will use the seq_params struct from
    % the base workspace to determine the sequence parameters, which are
    % defined as a number of transmits, transmit period, number of bursts,
    % and burst period. Each burst comprises multiple transmits separated
    % by the transmit period - the transmits are timed by the verasonics
    % Event sequencer for better timing performance, but when the
    % VSX_SEQUENCER is called next, it will wait for a cooldown period (the
    % burst period less the transmit time) before yielding back to the
    % Event sequencer to start the next burst. The sequencer also handles
    % recovery from Freeze commands, which directly stop the Event
    % sequencer, and Exit commands, either from the gui or another internal
    % source.
    import fus.sys.verasonics.*
    persistent logger
    
    app_var = 'vsx_app'; 
    seq = evalin('caller', 'seq_params');
    start_var = 'start_flag';
    exit_var = 'vsExit';
        
    % Check if we need to open the GUI
    app_loaded = false;
    app_var_exist = evalin('caller', sprintf('exist(''%s'', ''var'')', app_var));
    if app_var_exist
        app = evalin('caller', app_var); 
        if isvalid(app)
            app_loaded = true;
        end
    end
    if ~app_loaded
        % Create the GUI
        mainapp_fig = findall(0, 'Type', 'figure', 'Tag', 'us_neuromod');
        if isempty(mainapp_fig)
            mainapp_fig = -1;
            logger = fus.util.Logger.get();
        else
            logger = mainapp_fig.RunningAppInstance.log;
            seq.log = logger;
        end
        logger.info('Starting VSX controller...');
        seq.parent = mainapp_fig;
        args = fus.util.struct2args(seq);
        app = vsx_progress_gui(args{:});
        assignin('caller', app_var, app);
        logger.info('VSX controller started')
    end
    
    % Check if we need to wait for user input
    if ~app.is_running 
        app.FreezeButton.Enable = false;
        if ~isempty(app.last_pulse_train)
            if app.elapsed_time < seq.pulse_train_interval 
                % We have returned from Unfreeze without completing the
                % previous burst period, so cannot guarantee that the full
                % cooldown period has passed.
                app.set_mode('freezecooldown');
                while app.elapsed_time < seq.pulse_train_interval
                    app.update();
                    pause(1);
                    %elapsed_time = seconds(datetime('now') - app.last_pulse_train);
                end
            end
            app.set_mode('unfreeze');
        else
            app.set_mode('startup');
        end
        app.update();
        app.StartButton.Enable = true;
        start_flag = evalin('caller', start_var );
        exit_flag = evalin('caller', exit_var);
        while ~start_flag && ~exit_flag && isvalid(app)
            % Wait for the user to click start, close the app, or for vsx
            % to internally set its exit flag?
            exit_flag = evalin('base', 'vsExit');
            start_flag = evalin('base', 'start_flag');
            pause(0.1);
        end
        
        if ~isvalid(app)
            logger.warning('VSX controller was closed')
            return
        elseif exit_flag
            logger.error('Unexpected exit flag detected')
            app.exit();
            return
        elseif start_flag
            logger.info('Starting sequence')
            app.FreezeButton.Value = 0;
            app.FreezeButton.Enable = true;
        end
    end
    
    % Check where we are in the sequence
    if app.pulse_train_index >= seq.pulse_train_count
        app.set_mode('complete');
        app.update();
        pause(0.1);
        app.exit()
    else
        % Check if we need to wait before starting the next burst
        if ~isempty(app.last_pulse_train)
            last_whole_second = 0;
            if app.elapsed_time < seq.pulse_train_interval
                app.set_mode('cooldown')
                while  app.elapsed_time < seq.pulse_train_interval
                    wait_time = seq.pulse_train_interval - app.elapsed_time;
                    if last_whole_second ~= round(wait_time)
                        app.update('log',true);
                        last_whole_second = round(wait_time);
                    else
                        app.update('log',false);
                    end
                    pause(0.1);
                    if ~isvalid(app) || ~app.is_running
                        return
                    end
                end
            end
        end
        app.set_pulse(1);
        app.set_pulse_train(app.pulse_train_index+1);
        app.mark_pulse_train();
        app.set_mode('transmit');
    end
end