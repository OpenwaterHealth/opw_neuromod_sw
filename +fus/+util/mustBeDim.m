function mustBeDim(dims, obj_with_dims)
    if any(~ismember(dims, obj_with_dims.dims))
        error('mustBeDim:NotDim', 'Invalid dimension. Must be from {"%s"}', join([obj_with_dims.dims],'","'));
    end
end