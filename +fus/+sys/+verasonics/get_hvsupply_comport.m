function comport = get_hvsupply_comport(options)
    % GET_HV_SUPPLY_COMPORT find verasonics external power supply 
    %
    % USAGE:
    %   comport = get_hvsupply_comport(varargin)
    %
    % GET_HV_SUPPLY_COMPORT locates the linear power supply by it's vendor
    %   ID (VID) and product ID (PID) among enumerated serial devices.
    %
    % OPTIONAL KEY, VALUE PAIRS
    %   vid: [char or uint16] 4-byte hex code of VID. Default 0x103E
    %   pid: [char or uint16] 4-byte hex code of PID. Default 0x0456
    %   log: fus.util.Logger or fus.util.Logger input args
    %
    % OUTPUTS:
    %   comport: [char] 'COM<X>' matching port. Errors if no match is
    %   found.
    arguments
        options.vid = 0x103e
        options.pid = 0x0456
        options.simulate (1,1) logical = false
        options.log fus.util.Logger = fus.util.Logger.get()
    end
    import fus.sys.verasonics.find_comport
    log = options.log;
    comport = find_comport(options.vid, options.pid, ...
        'log', log, 'simulate', options.simulate);
    if iscell(comport)
        if ~options.simulate
            log.error("No power supply found")
        end
        comport = "NO_COMPORT";
    end
end