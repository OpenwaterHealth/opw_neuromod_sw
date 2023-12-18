classdef Vantage < fus.sys.UltrasoundSystem
    properties
        id = "vantage"
        name = "Verasonics Vantage"
        simulate (1,1) logical = false;
        fake_scanhead (1,1) logical = false;
        system_type (1,1) string {mustBeMember(system_type, ["LF","HIFU"])} = "HIFU";
        comport (1,1) string = "auto";
        use_thermistor (1,1) logical = true;
        connector (1,:) double {mustBeMember(connector, [1,2])} = 2;
        channels (1,1) double {mustBeMember(channels, [128, 256])} = 256;
        vsx_path (1,1) string = fus.sys.verasonics.get_path
    end
    
    methods
        function self = Vantage(options)
            arguments
                options.?fus.sys.verasonics.Vantage
            end
            self.parse_props(options);
        end
        
        function config = setup(self, solution)
            arguments
                self fus.sys.verasonics.Vantage
                solution (1,1) fus.treatment.Solution
            end
            options = rmfield(self.to_struct(), ...
                ["id", "name", "class", "vsx_path"]);
            args = fus.util.struct2args(options);
            config = fus.sys.verasonics.setup(solution, args{:});
        end
                
        function run(self, solution, options)
            arguments
                self fus.sys.verasonics.Vantage
                solution (1,1) fus.treatment.Solution
                options.simulate (1,1) logical = self.simulate
                options.filename (1,1) string = ""
                options.delete_file (1,1) logical = true
                options.figure = -1
                options.log fus.util.Logger = fus.util.Logger.get()
                options.validate_pid (1,1) logical = true
            end
            config = self.setup(solution);
            options.vsx_path = self.vsx_path;
            args = fus.util.struct2args(options);
            fus.sys.verasonics.run(config, args{:});
        end
    end
    
end