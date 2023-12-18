function mustBeAxes(ax)
    if ~isa(ax,"matlab.ui.control.UIAxes") && ~isa(ax,"matlab.graphics.axis.Axes")
        error("mustBeAxes:NotAxes", "Not an Axes or UIAxes Object");
    end
end