classdef Uniform < fus.bf.ApodMethod
    %UNIFORM Uniform Apodization
    %  apod_method = fus.bf.apodmethods.Uniform()
    methods 
        function apod = calc_apod(self, trans, position, params)
            %CALC_APOD Calculate apodization
            %  apod = apod_method.calc_apod(trans)
            %  apod = apod_method.calc_apod(trans, position, params)
            %
            % Inputs:
            %   trans (fus.xdc.Transducer): Transducer array
            %   position (3x1 double): Position of focus (unused)
            %   params (1xN fus.Volume): Material Properties (unused)
            %
            % Returns:
            %   apod (1xN double): Apodization vector
            arguments
                self fus.bf.apodmethods.Uniform
                trans fus.xdc.Transducer
                position (3,1) double
                params (1,:) fus.Volume
            end
            apod = ones(1, trans.numelements);
        end
        
        function tab = get_table(self)
            %GET_TABLE Get table representation
            %  tab = apod_method.get_table()
            %
            % Returns:
            %   tab (table): Table representation
            tab = struct2table(...
                struct(...
                    "Name", "Apodization", ...
                    "Value", "Uniform", ...
                    "Units", ""));
        end
    end
end