function options = parseargs(newfields, defaults, varargin)
    % PARSEARGS parse varargin into structure
    %
    % USAGE:
    %   options = parseargs(newfields, defaults, useroptions)
    %   options = parseargs(newfields, defaults, opt1, val1, opt2, val2..)
    %   options = parseargs(defaults, ...)
    %
    % PARSEARGS returns a structure containing options specified by the
    % user (as a struct or series of 'field', value, ... input arguments),
    % or defaults specified in the defaults structure if the options are
    % not specified by the user.
    %
    % INPUTS:
    %   newfields: [char] specification for handling provided keys that
    %       are not in the defaults. See MERGE_STRUCT. Defaults to 'error'
    %       (throw an exception if an invalid key is provided) if omitted.
    %   defaults: [struct] structure of default options    
    %   useroptions: can be provided as a struct, or as a series of
    %       comma-delimited key-value pairs.
    %
    % OUTPUTS:
    %   options: [struct] contained defaults and
    %
    % EXAMPLES:
    % >> defaults = struct('foo', 1, 'bar', 2);
    % >> options = struct('foo', 3)
    % >> parseargs(defaults, options)
    % >>   struct with fields:
    % >>      foo: 3
    % >>      bar: 2
    %
    % >> defaults = struct('foo', 1, 'bar', 2);
    % >> parseargs(defaults, 'foo', 3)
    % >>   struct with fields:
    % >>      foo: 3
    % >>      bar: 2
    %   
    % SEE ALSO: MERGE_STRUCT
    import fus.util.*
    if isstruct(newfields)
        if nargin > 2
            args = {defaults, varargin{:}};
        elseif nargin > 1
            args = {defaults};
        else
            args = {};
        end
        defaults = newfields;
        newfields = 'error';
    else
        args = {varargin{:}};
    end
    
    if isempty(args)
        user_options = struct();
    elseif length(args) == 1 && isstruct(args{1})
        user_options = struct(args{1});
    elseif mod(length(args), 2) == 0
        user_options = struct();
        for i = 1:2:length(args)
            user_options.(args{i}) = args{i+1};
        end
    else
        error('Unknown options specification')
    end
    options = merge_struct(user_options, defaults, newfields);
end