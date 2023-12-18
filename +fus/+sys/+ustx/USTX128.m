classdef USTX128 < fus.sys.UltrasoundSystem
    properties
        id = "ustx"
        name = "USTX 128"
    end
    
    methods
        function self = USTX128(options)
            arguments
                options.?fus.sys.ustx.USTX128
            end
            self.parse_props(options);
        end
        
        function run(self, solution, options)
            arguments
                self fus.sys.ustx.USTX128
                solution (1,1) fus.treatment.Solution                        
                options.delay_units (1,1) string {mustBeMember(options.delay_units, ["ps","ns"])} = "ns"
                options.apodization_bits (1,1) double {mustBeMember(options.apodization_bits,[8,16,32])} = 16
                options.frequency_units (1,1) string {mustBeMember(options.frequency_units, ["Hz","kHz","MHz"])} = "Hz"
                options.voltage_units (1,1) string {mustBeMember(options.voltage_units, ["mV","V"])} = "mV"
                options.pulse_interval_units (1,1) string {mustBeMember(options.pulse_interval_units, ["ms","s"])} = "ms"
                options.pulse_train_interval_units (1,1) string {mustBeMember(options.pulse_train_interval_units, ["ms","s"])} = "s"
                options.figure = -1
                options.log fus.util.Logger = fus.util.Logger.get()
            end
            log = options.log;
            args = fus.util.struct2args(rmfield(options, ["log", "figure"]));
            log.info("Configuring solution...");
            config = fus.sys.ustx.setup(solution, args{:});
            log.info("Running solution on %s...", self.name);
            answer = fus.util.dlg_confirm(...
                "Start Treatment?", ...
                "USTX Treatment Controller (Simlulated)", ...
                'figure', options.figure, ...
                'DefaultOption', 1, ...
                'Options', {'Start', 'Cancel'}, ...
                'CancelOption', 2);
            sol = solution.copy();
            min_pulse_train = solution.sequence.pulse_count*solution.sequence.pulse_interval;
            if solution.sequence.pulse_train_interval < min_pulse_train
                sol.sequence.pulse_train_interval = min_pulse_train;
            end
            total_time = sol.sequence.pulse_train_interval*sol.sequence.pulse_train_count;
            log.info("Config description: %s", config.description);
            log.warning("Not Implemented")
            switch answer
                case "Start"
                    p = fus.util.ProgressBar(...
                        "figure", options.figure, ...
                        "timer", true, ...
                        "tag", "USTX_Controller");
                    ii = 0;
                    t0 = tic;
                    for i = 1:sol.sequence.pulse_train_count
                        t_pulse_train = toc(t0);
                        for j = 1:sol.sequence.pulse_count
                            pct = toc(t0)/total_time;
                            p.update(pct, sprintf("Pulse Train %d/%d, Pulse %d/%d [%0.0f%%]", i, sol.sequence.pulse_train_count, j, sol.sequence.pulse_count, pct*100));
                            pause(sol.sequence.pulse_interval*j - (toc(t0)-t_pulse_train));
                        end
                        while (sol.sequence.pulse_train_interval*i) > toc(t0)
                            pct = toc(t0)/total_time;
                            p.update(pct, sprintf("Pulse Train %d/%d, Cooldown [%0.0f%%]", i, sol.sequence.pulse_train_count, pct*100));
                            pause(0.001)
                        end
                        %pause(sol.sequence.pulse_train_interval*i - toc(t0));
                    end
                    p.close();
                    fus.util.dlg_alert("Treatment Complete", "Treatment Complete", "figure", options.figure, "Icon", "success");
                    log.info("Treatment Complete")
                case "Cancel"
                    fus.util.dlg_alert("Treatment Canceled", "Treatment Canceled", "figure", options.figure, "Icon", "warning");
                    log.warning("Treatment Canceled")
            end
        end
    end
    
end