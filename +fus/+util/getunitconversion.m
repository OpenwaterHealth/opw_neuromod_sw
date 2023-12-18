function scl = getunitconversion(from_unit,to_unit,unitratio,constant)
%GETUNITCONVERSION get SI unit conversion factors
%scl = getunitconversion(from_unit,to_unit);
%scl = getunitconversion(from_unit,to_unit,unitratio,constant);
%
%GETUNITCONVERSION returns a scaling factor that can be multiplied by
%values with units from_unit to get values in units of to_unit. With two
%inputs, from_unit and to_unit must be the same type. With 4 inputs, a
%conversion ratio and value specify the constant that links the two unlike
%types.
%
%INPUTS:
%   from_unit: String or char array containing source SI-prefixed unit
%   to_unit: String or char array containing destination SI-prefixed unit
%   [unitratio]: string containing coversion ratio units i.e. 'm/s'
%   [constant]: numeric conversion i.e. 1540
%
%OUTPUT:
%   scl: scaling value to multiply by values in units of from_unit to get
%       units of to_unit.
%
% Currently supported units include:
%   -Linear distance (m,meter,micron)
%   -Angles (deg,rad,degree,radian,� (sprintf('\272')) )
%   -Time (sec,second,min,minute,hr,hour,day)
% Also supported are
%   -plurals (meters,seconds,degrees)
%   -SI letter prefixes (mm,ms,km)
%   -SI text prefixes (microseconds,kilometer,Terameters)
%   -multiple representations of greek mu (\mu,u,� (sprintf('\265') )
%   -ratios separated by '/' (m/s,km/hour,rad/s)
import fus.util.*
if ~(nargin==2 || nargin==4)
    error('incorrect number of input arguments')
end
if isempty(from_unit)
    scl = 1;
    return
end
if nargin==4
    slashr = strfind(unitratio,'/');
    from_unit = char(from_unit); %convert string to char array
    to_unit = char(to_unit); %convert string to char array
    if (contains(from_unit,'/') || contains(to_unit,'/'))
        error('ratios of ratios not supported.')
    end
    if isempty(slashr)
        error('conversion unit ratio must have a ''/'' symbol')
    end
    unitn = unitratio(1:slashr-1);
    unitd = unitratio(slashr+1:end);
    type0 = getunittype(from_unit);
    type1 = getunittype(to_unit);
    typen = getunittype(unitn);
    typed = getunittype(unitd);
    if strcmp(type0,typed) && strcmp(type1,typen)
        scl = getunitconversion(from_unit,unitd) * constant * getunitconversion(unitn,to_unit);
    elseif strcmp(type0,typen) && strcmp(type1,typed)
        scl = getunitconversion(from_unit,unitn) * 1/constant * getunitconversion(unitd,to_unit);
    elseif strcmp(type0,type1)
        scl = getunitconversion(from_unit,to_unit);
    else
        error('unit type mismatch %s -> (%s/%s) -> %s',type0,typen,typed,type1);
    end
else
    from_unit = char(from_unit); %convert string to char array
    to_unit = char(to_unit); %convert string to char array
    slash0 = strfind(from_unit,'/');
    slash1 = strfind(to_unit,'/');
    if length(slash0)==1 && length(slash1)==1
        num0 = from_unit(1:slash0-1);
        denom0 = from_unit(slash0+1:end);
        num1 = to_unit(1:slash1-1);
        denom1 = to_unit(slash1+1:end);
        scl = getunitconversion(num0,num1)/getunitconversion(denom0,denom1);
    elseif isempty(slash0) && isempty(slash1)
        type0 = getunittype(from_unit);
        type1 = getunittype(to_unit);
        if ~strcmpi(type0,type1)
            error('unit type mismatch (%s vs %s).',type0,type1);
        end
        if strcmp(type0,'other')
            if ~strcmp(from_unit(end),to_unit(end))
                error('cannot convert %s to %s',from_unit,to_unit);
            end
            i = 0;
            while (i< min(length(from_unit),length(to_unit))) && strcmp(from_unit(end-i:end),to_unit(end-i:end)) 
                type = from_unit(end-i:end);
                i = i+1;
            end
            scl0 = getsiscale(from_unit,type);
            scl1 = getsiscale(to_unit,type);
            scl = scl0/scl1;
        else    
            scl0 = getsiscale(from_unit,type0);
            scl1 = getsiscale(to_unit,type0);
            scl = scl0/scl1;
        end
    else
        error('unit ratio mismatch (%s vs %s).',from_unit,to_unit);
    end
end
end

function scl = getsiscale(unit,type)
    switch type
        case {'distance','area','volume'}
            idx = strfind(unit,'meters');
            if isempty(idx)
                idx = strfind(unit,'meter');
                if isempty(idx)
                    if strcmpi(unit,'micron') || strcmpi(unit,'microns')
                        idx = 6;
                    else
                        idx = strfind(unit,'m');
                        if isempty(idx)
                            idx = length(unit)+1;
                        end
                    end
                end
            end
        case 'time'
            idx = strfind(unit,'seconds');
            if isempty(idx)
                idx = strfind(unit,'second');
                if isempty(idx)
                    idx = strfind(unit,'sec');
                    if isempty(idx)
                        idx = strfind(unit,'s');
                        if isempty(idx)
                            idx = length(unit)+1;
                        end
                    end
                end
            end
        case 'angle'
            idx = length(unit)+1;
        case 'frequency'
            idx = length(unit)-1;
        otherwise
            idx = length(unit)-length(type)+1;
    end
    idx = idx(end);
    prefix = unit(1:idx-1);
    if isempty(prefix)
        scl = 1;
    else
        switch prefix
            case {'pico','p'}
                scl = 1e-12;
            case {'nano','n'}
                scl = 1e-9;
            case {'micro','u','\mu',sprintf('\265')}
                scl = 1e-6;
            case {'milli','m'}
                scl = 1e-3;
            case {'centi','c'}
                scl = 1e-2;
            case {'',[]}
                scl = 1;
            case {'kilo','k'}
                scl = 1e3;
            case {'mega','M'}
                scl = 1e6;
            case {'giga','G'}
                scl = 1e9;
            case {'tera','T'}
                scl = 1e12;
            case {'min','minute'}
                scl = 60;
            case {'hour','hr'}
                scl = 60*60;
            case {'day','d'}
                scl = 60*60*24;
            case {'rad','radian','radians'}
                scl = 1;
            case {'deg','degree','degrees',sprintf('\272')}
                scl = 2*pi/360;
            otherwise
                if isempty(prefix)
                    scl = 1;
                else
                    error('unkown prefix %s',prefix);
                end
        end
    end
    switch type
        case 'area'
            scl = scl^2;
        case 'volume'
            scl = scl^3;
    end        
end
