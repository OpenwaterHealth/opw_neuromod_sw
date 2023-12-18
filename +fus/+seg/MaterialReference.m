classdef MaterialReference < fus.DataClass
    % MATERIALREFERENCE Reference material properties
    %   matref = fus.seg.MaterialReference("param1", value1, ...)
    properties
        id (1,1) string {mustBeValidVariableName} = 'water' % ID of material
        name (1,1) string = "water" % Name of material
        sound_speed (1,1) double {mustBePositive} = 1500 % Speed of sound (m/s)
        density (1,1) double {mustBePositive} = 1000 % Density (kg/m3)
        attenuation (1,1) double {mustBeNonnegative} = 0.002 % Attenuation (dB/cm/MHz)
        specific_heat (1,1) double {mustBePositive} = 4182 % Specific heat (J/kg * degC)
        thermal_conductivity (1,1) double {mustBePositive} = 0.598 % Thermal conductivity (W/m * K)
    end
    
    methods
        function self = MaterialReference(options)
            % MATERIALREFERENCE Construct a material reference object
            %  matref = fus.seg.MaterialReference("param1", value1, ...)
            %
            % Optional Parameters:
            %  'id' (string): ID of matial. Default: 'water'
            %  'name' (string): Name of material. Default: 'water'
            %  'sound_speed' (double): Speed of sound (m/s). Default: 1500
            %  'density' (double): Density (kg/m3). Default: 1000
            %  'attenuation' (double): Attenuation (dB/cm/MHz). Default: 0.002
            %  'specific_heat' (double): Specific heat (J/kg * degC). Default: 4182
            %  'thermal_conductivity' (double): Thermal conductivity (W/m * K). Default: 0.598
            %
            % Returns:
            %  matref (fus.seg.MaterialReference): Material reference object
            arguments
                options.?fus.seg.MaterialReference
            end
            self.parse_props(options);
        end
        
        function matref = by_id(self, material_id)
            % BY_ID Get material reference by ID
            %  matref = matrefs.by_id(material_id)
            %
            % Inputs:
            %  material_id (string): ID(s) of material
            %
            % Returns:
            %  matref (fus.seg.MaterialReference): Material reference matching the ID(s)   
            arguments
                self fus.seg.MaterialReference
                material_id (1,1) string {mustBeValidVariableName}
            end
            matref = self(ismember([self.id], material_id));
        end
        
        function map = get_index_map(self)
            % GET_INDEX_MAP Get map of material IDs to indices
            %  map = matrefs.get_index_map()
            %
            % Returns:
            %  map (struct): Map of material IDs to indices
            arguments
                self fus.seg.MaterialReference
            end
            for i = 1:numel(self)
                map.(self(i).id) = i;
            end
        end
    end
    
    methods (Static)
        function self = from_struct(s)
            % FROM_STRUCT Construct a material reference object from a struct
            %  matref = fus.seg.MaterialReference.from_struct(s)
            %
            % Inputs:
            %  s (struct): Struct with fields matching the properties of fus.seg.MaterialReference
            %
            % Returns:
            %  matref (fus.seg.MaterialReference): Material reference object
            arguments
                s struct
            end
            if numel(s) > 1
                self = arrayfun(@fus.seg.MaterialReference.from_struct, s);
                return
            end
            args = fus.util.struct2args(s);
            self = fus.seg.MaterialReference(args{:});
        end
        
        function param_ids = get_param_ids()
            % GET_PARAM_IDS Get IDs of material parameters
            %  param_ids = fus.seg.MaterialReference.get_param_ids()
            %
            % Returns:
            %  param_ids (1xN string): String array of material parameter IDs
            param_ids = ["sound_speed", "density", "attenuation", "specific_heat", "thermal_conductivity"];
        end
        
        function info = get_param_info(param_id)
            % GET_PARAM_INFO Get info about a material parameter
            %  info = fus.seg.MaterialReference.get_param_info(param_id)
            %
            % Inputs:
            %  param_id (string): ID of material parameter
            %
            % Returns:
            %  info (struct): Struct with fields "id", "name", and "units"
            arguments
                param_id (1,1) string {mustBeMember(param_id, ["sound_speed", "density", "attenuation", "specific_heat", "thermal_conductivity"])}
            end
            switch param_id
                case "sound_speed"
                    info = struct(...
                        "id", "sound_speed", ...
                        "name", "Speed of Sound", ...
                        "units", "m/s");
                case "density"
                    info = struct(...
                        "id", "density", ...
                        "name", "Density", ...
                        "units", "kg/m3");
                case "attenuation"
                    info = struct(...
                        "id", "attenuation", ...
                        "name", "Attenuation", ...
                        "units", "db/cm/MHz");
                case "thermal_conductivity"
                    info = struct(...
                        "id", "thermal_conductivity", ...
                        "name", "Thermal Conductivity", ...
                        "units", "W/m * K");
                 case "specific_heat"
                    info = struct(...
                        "id", "specific_heat", ...
                        "name", "Specific Heat", ...
                        "units", "J/kg * degC");
                otherwise
                    error("invalid param ID %s", param_id);
            end
        end
        
        function self = load_default(material_id)
            % LOAD_DEFAULT Load default material reference
            %  matref = fus.seg.MaterialReference.load_default(material_id)
            %
            % Inputs:
            %  material_id (string): ID of material. Must be one of "water", "tissue", "skull", "standoff", "air", "all"
            %
            % Returns:
            %  matref (fus.seg.MaterialReference): Material reference object
            arguments
                material_id (1,:) string {mustBeMember(material_id, ["all", "water", "tissue", "skull", "standoff", "air"])}
            end
            if numel(material_id) == 1 && material_id == "all"
                material_id = ["water", "tissue", "skull", "standoff", "air"];
                self = fus.seg.MaterialReference.load_default(material_id);
                return
            else
                if numel(material_id) > 1
                    self = arrayfun(@fus.seg.MaterialReference.load_default, material_id);
                    return
                end
                switch material_id
                    case "water"
                        self = fus.seg.MaterialReference(...
                            "id", "water", ...
                            "name", "water", ...
                            "sound_speed", 1500, ...
                            "density", 1000, ...
                            "attenuation", 0.0022, ...
                            "specific_heat", 4182, ...
                            "thermal_conductivity", 0.598);
                    case "tissue"
                        self = fus.seg.MaterialReference(...
                            "id", "tissue", ...
                            "name", "tissue", ...
                            "sound_speed", 1540, ...
                            "density", 1050, ...
                            "attenuation", 0.3, ...
                            "specific_heat", 3600, ...
                            "thermal_conductivity", 0.528);
                    case "skull"
                        self = fus.seg.MaterialReference(...
                            "id", "skull", ...
                            "name", "skull", ...
                            "sound_speed", 2800, ...
                            "density", 1900, ...
                            "attenuation", 6, ...
                            "specific_heat", 1300, ...
                            "thermal_conductivity", 0.4);
                    case "standoff"
                        self = fus.seg.MaterialReference(...
                            "id", "standoff", ...
                            "name", "standoff", ...
                            "sound_speed", 1420, ...
                            "density", 1000, ...
                            "attenuation", 1.0, ...
                            "specific_heat", 4182, ...
                            "thermal_conductivity", 0.598);   
                    case "air"
                        self = fus.seg.MaterialReference(...
                            "id", "air", ...
                            "name", "air", ...
                            "sound_speed", 344, ...
                            "density", 1.25, ...
                            "attenuation", 7.5, ...
                            "specific_heat", 1012, ...
                            "thermal_conductivity", 0.025);                    
                    otherwise
                        error('Invalid material ID %s', material_id);
                end
            end
        end
    end
end