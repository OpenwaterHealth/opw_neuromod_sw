function results = detect_blocked_elements(vol, trans, target, options)
    arguments
        vol (1,1) fus.Volume
        trans fus.xdc.Transducer
        target (1,1) fus.Point
        options.skin_thresh (1,1) double = .5
        options.air_thresh (1,1) double = 0.1
        options.clim double = []
        options.r_step (1,1) double = 0.5
        options.bg_roi (1,1) double = 1;
        options.fg_roi (1,1) double = 2;
    end
    ele_pos = trans.get_positions("units","mm");
    t_pos = target.get_position("units", "mm");
    dists = vecnorm(t_pos-ele_pos, 2, 1);
    uvs = (t_pos-ele_pos) ./ dists;
    dr = options.r_step;
    n = ceil(dists/dr);
    nr = max(n);
    r = (0:nr-1)*dr;
    nvec = permute(r,[1,3,2]);
    ray_pos = ele_pos(1:3,:) + uvs.*nvec;
    ray_pos = squeeze(mat2cell(permute(ray_pos, [3, 2, 1]), size(ray_pos,3), size(ray_pos,2), ones(1,3)));
    rays = vol.interp(ray_pos{:}, "transform", true, "units", "mm");
    if ~isempty(options.clim)
        bg = options.clim(1);
        fg = options.clim(2);
    else
        bg = median(rays(1:round(options.bg_roi/dr),:),'all','omitnan');
        fg = fus.util.percentile(...
            reshape(rays(end-round(options.fg_roi/dr):end,:),[],1), 90);
    end
    rays_norm = (rays - bg) / (fg - bg);
    sinus_map = zeros(size(rays_norm));
    scatter_vals = rays_norm;
    for ele = 1:trans.numelements
        skin_start = find(rays_norm(:,ele) > options.skin_thresh, 1, 'first');
        if ~isempty(skin_start)
            skin_boundary(ele) = skin_start * dr;
            sinus_map(skin_start:end,ele) = rays_norm(skin_start:end,ele)<options.air_thresh;    
            ele_blocked(ele) = any(sinus_map(:,ele));
        else
            skin_boundary(ele) = nan;
            ele_blocked(ele) = nan;
        end
        scatter_vals(round(dists(ele)/dr):end,ele) = nan;
    end
    scatter_pos = cellfun(@(x)x(~isnan(scatter_vals)), ray_pos, 'UniformOutput', false);
    scatter_blocked = sinus_map(~isnan(scatter_vals));
    R = repmat(r(:), 1, trans.numelements);
    scatter_R = R(~isnan(scatter_vals));
    scatter_vals = scatter_vals(~isnan(scatter_vals));
    n_blocked = sum(ele_blocked(~isnan(ele_blocked)));
    
    results = struct(...
        'vol', rays_norm, ...
        'vol_pos', {ray_pos}, ...
        'scatter_vals', scatter_vals, ...
        'scatter_pos', {scatter_pos}, ...
        'scatter_blocked', scatter_blocked, ...
        'scatter_R', scatter_R, ...
        'skin_boundary', skin_boundary, ...
        'sinus_map', sinus_map, ...
        'ele_blocked', ele_blocked, ...
        'n_blocked', n_blocked, ...
        'n', trans.numelements);
end