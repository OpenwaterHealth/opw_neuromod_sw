function answer = dlg_confirm(msg, ttl, varargin)
    % DLG_CONFIRM unified confirmation box syntax
    %
    % USAGE:
    %   dlg_confirm(msg, ttl, varargin)
    %
    % DLG_ALERT calls either UICONFIRM or QUESTDLG depending on whether a
    % parent graphics handle is provided. Syntax generally follows the
    % UICONFIRM conventions.
    %
    % INPUTS:
    %   msg: [char] alert message
    %   ttl: [char] alert title
    %
    % OPTIONAL KEY, VALUE PAIRS
    %   figure: parent figure handle for modal dialogs, or -1
    %   Options: [cell] array of char options. Default {'OK', 'Cancel'}.
    %   DefaultOption: [int] index of default option. Default 1
    %   CancelOption: [inf] index of options if window is closed. Default
    %       inf (length of Options)
    %   all additional K-V pairs are passed to UICONFIRM if the dialog is
    %   modal 
    %
    % SEE ALSO: UICONFIRM, QUESTDLG
    options = struct('figure', -1, ...
        'DefaultOption', 1, ...
        'Options', {{'OK', 'Cancel'}}, ...
        'CancelOption', inf);
    options = fus.util.parseargs('add', options, varargin{:});
    if options.CancelOption > length(options.Options)
        options.CancelOption = length(options.Options);
    end
    if ishandle(options.figure)
        args = fus.util.struct2args(rmfield(options, 'figure'));
        answer = uiconfirm(options.figure, msg, ttl, args{:});
    else
        answer = questdlg(msg, ttl, options.Options{:}, options.Options{options.DefaultOption});
        if isempty(answer)
            answer = options.Options{options.CancelOption};
        end
    end        
end