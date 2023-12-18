function vsx_path = get_path(options)
    arguments
        options.figure = -1
        options.default_location (1,1) string = "."
        options.save (1,1) logical = true
        options.log fus.util.Logger = fus.util.Logger.get()
    end
    log = options.log;
    paths = fus.get_paths();
    if isfield(paths, 'vsx')
        vsx_path = paths.vsx;
    else
        path_ok = false;
        log.warning('Verasonics directory not found on disk. Please identify the location of VSX.m')
        answer = fus.util.dlg_confirm(...
            'Please identify the location of VSX.m', ...
            'Could not find Verasonics Directory', ...
            'Options', {'Choose...', 'Exit'}, ...
            'DefaultOption', 1, ...
            'CancelOption', 2, ...
            'Icon', 'warning', ...
            'figure', options.figure);
        switch answer
            case 'Choose...'
                [~, choosepath] = uigetfile({'VSX.m', 'VSX.m'},'Select location of VSX.m', options.default_location);
                choosepath = strrep(choosepath, '\', '/');
                if ~isnumeric(choosepath) && isfolder(choosepath) && isfile(fullfile(choosepath, 'VSX.m'))        
                    vsx_path = choosepath;
                    paths.vsx = vsx_path;
                    if options.save
                        save_paths(paths);
                    end
                    path_ok = true;
                end
            case 'Exit'
        end
        if ~path_ok
            vsx_path = string.empty;
            log.error('Could not find VSX.m');
            fus.util.dlg_alert(...
                'Could not find VSX.m',...
                'Invalid Path', ...
                'Icon', 'error', ...
                'figure', options.figure);
        end
    end
end