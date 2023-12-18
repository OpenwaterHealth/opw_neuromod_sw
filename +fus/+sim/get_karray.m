function karray = get_karray(array, options)
    % GET_KARRAY Convert fus.xdc.Transducer into kWaveArray
    arguments
        array fus.xdc.Transducer % Transducer object
        options.BLITolerance (1,1) double {mustBePositive} = 0.05 % Scalar value controlling where the spatial extent of the BLI at each point is trunctated as a portion of the maximum value
        options.UpsamplingRate (1,1) double {mustBeInteger, mustBePositive} = 5
        options.SinglePrecision (1,1) logical {mustBeNumericOrLogical} = true
        options.translation (1,3) double = [0,0,0]
        options.rotation (1,3) double = [0,0,0]
    end
    karray_options = struct();
    valid_options = {'BLITolerance', 'UpsamplingRate','SinglePrecision'};
    for i = 1:length(valid_options)
        karray_options.(valid_options{i}) = options.(valid_options{i});
    end
    args = fus.util.struct2args(karray_options);
    karray = kWaveArray(args{:});
    prev_units = array.units;
    array.rescale("m");
    for i = 1:array.numelements
        karray.addRectElement(...
            array.elements(i).get_position', ...
            array.elements(i).w, ...
            array.elements(i).l, ...
            [rad2deg(array.elements(i).el), rad2deg(array.elements(i).az) rad2deg(array.elements(i).roll)]);        
    end
    karray.setArrayPosition(options.translation, options.rotation);
    array.rescale(prev_units);
end