function [ x, y, m, a] = myPowerLaw( x, y, m, a )
%myPowerlaw Returns fitted data according to a power law of the type y = a * x^m
%
%   * The input x and y can be experimental data that is used to determine the prefator 'a' and/or
%     the exponent 'm' depending on how many input arguments are given. For example, specifying 'm'
%     but not 'a' leads to 'a' being fitted.
%   * The output can be used for plotting, where x consists of monotonically increasing values
%     equally distributed in the range of the input.
%   * When not output argument is requested at all, the result is plotted.
%

%
% basic input check
narginchk(2,4);
nargoutchk(0,4);
assert(isnumeric(x) && isnumeric(y) && numel(x) == numel(y),'Mismatch in type or length for given data');
%
% remove NaNs
idx = ~isnan(x(:)) & ~isnan(y(:));
x   = reshape(x(idx),[],1);
y   = reshape(y(idx),[],1);
assert(~isempty(x),'Not enough valid data points available');
%
% fit when necessary 
isYNeg = y(:)<=0;
isXNeg = y(:)<=0;
if all(isYNeg) || all(~isYNeg) && (all(isXNeg) || all(~isXNeg))
    % fit in log space
    if nargin == 2
        fitS = polyfit(log10(x),log10(y),1);
        m    = fitS(1);
        a    = 10^fitS(2);
    elseif nargin == 3
        a = 10^(mean(log10(y))-m*mean(log10(x)));
    end
else
    % fit in linear space
    if nargin == 2
        xMean = mean(x(:));
        yMean = mean(y(:));
        fitS  = polyfit(x,y,1);
        cfit  = fit(x,y,'a*x^m','StartPoint',[yMean/xMean sign(fitS(1))]);
        m     = cfit.m;
        a     = cfit.a;
    elseif nargin == 3
        xMean = mean(x(:));
        yMean = mean(y(:));
        cfit  = fit(x,y,sprintf('a*x^(%e)',m),'StartPoint',yMean/xMean^m);
        a     = cfit.a;
    end
end
assert(isnumeric(m) && isnumeric(a) && isscalar(m) && isscalar(a),'Mismatch in type or length for model parameters');
%
% prepare output
nPlot = 1000;
bak_x = x;
bak_y = y;
x     = linspace(min(x(:)),max(x(:)),nPlot);
y     = a*x.^m;
%
% plot if nothing was asked as a return
if nargout < 1
    h                = plot(bak_x,bak_y,'ob',x,y,'-r');
    h(1).DisplayName = 'data';
    h(2).DisplayName = sprintf('y = a  x^m, m = %0.2f, a = %.2e',m,a);
end
end