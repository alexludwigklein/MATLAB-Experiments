function out = labbookGetLiquids(varargin)
%labbookGetLiquids Read liquid properties from digital labbook and return as table or struct
%   Function to read liquid properties from an excel workbook, optional input can be the filename of
%   the Excel workbook, the name of the sheet with the liquid properties in the workbook and the
%   liquid(s) to be read given by the corresponding ID(s) or name(s)
%
%----------------------------------------------------------------------------------
%   Copyright 2016 Alexander Ludwig Klein, alexludwigklein@gmail.com
%
%   Physics of Fluids, University of Twente
%----------------------------------------------------------------------------------

%
% use input parser to process options
opt               = inputParser;
opt.StructExpand  = true;
opt.KeepUnmatched = false;
% filename of the labbook
opt.addParameter('filename', 'Labbook.xlsx', ...
    @(x) ischar(x));
% name of the sheet in the labbook
opt.addParameter('sheet', 'Liquids', ...
    @(x) ischar(x));
% name of the liquid or its numeric ID
opt.addParameter('liquid', '', ...
    @(x) isempty(x) || isnumeric(x) || ischar(x) || iscellstr(x));
% true\false whether to return result as table or struct
opt.addParameter('returnTable', true, ...
    @(x) islogical(x) && isscalar(x));
opt.parse(varargin{:});
opt = opt.Results;
%
% read file
if ~exist(opt.filename,'file') == 2
    error(sprintf('%s:Input',mfilename),'File ''%s'' is not found, please check!',opt.filename);
end
[status, sheets] = xlsfinfo(opt.filename);
if ~status
    error(sprintf('%s:Input',mfilename),'File ''%s'' cannot be read by xlsread, please check!',opt.filename);
elseif ~ismember(opt.sheet,sheets)
    error(sprintf('%s:Input',mfilename),'Sheet ''%s'' not found in Excel file ''%s''',opt.sheet,opt.filename);
end
[~, ~, raw]  = xlsread(opt.filename,opt.sheet);
tmp          = raw(:,1);
for k = 1:numel(tmp), if ~ischar(tmp{k}), tmp{k} = ''; end; end
[idxOK, idx] = ismember('ID',tmp(:,1));
if ~idxOK
    error(sprintf('%s:Input',mfilename),['Sheet ''%s'' in Excel file ''%s'' does not seem to be a ',...
        'valid table since no ''ID'' could be found in the first column, please check!'],opt.sheet,opt.filename);
end
%
% read property names
desc = raw(idx,:);
fn   = raw(idx+1,:);
for k = 1:numel(fn)
    [fn{k}, modified] = matlab.lang.makeValidName(fn{k});
    if modified
        warning(sprintf('%s:Input',mfilename),['Sheet ''%s'' in Excel file ''%s'' contains ',...
            'an invalid property name that was changed to ''%s'', please check!'],opt.sheet,opt.filename,fn{k});
    end
end
%
% remove header line and invalid lines
raw   = raw((idx+2):end,:);
idxOK = false(size(raw,1),1);
for k = 1:size(raw,1)
    if isnumeric(raw{k,1}) && ischar(raw{k,2})
        idxOK(k) = true;
    end
end
raw = raw(idxOK,:);
%
% check liquids
ID  = cell2mat(raw(:,1));
STR = raw(:,2);
if numel(ID) ~= numel(unique(ID)) || numel(STR) ~= numel(unique(STR))
    warning(sprintf('%s:Input',mfilename),['Sheet ''%s'' in Excel file ''%s'' contains ',...
        'ambiguous entries, please check!'],opt.sheet,opt.filename);
end
%
% find liquid(s)
if isempty(opt.liquid)
    opt.liquid = cell2mat(raw(:,1));
elseif ischar(opt.liquid)
    opt.liquid = {opt.liquid};
end
if isnumeric(opt.liquid)
    ID = cell2mat(raw(:,1));
else
    ID = raw(:,2);
end
[idxOK, idx] = ismember(opt.liquid,ID);
if ~all(idxOK)
    warning(sprintf('%s:Input',mfilename),['Sheet ''%s'' in Excel file ''%s'' does not contain ',...
        'properties for %d requested liquid(s), please check!'],opt.sheet,opt.filename,sum(~idxOK));
end
idx = idx(idxOK);
raw = raw(idx,:);
%
% return data
out = struct;
for k = 1:size(raw,1)
    for l = 1:numel(fn)
        out(k).(fn{l}) = raw{k,l};
    end
end
%
% fix entries
fn = fieldnames(out);
for k = 1:numel(fn)
    switch fn{k}
        case {'comment' 'description' 'solute' 'solvent' 'name' 'manufacturer' 'partNumber'}
            for l = 1:numel(out)
                if isnan(out(l).(fn{k}))
                    out(l).(fn{k}) = '';
                end
            end
        case 'date'
            for l = 1:numel(out)
                out(l).(fn{k}) = datetime(out(l).(fn{k}),'ConvertFrom','excel');
            end
    end
end
%
% prepare output
% [out, perm] = orderfields(out);
% desc        = desc(perm);
for i = 1:numel(desc)
    desc{i} = strrep(desc{i},char(10),' ');
end
if opt.returnTable
    if numel(out) == 1
        out = struct2table(repmat(out,2,1));
        out = out(1,:);
    else
        out = struct2table(out);
    end
    out.Properties.VariableDescriptions = desc;
    out.Properties.RowNames = out.name;
    fn = out.Properties.VariableNames;
    for k = 1:numel(fn)
        switch fn{k}
            case {'solute' 'solvent' 'name' 'manufacturer' 'partNumber'}
                out.(fn{k}) = categorical(out.(fn{k}));
        end
    end
end
