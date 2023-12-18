classdef Session < fus.DataClass
% SESSION Session level data class
    properties
        id (1,1) string {mustBeValidVariableName} = "session" % Session ID
        subject_id (1,1) string {mustBeValidVariableName} = "subject" % Subject ID
        name (1,1) string = "Session" % Session name
        date (1,1) datetime = datetime % Session date
        targets (1,:) fus.Point % Treatment targets
        markers (1,:) fus.Point % Registration markers
        volume (1,1) fus.Volume % MRI volume
        transducer fus.xdc.Transducer % Transducer
        attrs (1,1) struct = struct() % Additional attributes
        date_modified (1,1) datetime = datetime % Date modified
    end
    
    methods
        function self = Session(options)
            % SESSION Construct a new session object
            %
            % session = fus.Session("param", value, ...)
            %
            % Optional Parameters:
            %   'id' (string): Session ID
            %   'subject_id' (string): fus.Subject ID
            %   'name' (string): Session name
            %   'date' (datetime): Session date
            %   'targets' (fus.Point): Treatment targets
            %   'markers' (fus.Point): Registration markers
            %   'volume' (fus.Volume): MRI volume
            %   'transducer' (fus.xdc.Transducer): Transducer
            %   'attrs' (struct): Additional attributes
            %   'date_modified' (datetime): Date modified
            arguments
                options.?fus.Session
            end
            self.parse_props(options);
        end
        
        function to_file(self, filename)
            % TO_FILE Save session to file
            %
            % session.to_file(filename)
            %
            % Inputs:
            %   'filename' (string): File name
            arguments
                self fus.Session
                filename (1,1) string
            end
            s = self.to_struct();
            s.volume = s.volume.id;
            s.transducer = struct('id', s.transducer.id, 'matrix', s.transducer.matrix);
            fus.util.struct2json(s, filename);
        end
        
        function scene = to_scene(self, options)
            % TO_SCENE Convert session to scene
            %
            % scene = session.to_scene("param", value, ...)
            %
            % Optional Parameters:
            %   'id' (string): Scene ID. Default = Session ID
            %   'name' (string): Scene name. Default = Session name
            %
            % Returns:
            %   'scene' (fus.Scene): Scene
            arguments
                self fus.Session
                options.id (1,1) string {mustBeValidVariableName} = self.id
                options.name (1,1) string = self.name
            end
            cmap = fus.ColorMapper.from_volume(self.volume, "cmap", "bone", "alim_pct", [0, 0.5], "alim_out", [0, 1]);
            cmap.id = 'mri';
            scene = fus.Scene(...
                "id", options.id, ...
                "name", options.name, ...
                "targets", self.targets, ...
                "markers", self.markers, ...
                "volumes", self.volume, ...
                "colormaps", cmap, ...
                "transducer", self.transducer,...
                "attrs", self.attrs);
        end
    end

end
