function info = get_serial_port_info()
    % GET_SERIAL_PORT_INFO scan serial ports
    %
    % USAGE:
    %   info = get_serial_port_info()
    %
    % GET_SERIAL_PORT_INFO uses the system command 
    %   'wmic path Win32_SerialPort' to print information about connected
    %   serial ports and parses the output into a stucture.
    %
    % OUTPUTS:
    %   info: [1xN struct] of serial port information. Of particular
    %       interest are the fields:
    %       .PNPDeviceID: COM port
    %       .DeviceID: the hardware ID, typically containing VID and PID    
    [~, out] = system('wmic path Win32_SerialPort');
    lines = splitlines(out);
    headers = lines{1};
    col_start = [0, regexp(headers,' \S+'), length(headers)]+1;
    N = length(col_start)-1;
    col_names = cell(1,N);
    col_width = zeros(1,N);
    for i = 1:N
        col_names{i} = strip(headers(col_start(i):col_start(i+1)-1));
        col_width(i) = col_start(i+1)-col_start(i);
    end 
    index = 1;
    for row_index = 2:length(lines)
        l = lines{row_index};
        if ~isempty(l)
            si = struct();
            for i = 1:length(col_names)
                si.(col_names{i}) = strip(l(col_start(i)+(0:col_width(i)-1)));
            end
            info(index) = si;
            index = index + 1;
        end
    end
    if ~exist('info', 'var')
        warning('No serial port connections found')
        info = struct('PNPDeviceID',{},'DeviceID',{});
    end
end    