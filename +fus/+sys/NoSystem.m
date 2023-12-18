classdef NoSystem < fus.sys.UltrasoundSystem
    %NOSYSTEM Dummy System when no system is connected
    properties
        id = "none"
        name = "No System"
    end
    
    methods
        function run(self, solution, options)
            arguments
                self fus.sys.NoSystem
                solution (1,1) fus.treatment.Solution                        
                options.log fus.util.Logger = fus.util.Logger.get()
            end
            log = options.log;
            log.warning("No System Connected")
        end
    end
    
end