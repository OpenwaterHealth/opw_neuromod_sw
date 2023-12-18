function s = list_dir(path, options)
%LIST_DIR recursively list files and folders
    arguments
        path (1,1) string {mustBeFolder}
        options.indent (1,1) double {mustBeInteger} = 0
        options.recursive (1,1) logical = true
        options.depth (1,1) double = inf
        options.ignore (1,:) string = "^\.*"
        options.tabwidth (1,1) double {mustBeInteger} = 2
    end
    d = dir(path);
    if options.indent == 0
        s = sprintf('%s%s\n', path, filesep);
    else
        s = '';
    end
    bar = char(compose("\xFFE8"));
    dgood = [];
    for i = 1:length(d)
        di = d(i);
        if all(arrayfun(@(x)isempty(regexp(di.name, x, 'once')), options.ignore))
            dgood = [dgood di];
        end
    end
    for i = 1:length(dgood)
        di = dgood(i);
        space = ' ';
        prefix = [...
            repmat([bar repmat(' ',1,options.tabwidth-1)],1,options.indent), ...
            bar, repmat(space,1,options.tabwidth-1)];
        if di.isdir
            s = [s sprintf('%s%s%s\n', prefix, di.name, filesep)];
            if options.recursive && options.depth > 0
                s = [s fus.util.list_dir(...
                        fullfile(di.folder, di.name), ...
                        indent=options.indent+1, ...
                        recursive=options.recursive, ...
                        depth=(options.depth-1), ...
                        ignore=options.ignore,...
                        tabwidth=options.tabwidth)];
            end
        else
            s = [s sprintf('%s%s\n', prefix, di.name)];
        end
    end
end
    
