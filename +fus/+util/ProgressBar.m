classdef ProgressBar < handle
    %ProgressBar flexible progress bar
    %   This combines uipgrogressdlg and waitbar

    properties
        handle
        ischild
        x = 0;
        msg = '';
        N
        start_time
        elapsed_time
        timer
        refresh_limit
        last_refresh
    end

    methods
        function obj = ProgressBar(options)
            arguments
                options.title (1,1) string = ""
                options.figure = -1
                options.tag (1,1) string = ""
                options.close_previous (1,1) logical = true
                options.N double = []
                options.timer (1,1) logical = false
                options.refresh_limit (1,1) double = 0
                options.message = ""
            end
            if isa(options.figure, "fus.util.ProgressBar")
                obj = options.figure;
                return
            elseif ishandle(options.figure)
                obj.handle = uiprogressdlg(options.figure, 'Title', options.title);
                obj.ischild = true;
            else
                obj.handle = waitbar(0, options.title);
                obj.handle.Name = options.title;
                obj.handle.Children.Title.Interpreter = 'None';
                obj.ischild = false;
                tag = sprintf('ProgressBar_%s', options.tag);
                if options.close_previous
                    garbage = findall(0, ...
                        'type', 'figure', ...
                        'tag', 'TMWWaitbar', ...
                        'UserData', tag);
                    for i = 1:length(garbage)
                        close(garbage);
                    end
                end
                obj.handle.UserData = tag;
            end
            obj.timer = options.timer;
            obj.refresh_limit = options.refresh_limit;
            obj.N = options.N;
            obj.start_time = tic();
            obj.elapsed_time = 0;
            obj.last_refresh = obj.start_time;
            obj.msg = options.message;
        end

        function reset_timer(obj)
            obj.start_time = tic();
            obj.elapsed_time = 0;
        end
        
        function fmsg = get_msg(obj)
            if ~isempty(obj.N)
                countmsg = sprintf('(%d/%d) ', obj.x, obj.N);    
            else
                countmsg = '';
            end
            if obj.timer
                t = toc(obj.start_time);
                obj.elapsed_time = t;
                minutes = floor(t/60);
                seconds = floor(t - (minutes*60));
                if isempty(obj.N)
                    tmsg = sprintf('[%02d:%02d] ', minutes, seconds);
                elseif obj.x <= 1
                    tmsg = sprintf('[%02d:%02d/--:--] ', minutes, seconds);
                else
                    ttot = t / ((obj.x-1)/obj.N);
                    tminutes = floor(ttot/60);
                    tseconds = floor(ttot - (tminutes*60));
                    tmsg = sprintf('[%02d:%02d/%02d:%02d] ', minutes, seconds, tminutes, tseconds);
                end
            else
                tmsg = '';
            end
            fmsg = sprintf('%s%s%s',tmsg,countmsg,obj.msg);
        end
        
        function varargout = update(obj, x, msg)
            if toc(obj.last_refresh) < obj.refresh_limit
                return
            end
            if exist('x','var') && ~isempty(x)
                obj.x = x;
            end
            if isempty(obj.N)
                xfrac = obj.x;
            else
                xfrac = obj.x/obj.N;
            end
            if exist('msg', 'var') && ~isempty(msg)
                obj.msg = msg;
            end
            fmsg = obj.get_msg();
            if obj.ischild
                obj.handle.Message = fmsg;
                obj.handle.Value = xfrac;
            else
                wrap_length = 48;
                if length(fmsg) <= wrap_length
                    wrap_msg = [newline fmsg];
                elseif length(fmsg) <= 2*wrap_length
                    wrap_msg = [fmsg(1:wrap_length) newline fmsg(wrap_length+1:end)];
                else
                    wrap_msg = [fmsg(1:wrap_length-3) '...' newline '...' fmsg(end-wrap_length+4:end)];
                end
                waitbar(xfrac, obj.handle, wrap_msg)
            end
            if nargout > 0
                varargout{1} = msg;
            end
            obj.last_refresh = tic;
        end

        function close(obj)
            if isvalid(obj.handle)
                close(obj.handle)
            end
        end
    end
end