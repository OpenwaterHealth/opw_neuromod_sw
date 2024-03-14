function [skin_lps, skin_sph, vsph] =  detect_skin(vol, options)
    % DETECT_SKIN detect the skin surface within a volume
    %   [skin_lps, skin_sph, vsph] =  fus.seg.detect_skin(vol, "param", value, ...)
    %
    % Inputs:
    %   vol (fus.Volume): Volume to detect skin surface in
    %
    % Optional Parameters:
    %   'skin_thresh' (double): Threshold for skin detection relative to maximum. Default 0.3
    %   'max_percentile' (double): Percentile to use as maximum for threshold computation. Default 0.99
    %   'th_min' (double): Minimum azimuth angle in degrees. Default -180
    %   'th_max' (double): Maximum azimuth angle in degrees. Default 180
    %   'th_spacing' (double): Spacing of azimuth angles in degrees. Default 1
    %   'phi_min' (double): Minimum elevation angle in degrees. Default 0
    %   'phi_max' (double): Maximum elevation angle in degrees. Default 90
    %   'phi_spacing' (double): Spacing of elevation angles in degrees. Default 1
    %   'r_min' (double): Minimum radial distance in mm. Default 0
    %   'r_max' (double): Maximum radial distance in mm. Default 150
    %   'r_spacing' (double): Spacing of radial distances in mm. Default 1
    %   'medfile' (double): median filter size. Deafult 1
    %   'smooth' (logical): Whether to smooth the skin surface using a bicubic spline. Default false
    %   'smooth_opts' (struct): Options for smoothing. See fus.seg.bicubic_fit. Default struct('n',17,'lower', 50,'upper', 150, 'startpoint', 100, 'robust',true)
    %   'units' (string): Units of radial distance. Default "mm"
    %   'vectorize' (logical): Whether to vectorize the output. Default false
    %   'log' (fus.util.Logger): fus.util.Logger instance. Default fus.util.Logger.get()
    %
    % Returns:
    %   skin_lps (cell): Cell array of [x,y,z] coordinates of skin surface in LPS coordinates
    %   skin_sph (cell): Cell array of [th,phi,r] coordinates of skin surface in spherical coordinates
    arguments
        vol fus.Volume
        options.skin_thresh (1,1) double {mustBeInRange(options.skin_thresh, 0,1)} = 0.3;
        options.max_percentile (1,1) double {mustBeInRange(options.max_percentile, 0, 1)} = 0.99;
        options.th_min (1,1) double = -180;
        options.th_max (1,1) double = 180
        options.th_spacing (1,1) double {mustBePositive} = 1;
        options.phi_min (1,1) double = 0;
        options.phi_max (1,1) double = 90
        options.phi_spacing (1,1) double {mustBePositive} = 1;
        options.r_min (1,1) double = 0;
        options.r_max (1,1) double = 150
        options.r_spacing (1,1) double {mustBePositive} = 1;
        options.medfilt (1,1) double {mustBeInteger, mustBePositive} = 1;
        options.smooth (1,1) logical = false;
        options.smooth_opts (1,1) struct = struct(...
                'n',17, ...
                'lower', 50,...
                'upper', 150, ...
                'startpoint', 100, ...
                'robust',true);
        options.units (1,1) string = "mm"
        options.vectorize (1,1) logical = false
        options.log fus.util.Logger = fus.util.Logger.get()
    end
    th = options.th_min:options.th_spacing:options.th_max;
    phi = options.phi_min:options.phi_spacing:options.phi_max;
    r = options.r_min:options.r_spacing:options.r_max;
    TPR = cell(1,3);
    [TPR{:}] = ndgrid(th,phi,r);
    LPS = cell(1,3);
    [LPS{:}] = sph2cart(deg2rad(TPR{1}-90), deg2rad(TPR{2}), TPR{3});
    data = vol.interp(LPS{:});
    coords = [...
        fus.Axis(th,"th","name","Azimuth","units",""),...
        fus.Axis(phi,"phi","name","Elevation","units",""),...
        fus.Axis(r,"r","name","Radial","units","")];
    vsph = fus.Volume(data, coords);
    x = vsph.isel('r',1).coords.ndgrid();
    sz = vsph.shape;
    top_skin_raw_idx = nan(sz([1 2]));
    thresh = vsph.percentile(options.max_percentile)*options.skin_thresh;
    for i = 1:sz(1)
        for j = 1:sz(2)
            k = find(data(i,j,:)>thresh, 1, 'last');
            if ~isempty(k)
                top_skin_raw_idx(i,j) = k;
            end
        end
    end
    msk = ~isnan(top_skin_raw_idx);
    top_skin_raw = r(top_skin_raw_idx(msk));
    top_skin = nan(sz(1:2));
    top_skin(msk) = top_skin_raw;
    if options.medfilt > 1
        if any(isnan(top_skin))
            f = @fus.seg.nanmedfilt2;
        else
            f = @(x, sz)medfilt2(x, sz, "symmetric");
        end
         top_skin = f(top_skin, options.medfilt*[1,1]);
    end
    if options.smooth
        options.log.info("Fitting to spline...");
        args = fus.util.struct2args(options.smooth_opts);
        top_skin_fit = fus.seg.bicubic_fit(...
            x{1}(msk),...
            x{2}(msk), ...
            top_skin_raw, ...
            args{:});    
        top_skin = reshape(top_skin_fit(x{1:2}), size(x{1}));
    end
    skin_lps = cell(1,3);
    [skin_lps{:}] = sph2cart(deg2rad(x{1}-90),deg2rad(x{2}),top_skin);
    skin_sph = {x{1}, x{2}, top_skin};
    if options.vectorize
        skin_lps = cellfun(@(x)x(:),skin_lps, "UniformOutput", false);
        skin_sph = cellfun(@(x)x(:),skin_sph, "UniformOutput", false);
    end 
end