function mustBeDistance(units)
    if ~isempty(char(units)) && ~isequal(fus.util.getunittype(units), "distance")
        error('mustBeDistance:NotDistance', 'Must be a unit of distance');
    end
end