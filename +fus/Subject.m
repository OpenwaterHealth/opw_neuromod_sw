classdef Subject < fus.DataClass
    %SUBJECT Subject level data class
    
    properties
        id (1,1) string {mustBeValidVariableName} = "subject" % Subject ID
        name (1,1) string % Display name
        volumes (1,:) string {mustBeValidVariableName} % Volume IDs
        attrs struct = struct() %Additional Attributes
    end
    
    methods
        function self = Subject(options)
            % Create Subject object
            %   subject = fus.Subject("param", value, ...)
            %
            % Optional Parameters:
            %   'id' (string): Subject ID. Default: "subject"
            %   'name' (string): Display name. Default: id
            %   'volumes' (string): Volume IDs. Default: []
            %   'attrs' (struct): Additional attributes. Default: struct()
            %
            % Returns:
            %   subject (fus.Subject): Subject object
            arguments
                options.?fus.Subject
            end
            self.parse_props(options);
            if ~isfield(options, "name")
                self.name = self.id;
            end
        end
    end
    
    methods (Static)
        function subject = from_file(filename)
            % Load subject from file
            %   subject = fus.Subject.from_file(filename)
            %
            % Inputs:
            %   filename (string): Path to file
            %
            % Returns:
            %   subject (fus.Subject): Subject object
            arguments
                filename (1,1) string {mustBeFile}
            end
            s = jsondecode(fileread(filename));
            if isstruct(s.volumes)
                warning("Updating subject file")
                s.volumes = reshape(string(fieldnames(s.volumes)),1,[]);
                subject = fus.Subject.from_struct(s);
                subject.to_file(filename);
            else
                subject = fus.Subject.from_struct(s);
            end
            
        end
        
        function subject = from_struct(s)
            % Create subject from struct
            %   subject = fus.Subject.from_struct(s)
            %
            % Inputs:
            %   s (1,1) struct: Struct with subject properties
            %
            % Returns:
            %   subject (fus.Subject): Subject object
            arguments
                s (1,1) struct
            end
            args = fus.util.struct2args(s);
            subject = fus.Subject(args{:});
        end
    end
end
