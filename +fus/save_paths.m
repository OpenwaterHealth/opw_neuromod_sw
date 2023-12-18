function save_paths(paths)
    % SAVE_PATHS Save paths to JSON file
    HERE = fileparts(mfilename('fullpath'));
    filename = fullfile(HERE, 'paths.json');
    fus.util.struct2json(paths, filename);
end