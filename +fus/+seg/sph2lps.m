function [l,p,s] = sph2lps(th, phi, r)
    % SPH2LPS converts from spherical coordinates to LPS coordinates
    %   [l,p,s] = fus.seg.sph2lps(th, phi, r)
    %
    % Input:
    %   th (double): Azimuthal Angle (towards patient left from nose line)
    %   phi (double): Elevation Angle (above eye line)
    %   r (double): Radial Distance
    %
    % Returns:
    %   l (double): Left Position
    %   p (double): Posterior Position
    %   s (double): Superior Position
    [l,p,s] = sph2cart(deg2rad(th-90), deg2rad(phi), r);
end
