function mustBeFrequency(units)
    if ~isempty(char(units)) && ~isequal(fus.util.getunittype(units), "frequency")
        error('mustBeFrequency:NotFrequency', 'Must be a unit of frequency');
    end
end