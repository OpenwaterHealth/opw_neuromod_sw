classdef vsx_progress_gui_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        VSXProgressGUI     matlab.ui.Figure
        TemperatureLabel   matlab.ui.control.Label
        SequenceInfoLabel  matlab.ui.control.Label
        FreezeButton       matlab.ui.control.StateButton
        MessageLabel       matlab.ui.control.Label
        StartButton        matlab.ui.control.Button
        ProgressBarAxes    matlab.ui.control.UIAxes
    end

    
    properties (Access = private)
        flag_workspace = 'base'
        ProgressBar
        use_thermistor;
        pulse_train_count;
        pulse_train_interval;
        pulse_count;
        pulse_interval;
        mode = 'startup'
        temperature_widget;
        temperature_warn;
        temperature_error;
        been_warned = false;
        log fus.util.Logger = fus.util.Logger.get();
    end
    
    properties (Access = public)
        is_running = false
        BLUE = [0.4, 0.4, 1.0];
        GREEN = [0.2, 0.9, 0.3];
        YELLOW = [0.9, 0.9, 0.1];
        pulse_train_index = 0;
        pulse_index = 0;
        elapsed_time = 0;
        start_time = [];
        treatment_time = duration;
        last_pulse_train = [];
        simulate
        alerts = struct('type',{},'message',{});
    end
    
    methods (Access = private)
        
        function msg = get_msg(app)
            % GET_MSG get message for the progress bar
            switch app.mode
                case 'startup'
                    msg = sprintf('[%s] Press Start to begin treatment', ...
                        datestr(sum(app.treatment_time), 'MM:SS'));
                case 'freeze'
                    msg = sprintf('[%s] Press Unfreeze to continue, or close the window to exit', ...
                        datestr(sum(app.treatment_time), 'MM:SS'));
                case 'freezecooldown'
                    msg = sprintf('[%s] Cooling down...', ...
                        datestr(sum(app.treatment_time), 'MM:SS'));
                case 'unfreeze'
                    msg = sprintf('[%s] Press Start to resume', ...
                        datestr(sum(app.treatment_time), 'MM:SS'));
                case 'transmit'
                    msg = sprintf('[%s] Burst [%d/%d], Transmit [%d/%d]',...
                        datestr(sum(app.treatment_time), 'MM:SS'),...
                        app.pulse_train_index, ...
                        app.pulse_train_count, ...
                        app.pulse_index, ...
                        app.pulse_count);
                case 'cooldown'
                    wait_time = app.pulse_train_interval - app.elapsed_time;
                    msg = sprintf('[%s] Burst [%d/%d], Waiting %0.1fs...',...
                        datestr(sum(app.treatment_time), 'MM:SS'),...
                        app.pulse_train_index, ...
                        app.pulse_train_count, ...
                        wait_time);
                case 'complete'
                    msg = 'Sequence complete';
                otherwise
                    msg = '';
            end
        end
        
        function progress = get_progress(app) 
            % GET_PROGRESS get length of progress bar
            switch app.mode
                case 'startup'
                    progress = 0;
                case 'transmit'
                    frac = (app.pulse_interval * app.pulse_count) / app.pulse_train_interval;
                    progress = ((app.pulse_train_index - 1) + ...
                        (app.pulse_index / app.pulse_count)*frac) / ...
                         app.pulse_train_count;
                case {'cooldown', 'freezecooldown'}
                    progress = ((app.pulse_train_index - 1) + (app.elapsed_time/app.pulse_train_interval)) / app.pulse_train_count;
                case 'complete'
                    progress = 1;
                otherwise
                    progress = [];
            end
        end
        
        function state = check_flag(app, flagname)
            % CHECK_FLAG read variable from base workspace
            % Retrieve the value of a variable from the base workspace, or
            % return 0 if it does not exist
            flagname = genvarname(flagname);
            flag_exists = evalin(app.flag_workspace, sprintf('exist(''%s'', ''var'')', flagname));
            if ~flag_exists
                state = 0;
            else
                state = evalin(app.flag_workspace, flagname);
            end
        end
        
        function set_flag(app, flagname, state)
            % SET_FLAG set variable in base workspace
            flagname = genvarname(flagname);
            assignin(app.flag_workspace, flagname, state)
        end
        
        function set_progress(app, value)
            % SET_PROGRESS update the length of the progress bar
            app.ProgressBar.XData = [0, 0, value, value];            
        end

        function set_color(app, color)
            % SET_COLOR set the color of the progress bar
            app.ProgressBar.FaceColor = color;
        end
        
        function set_message(app, message)
            % SET_MESSAGE set the progress bar message
            app.MessageLabel.Text = message;
        end
        
        function add_alert(app, type, message, varargin)
            if isempty(varargin)
                msg = message;
            else
                msg = sprintf(message, varargin{:});
            end
            app.alerts(end+1) = struct(...
                'type', type, ...
                'message', msg);
        end
    end
    
    methods (Access = public)
       
        function update(app, options)
            % UPDATE update the progress bar to show the current sequence state
            arguments
                app fus.sys.verasonics.vsx_progress_gui
                options.log (1,1) logical = true
            end
            import fus.sys.verasonics.get_trans_temperature
            timestamp = datetime('now');
            if ~isempty(app.last_pulse_train)
                app.elapsed_time = seconds(timestamp - app.last_pulse_train);
            else
                app.elapsed_time = 0;
            end
            if app.is_running
                app.treatment_time(end) = timestamp - app.start_time;
            end
            msg = app.get_msg();
            progress = app.get_progress();
            switch app.mode
                case {'startup', 'transmit'}
                    color = app.GREEN;
                case {'freeze', 'unfreeze'}
                    color = app.YELLOW;
                case {'freezecooldown', 'cooldown', 'complete'}
                    color = app.BLUE;
            end
            if ~isempty(progress)
                app.set_progress(progress)
            end
            app.set_message(msg)
            if options.log
                app.log.info(msg)
            end
            app.set_color(color);
            if app.use_thermistor
                temp = get_trans_temperature('simulate', app.simulate);
                app.set_temperature_ind(temp);
            end

        end
        
        function set_temperature_ind(app, temp)
            % SET_TEMPERTURE set temperature indicator
            if isnan(temp)
                app.TemperatureLabel.Text = '-- °C';
                app.TemperatureLabel.FontColor = [0.5, 0.5, 0.5];
            else
                HI_LIMIT = app.temperature_error;
                MID_LIMIT = app.temperature_warn;
                app.TemperatureLabel.Text = sprintf('%0.1f °C', temp);
                if temp > HI_LIMIT
                    app.error('Temperature (%0.1f °C) exceeds hi limit of (%0.1f °C)', temp, HI_LIMIT)
                    app.TemperatureLabel.FontColor = [0.8, 0, 0];
                    app.exit()
                    % DO SOMETHING
                elseif temp > MID_LIMIT
                    if app.been_warned
                        app.log.warning('Temperature (%0.1f °C) exceeds mid limit of (%0.1f °C)', temp, MID_LIMIT);
                    else
                        app.warning('Temperature (%0.1f °C) exceeded mid limit of (%0.1f °C) at least once', temp, MID_LIMIT)
                        app.been_warned = true;
                    end
                    app.TemperatureLabel.FontColor = [0.8, 0.7, 0];
                else
                    app.TemperatureLabel.FontColor = [0, 0.7, 0];
                end
            end
        end
        
        function set_mode(app, mode)
            % SET_MODE change the progress bar mode
            app.mode = mode;
        end
        
        function mark_pulse_train(app)
            % MARK_BURST mark the current time as the latest burst
            app.last_pulse_train = datetime('now');
            app.elapsed_time = 0;
        end
        
        function set_pulse_train(app, index)
            % SET_BURST set the burst index
            app.pulse_train_index = index;
        end
        
        function set_pulse(app, index)
            % SET_XMIT set the transmit index
            app.pulse_index = index;
        end
        
        function set_description(app, description)
            % SET_DESCRIPTION change the description at the top of the gui
            app.SequenceInfoLabel.Text = description;
        end
        
        function warning(app, message, varargin)
            app.add_alert('warning', message, varargin{:});
            app.log.warning('warning: %s', app.alerts(end).message);
        end
        
        function error(app, message, varargin)
            app.add_alert('error', message, varargin{:});
            app.log.error('error: %s', app.alerts(end).message);
        end
        
        function exit(app)
            % EXIT exit the app
            app.log.info('Exit')
            try
                vsx_gui_FreezeButton = findobj('String','Freeze');
                if ~isempty(vsx_gui_FreezeButton)
                    vsx_gui_FreezeButton.Value = 0;
                end
            catch me
                app.set_flag('vsExit', true)
                app.error('unexpected error %s:%s', me.identifier, me.message)  
                assignin('base', 'alerts', app.alerts);
                app.delete();
                rethrow(me)
            end
            app.set_flag('vsExit', true)
            assignin('base', 'alerts', app.alerts);
            nwarn = sum(ismember({app.alerts.type}, 'warning'));
            nerr = sum(ismember({app.alerts.type}, 'error'));
            app.log.info('Completed with %d warning(s) and %d error(s).', nwarn, nerr)
            if ~isempty(app.temperature_widget)
                delete(app.temperature_widget);
            end
            app.delete();
        end
        
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, options)
            arguments
                app fus.sys.verasonics.vsx_progress_gui
                options.use_thermistor (1,1) logical = true
                options.pulse_train_interval double = 1
                options.pulse_train_count double = 1
                options.pulse_interval double = 1
                options.pulse_count double = 1
                options.pattern_length double = 1
                options.burst_cooldown double = 0
                options.description (1,1) string = ''
                options.parent = -1
                options.temperature_warn (1,1) double = 35
                options.temperature_error (1,1) double = 40
                options.log fus.util.Logger = fus.util.Logger.get()
            end
            import fus.sys.verasonics.SimTemperatureWidget
            app.log = options.log;    
            app.temperature_warn = options.temperature_warn;
            app.temperature_error = options.temperature_error;
            Resource = app.check_flag('Resource');
            if isstruct(Resource)
                app.simulate = Resource.Parameters.simulateMode;
            else
                app.simulate = 1;
            end
            if app.simulate
                app.temperature_widget = SimTemperatureWidget();
            end
            app.use_thermistor = options.use_thermistor;
            app.pulse_train_interval = options.pulse_train_interval;
            app.pulse_train_count = options.pulse_train_count;
            app.pulse_interval = options.pulse_interval;
            app.pulse_count = options.pulse_count;
            app.SequenceInfoLabel.Text = options.description;
            app.ProgressBar = patch(app.ProgressBarAxes, [0,0,0,0], [0, 0.1, 0.1, 0], app.BLUE, 'EdgeColor', 'none');
            disableDefaultInteractivity(app.ProgressBarAxes)
            app.ProgressBarAxes.Toolbar.Visible = 'off';
            orig_position = app.VSXProgressGUI.Position;
            pos = orig_position;
            if ishandle(options.parent)
                screen_pos = get(options.parent, 'Position');
            else
                screen_pos = get(0, 'ScreenSize');
            end
            pos(1) = round(screen_pos(1) + screen_pos(3)/2 - orig_position(3)/2);
            pos(2) = round(screen_pos(2) + screen_pos(4)/2 - orig_position(4)/2);
            app.VSXProgressGUI.Position = pos;
            assignin('base', 'alerts', app.alerts);
        end

        % Button pushed function: StartButton
        function StartButtonPushed(app, event)
            app.set_flag('start_flag', true);
            app.is_running = true;
            app.StartButton.Enable = false;
            timestamp = datetime("now");
            if isempty(app.start_time)
                app.treatment_time = duration();
            else
                app.treatment_time(end+1) = duration();
            end
            app.start_time = timestamp;
            app.log.info('Start')
        end

        % Value changed function: FreezeButton
        function FreezeButtonValueChanged(app, event)
            vsx_gui_FreezeBUtton = findobj('String','Freeze');
            value = app.FreezeButton.Value;
            app.set_flag('freeze', value);
            vsx_gui_FreezeBUtton.Value = value;
            if value
                app.set_mode('freeze');
                app.log.info('Freeze')
                app.is_running = false;
                app.set_flag('start_flag', false)
                app.alerts(end+1) = struct('type', 'warning', 'message', sprintf('Freeze detected at %s', datestr(datetime('now'), 'yyyy-mm-dd HH:MM:SS')));
                app.StartButton.Enable = false;
                app.FreezeButton.Text = 'Unfreeze';
            else
                app.set_mode('unfreeze');
                app.FreezeButton.Text = 'Freeze';
                app.log.info('Unfreeze')
            end
            app.update();
        end

        % Close request function: VSXProgressGUI
        function VSXProgressGUICloseRequest(app, event)
            try
                app.warning('Control app closed by user')
            catch ME
                
            end
            app.exit();
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create VSXProgressGUI and hide until all components are created
            app.VSXProgressGUI = uifigure('Visible', 'off');
            app.VSXProgressGUI.Position = [100 100 425 176];
            app.VSXProgressGUI.Name = 'Treatment Control';
            app.VSXProgressGUI.Resize = 'off';
            app.VSXProgressGUI.CloseRequestFcn = createCallbackFcn(app, @VSXProgressGUICloseRequest, true);

            % Create ProgressBarAxes
            app.ProgressBarAxes = uiaxes(app.VSXProgressGUI);
            app.ProgressBarAxes.XLim = [0 1];
            app.ProgressBarAxes.YLim = [0 0.1];
            app.ProgressBarAxes.ZLim = [0 1];
            app.ProgressBarAxes.XColor = 'none';
            app.ProgressBarAxes.XTick = [];
            app.ProgressBarAxes.YColor = 'none';
            app.ProgressBarAxes.YTick = [];
            app.ProgressBarAxes.ZColor = 'none';
            app.ProgressBarAxes.ZTick = [];
            app.ProgressBarAxes.BoxStyle = 'full';
            app.ProgressBarAxes.ClippingStyle = 'rectangle';
            app.ProgressBarAxes.Box = 'on';
            app.ProgressBarAxes.Position = [26 68 376 25];

            % Create StartButton
            app.StartButton = uibutton(app.VSXProgressGUI, 'push');
            app.StartButton.ButtonPushedFcn = createCallbackFcn(app, @StartButtonPushed, true);
            app.StartButton.FontSize = 24;
            app.StartButton.FontWeight = 'bold';
            app.StartButton.Enable = 'off';
            app.StartButton.Position = [26 13 175 40];
            app.StartButton.Text = 'Start';

            % Create MessageLabel
            app.MessageLabel = uilabel(app.VSXProgressGUI);
            app.MessageLabel.Position = [26 93 376 25];
            app.MessageLabel.Text = '';

            % Create FreezeButton
            app.FreezeButton = uibutton(app.VSXProgressGUI, 'state');
            app.FreezeButton.ValueChangedFcn = createCallbackFcn(app, @FreezeButtonValueChanged, true);
            app.FreezeButton.Enable = 'off';
            app.FreezeButton.Text = 'Freeze';
            app.FreezeButton.FontSize = 24;
            app.FreezeButton.FontWeight = 'bold';
            app.FreezeButton.Position = [226 13 176 40];

            % Create SequenceInfoLabel
            app.SequenceInfoLabel = uilabel(app.VSXProgressGUI);
            app.SequenceInfoLabel.BackgroundColor = [0.902 0.902 0.902];
            app.SequenceInfoLabel.Position = [26 140 310 25];
            app.SequenceInfoLabel.Text = '';

            % Create TemperatureLabel
            app.TemperatureLabel = uilabel(app.VSXProgressGUI);
            app.TemperatureLabel.FontSize = 16;
            app.TemperatureLabel.FontWeight = 'bold';
            app.TemperatureLabel.FontColor = [0.502 0.502 0.502];
            app.TemperatureLabel.Position = [347 141 64 25];
            app.TemperatureLabel.Text = '-- °C';

            % Show the figure after all components are created
            app.VSXProgressGUI.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = vsx_progress_gui_exported(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.VSXProgressGUI)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.VSXProgressGUI)
        end
    end
end