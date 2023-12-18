function varargout = fit_to_skin(th, phi, skin_sph, options)
    % FIT_TO_SKIN Get virtual instrument position on skin
    %   inst_matrix = fit_to_skin(th, phi, skin_sph)
    %   inst_matrix = fit_to_skin(th, phi, skin_sph, 'param', value, ...)
    %   [inst_matrix, results] = get_inst_matrix(th, phi, skin_sph, ...)
    %
    % FIT_TO_SKIN takes a segmentation of the surface of the skin in
    % spherical coordinates (obtained via DETECT_SKIN), as well as an 
    % azimuthal angle theta and an elevation angle phi. It finds the point
    % on the surface of the skin at that angular position, and estimates
    % where a physical transducer would lie relative to that point. An
    % optional offset matrix can be provided to transform the instrument
    % position based on a standoff, otherwise the mattrix positions the 
    % transducer normal to the skin surface at the point of contact.
    %
    % Inputs:
    %   th (double): angle in degrees towards the patient's left ear, where
    %      0 is straight ahead and 90 is directly to the patients' left.
    %   phi (double): angle in degrees above the horizontal plane, where 0
    %      is the patient's eye line and 90 is the crown of the head.
    %   skin_sph (1,3) cell: cell array containing the spherical
    %      coordinates of the skin surface, as returned by DETECT_SKIN.
    %
    % Optional Parameters:
    %   'offset_matrix' (4,4) double: matrix to transform the instrument
    %       position based on a standoff. If not provided, the identity
    %       matrix is used.
    %   'search_x' (double): half-width of the search grid in the lateral
    %       direction, in mm. Default is 20.
    %   'search_dx' (double): step size of the search grid in the lateral
    %       direction, in mm. Default is 1.
    %   'search_y' (double): half-width of the search grid in the
    %       elevation direction, in mm. Default is 20.
    %   'search_dy' (double): step size of the search grid in the
    %       elevation direction, in mm. Default is 1.
    %
    % Outputs:
    %   inst_matrix (4x4 double): matrix to transform the instrument
    %       position to the desired location on the skin surface.
    %   results (struct): struct containing the intermediate computation data
    arguments
        th double
        phi double
        skin_sph (1,3) cell
        options.offset_matrix (4,4) double = eye(4);
        options.search_x = 20
        options.search_dx = 1
        options.search_y = 20
        options.search_dy = 1
    end
    import fus.seg.lps2sph
    import fus.seg.sph2lps
    SEARCH_X = options.search_x;
    SEARCH_DX = options.search_dx;
    SEARCH_Y = options.search_y;
    SEARCH_DY = options.search_dy;
    % find point on skin surface
    skin_vec = cellfun(@(x)x(:), skin_sph, "UniformOutput", false);
    interpolant = scatteredInterpolant(skin_vec{:});
    r = interpolant(th, phi);
    [l,p,s] = sph2lps(th, phi, r);
    origin = [l;p;s];
    % set up local unit vectors for ROI definition
    roi_uv = cell(1,3);
    roi_uv{3} = -origin;
    roi_uv{3} = roi_uv{3}/norm(roi_uv{3},2);
    [l1, p1, s1] = sph2lps(th-1, phi, r);
    roi_uv{1} = [l1;p1;s1]-origin;
    roi_uv{1} = roi_uv{1} - roi_uv{3}*dot(roi_uv{1},roi_uv{3});
    roi_uv{1} = roi_uv{1}/norm(roi_uv{1},2);
    roi_uv{2} = cross(roi_uv{3},roi_uv{1});
    roi_matrix = [cell2mat(roi_uv) origin; zeros(1,3) 1];
    roi_forward_matrix = (roi_matrix.'*roi_matrix)\roi_matrix.';
    % define search grid in local coords
    dx = -SEARCH_X:SEARCH_DX:SEARCH_X;
    dy = -SEARCH_Y:SEARCH_DY:SEARCH_Y;
    [DX,DY] = ndgrid(dx,dy);
    roi_grid = mat2cell(reshape([l,p,s],[1,1,3]) + reshape(roi_uv{1},[1,1,3]).*DX + reshape(roi_uv{2},[1,1,3]).*DY, length(dx), length(dy), ones(1,3));
    % convert search grid to pitch-yaw
    roi_pgrid = cell(1,3);
    [roi_pgrid{:}] = lps2sph(roi_grid{:});
    % get surface grid
    surf_pgrid = roi_pgrid;
    surf_pgrid{3} = interpolant(roi_pgrid{1},roi_pgrid{2});
    surf_lps = cell(1,3);
    [surf_lps{:}] = sph2lps(surf_pgrid{:});
    % get surface grid in local coords
    surf_lps_vec = cell2mat(cellfun(@(x)x(:), surf_lps, 'UniformOutput', false));
    surf_lps_vec = [surf_lps_vec ones(size(surf_lps_vec,1),1)]';
    surf_xyz = roi_forward_matrix*surf_lps_vec;
    % fit local surfact to plane
    plane_fit = [surf_xyz(1,:)' surf_xyz(2,:)']\surf_xyz(3,:)';
    % get plane-fit unit vectors and convert to LPS
    plane_matrix_xyz = [[1;0;plane_fit(1)] [0;1;plane_fit(2)]];
    plane_matrix_xyz = plane_matrix_xyz ./ vecnorm(plane_matrix_xyz, 2, 1);
    plane_matrix_xyz(:,3) = cross(plane_matrix_xyz(:,1), plane_matrix_xyz(:,2));
    plane_matrix = roi_matrix(1:3,1:3)*plane_matrix_xyz;
    plane_matrix = [[plane_matrix;zeros(1,3)] roi_matrix(:,4)];
    inst_matrix = plane_matrix * options.offset_matrix;
    inst_forward_matrix = (inst_matrix.'*inst_matrix)\(inst_matrix.');
    if nargout > 0
        varargout{1} = inst_matrix;
    end
    if nargout > 1
        results = struct(...
            'surface_point', origin(:), ...
            'th', th, ...
            'phi', phi, ...
            'r', r, ...
            'roi_matrix', roi_matrix, ...
            'surface', {surf_lps}, ...
            'plane_fit', plane_fit, ...
            'plane_matrix', plane_matrix, ...
            'inst_matrix', inst_matrix, ...
            'inst_forward_matrix', inst_forward_matrix);
        varargout{2} = results;
    end
end


