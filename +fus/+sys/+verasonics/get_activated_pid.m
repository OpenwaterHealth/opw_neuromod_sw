function pid = get_activated_pid(options)
    arguments
        options.log fus.util.Logger = fus.util.Logger.get()
    end
    log = options.log;
    FNAME = 'activated_pid.txt';
    filename = fullfile(fileparts(mfilename('fullpath')), FNAME);
    if ~exist(filename, 'file')
        log.debug('%s does not exist', filename);
        pid = [];
    else
        log.debug('reading %s', filename);
        pid = fileread(filename);
    end
end

