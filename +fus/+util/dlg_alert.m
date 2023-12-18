function dlg_alert(msg, ttl, varargin)
    % DLG_ALERT unified alert syntax
    %
    % USAGE:
    %   dlg_alert(msg, ttl, varargin)
    %
    % DLG_ALERT calls either UIALERT or MSGBOX depending on whether a
    % parent graphics handle is provided. Syntax generally follows the
    % UIALERT conventions.
    %
    % INPUTS:
    %   msg: [char] alert message
    %   ttl: [char] alert title
    %
    % OPTIONAL KEY, VALUE PAIRS
    %   figure: parent figure handle for modal dialogs, or -1
    %   Icon: [char] name of icon ('error', 'warning', 'info', 'success',
    %       'none'). Default 'none'
    %   all additional K-V pairs are passed to uialert if the dialog is
    %   modal 
    %
    % SEE ALSO: UIALERT, MSGBOX
    options = struct('figure', -1, ...
       'Icon', 'none');
    options = fus.util.parseargs('add', options, varargin{:});
    
    if ishandle(options.figure)
        args = fus.util.struct2args(rmfield(options, 'figure'));
        [~] = uiconfirm(options.figure, msg, ttl, args{:}, 'Options', 'Ok');
    else
        icon_map = struct(...
            'error', 'error',...
            'warning', 'warn', ...
            'info', 'none', ...
            'success', 'none', ...
            'none', 'none');
        uiwait(msgbox(msg, ttl, icon_map.(options.Icon)));
    end        
end