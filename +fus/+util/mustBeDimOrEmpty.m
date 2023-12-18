function mustBeDimOrEmpty(dim, obj_with_dims)
    if isequal(dim, "") || isempty(dim)
       return
    end
    if ~ismember(dim, obj_with_dims.dims)
        error('mustBeDimOrEmpty:NotDimOrEmpty', 'Invalid dimension. Must be "" or one of {"%s"}', join([obj_with_dims.dims],'","'));
    end
end