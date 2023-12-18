function [set_ok, this_pid] = set_activated_pid(options)
    arguments
        options.pid
        options.log fus.util.Logger = fus.util.Logger.get
    end
    import fus.sys.verasonics.*
    FNAME = 'activated_pid.txt';
    filename = fullfile(fileparts(mfilename('fullpath')), FNAME);
    log = options.log;
    if isfield(options, 'pid')
        this_pid = options.pid;
    else
        this_pid = get_pid();    
    end
    log.debug('setting %s to %s\n', filename, this_pid);
    try
        fid = fopen(filename, 'w');
        fprintf(fid,this_pid);
        fclose(fid);
        set_ok = true;
    catch me
        log.debug(me.message)
        set_ok = false;
    end
end