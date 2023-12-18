function Trans = compute_trans(array, options)
    arguments
        array fus.xdc.Transducer
        options.connType (1,1) double {mustBeInteger, mustBeInRange(options.connType, -1,11)} = 1
    end
    array = array.rescale("mm");
    xyz = array.elements.get_position();
    [az, el] = array.elements.get_angle("units", "rad");
    [w, l] = array.elements.get_size();
    position = [xyz;az;el]';
    th = (-pi/2:pi/100:pi/2);
    th(51) = 0.0000001; % set to almost zero to avoid divide by zero.
    avg_el_size = mean([[array.elements.w];[array.elements.l]],'all');
    x_sens = avg_el_size*pi*sin(th);
    sensitivity = abs(cos(th)).*(sin(x_sens)./x_sens);
    if isfield(array.attrs, "vsx")
        attrs = fus.util.merge_struct(options, array.attrs.vsx, 'add');
    else
        attrs = options;
    end
    if all(isfield(attrs, ["Z_MHz", "Z_re", "Z_im"]))
        attrs.impedance = [attrs.Z_MHz, attrs.Z_re+1i*attrs.Z_im];
        attrs = rmfield(attrs, ["Z_MHz", "Z_re", "Z_im"]);
    end
    args = fus.util.struct2args(attrs);
    Trans = struct(...
        "name", char(array.name), ...
        "units", 'mm', ...
        "id", -1, ... % NOT the same as the string ID
        "frequency", array.frequency/1e6, ...
        "type", 2, ...
        "numelements", array.numelements(), ...
        "ElementPos", position, ...
        "elementWidth", mean(w), ...
        "elementLength", mean(l), ...
        "ElementSens", sensitivity, ...
        "ConnectorES", [array.elements.pin]', ...
        args{:});
end