function temp = get_trans_temperature(options)
    arguments
        options.simulate (1,1) double {mustBeInteger} = 0
        options.thermistor_index (1,1) double {mustBeInteger} = 1
        options.log fus.util.Logger = fus.util.Logger.get()
    end
    import vsv.hal.shi.thermo.*
    % GET_TRANS_TEMPERATURE read transducer temperature
    %
    % USAGE:
    %   temp = get_trans_temperatrue()
    %
    % OPTIONAL KEY, VALUE PAIRS:
    %   log: fus.util.Logger object
    %   simulate: simulate mode
    %
    % OUTPUTS:
    %   temp: temperature [Deg C]
    %
    COEFFS = [0.000117, -0.011369, 0.434951, -8.814721, 102.236226];
    global SIM_TEMPERATURE

    log = options.log;
    if options.simulate > 0
        if exist('SIM_TEMPERATURE','var')
            temp = SIM_TEMPERATURE;
        else
            temp = 36 + 5*(randn()^2);
        end

    else
        try
            Resource = evalin('base', 'Resource');
            connSel = Resource.Parameters.Connector;
            numThermistors = numel(Resource.Parameters.ProbeThermistor);
            VDAS = evalin('base', 'VDAS');
            thermistorValues = readProbeThermistorValues(connSel, numThermistors,VDAS); % gets the AD values
            resistances = convertThermistorValues(thermistorValues)/1e3; %converts AD values to resistances
            temp = polyval(COEFFS, resistances);
            temp = temp(options.thermistor_index);
        catch me
            log.warning(me.message)
            temp = nan;
        end
    end
end