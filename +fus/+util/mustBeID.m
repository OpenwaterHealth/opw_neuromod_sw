function mustBeID(id, obj_with_id)
    if ~all(ismember(id, [obj_with_id.id]))
        error('mustBeID:NotID', 'Invalid ID. Valid IDs are {"%s"}', join([obj_with_id.id],'","'));
    end
end