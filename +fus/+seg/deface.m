function defaced_vol = deface(vol, options)
    % DEFACE Deface a volume
    %   defaced_vol = fus.seg.deface(vol, "param", value, ...)
    %
    % DEFACE used a segmented linear model to deface a volume. Defaced voxels
    % are set to NaN. The deface model masks voxels in the S-P plane based on 
    % their distance from the nasion. The nasion is detected along the S=0, L=0
    % line if not provided as an option. The masking is piecewise linear, with
    % the first piece being a line with slope -0.4 and intercept 0. The second
    % piece is a line with slope -4 and intercept 0. The two pieces are joined
    % at a point offset from the nasion. In additional to masking the face, all
    % voxels outside of a sphere centered at (0,0,0) are masked.
    %
    % Inputs:
    %   vol (fus.Volume): volume to deface
    %
    % Optional Parameters:
    %   'nasion' (1x3 double): nasion location
    %   'skin_thresh_pct' (double): percentage of max skin value to use as. Default: 0.15
    %   'radius' (double): radius of deface sphere. Default: 130
    %   's_offset' (double): superior offset of sphere center from nasion. Default: -10
    %   'p_offset' (double): posterior offset of sphere center from nasion. Default: 30
    %   'units' (string): units of radius, s_offset, and p_offset. Default: "mm"
    %
    % Returns:
    %   defaced_vol (fus.Volume): defaced volume
    arguments
        vol (1,1) fus.Volume
        options.nasion (1,3) double
        options.skin_thresh_pct (1,1) double {mustBeInRange(options.skin_thresh_pct, 0, 1)} = 0.15;
        options.radius = 130
        options.s_offset = -10;
        options.p_offset = 30;
        options.units (1,1) string {fus.util.mustBeDistance} = "mm";
    end
    defaced_vol = vol.copy();
    defaced_vol.rescale(options.units);
    X = defaced_vol.ndgrid('transform', true);    
    R = vecnorm(cell2mat(reshape(X,1,1,1,[])),2,4);
    defaced_vol.data(R>130) = nan;
    if ~isfield(options, "nasion")
        edges = defaced_vol.get_edges("transform", true);
        p_min = min(edges{2},[],'all');
        p_max = max(edges{2},[],'all');
        p_vec = p_min:p_max;
        l_vec = zeros(size(p_vec));
        s_vec = zeros(size(p_vec));
        profile = defaced_vol.interp(l_vec, p_vec, s_vec, "transform", true);
        index = find(...
            profile(1:end-1)>max(profile)*options.skin_thresh_pct & ...
            diff(profile)>0 , 1, 'first');
        nasion = [l_vec(index); p_vec(index); s_vec(index); 1];
    else
        nasion = options.nasion;
    end
    S = (X{3}-nasion(3)-options.s_offset);
    P = (X{2}-(nasion(2)+options.p_offset));
    mask = (S>0) & (S < -0.4*P);
    mask((S<0) & (S<-4*P)) = 1;
    defaced_vol.data(mask) = nan;

end