function f = bicubic_fit(x,y,data,options)
    % BICUBIC_FIT fits a bicubic spline to data
    %   f = fus.seg.bicubic_fit(x,y,h, "param", value, ...)
    %
    %   BICUBIC_FIT fits a bicubic spline to the data (x,y,h)
    %   where x and y are the independent variables and h is the dependent
    %   variable. The function returns a fit object f. The fit is defined by 
    %   a grid of knots in x and y.
    %
    % Inputs:
    %   x (double): x position values
    %   y (double): y position values
    %   h (double): data values
    %
    % Optional Parameters:
    %   'n' (double): number of knots in x and y (default: 3)
    %   'lower' (double): lower bound for the fit parameters
    %   'upper' (double): upper bound for the fit parameters
    %   'startpoint' (double): starting point for the fit parameters
    %   'maxiter' (double): maximum number of iterations for the fit
    %   'maxfunevals' (double): maximum number of function evaluations for
    %       the fit
    %   'robust' (logical): use robust fitting (default: false)
    %
    % Outputs:
    %   f (sfit): fit object
    arguments
        x (:,:) double
        y (:,:) double
        data (:,:) double
        options.n double {mustBeInteger} = 3;
        options.lower (1,1) double
        options.upper (1,1) double
        options.startpoint (1,1) double
        options.maxiter (1,1) double {mustBeInteger}
        options.maxfunevals (1,1) double {mustBeInteger}
        options.robust (1,1) logical = false
    end
    i = [1:options.n];
    j = [1:options.n];
    [I,J] = meshgrid(i,j);
    xknots = linspace(min(x(:)),max(x(:)),options.n);
    yknots = linspace(min(y(:)),max(y(:)),options.n);
    hstr = '';
    for ii = 1:numel(I)
        hstr = [hstr, sprintf('h%d_%d,', I(ii), J(ii))];
    end
    hmatstr = '[';
    for ii = 1:options.n
        for jj = 1:options.n
            hmatstr = [hmatstr sprintf('h%d_%d,', i(ii), j(jj))];
        end
        hmatstr = [hmatstr(1:end-1),';'];
    end
    hmatstr = [hmatstr(1:end-1),']'];
    xknotstr = sprintf('[%s]',join(string(cellfun(@num2str,num2cell(xknots),'UniformOutput',false)),','));
    yknotstr = sprintf('[%s]',join(string(cellfun(@num2str,num2cell(yknots),'UniformOutput',false)),','));
    fstr = sprintf('@(%sx,y)interp2(%s,%s,%s,x,y,''spline'')', hstr,xknotstr, yknotstr, hmatstr);
    fitfun = str2func(fstr);
    g = fittype(fitfun, 'independent', {'x','y'},'dependent','z');
    gfo = fitoptions(g);
    if isfield(options, 'lower')
        gfo.Lower = ones(1,options.n^2)*options.lower;
    end
    if isfield(options, 'upper')
        gfo.Upper = ones(1,options.n^2)*options.upper;
    end
    if isfield(options, 'startpoint')
        gfo.StartPoint = ones(1,options.n^2)*options.startpoint;
    end
    if isfield(options, 'maxiter')
        gfo.MaxIter = options.maxiter;
    end
    if isfield(options, 'maxfunevals')
        gfo.MaxFunEvals = options.maxfunevals;
    end
    
    if options.robust
        gfo.Robust = 'on';
    end
    f = fit([x(:) y(:)], data(:), g, gfo);
end