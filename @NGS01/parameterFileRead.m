function out = parameterFileRead(in,type)
%parameterFileRead Reads parameters and comments from simple parameter file as often written by
% some lab equipment, first input is the filename, second input the type of parameter file (':')
%
%----------------------------------------------------------------------------------
%   Copyright 2016 Alexander Ludwig Klein, alexludwigklein@gmail.com
%
%   Physics of Fluids, University of Twente
%----------------------------------------------------------------------------------

if nargin < 2 || ~(ischar(in) && ischar(type))
    error(sprintf('%s:Input',mfilename),'Unknown input: First input should be a filename to a parameter file and second input the type of encoding');
elseif exist(in,'file') ~= 2
    error(sprintf('%s:Input',mfilename),'File ''%s'' does not exist',in);
else
    switch type
        case ':'
            out = parameterFile01Read(in);
        otherwise
            error(sprintf('%s:Input',mfilename),'Unknown type of parameter file ''%s''',type);
    end
end
end

function out = parameterFile01Read(in)
% Input is the filename to an info file:
% * Comments in the file start with an % or # symbol
% * Parameters are encoded in "<propertyname> : <propertyvalue>" style
% * Function tries to interpret the values as numerical datatype
%
% Output is a structure with the parameters and all comment lines

out.Comment = {};
fid = fopen(in);
str = fgetl(fid);
while ischar(str)
    str = strtrim(str);
    if isempty(str)
        % do nothing
    elseif strcmp(str(1),'%') || strcmp(str(1),'#')
        out.Comment{end+1} = str;
    else
        [token, remain] = strtok(str,':');
        token  = strtrim(token);
        if ~isempty(token)
            remain = strtrim(remain(2:end));
        end
        switch token
            otherwise
                % try to read numeric value, otherwise store as
                % string in structure
                [tmp, status] = str2num(remain); %#ok<ST2NM>
                if status
                    out.(matlab.lang.makeValidName(token)) = tmp;
                else
                    out.(matlab.lang.makeValidName(token)) = remain;
                end
        end
    end
    str = fgetl(fid);
end
fclose(fid);
out = orderfields(out);
end
