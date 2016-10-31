function [data, hFig] = calibrationCurveFit(data,varargin)
%calibrationCurveFit Fits one or multiple measurement(s) of two energy meters to calibration
% function(s). The calibration function(s) are better suited, e.g. for the measurement of the
% attenuation of optical elements, the absorption in fluids or just a simple interpolation. Of
% course, it can also be used for other 2D data than readings from energy meters.
%
% Input:
% * "data" is a structure array (one element per measurement) with the following fields:
%   * "em1" and "em2" represent the readings from two energy meters that are in a certain relation.
%      Note: if em1 and em2 are strings they are interpreted as filenames to the actual data, which
%      is tried to be read with dataFileRead. In that case, the data is correct for saturated
%      measurements and an offset at low energies. Therefore, it is good to include zero
%      measurements in the data otherwise the offset can not be determined correctly.
%   * "model" specifies how the data should be fitted, i.e. 'linear' or 'zero-Linear', etc.
%   * "opt" options for the fitting process of the model
% * "varargin" are global options read by inputParser:
%   * "maxZero" is maximum allowed value to be considered a zero measurement relative to the maximum
%     value (used for offset calibration when reading from a file)
%   * "plot" indicates whether to plot the calibration curves
%
% Output:
% * "data" Input structure extended with fittted calibration curve(s) and model parameter(s)
% * "hFig" Handle to plotting figure, or empty if no figure was created
%
% Models (result from SLM, see slmengine):
% 'linear'          Fits one linear section to the data, no further options
% 'zero-linear'     Initial part is zero until a certain threshold, afterwards a linear fit
%   Motivation: energy meter 1 (em1) is supposed to be an energy meter that measures the split off
%   from a Glan-Laser polarizer. It measure any "dirty' polarization and, therefore, it can measure
%   an energy although no energy passes the Glan-Laser polarizer to the second energy meter (em2).
%   This energy threshold needs to be found and accounted for, since below the threshold the
%   readings from the two energy meters are not related. The threshold in the reading(s) form energy
%   meter 1 should be the same as long as energy meter 1 is in the same position, which is assumed
%   to be true here. Therefore, any model whose name starts with 'zero-' gets the same threshold
%   that is found by an optimization (see also spline-linear). Options of the model as a structure:
%   * "x0" threshold that is optimized, initial input is ignored (double)
%   * "slmOpt" Additional options for slmengine as cell (<propertyname>, <propertyvalue> style)
% 'spline-linear'   Initial part is a spline afterwards a linear fit
%   Break point to go from spline to linear part is found by an optimization and is equal to
%   threshold of 'zero-linear'. Options of the model as a structure:
%   * "x0" break point to go from spline to linear part, initial input is ignored (doubel)
%   * "slmOpt" Additional options for slmengine as cell (<propertyname>, <propertyvalue> style)
%   
%----------------------------------------------------------------------------------
%   Copyright 2016 Alexander Ludwig Klein, alexludwigklein@gmail.com
%
%   Physics of Fluids, University of Twente
%----------------------------------------------------------------------------------

%
% check input and use input parser to process global options (not model options)
opt               = inputParser;
opt.StructExpand  = true;
opt.KeepUnmatched = false;
opt.addParameter('maxZero', 0.001, ...
    @(x) isnumeric(x) && isscalar(x));
opt.addParameter('plot', true, ...
    @(x) islogical(x) && isscalar(x));
opt.parse(varargin{:});
opt = opt.Results;
if ~isstruct(data) || ~all(isfield(data,{'em1','em2','model'}))
    error(sprintf('%s:Input',mfilename),'Unexpected input for data');
end
if ~isfield(data,'opt')
    for i = 1:numel(data), data(i).opt = []; end
end
%
% check if all data is available and in good order
for j = 1:numel(data)
    % read data
    isRead = false;
    if ischar(data(j).em1)
        tmp       = NGS01.dataFileRead(data(j).em1,'importdata');
        data(j).em1 = reshape(tmp.data(:,2),[],1);
        isRead    = true;
    else
        data(j).em1 = reshape(data(j).em1,[],1);
    end
    if ischar(data(j).em2)
        tmp       = NGS01.dataFileRead(data(j).em2,'importdata');
        data(j).em2 = reshape(tmp.data(:,2),[],1);
        isRead    = true;
    else
        data(j).em2 = reshape(data(j).em2,[],1);
    end
    % check length
    if numel(data(j).em1) ~= numel(data(j).em2)
        error(sprintf('%s:Input',mfilename),'Measurement %s (%d of %d): number of shots differs among energy meters',char(64+j),j,numel(data));
    end
    if isRead
        % find indices that indicate saturated measurments
        idxMax = data(j).em1 == max(data(j).em1) & data(j).em2 == max(data(j).em2);
        if sum(idxMax) > 1
            fprintf('Measurement %s (%d of %d): %d data points seem to be saturated and are removed\n',char(64+j),j,numel(data),sum(idxMax));
            data(j).em1(idxMax) = [];
            data(j).em2(idxMax) = [];
        end
        % find indices that indicate zero measurements and calibrate data
        idxMin = data(j).em1 == min(data(j).em1) & data(j).em2 == min(data(j).em2);
        if sum(idxMin ) > 1
            fprintf('Measurement %s (%d of %d): %d data points seem to be zero measurements and are used for an offset calibration\n',char(64+j),j,numel(data),sum(idxMin));
            if mean(data(j).em1(idxMin)) > opt.maxZero * max(data(j).em1) || ...
                    mean(data(j).em2(idxMin)) > opt.maxZero * max(data(j).em2)
                warning(sprintf('%s:Input',mfilename),'Measurement %s (%d of %d): zero measurement is too high compared to maximum value ... no offset calibration performed',char(64+j),j,numel(data));
            else
                data(j).em1 = data(j).em1 - mean(data(j).em1(idxMin));
                data(j).em2 = data(j).em2 - mean(data(j).em2(idxMin));
            end
        end
    end
end
%
% optimize zero-... and spline-... models by parameter x0
mIdx = cellfun(@(x) isequal(x,1),strfind({data.model},'zero-')) | ...
    cellfun(@(x) isequal(x,1),strfind({data.model},'spline-'));
if any(mIdx)
    x0Min = min(arrayfun(@(data) min(data.em1), data(mIdx)));
    x0Max = min(arrayfun(@(data) max(data.em1) * 0.99,data(mIdx)));
    parX0 = fminbnd(@(x) sum(arrayfun(@(y) fitModelParameter(y,'x0',x),data(mIdx))),x0Min,x0Max);
end
%
% add optimized parameter(s) to model(s) and perform final fit(s)
for j = 1:numel(data)
    if isequal(strfind(data(j).model,'zero-'),1) || isequal(strfind(data(j).model,'spline-'),1)
        data(j).opt.x0 = parX0;
    end
    data(j).fit = fitModel(data(j));
end
%
% plot results
if opt.plot
    % prepare figure
    hFig = figure;
    hAx  = subplot(2,1,1,'Nextplot','Add');
    xlabel(hAx(1),'E_1 (mJ)');
    ylabel(hAx(1),'E_2 (mJ)');
    hAx(2) = subplot(2,1,2,'Nextplot','Add');
    xlabel(hAx(2),'E_1 (mJ)');
    ylabel(hAx(2),'-log_{10}(E_{X,2}/E_{A,2})');
    % plot good data, EM2 vs EM1 and fitting line
    mycolor = distinguishable_colors(numel(data));
    nFit    = 1000;
    for j = 1:numel(data)
        % data
        plot(hAx(1),data(j).em1*1e3,data(j).em2*1e3, ...
            'DisplayName',sprintf('%s: experiment',char(64+j)), 'linewidth', 2,...
            'marker','o','linestyle','none','Color',mycolor(j,:));
        % model
        tmp = linspace(0,max(data(j).em1),nFit);
        plot(hAx(1),tmp*1e3,slmeval(tmp,data(j).fit)*1e3, ...
            'DisplayName',sprintf('%s: %s',char(64+j),data(j).model),'linewidth',2,...
            'marker','none','linestyle','-','Color',mycolor(j,:));
        % plot attenuation factor relative to first measurement
        tmp = linspace(0,min(max(data(1).em1),max(data(j).em1)),nFit);
        plot(hAx(2),tmp*1e3, -1*log10(slmeval(tmp,data(j).fit)./slmeval(tmp,data(1).fit)), ...
            'DisplayName',sprintf('%s vs. A',char(64+j)),'linewidth',2,...
            'marker','none','linestyle','-','Color',mycolor(j,:));
    end
    legend(hAx(1),'show');
    legend(hAx(2),'show');
    linkaxes(hAx,'x');
else
    hFig = [];
end
end

function [fit, rms] = fitModel(data)
% fitModel Fits a single model to its data and returns the actual fit and the normalized root mean
% square error per data point

if numel(data) > 1
    error(sprintf('%s:Input',mfilename),'Unexpected input');
end
switch data.model
    case 'linear'
        fit = slmengine(data.em1,data.em2,'plot','off', 'degree', 1, 'knots',2,...
            'extrapolation','linear');
        rms = fit.stats.RMSE / max(data.em2) / numel(data.em2);
    case 'zero-linear'
        if ~(~isempty(data.opt) && isfield(data.opt,'slmOpt'))
            slmOpt = {};
        else
            slmOpt = data.opt.slmOpt;
        end
        fit = slmengine(data.em1,data.em2,'plot','off',...
            'leftvalue', 0, 'degree', 1,...
            'knots',[min(data.em1), data.opt.x0, max(data.em1)],...
            'constantregion', [min(data.em1), data.opt.x0],...
            'extrapolation','linear',slmOpt{:});
        rms = fit.stats.RMSE / max(data.em2) / numel(data.em2);
    case 'spline-linear'
        if ~(~isempty(data.opt) && isfield(data.opt,'slmOpt'))
            slmOpt = {};
        else
            slmOpt = data.opt.slmOpt;
        end
        fit = slmengine(data.em1,data.em2,'plot','off',...
            'knots',[min(data.em1), data.opt.x0, max(data.em1)],...
            'linearregion', [data.opt.x0+eps, max(data.em1)],...
            'extrapolation','linear',slmOpt{:});
        rms = fit.stats.RMSE / max(data.em2) / numel(data.em2);
    otherwise
        error(sprintf('%s:Input',mfilename),'Unknown model ''%s''',data.model);
end
end

function [rms, fit] = fitModelParameter(data,varargin)
% fitModelzero Wrapper function to fitModel that first adds information to options field, data
% should be given in <propertyname>, <propertyvalue> style. Note: no error checking to save
% computational time, since this function is used during the fitting of models with parameters that
% need to be optimized. Furthermore, it returns as first output a number that is used to quantify
% the quality of a fit, as this is needed during the optimization

for i = 1:2:numel(varargin)
    data.opt.(varargin{i}) = varargin{i+1};
end
[fit, rms] = fitModel(data);
end