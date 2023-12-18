function cmap = mustBeStringOrColorMapper(cmap)
    if isa(cmap, "fus.ColorMapper")
       return
    elseif isa(cmap, "string") || isa(cmap, "char")
        return
    elseif isnumeric(cmap) && ismatrix(cmap) && size(cmap,2) == 3
        return
    else
        error('mustBeStringOrColorMapper:InvalidColorMapper', "Must be a ColorMapper or a colormap string");
    end
end