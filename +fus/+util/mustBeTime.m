function mustBeTime(units)
    if ~isempty(char(units)) && ~isequal(fus.util.getunittype(units), "time")
        error('mustBeTime:NotTime', 'Must be a unit of time');
    end
end