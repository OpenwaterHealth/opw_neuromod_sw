function ustx_config = setup(solution, options)
    arguments
        solution fus.treatment.Solution
        options.delay_units (1,1) string {mustBeMember(options.delay_units, ["ps","ns"])} = "ns"
        options.apodization_bits (1,1) double {mustBeMember(options.apodization_bits,[8,16,32])} = 16
        options.frequency_units (1,1) string {mustBeMember(options.frequency_units, ["Hz","kHz","MHz"])} = "Hz"
        options.voltage_units (1,1) string {mustBeMember(options.voltage_units, ["mV","V"])} = "mV"
        options.pulse_interval_units (1,1) string {mustBeMember(options.pulse_interval_units, ["ms","s"])} = "ms"
        options.pulse_train_interval_units (1,1) string {mustBeMember(options.pulse_train_interval_units, ["ms","s"])} = "s"
    end
    import fus.util.getunitconversion
    ustx_config.description = solution.description;
    ustx_config.delays = round(solution.delays * getunitconversion("s", options.delay_units));
    ustx_config.delay_units = options.delay_units;
    ustx_config.apodizations = round(solution.apodizations * (2^options.apodization_bits)-1);
    ustx_config.apodization_bits = options.apodization_bits;
    ustx_config.voltage = round(solution.pulse.amplitude*getunitconversion("V",options.voltage_units));
    ustx_config.voltage_units = options.voltage_units;
    ustx_config.pulse_frequency = round(solution.pulse.frequency*getunitconversion("Hz",options.frequency_units));
    ustx_config.pulse_frequency_units = options.frequency_units;
    ustx_config.pulse_cycles = round(solution.pulse.frequency*solution.pulse.duration);
    ustx_config.pulse_interval = round(solution.sequence.pulse_interval*getunitconversion("s", options.pulse_interval_units));
    ustx_config.pulse_interval_units = options.pulse_interval_units;
    ustx_config.pulse_count = solution.sequence.pulse_count;
    ustx_config.pulse_train_interval = round(solution.sequence.pulse_train_interval*getunitconversion("s", options.pulse_train_interval_units));
    ustx_config.pulse_train_interval_units = options.pulse_train_interval_units;
    ustx_config.pulse_train_count = solution.sequence.pulse_train_count;
end
    