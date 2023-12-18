function type = getunittype(unit)
    arguments
        unit (1,:) char
    end
    unit = lower(unit);
    switch lower(unit)
        case {'micron','microns'}
            type = 'distance';
        case {'minute','minutes','min','mins','hour','hours','hr','hrs','day','days','d'}
            type = 'time';
        case {'rad','deg','radian','radians','degree','degrees',sprintf('\272')}
            type = 'angle';
        otherwise
            if contains(unit,'sec')
                type = 'time';
            elseif contains(unit,'meter')
                type = 'distance';
            elseif contains(unit,'micron')
                type = 'distance';    
            elseif endsWith(unit,'s')
                type = 'time';
            elseif endsWith(unit,'m')
                type = 'distance';
            elseif endsWith(unit, "m2") || endsWith(unit,"m^2")
                type = 'area';
            elseif endsWith(unit, "m3") || endsWith(unit,"m^3")
                type = 'volume';
            elseif endsWith(unit, "hz")
                type = 'frequency';
            else
                type = 'other';
                %error('unkown unit %s',unit);
            end
    end
end
