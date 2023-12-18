function args = struct2args(s)
    % STRUCT2ARGS convert structure to cell
    %
    % USAGE:
    %   args = struct2args(s)
    %
    % STRUCT2ARGS turns a structure into a cell array of arguments to feed
    % into a function that accepts varargin key, value pairs. 
    %
    % INPUTS:
    %   s: [struct] input structure
    %
    % OUPUTS:
    %   args: [cell] array of arguments. Assign as varargin with 
    %       function_with_varargin(..., args{:})
    %
    
    
    % struct2args(struct('foo',1, 'bar', 2))
    % ans =
    %    1×4 cell array
    %   {'foo'}    {[1]}    {'bar'}    {[2]}
    %
    fn = fieldnames(s);
    args = cell(1,length(fn)*2);
    for i = 1:length(fn)
        args{2*i-1} = fn{i};
        args{2*i} = s.(fn{i});
    end
end