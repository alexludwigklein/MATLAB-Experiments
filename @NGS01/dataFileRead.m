function out = dataFileRead(in,type)
%dataFileRead Reads data and header from simple data file as often written by some lab equipment,
% first input is the filename, second input the type of parameter file ('importdata')
%
%----------------------------------------------------------------------------------
%   Copyright 2016 Alexander Ludwig Klein, alexludwigklein@gmail.com
%
%   Physics of Fluids, University of Twente
%----------------------------------------------------------------------------------

if nargin < 1
    error(sprintf('%s:Input',mfilename),'No input at all, but first input should be a filename to a data file and second input (optional) the type of encoding');
elseif nargin < 2
    type = 'importdata';
end
if ~(ischar(in) && ischar(type))
    error(sprintf('%s:Input',mfilename),'Unknown input: First input should be a filename to a data file and second input (optional) the type of encoding');
elseif exist(in,'file') ~= 2
    error(sprintf('%s:Input',mfilename),'File ''%s'' does not exist',in);
else
    switch type
        case 'importdata'
            out = dataFile01Read(in);
        otherwise
            error(sprintf('%s:Input',mfilename),'Unknown type of data file ''%s''',type);
    end
end
end

function out = dataFile01Read(in)
% Input is the filename to a data file:
% * Data written as two column text with an optional header that can be understood by importdata
% * Function tries to vary delimiter if nothing is read with default settings of importdata.
%
% Output is a structure with data and textdata field

tmp = importdata(in);
if isnumeric(tmp)
    tmp = struct('data',tmp,'textdata',''); 
end
if ~isempty(tmp) && (~(isstruct(tmp) && isfield(tmp,'data')) || (numel(tmp.data) < 2 || size(tmp.data,2) < 2))
    % re-try with different delimiter
    [tmp,delim] = importdata(in,' ');
    if ~isempty(tmp) && (~(isstruct(tmp) && isfield(tmp,'data')) || (numel(tmp.data) < 2 || size(tmp.data,2) < 2) && size(tmp.textdata,1) > 0)
        if iscellstr(tmp), tmp = struct('textdata',{tmp}); end
        % data might be ended up in textdata, find the first line which starts with an numeric and
        % read again
        nHeader = 0;
        for i = 1:size(tmp.textdata,1)
            if ischar(tmp.textdata{i,1}) && numel(tmp.textdata{i,1}) > 1 && ...
                    ismember(tmp.textdata{i,1}(1),'+-1234567890') && (ismember(tmp.textdata{i,1}(2),'.e1234567890') || ...
                    ismember(tmp.textdata{i,1}(2),[sprintf('\t ')]))
                nHeader = i - 1;
                break
            end
        end
        if nHeader > 0
            tmp.textdata = tmp.textdata(1:nHeader,:);
            tmp.data     = dlmread(in, delim, nHeader, 0);
        end
    end
end
if isempty(tmp) || numel(tmp.data)  < 2
    warning(sprintf('%s:Input',mfilename),'File ''%s'' does not contain data',in);
    out.data     = [];
    out.textdata = [];
else
    out.data     = tmp.data;
    out.textdata = tmp.textdata;
end
end