function [pid_ok, activated_pid] = check_pid(options)
    arguments
        options.log fus.util.Logger = fus.util.Logger.get()
    end
    import fus.sys.verasonics.*
    log = options.log;
    activated_pid = get_activated_pid('log', log);
    this_pid = get_pid();
    log.debug('This Process PID = %s', this_pid);
    log.debug('Activated Process PID = %s', activated_pid);
    if isempty(activated_pid)
        pid_ok = true;
    elseif isequal(activated_pid, this_pid)
        pid_ok = true;
    else
        tasks = get_tasks();
        if any(ismember(tasks(strcmp(tasks.Image_Name, 'MATLAB.exe'),'PID').PID, activated_pid))
            log.warning('Previous activated PID %s is running. Please close it before continuing', activated_pid);
            pid_ok = false;
        else
            log.debug('Previous activated PID %s is not running', activated_pid);
            pid_ok = true;
        end
    end 
end