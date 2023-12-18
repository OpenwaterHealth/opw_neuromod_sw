function kwave_path = get_path(options)
    arguments
        options.figure = -1
        options.default_location (1,1) string = "."
        options.save (1,1) logical = true
        options.log fus.util.Logger = fus.util.Logger.get()
    end
    log = options.log;
    paths = fus.get_paths();
    if isfield(paths, 'kwave')
        kwave_path = paths.kwave;
    else
        path_ok = false;
        log.warning('K-Wave not found on disk. Please identify the location of K-Wave')
        answer = fus.util.dlg_confirm('Please identify the location of "k-Wave"', ...
            'Could not find K-Wave Direcotry', ...
            'Options', {'Choose...', 'Exit'}, ...
            'DefaultOption', 1, ...
            'CancelOption', 2, ...
            'Icon', 'warning', ...
            'figure', options.figure);
        switch answer
            case 'Choose...'
                [~,choosepath] = uigetfile({'k-Wave.m;kWaveArray.m','k-Wave.m'},'Select location of k-Wave.m or kWaveArray.m','.');
                choosepath = strrep(choosepath, '\', '/');
                if ~isnumeric(choosepath) && isfolder(choosepath) && isfile(fullfile(choosepath, 'kWaveArray.m'))        
                    kwave_path = choosepath;
                    paths.kwave = kwave_path;
                    if options.save
                        save_paths(paths);
                    end
                    path_ok = true;
                end
            case 'Exit'
        end
        if ~path_ok
            kwave_path = string.empty;
            log.error('Could not find kWaveArray.m');
            fus.util.dlg_alert(...
                'Could not find K-Wave',...
                'Invalid Path', ...
                'Icon', 'error', ...
                'figure', options.figure);
        end
    end
end