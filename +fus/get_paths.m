function paths = get_paths()
    %GET_PATHS Get the default paths for the project
    HERE = fileparts(mfilename('fullpath'));
    filename = fullfile(HERE, 'paths.json');
    if isfile(filename)
        paths = jsondecode(fileread(filename));
    else
        paths = struct();
    end
end