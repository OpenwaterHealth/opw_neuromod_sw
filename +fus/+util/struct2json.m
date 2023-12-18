function struct2json(s, filename, varargin)
    % STRUCT2JSON Write struct to file as json
    %
    % USAGE:
    %   struct2json(s, filename)
    %
    % Writes a struct to file as json, creating directories if needed.
    %
    % INPUTS:
    %   s: struct
    %   filename: output filename
    %
    % OPTIONAL KEY, VALUE PAIRS
    %   ConvertInfAndNan
    %   PrettyPrint
        
    % Version History
    % Created 2022-06-03
    options = struct(...
        'ConvertInfAndNaN', true, ...
        'PrettyPrint', true);
    options = fus.util.parseargs(options, varargin{:});
    
    path = fileparts(char(filename));
    if ~isempty(path) && ~exist(path, 'dir')
        mkdir(path)
    end
    f = fopen(filename, 'wt');
    args = fus.util.struct2args(options);
    fwrite(f, jsonencode(s, args{:}));
    fclose(f);
end