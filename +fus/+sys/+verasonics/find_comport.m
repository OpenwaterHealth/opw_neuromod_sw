function comport = find_comport(vid, pid, options)
    % FIND_COMPORT Identify COM Port by VID, PID
    % 
    % USAGE
    %   comport = find_comport(vid, pid)
    %
    % FIND_COMPORT searches serial port info for a match of the vendor ID
    % (VID) and product id (PID). This can help identify which COM port
    % contains a particular piece of hardware. Note that
    % GET_SERIAL_PORT_INFO cannot find every type of serial device (it uses
    % 'wmic path Win32_SerialPort', which doesn't necessarily find every
    % COM device in Device Manager.
    %
    % INPUTS:
    %   vid: [char or uint16] VID of hardware device (e.g. 'C1F0' or
    %       0xC1F0)
    %   pid: [char or uint16] PID of hardware device (e.g. 'B2AD' or
    %       0xB2AD)
    %
    % OPTIONAL KEY, VALUE PAIRS:
    %   log: fus.util.Logger or fus.util.Logger input args
    %
    % OUTPUTS:
    %   comport: [char] 'COM<X>' if a single match is found or [cell] array
    %       of matches if 0 or 2+ matches are found
    %
    % SEE ALSO: GET_SERIAL_PORT_INFO
    arguments
        vid
        pid
        options.simulate (1,1) logical = false
        options.log fus.util.Logger = fus.util.Logger.get()
    end
    import fus.sys.verasonics.get_serial_port_info
    log = options.log;
    switch class(vid)
        case 'uint16'
            vid_str = sprintf('%04X', vid);
        case {'string', 'char'}
            vid_str = char(vid);
        otherwise
            log.throw_error('VID must be char, string or uint16');
    end
    switch class(pid)
        case 'uint16'
            pid_str = sprintf('%04X', pid);
        case {'string', 'char'}
            pid_str = char(vid);
        otherwise
            log.throw_error('PID must be char, string or uint16');
    end
    all_port_info = get_serial_port_info();
    index = 0;
    matches = [];
    re = sprintf('(VID_%s)+&(PID_%s)+', vid_str, pid_str);
    for i = 1:length(all_port_info)
        port_info = all_port_info(i);
        pnpdid = port_info.PNPDeviceID;
        if ~isempty(regexp(pnpdid, re, 'once'))
            matches(end+1) = i;
        end
    end
    comports = {all_port_info(matches).DeviceID};
    if length(comports) == 1
        comport = comports{1};
    else
        if ~options.simulate % If in simulate mode, we don't care that we didn't find the port
            log.warning('Found %d matches for VID = %s and PID = %s', index, vid_str, pid_str);
            log.info('available port HWIDs:')
            for i = 1:length(all_port_info)
                log.info('    %s', all_port_info(i).PNPDeviceID);
            end
        end
        comport = comports;
    end
end
