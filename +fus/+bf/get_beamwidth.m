function res = get_beamwidth(vol, focus, cutoff, options)
    arguments
        vol (1,1) fus.Volume
        focus (1,1) fus.Point
        cutoff (1,1) double
        options.units (1,1) string {fus.util.mustBeDistance} = focus.units;
        options.dims (1,:) double {mustBeInteger} = [1,2]
        options.mask logical = []
        options.hulls (1,1) logical = false
        options.points (1,1) logical = false
        options.masks (1,1) logical = false
        options.simplify_hulls (1,1) logical = true;
    end
    coords = vol.get_coords();
    coords = coords.rescale(options.units);
    if isempty(options.mask)
        search_mask = true([coords.length]);
    else
        search_mask = options.mask;
    end
    ngrid0 = coords.ndgrid("units", options.units);
    mdata = search_mask.*vol.data;
    inlier_mask = mdata>cutoff;
    ogrid = fus.bf.offset_grid(coords, focus, "units", "mm");
    omask = cellfun(@(x)x(inlier_mask),ogrid, "UniformOutput", false);
    inlier_points = cellfun(@(x)double(x(inlier_mask)), ngrid0, 'UniformOutput', false);
    try
        inlier_hull = convhull(inlier_points{:},"simplify", options.simplify_hulls);
    catch me
        switch me.identifier
            case 'MATLAB:convhull:EmptyConvhull3DErrId'
                %warning('invalid inliers, attempting to add jitter to create a valid volume...')
                dx = mean(diff([coords.extent{:}])./(coords.length-1));        
                inlier_points = cellfun(@(x)x+(rand(size(x))-0.5)*dx/2, inlier_points, 'UniformOutput', false);
                inlier_hull = convhull(inlier_points{:},"simplify", options.simplify_hulls);
            case 'MATLAB:convhull:NotEnoughPtsConvhullErrId'
                    res = struct(...
                        "dims", options.dims, ...
                        "beamwidth", nan, ...
                        "units", options.units);
                    if options.masks
                        res.inlier_mask = nan;
                        res.fit_mask = nan;
                    end
                    if options.points || options.hulls
                        res.inlier_points = nan;
                        res.fit_points = nan;
                    end
                    if options.hulls
                        res.inlier_hull = nan;
                        res.fit_hull = nan;
                    end
                    return
            otherwise
                rethrow(me)
        end
    end
    hull_indices = unique(inlier_hull(:));
    hull_points = cellfun(@(x)x(hull_indices), omask, "UniformOutput", false);
    omat = cellfun(@(x)x-x',hull_points, "UniformOutput", false);    
    dists = sqrt(sum((cell2mat(reshape(omat(options.dims),1,1,1,[]))).^2,4));
    beamwidth = max(dists,[],"all");
    d_dims = sqrt(sum((cell2mat(reshape(ogrid(options.dims), 1,1,1,[]))).^2,4));
    fit_mask = d_dims<=beamwidth/2;
    res = struct(...
        "dims", options.dims, ...
        "beamwidth", beamwidth, ...
        "units", options.units);
    if options.masks
        res.inlier_mask = inlier_mask;
        res.fit_mask = fit_mask;
    end
    if options.points || options.hulls
        res.inlier_points = inlier_points;
        res.fit_points = cellfun(@(x)x(fit_mask),ngrid0, "UniformOutput", false);
    end
    if options.hulls
        res.inlier_hull = inlier_hull;
        res.fit_hull = convhull(res.fit_points{:},"simplify", options.simplify_hulls);
    end
end