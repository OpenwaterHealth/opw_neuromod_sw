function h = draw_transform(matrix, options)
arguments
    matrix (4,4) double
    options.?matlab.graphics.chart.primitive.Surface
    options.length = 3;
    options.head_length = 1;
    options.width = 0.5;
    options.n_theta = 8;
    options.brim_width = 0.25;
    options.colors = ["r","g","b"];
end    
vector_length = options.length;
th = linspace(0, 2*pi, options.n_theta+1)';
radius = options.width/2;
head_length = min(vector_length/2, options.head_length);
stem_length = vector_length - head_length;
x = [0 0 stem_length stem_length, vector_length];
r = [0 radius radius radius+options.brim_width, 0];
x = repmat(x,size(th,1),1);
y = r.*cos(th);
z = r.*sin(th);
xyz = {x,y,z};
xyz1 = cell2mat(cellfun(@(x)x(:), xyz, 'UniformOutput', false))';
sopts = rmfield(options, ["length", "head_length", "width", "brim_width", "colors", "n_theta"]);
for i = 1:3
    xyzi = [circshift(xyz1,i-1,1);ones(1,numel(x))];
    xyzt = matrix*xyzi;
    sopts.FaceColor = options.colors(i);
    sargs = fus.util.struct2args(sopts);
    h(i) = surf(...
        reshape(xyzt(1,:),size(x)), ...
        reshape(xyzt(2,:),size(y)), ...
        reshape(xyzt(3,:),size(z)), ...
        sargs{:});
    hold all;
end