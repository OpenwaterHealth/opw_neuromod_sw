function medium = get_acoustic_medium(params, varargin)
    % GET_ACOUSTIC_MEDIUM Construct kWave medium structure
    % get_acoustic_medium(params, options)
    % Constructs the kWave medium structure from the acoustic parameters.
    %
    % INPUTS
    %   params: acoustic parameters structure
    %   options: optional argument structure. Available fields include:
    %       alpha_power: coefficient for attenuation (default 0.9)
    %
    % OUTPUTS
    %   medium: struct containing medium data

    % Version History
    % Created 2022-06-09
    options = struct('alpha_power', 0.9);
    options = fus.util.parseargs('skip', options, varargin{:});
    param_map = struct('sound_speed', 'sound_speed',...
                       'density', 'density', ...
                       'alpha_coeff', 'attenuation');
    target_params = fieldnames(param_map);
    param_ids = [params.id];
    for i = 1:length(target_params)
        target_param = target_params{i};
        source_param = param_map.(target_param);
        if ismember(source_param, param_ids)
            medium.(target_param) = params(param_ids == source_param).data;
        else
            error('Parameter %s not found', source_param);
        end
    end
    medium.alpha_power = options.alpha_power;
end