function [sim_error, status_msg] = run(config, options)
    % RUN launch VSX from a config file
    %
    % USAGE:
    %   [sim_error, status_msg] = fus.sys.verasonics.run(config, varargin)
    %
    % VERASONICS.RUN saves the configutation to a .mat file (in a default
    % location or a specified location), changes the current working
    % directory to the Verasonics code location, activates that directory,
    % and launches VSX.m in the base workspace with the filename variable
    % set to the mat file. A try-catch loop attempts to handle any errors
    % in the execution of VSX so that they can be passed to the calling
    % application for notification of the user.
    %
    % INPUTS:
    %   config: [struct] input structure. See VSX_SETUP
    %   
    % OPTIONAL KEY, VALUE PAIRS
    %   filename: [char] target filename to save config to. Uses temporary
    %       name if not included or empty.
    %   simulate: [bool] force simulate mode
    %   delete_file: [bool] delete config file after running. Default true.
    %   figure: [handle or -1] parent figure for modal dialogs
    %   vsx_path: [char] path to verasonics software. Uses GET_PATHS if 
    %       empty.
    %   log: [fus.util.Logger] Logging utility
    %   validate_pid: [bool] check for other running matlab processes that
    %       have activated via this function.
    %
    % OUTPUTS:
    %   sim_error: [int] status of sequence 0 if success, 1 if warning, 2
    %       if error. 
    %   status_msg: [char] status message of sequence
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
        config struct
        options.simulate (1,1) logical
        options.filename (1,1) string = ""
        options.delete_file (1,1) logical = true
        options.figure = -1
        options.vsx_path (1,1) string {mustBeFolder} = fus.sys.verasonics.get_path
        options.log fus.util.Logger = fus.util.Logger.get()
        options.validate_pid (1,1) logical = true
    end
    import fus.sys.verasonics.*
    log = options.log;
    here = pwd;
    t0 = tic;
    try
        if isfield(options, "simulate")
            config.Resource.Parameters.simulateMode = double(options.simulate);
        end
        if config.Resource.HIFU.extPwrComPortID=="auto"
            config.Resource.HIFU.extPwrComPortID = get_hvsupply_comport(...
                'simulate', config.Resource.Parameters.simulateMode, ...
                'log', log);            
        end
        if isempty(options.filename) || options.filename == ""
            options.filename = tempname;
        end
        [pth, fname, ~] = fileparts(options.filename);
        options.filename = fullfile(pth, sprintf('%s.mat', fname)); % enforce .mat extension
        repo = fileparts(fileparts(fileparts(mfilename('fullpath'))));
        addpath(repo)
        cd(options.vsx_path)
        log.info('Activating %s', options.vsx_path);
        this_pid = fus.sys.verasonics.get_pid();
        if options.validate_pid
            [pid_ok, activated_pid] = fus.sys.verasonics.check_pid('log', log);
            while ~pid_ok
                answer = dlg_confirm(...
                    sprintf(...
                        'Another MATLAB process that has activated the Verasonics software is running (PID = %s). Please close it and click Continue, or click Cancel to abort.', ...
                        activated_pid), ...
                    'Cannot Activate VSX', ...
                    'figure', options.figure, ...
                    'Options', {'Continue', 'Cancel'});
                switch answer
                    case 'Continue'
                        [pid_ok, activated_pid] = fus.sys.verasonics.check_pid('log', log);
                    case 'Cancel'
                        sim_error = 2;
                        status_msg = sprintf('Could not activate VSX software due to a conflict with another MATLAB process (PID = %s)', activated_pid);
                        return
                end
            end
        end 
        if ~strcmp(this_pid, activated_pid)
            evalin('base', 'activate')
        end
        addpath(repo);
        
        if options.validate_pid
            [set_ok, this_pid] = set_activated_pid('log', log);
            if ~set_ok
                log.warning('Could not set environment variable for this session');
            else
                log.info('Activated PID %s', this_pid);
            end
        end
        log.info('Saving config to %s', options.filename);
        save(options.filename, '-struct', 'config');
        evalin('base', 'clearvars');
        assignin('base', 'filename', options.filename)
        
		log.info('Launching VSX.m...');
        evalin('base', 'VSX')
        sim_error = 0;
        alerts_ok = evalin('base', sprintf('exist(''%s'', ''var'')', 'alerts'));
        if alerts_ok
            alerts = evalin('base', 'alerts');		
            log.info('VSX.m finished');
        else
            alerts = struct('type',{'error'},'message',{'Unexpected error in VSX. Check command prompt for details.'});
            log.error('VSX did not complete sucessfully');
        end
        nwarn = sum(ismember({alerts.type}, 'warning'));
        nerr = sum(ismember({alerts.type}, 'error'));
        
        tend = toc(t0);
        if nerr>0
            sim_error = 2;
            err = alerts(ismember({alerts.type}, 'error'));
            status_msg = sprintf('Exited in %0.1fs with %d warning(s) and %d error(s). The latest error was: %s', tend, nwarn, nerr, err(end).message);
        elseif nwarn>0
            sim_error = 1;
            warn = alerts(ismember({alerts.type}, 'warning'));
            status_msg = sprintf('Completed in %0.1fs with %d warning(s). The latest warning was: %s', tend, nwarn, warn(end).message);
        else            
            status_msg = sprintf('Completed in %0.1fs with no errors.', tend);
        end
        if options.delete_file
            delete(options.filename)
        end
    catch me
        switch me.identifier
            case 'save_run_vsx:vsxNotFound'
                dlg_alert(me.message, 'Failed to complete treatment',...
                    'figure', options.figure, ...
                    'Icon', 'error')
                sim_error = 1;
                status_msg = sprintf('Finished in %0.1ds with errors. %s:"%s"', toc(t0), me.identifier, me.message);
                log.error('%s\n', status_msg);
            otherwise
				log.error('Unexpected error in VSX:');
				log.error('%s:%s', me.identifier, me.message);
                rethrow(me)
        end
    end
    f = findall(0, 'Type', 'Figure', 'Name', 'VSX Control');
    close(f);
    cd(here)
end