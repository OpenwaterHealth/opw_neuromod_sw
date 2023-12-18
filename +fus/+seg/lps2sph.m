function [th, phi, r] = lps2sph(l,p,s)
    % LPS2SPH converts from LPS to spherical coordinates
    %   [th, phi, r] = fus.seg.lps2sph(l,p,s)
    %
    % Input:
    %   l (double): Left Position
    %   p (double): Posterior Position
    %   s (double): Superior Position
    %
    % Returns:
    %   th (double): Azimuthal Angle (towards patient left from nose line)
    %   phi (double): Elevation Angle (above eye line)
    %   r (double): Radial Distance
    [th, phi, r] = cart2sph(l,p,s);
    th = rad2deg(th)+90;
    phi = rad2deg(phi);
end