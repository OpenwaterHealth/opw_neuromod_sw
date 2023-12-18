classdef Logger < handle
    % Logger basic logging utility
    %   Logger creates a handle object with configurable output
    
    properties (GetAccess=public, SetAccess=protected)
        logfile (1,1) string % Name of logfile
        logfile_ok (1,1) logical % Status of logfile
    end
    
    properties (Access=public)
        loglevel_file (1,1) string {mustBeMember(loglevel_file, ["DEBUG", "INFO", "WARNING", "ERROR", "NONE"])}= "INFO" % log level for logfile
        loglevel_stdout (1,1) string {mustBeMember(loglevel_stdout, ["DEBUG", "INFO", "WARNING", "ERROR", "NONE"])}= "INFO" % log level for stdout
        show_timestamp (1,1) logical % show timestamp flag
        timestamp_fmt (1,1) string % timestamp format
        show_stacktrace (1,1) logical % show stacktrace flag
    end
    
    properties (GetAccess=private, SetAccess=protected)
        iobuf % File buffer
    end
    
    properties (GetAccess=private, SetAccess=immutable)
        priority = struct(...
            'DEBUG', 1, ...
            'INFO', 2, ...
            'WARNING', 3, ...
            'ERROR', 4, ...
            'NONE', inf); % Priority map
    end
    
    methods (Access=public)
        function self = Logger(options)
            % LOGGER Logger Constructor
            % log = fus.util.Logger("param", value, ...)
            %
            % Inputs:
            %   logfile (string): Logfile name.
            %
            % Optional Parameters:
            %   'loglevel_file' (string): Log level for the logfile. Default is 'INFO'.
            %   'loglevel_stdout' (string): Log level for stdout. Default is 'INFO'.
            %   'loglevel' (string): Log level for both the logfile and stdout. Default is 'INFO'.

            arguments
                options.logfile (1,1) string= "";
                options.loglevel_file (1,1) string {mustBeMember(options.loglevel_file, ["", "DEBUG", "INFO", "WARNING", "ERROR", "NONE"])}= "";
                options.loglevel_stdout (1,1) string {mustBeMember(options.loglevel_stdout, ["", "DEBUG", "INFO", "WARNING", "ERROR", "NONE"])}= "";
                options.loglevel (1,1) string {mustBeMember(options.loglevel, ["", "DEBUG", "INFO", "WARNING", "ERROR", "NONE"])}= "INFO";
                options.writemode (1,1) string {mustBeMember(options.writemode, ["w","wt", "write", "a","at","append"])}= "w";
                options.show_timestamp (1,1) logical = true;
                options.timestamp_fmt (1,1) string = "yyyy-mm-dd HH:MM:SS.FFF";
                options.show_stacktrace (1,1) logical = true;
            end
            
            if isempty(options.loglevel_file) || options.loglevel_file == ""
                self.loglevel_file = upper(options.loglevel);
            else
                self.loglevel_file = upper(options.loglevel_file);
            end
            if isempty(options.loglevel_stdout) || options.loglevel_stdout == ""
                self.loglevel_stdout = upper(options.loglevel);
            else
                self.loglevel_stdout = upper(options.loglevel_stdout);
            end
            self.show_timestamp = options.show_timestamp;
            self.timestamp_fmt = options.timestamp_fmt;
            self.show_stacktrace = options.show_stacktrace;
            switch lower(options.writemode)
                case {'w','wt','write'}
                    writemode = 'wt';
                case {'a', 'at','append'}
                    writemode = 'at';
                otherwise
                    error('invalid writemode %s', options.writemode);
            end
            if ~(isempty(options.logfile) || options.logfile == "")
                self.iobuf = fopen(options.logfile, writemode);
                if self.iobuf == -1
                    error('Could not open %s', options.logfile)
                end
                self.logfile = options.logfile;
                self.logfile_ok = true;
            else
                self.logfile_ok = false;
            end
        end
        
        function close(self)
            % CLOSE close logfile
            global LOGGER
            % CLOSE close logfile
            if ~isempty(self.logfile) && self.logfile_ok
                fclose(self.iobuf);
                self.logfile_ok = false;
            end
            if self.is_global
                LOGGER = [];
            end
        end
                
        function varargout = debug(self, msg, varargin)
            % DEBUG log message with level DEBUG
            % log.debug(msg, varargin)
            % msg = log.debug(msg, varargin)
            %
            % Inputs:
            %   msg (string): Message to log
            %   varargin: Arguments to sprintf
            %
            % Outputs:
            %   fmt_msg: Formatted message
            fmt_msg = self.format_msg(sprintf('DEBUG: %s', msg), varargin{:});
            self.log_to_stdout('DEBUG', fmt_msg, 1);
            self.log_to_file('DEBUG', fmt_msg);
            if nargout > 0 
                varargout{1} = fmt_msg;
            end
        end
        
        
        function varargout = info(self, msg, varargin)
            % INFO log message with level INFO
            % log.info(msg, varargin)
            % msg = log.info(msg, varargin)
            %
            % Inputs:
            %   msg (string): Message to log
            %   varargin: Arguments to sprintf
            %
            % Outputs:
            %   fmt_msg: Formatted message
            if nargin > 2
                fmt_msg = self.format_msg(sprintf('INFO: %s', msg), varargin{:});
            else
                fmt_msg = self.format_msg('INFO: %s', msg);
            end
            self.log_to_stdout('INFO', fmt_msg, 1);
            self.log_to_file('INFO', fmt_msg);
            if nargout > 0
                varargout{1} = fmt_msg;
            end
        end
        
        function varargout = warning(self, msg, varargin)
            % WARNING log message with level WARNING
            % log.warning(msg, varargin)
            % msg = log.warning(msg, varargin)
            %
            % Inputs:
            %   msg (string): Message to log
            %   varargin: Arguments to sprintf
            %
            % Outputs:
            %   fmt_msg: Formatted message
            if nargin > 2
                fmt_msg = self.format_msg(sprintf('WARNING: %s', msg), varargin{:});
            else
                fmt_msg = self.format_msg('WARNING: %s', msg);
            end
            self.log_to_stdout('WARNING', fmt_msg, 1);
            self.log_to_file('WARNING', fmt_msg);
            if nargout > 0
                varargout{1} = fmt_msg;
            end
        end
        
        function varargout = error(self, msg, varargin)
            % ERROR log message with level ERROR
            % log.error(msg, varargin)
            % msg = log.error(msg, varargin)
            %
            % Inputs:
            %   msg (string): Message to log
            %   varargin: Arguments to sprintf
            %
            % Outputs:
            %   fmt_msg: Formatted message
            if nargin > 2
                fmt_msg = self.format_msg(sprintf('ERROR: %s', msg), varargin{:});
            else
                fmt_msg = self.format_msg('ERROR: %s', msg);
            end
            self.log_to_stdout('ERROR', fmt_msg, 2);
            self.log_to_file('ERROR', fmt_msg);
            if nargout > 0
                varargout{1} = fmt_msg;
            end
        end
        
        function throw_error(self, msg, varargin)
            % THROW_ERROR log message with level ERROR and throw exception
            % log.throw_error(msg)
            % log.throw_error(msg, varargin)
            % log.throw_error(id, msg)
            % log.throw_error(id, msg, varargin)
            %
            % Inputs:
            %   msg (string): Message to log
            %   varargin: Arguments to sprintf

            if ~isempty(varargin) && isequal(regexp(msg, "\w+:\w+", "match", "once"), msg)
                id = msg;
                msg = varargin{1};
                varargin = varargin(2:end);
            else
                id = 'error:RaisedByLog';
            end
            if numel(varargin)>0
                fmt_msg = self.format_msg(sprintf('ERROR: %s', msg), varargin{:});
            else
                fmt_msg = self.format_msg('ERROR: %s', msg);
            end
            self.log_to_file('ERROR', fmt_msg);
            ME = MException(id, '%s', fmt_msg);
            throwAsCaller(ME)
        end
        
        function set_global(self)
            % SET_GLOBAL set this logger as global
            global LOGGER
            LOGGER = self;
        end
        
        function tf = is_global(self)
            % IS_GLOBAL check if this logger is global
            global LOGGER
            tf = isequal(LOGGER, self);
        end

    end
    
    methods (Access=protected)
        
        function fmt_msg = format_msg(self, msg, varargin)
            % FORMAT_MSG format message
            if self.show_timestamp
                ts = sprintf('(%s) ', datestr(now, self.timestamp_fmt));
            else
                ts = '';
            end
            if self.show_stacktrace
                [dbst] = dbstack(2);
                if ~isempty(dbst)
                    caller = dbst(1).name;
                else
                    caller = 'base';
                end
                st = sprintf('[%s] ', caller);
            else
                st = '';
            end

            template = '%s%s%s';
            fmt_msg = sprintf(template, ts, st, sprintf(msg, varargin{:}));
        end
        
        function log_to_stdout(self, level, msg, buf)
            % LOG_TO_STDOUT log message to stdout
            if self.priority.(upper(self.loglevel_stdout)) <= self.priority.(upper(level))
                switch level
                    case 'WARNING'
                        fprintf(buf, '[\b%s]\b\n', msg);
                    otherwise
                        fprintf(buf, '%s\n', msg);
                end
            end
        end
        
        function log_to_file(self, level, msg)
            % LOG_TO_FILE log message to file
            if ~isempty(self.logfile) &&  self.logfile_ok
                if self.priority.(upper(self.loglevel_file)) <= self.priority.(upper(level))
                    try
                        fprintf(self.iobuf, '%s\n', msg);
                    catch me
                        switch me.identifier
                            case 'MATLAB:badfid_mx'
                                try
                                    self.iobuf = fopen(self.logfile, 'at');
                                    fprintf(self.iobuf, '%s\n', msg);
                                    warning('Logger:closed','%s was closed and had to be re-opened', self.logfile);
                                catch me
                                    warning('Logger:closed','%s was closed and could not  be re-opened', self.logfile);
                                    self.logfile_ok = false;
                                end
                            otherwise
                                fprintf('Logger Error! %s:%s\n', me.identifier, me.message);
                                self.logfile_ok = false;
                        end
                    end
                end
            end
        end
        
    end   
    
    methods (Static)
        function log = get(varargin)
            % GET get global logger object
            % log = fus.util.Logger.get()
            % log = fus.util.Logger.get(log)
            % log = fus.util.Logger.get(args_struct)
            % log = fus.util.Logger.get("param1", value1, "param2", value2, ...)
            %
            % Inputs:
            %   log (fus.util.Logger): Logger object
            %   args_struct: Arguments to Logger constructor
            %   args* : Key, Value pairs to Logger constructor
            global LOGGER
            switch nargin 
                case 0
                    if isa(LOGGER, 'fus.util.Logger')
                        log = LOGGER;
                    else
                        log = fus.util.Logger();
                        LOGGER = log;
                    end
                case 1
                    switch class(varargin{1})
                        case 'fus.util.Logger'
                            log = varargin{1};
                        case 'struct'
                            args = fus.util.struct2args(varargin{1});
                            if isempty(args) && isa(LOGGER, 'fus.util.Logger')
                                log = LOGGER;
                            else
                                log = fus.util.Logger(args{:});
                                LOGGER = log;
                            end
                        otherwise
                            error('Could not parse logger arguments')
                    end
                otherwise
                    log = fus.util.Logger(varargin{:});
                    LOGGER = log;
            end
        end                    
    end
    
end