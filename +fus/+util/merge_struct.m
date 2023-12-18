function s = merge_struct(options, defaults, newfields)
    % MERGE_STRUCT merge two structs
    %
    % USAGE:
    %   s = merge_struct(options, defaults, newfields)
    %
    % Returns a structure that is the combination of defaults and options.
    % Recursively merges substructures. 
    %
    % INPUTS:
    %   options: the structure of fields to be set
    %   defaults: the structure of default values
    %   newfields: the method of handling new fields not present in the
    %       defaults. Must be one of:
    %       'error' [default] raises an error
    %       'warn_add' raise a warning and add the field
    %       'warn_skip' raise a warning and skip the field
    %       'add' add the field
    %       'skip', skip the field
    %
    % OUTPUTS:
    %   s: merged structure
    
    % Version History
    % Created 2022-06-08
    import fus.util.*
    if ~exist('newfields', 'var')
        newfields = 'error';
    end
    newfield_options = {'error', 'warn_add', 'add', 'skip', 'warn_skip'};
    if isstruct(options) && isstruct(defaults) && length(defaults) == 1 && length(options) == 1
        s = defaults;
        fn = fieldnames(options);
        for i = 1:length(fn)
            if isfield(defaults, fn{i}) 
                s.(fn{i}) = merge_struct(options.(fn{i}), defaults.(fn{i}), 'add');
            elseif isempty(fieldnames(defaults))
                s.(fn{i}) = options.(fn{i});
            else
                switch newfields
                    case 'error'
                        dfns = fieldnames(defaults);
                        fns = sprintf('%s,', dfns{:});
                        fns = fns(1:end-1);
                        error('Cannot add field %s. Available options are {%s}, Set newfields to "add", "skip", "warn_add", or "warn_skip" if you want to change this behavior', fn{i}, fns);
                    case 'warn_add'
                        warning('Adding field %s', fn{i})
                        s.(fn{i}) = options.(fn{i});
                    case 'warn_skip'
                        warning('Skipping field %s', fn{i})
                    case 'add'
                        s.(fn{i}) = options.(fn{i});
                    case 'skip'
                    otherwise
                        error('newfields must be in {%s\b\b}\n', sprintf('"%s", ', newfield_options{:}))
                end
            end
        end
    else
        s = options;
    end
end