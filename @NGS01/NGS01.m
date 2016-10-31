classdef NGS01 < matlab.mixin.Copyable
    %NGS01 Abstract class describing the general outcome of experiments at the NGS01 setup, emerged
    % from class myExperiments combined with some functions from class myDropKickA (sub class of
    % myExperiments). In principle an object of the NGS01 class can be used to store almost
    % arbitrary data in a handle object with custom indexing and assignment syntax. It is similar to
    % MATLAB's table datatype extended by all benefits of a class design (e.g. dependent and
    % transient properties), a backup and restore feature and a GUI to select and browse the data.
    %
    % Implementation Notes:
    %   * Stores data of numeric, char, logical, struct, datetime, duration, cell, categorical
    %     (comparison based on order for ordinal categorical is not directly supported), Video (user
    %     class by alexludwigklein, also any subclass such as the BeamProfile) and UC/DimVar (user
    %     class from FEX) type for properties of experiments (called physical properties). Stores
    %     also some additional properties, such as format setting, number of experiments in object,
    %     etc. (called non-physical properties that are necessary to handle the actual physical
    %     properties).
    %   * Identification of an experiment: uid (unique identification number) is a serial number
    %     identifying a single experiment or a collection of a single experiments (e.g. several
    %     stroboscopic experiments or a parameter scan stored in one folder, which is given a
    %     specific uid). A further index is used to identify a single experiment within a collection
    %     of several experiments with the same uid (e.g. previous example of a stroboscopic
    %     experiment). uid and index start at 1 and are represented by uint32 values. Therefore, the
    %     uid and index combined should be a unique identifier for an experiment. Numerically, this
    %     is achieved by bitshifting the uid and add the index to an uint64 identifier called uuid.
    %     This leads to a number easily read by a human in dual system, but unhandy in decimal
    %     system (used by MATLAB to display numbers). Therefore it is changed, such that it can be
    %     better read in decimal system, i.e. the first lowest 9 digits are used for the index and
    %     the remaining highest digits for the uid. Therefore, this implementation can handle 1e9
    %     different indices (and more UIDs than uint32 can handle), whereas the bitshifting can
    %     handle intmax('uint32') > 1e9 indices.
    %   * To group data in arbitrary subsets, a setName can be assigned to each experiment, e.g. a
    %     descriptive name ('Parameter is 10') or just a short name ('A' 'B', etc.)
    %   * Timing information of an experiment: MATLAB's datetime is used to specify a point in time
    %     called time of an experiment (allows for at least nanosecond precision).
    %   * Size of any class property that represents a physical property is supposed to be n x
    %     <something> where n is the number of experiments contained in NGS01 object and <something>
    %     is arbitrary for each property but constant, i.e. the same for all experiments. For
    %     example a single value per experiments leads to a n x 1 property, wheras a 2D matrix leads
    %     to a n x m x l property (with m and l being constant among experiments). Numeric data that
    %     changes in size or datatype from experiment to experiment should be put into cells or
    %     fields of a structure (keep the fieldname constant among experiments, but change
    %     datatype). Each physical property that is not of the size n x 1 and not a float should
    %     have a function called <property>2Numeric which converts the property to a numeric
    %     representation of size n x 1 of class double or single, i.e. a float value. This value can
    %     be used to select experiments based on a scalar value per experiment.
    %   * Directory structure: The experimental data files are supposed to be in
    %     <rootdir>/<date>/<uid> and the current directory is used as rootdir if this property is
    %     empty (rootdir is set per object for all experiments), getDir can be used to query the
    %     directory according to the naming scheme, use the properties formatDate, formatUID (and
    %     formatIndex) to change the appearance of the date and uid strings, Note: getDir is not a
    %     sealed method, therefore, it might be redefined to get a different naming scheme for a
    %     subclass. In each folder of an experiment should be an parameter file that is a matlab
    %     function returning all information on that experiment.
    %   * Indexing of experiments: obj(<specify experiment (see findExp))>.<property name>(<further
    %     indexing for property>). Note: This leads to the problem that MATLAB can not return comma
    %     seperated lists for properties of struct or cell datatype, e.g. [obj(:).mystruct.x] does
    %     not return an array but just a single value, the number of outputs need to be specified
    %     directly, e.g. [C(1:d.numSel)] = d.mystruct.x (similar for cells), BUT this has been fixed
    %     in recent MATLAB versions with the numArgumentsFromSubscript feature for user defined
    %     classes (e.g. in R2014b)
    %   * Note on indexing:
    %     * Indexing like obj(<something>) sets a new selection (e.g. all experiments: obj(:))
    %     * Indexing like obj(end:-1:1) and obj(1:end) select the same experiments. Therefore,
    %       obj(end:-1:1).uid and obj(1:end).uid return the same array and not in reversed order
    %     * Add fields to obj.sel to save selections that can be used later via its fieldname, e.g.
    %       store selection based on uid obj.sel.sel1 = {'uid' [3 10]}, Note: This is a dynamic
    %       selection meaning it is re-evaluated when it is used again. This is a better approach
    %       than storing the absolute indices, e.g. obj.sel.sel1 = 1:4, since indices may change
    %       when experiments are sorted differently.
    %   * See get and set functions as an alternative way to set and get multiple properties in a
    %     single function call. The get function can also be used to query the return value of the
    %     <property name>2Numeric function.
    %
    %----------------------------------------------------------------------------------
    %   Copyright 2016 Alexander Ludwig Klein, alexludwigklein@gmail.com
    %
    %   Physics of Fluids, University of Twente
    %----------------------------------------------------------------------------------
    
    %% Properties
    properties (GetAccess = public, Constant = true)
        % gravity Standard gravity in m/s^2 (constant double, 1 x 1)
        gravity = 9.80665;
        % boltzmann Boltzmann constant in J/K (constant double, 1 x 1)
        boltzmann = 1.3806488*10e-23
        % planck Planck constant in J s (constant double, 1 x 1)
        planck = 6.62606957e-34;
        % speedOfLight Speed of light in vacuum in m/s (constant double, 1 x 1)
        speedOfLight = 299792458;
    end
    
    properties (GetAccess = public, Constant = true)
        % noprop Properties that do not reflect a physical property of an experiment (cellstr, 1 x m)
        %
        % Note: For those properties the size restriction n x m, etc. is not tested, Therefore,
        % every non physical class property must be listed here (constant properties are not tested
        % by default, since the cannot change in size and cannot be used for physical properties)
        noprop = {'gravity','boltzmann','noprop','ismyarray','nopropsub','formatUID', ...
            'formatIndex','formatDate','mytmp','sel','vip','vip2Numeric','ind','isSync','numAbs',...
            'numSel','memory','infoStruct','info','myprop','mypropSize','myprop2Set','myprop2SetDefault',...
            'myprop2SetSize','myclass','myprop2Numeric','hWaitbar','isUnique','rootdir','parameterFile',...
            'dataFilePrefix','verbose','infopanel','labbook','liquids', 'mydesc', 'isVideo'}
        % ismyarray Function to test if input can be handled as scalar float value per experiment,
        % i.e. a column vector of a float class
        ismyarray = @(x) isfloat(x) && iscolumn(x);
    end
    
    properties (GetAccess = public, Constant = true, Abstract = true)
        % nopropsub Properties in subclass that do not reflect physical properties (cellstr, 1 x m)
        nopropsub
    end
    
    properties (GetAccess = public, SetAccess = public)
        % rootdir Root directory for data (char)
        %
        % Note: The experimental data files are supposed to be in <rootdir>/<date>/<uid> and the
        % current directory is used as rootdir if its empty
        rootdir = 'Data';
        % labbook Filename (relative to rootdir) of an Excel file with additional information such as liquid properties (char)
        labbook = 'Labbook.xlsx';
        % parameterFile Filename of matlab script that returns necessary information on experiment (char)
        parameterFile = 'parameters.m';
        % dataFilePrefix Filename of MAT file to store object of one UID (char)
        %
        %  It is the prefix of the filename that is extended by the actual class name. The file is
        %  used to store the part of the object that belongs to one UID  in the corresponding
        %  folder. The data is read instead of starting from the parameterFile. Note: a parameter
        %  file must be available nevertheless to allow for the directory to be recognized as valid.
        dataFilePrefix = 'parameters_';
        % formatUID Format string to create directory name based on uid (char, 1 x m)
        formatUID = '%0.6d';
        % formatIndex Format string to create name based on index (char, 1 x m)
        formatIndex = '%0.4d';
        % formatDate Format string for datestr to create directory name based on time (char, 1 x m)
        formatDate = 'yyyy-mm-dd';
        % time Time of the start of the experiment (datetime, n x 1)
        time = datetime('now');
        % period Duration of the experiment (duration, n x 1)
        period = duration(0,0,0);
        % uid Unique identification number of experiment (uint32, n x 1)
        uid = uint32(1);
        % index Scalar index of the experiment within collection of experiments of one uid (uint32, n x 1)
        index = uint32(1);
        % enable Logical whether the experiment is selected (logical, n x 1)
        enable = true;
        % userdata Arbitrary user data as cell linked to object (cell, n x 1)
        userdata = cell(1,1);
        % comment Comment on experiment (cell with cellstr, n x 1)
        comment = cell(1,1);
        % name Name of experiment (categorical, n x 1)
        name = categorical({''});
        % version Version of the experiment (double, n x 1)
        version = 0;
        % status Status of the experiment (double, n x 1)
        status = 0;
        % setIndex The name of the set the experiments belongs to (categorical, n x 1)
        setName = categorical({''});
        % options Place to store options for the post processing (cell, n x 1)
        options = cell(1,1);
        % data Place to store data of the post processing (cell, n x 1)
        data = cell(1,1);
        % user User who operates the setup during experiment (categorical, n x 1)
        user = categorical({''});
        % mytmp Place to store some temporary data of object, e.g for a GUI (set to empty, 1 x 1)
        mytmp = [];
        % sel User defined definition of selections (see findExp for predefined selections, such as 'all') (struct, 1 x 1)
        sel = struct('example',{{'uid' 1}},'prev',{{'uuid' []}});
        % verbose Set level of verbosity, < 100: No waitbar
        verbose = Inf;
        % vip Very important properties often used or plotted (subset of myprop, 1 x m)
        vip = sort({ 'time' 'uid' 'index'});
        % infopanel Infopanel that should be shown in NGS01Info GUI (cellstr)
        infopanel = {'NGS01Infotab_Property', 'NGS01Infotab_Experiment' 'NGS01Infotab_Selection',...
            'NGS01Infotab_Histogram','NGS01Infotab_Overview','NGS01Infotab_Video'};
    end
    
    properties (GetAccess = public, SetAccess = public, Dependent = true)
        % t Short for time
        t
        % p Short for period
        p
        % u Short for uid
        u
        % i Short for index
        i
        % sn Short for setName
        sn
        % c Short for comment
        c
        % n Short for name
        n
        % v Short for version
        v
        % s Short for status
        s
        % o Short for options
        o
        % d Short for data
        d
        % ud Short for userdata
        ud
    end
    
    properties (GetAccess = public, SetAccess = protected, Dependent = true)
        % vip2Numeric Transformation of vip to scalar representative (subset of myprop2Numeric, 1 x m)
        vip2Numeric
        % ind Linear absolute indices of selected experiments (double, numSel x 1)
        %
        % For example an ind of 5 means the experiment is at position 5 in the data, independent of
        % the current selection i.e. this ind is fixed or absolute
        ind
        % rel Linear relative indices of selected experiments (double, numSel x 1)
        %
        % Index in the current selection, can be used to get a vector 1:obj.numSel or to select an
        % experiment in crurrent selection. For example to select the 5th experiment among the
        % already selected experiments use obj('rel',5);
        rel
        % isSync Logical whether all physical properties are of the same length (logical, 1 x 1)
        isSync
        % numAbs Number of experiments (double, 1 x 1)
        numAbs
        % numSel Number of selected experiments (double, 1 x 1)
        numSel
        % memory Memory usage in MiB for each independent physical quantities in obj.myprop2Set (double, 1 x length(obj.myprop))
        memory
        % infoStruct Information on selected experiments (struct, 1 x 1)
        infoStruct
        % info Information string on selected experiments (char, 1 x m)
        info
        % uuid Combination of uid and index for a unique number identifying an experiment (uint64, n x 1)
        uuid
        % uuidStr Combination of uid and index for a unique string identifying an experiment (cellstr, n x 1)
        uuidStr
        % isUnique Test if all uuid are unique
        isUnique
        % dir Directory of experiment (categorical, n x 1)
        dir
        % liquids Liquids in labbook as table, use updateLiquids to read information from the labbook (table)
        liquids
    end
    
    properties (GetAccess = public, SetAccess = protected, Transient = true)
        % mydesc Description for each entry in myprop (cellstr, 1 x m)
        mydesc
        % myprop Physical and public class properties to describe an experiment (cellstr, 1 x m)
        myprop
        % mypropSize Size of physical and public class properties to describe an experiment (cellstr, 1 x m)
        %
        % The first dimension should be equal to one, since it is the size per experiment
        mypropSize
        % myprop2Set Independent physical and public class properties to describe an experiment (cellstr, 1 x m)
        myprop2Set
        % myprop2SetDefault Default value of independent physical and public class properties to describe an experiment (cellstr, 1 x m)
        myprop2SetDefault
        % myprop2SetSize Size of independent physical and public class properties to describe an experiment (cellstr, 1 x m)
        %
        % The first dimension should be equal to one, since it is the size per experiment
        myprop2SetSize
        % myclass Class for each entry in myprop (cellstr, 1 x m)
        myclass
        % myprop2Numeric Functions to determine a numeric representation of a cell property (cell, 1 x m)
        %
        % An empty entry means the corresponding property holds a numeric values
        myprop2Numeric
        % hWaitbar Handle of a general waitbar used in some functions (double, 1 x 1)
        hWaitbar = NaN;
        % isVideo True\false whether not to load Video objects but keep them as structure (scalar logical)
        isVideo = true;
    end
    
    properties (GetAccess = protected, SetAccess = protected, Transient = true)
        % p_memory Private property to hold information on memory consumption (double 1 x length(obj.myprop))
        p_memory  = [];
        % p_dir Private property to hold directory names for experiments (categorical)
        p_dir     = [];
        % p_uuidStr Private property to hold uuids of experiments as short string (cellstr)
        p_uuidStr = [];
        % p_liquids Storage for liquids
        p_liquids = [];
    end
    
    %% Events
    events
        % resetSelection Notify on selection change
        resetSelection
        % resetSettings Notify on change of settings, i.e. VIP
        resetSettings
        % resetData Notify on data change
        resetData
        % resetNew Notify whenever the UUID changes or new data is added or removed
        resetNew
        % resetMemory Notify whenever the memory usage of a property is recomputed
        resetMemory
        % deleteObject Notify when the object delete function is called, a GUI may listen to this
        deleteObject
    end
    
    %% Constructor, SET/GET
    methods
        function obj = NGS01(varargin)
            % NGS01 Class constructor accepting number of experiments that should be allocated as
            % first input and/or some class properties in <propertyname>, <propertyvalue> style,
            % number of experiments can also be omitted
            
            % get number of experiments and options
            if numel(varargin) < 1
                nExp  = 1;
                optIn = {};
            elseif numel(varargin) == 1 && isnumeric(varargin{1}) && isscalar(varargin{1})
                nExp  = varargin{1};
                optIn = {};
            elseif numel(varargin) > 1 && mod(numel(varargin),2) == 1 && isnumeric(varargin{1}) && isscalar(varargin{1})
                nExp = varargin{1};
                optIn = varargin(2:end);
            elseif numel(varargin) > 1 && mod(numel(varargin),2) == 0 && ischar(varargin{1})
                nExp = 1;
                optIn = varargin;
            else
                error(sprintf('%s:Input',mfilename),...
                    ['Constructor of class ''%s'' accepts number of experiments that should be ',...
                    'allocated as first input and/or some class settings in <propertyname>, <propertyvalue> style',...
                    ', number of experiments can also be omitted'],class(obj));
            end
            % use input parser to process options, filter for explicitly entered properties and set
            % class properties that are given as input
            opt               = inputParser;
            opt.StructExpand  = true;
            opt.KeepUnmatched = false;
            opt.addParameter('rootdir', '', ...
                @(x) isempty(x) || (ischar(x) && exist(x,'dir') ==7));
            opt.addParameter('parameterFile', '', ...
                @(x) isempty(x) || ischar(x));
            opt.addParameter('dataFilePrefix', '', ...
                @(x) isempty(x) || ischar(x));
            opt.addParameter('formatUID', '', ...
                @(x) isempty(x) || ischar(x));
            opt.addParameter('formatIndex', '', ...
                @(x) isempty(x) || ischar(x));
            opt.addParameter('formatDate', '', ...
                @(x) isempty(x) || ischar(x));
            opt.addParameter('labbook', '', ...
                @(x) isempty(x) || ischar(x));
            % include certain UID(s) (ignore everything else)
            opt.addParameter('includeUID', [], ...
                @(x) isempty(x) || isnumeric(x));
            % exclude certain UIDs from reading (applied after includeUID)
            opt.addParameter('excludeUID', [], ...
                @(x) isempty(x) || isnumeric(x));
            % include certain name(s) (ignore everything else)
            opt.addParameter('includeName', [], ...
                @(x) isempty(x) || ischar(x) || iscellstr(x));
            % exclude certain name(s) (applied after includeName)
            opt.addParameter('excludeName', [], ...
                @(x) isempty(x) || ischar(x) || iscellstr(x));
            % ignore any data file (MAT file with class properties) when reading the data and use
            % the parameter file (M file) instead
            opt.addParameter('ignoreDat', false, ...
                @(x) islogical(x) && isscalar(x));
            % true/false whether to load Video objects
            opt.addParameter('isVideo', true, ...
                @(x) islogical(x) && isscalar(x));
            opt.parse(optIn{:});
            % remove field that are not a class property and keep only non-defaults for class
            % properties
            excludeUID  = opt.Results.excludeUID;
            includeUID  = opt.Results.includeUID;
            includeName = opt.Results.includeName;
            excludeName = opt.Results.excludeName;
            ignoreDat   = opt.Results.ignoreDat;
            obj.isVideo = opt.Results.isVideo;
            if ischar(includeName), includeName = {includeName}; end
            if ischar(excludeName), excludeName = {excludeName}; end
            opt = rmfield(opt.Results,opt.UsingDefaults);
            if isfield(opt,'includeUID'), opt = rmfield(opt,'includeUID');  end
            if isfield(opt,'excludeUID'), opt = rmfield(opt,'excludeUID');  end
            if isfield(opt,'excludeName'),opt = rmfield(opt,'excludeName'); end
            if isfield(opt,'includeName'),opt = rmfield(opt,'includeName'); end
            if isfield(opt,'ignoreDat'),  opt = rmfield(opt,'ignoreDat');   end
            if isfield(opt,'isVideo'),    opt = rmfield(opt,'isVideo');     end
            fn = fieldnames(opt);
            for i = 1:numel(fn)
                obj.(fn{i}) = opt.(fn{i});
            end
            % replace video by struct early on to fake it is not a Video at all
            if ~obj.isVideo
                props = prop2Set(obj);
                for i = 1:numel(props)
                    if isa(obj.(props{i}),'Video')
                        obj.(props{i}) = saveobj(obj.(props{i}));
                    end
                end
            end
            % allocate number of experiments
            [props, defVal] = prop2Set(obj);
            for i = 1:numel(props), obj.(props{i}) = repmat(defVal{i},nExp,1); end
            % check settings in subclass
            if ~iscellstr(obj.vip) || ~all(ismember(obj.vip,obj.myprop))
                error(sprintf('%s:Check',mfilename),...
                    'Selected vip are not valid for class ''%s''',class(obj));
            end
            for i = 1:numel(obj.myprop)
                xStr = obj.myprop{i};
                xDat = obj.(xStr);
                y    = obj.myprop2Numeric{i};
                if ~(size(xDat,1) == obj.numAbs && (...
                        isa(xDat,'numeric')  || isa(xDat,'logical') || isa(xDat,'char') || ...
                        isa(xDat,'cell')     || isa(xDat,'struct')  || isa(xDat,'datetime') || ...
                        isa(xDat,'Video')    || isa(xDat,'duration')|| isa(xDat,'categorical') || ...
                        isa(xDat,'UC')       || isa(xDat,'DimVar') ...
                        ) && ((obj.ismyarray(xDat) && isempty(y)) || (~obj.ismyarray(xDat) && ~isempty(y))))
                    error(sprintf('%s:Check',mfilename),['Class property ''%s'' is not valid ',...
                        'physical property for class ''%s'', make sure it is a valid data type and ',...
                        '- in case it is not a float - provide a %s2Numeric function for ',...
                        'proper conversion'], xStr, class(obj), xStr);
                end
                if ~isempty(y)
                    % repmat the object to check if the number of elements are correct as well
                    tmp = obj.myprop2Numeric{i}(obj,repmat(xDat,2,1),[1:obj.numAbs 1:obj.numAbs]');
                    if ~(iscolumn(tmp) && isnumeric(tmp) && 2*obj.numAbs == numel(tmp))
                        error(sprintf('%s:Check',mfilename),['Conversion of class property ''%s'' to ',...
                            'numeric (double or single) by ''%s'' is not valid for class ''%s'', '...
                            'make sure the function returns a column vector of float values with as ',...
                            'many elements as experiments'],xStr,func2str(obj.myprop2Numeric{i}),class(obj));
                    end
                end
            end
            % check number of properties
            if ~obj.isSync
                error(sprintf('%s:Check',mfilename),'Length of data in object of class ''%s'' is out of sync',class(obj));
            end
            %
            % scan root directory for experiments with valid parameter file and read their data.
            % This used to be in the subclass, but all information is read: any known property is
            % put to class properties and anything that is left is put to the data property
            if exist(obj.rootdir,'dir') == 7
                myFiles = findParameterFiles(obj,ignoreDat);
                nMax    = ceil(log10(size(myFiles,1)));
                fprintf('%*d parameter file(s) (''%s'') found in root directory ''%s''\n',...
                    nMax,size(myFiles,1),obj.parameterFile,obj.rootdir);
                if numel(includeUID) > 0
                    idx      = cellfun(@(x) ismember(x,includeUID),myFiles(:,3));
                    myFiles  = myFiles(idx,:);
                    fprintf('%*d parameter file(s) are included based on their UID\n',nMax,sum(idx));
                end
                if numel(excludeUID) > 0
                    idx          = cellfun(@(x) ismember(x,excludeUID),myFiles(:,3));
                    myFiles(idx,:) = [];
                    fprintf('%*d parameter file(s) are excluded based on their UID\n',nMax,sum(idx));
                end
                fprintf('%*d parameter file(s) are tried to be read into memory\n',nMax,size(myFiles,1));
                % run each parameter file with class as first argument, extract information from
                % output and add data to object; if a data file is available, use the data from that
                % file instead.
                if size(myFiles,1) > 0
                    bakdir     = pwd;
                    expCounter = 1;
                    myWaitbar(obj,'start',sprintf('Reading %d parameter file(s)...',size(myFiles,1)));
                    allGood = true;
                    for i = 1:size(myFiles,1)
                        % check for waitbar
                        if myWaitbar(obj,'check',sprintf(['Canceled after %d of %d parameter ',...
                                'file(s)\n'],i-1,size(myFiles,1))), break; end
                        % get a parameter file (an M file) to execute or a MAT file to load
                        [pathstr,fname,ext] = fileparts(myFiles{i,1});
                        if strcmp(ext,'.m')
                            fprintf('  ''%s'': ',myFiles{i,1});
                        else
                            fprintf('  ''%s'' (data file): ',myFiles{i,1});
                        end
                        % change working directory such that any code or load process can see the
                        % local files in the folder of the experiment
                        cd(pathstr);
                        if strcmp(ext,'.m')
                            % call the function that handles parameter files
                            try
                                out = obj.readParameters(fname,class(obj));
                            catch err
                                fprintf('error while reading the parameter file: %s ',err.getReport);
                                allGood = false;
                                out     = [];
                            end
                            % check for the minimum information required for any NGS01 class
                            if isempty(out)
                                nExp = 0;
                            elseif isstruct(out) && numel(out) == 1 && all(isfield(out,...
                                    {'name', 'version', 'user', 'comment', 'time'}))
                                % in case time is a duration it is interpreted as time of the
                                % day of measurement, in case it is a datetime or datenume, the
                                % correct day is checked and corrected
                                if isfloat(out.time)
                                    out.time = datetime(out.time,'ConvertFrom','datenum');
                                    fprintf('converting time from float to datetime, ');
                                    allGood = false;
                                end
                                if isa(out.time,'duration')
                                    out.time = out.time + myFiles{i,2};
                                elseif isa(out.time,'datetime') && any(out.time-myFiles{i,2} > 24)
                                    for j = 1:numel(out.time)
                                        out.time(j) = out.time(j) - datetime(out.time(j).Year,...
                                            out.time(j).Mounth,out.time(j).Day) + myFiles{i,2};
                                    end
                                    fprintf('adjusting time to match parent folder name, ');
                                    allGood = false;
                                end
                                % check for UID and index
                                if isfield(out,'uid') && any(out.uid ~= myFiles{i,3})
                                    out.uid = repmat(uint32(myFiles{i,3}),size(out.uid));
                                    fprintf('adjusting UID to match parent folder name, ');
                                    allGood = false;
                                elseif ~isfield(out,'uid')
                                    out.uid = repmat(uint32(myFiles{i,3}),size(out.time));
                                end
                                if ~isfield(out,'index')
                                    out.index = uint32(reshape(1:numel(out.uid),size(out.time)));
                                end
                                % process further to match current class definition
                                [out, nExp, myGood] = readProperties(obj,out,props,...
                                    defVal,includeName,excludeName);
                                allGood = allGood && myGood;
                            else
                                fprintf('unknown parameter file, ');
                                allGood = false;
                                nExp    = 0;
                            end
                        else
                            % load data from MAT file
                            try
                                [out, nExp, myGood] = readProperties(obj,myFiles{i,1},props,...
                                    defVal,includeName,excludeName);
                            catch err
                                fprintf('error while loading data file: %s ',err.getReport);
                                allGood = false;
                                nExp    = 0;
                            end
                            allGood = allGood && myGood;
                        end
                        % add data to object
                        if nExp > 0
                            idxExp = expCounter:(expCounter+nExp-1);
                            if max(idxExp)-obj.numAbs > 0
                                extend(obj,max(idxExp)-obj.numAbs);
                            end
                            fn = fieldnames(out);
                            for k = 1:numel(fn)
                                obj.set(idxExp,fn{k},out.(fn{k}));
                            end
                            expCounter = expCounter + numel(idxExp);
                            fprintf('%3d entry(ies) read\n',numel(idxExp));
                        else
                            fprintf('%3d entry(ies) read\n',0);
                        end
                        myWaitbar(obj,'update',i/size(myFiles,1));
                    end
                    cd(bakdir);
                    myWaitbar(obj,'end');
                    if ~allGood
                        warning(sprintf('%s:Check',mfilename),['Some parameter or data file(s) could ',...
                            'not be read without any issue, please check previous output to command line ',...
                            'for an explanation of the issue(s)']);
                    end
                end
            else
                warning(sprintf('%s:Input',mfilename),...
                    ['Constructor of class ''%s'' cannot find the root directory ''%s'', ',...
                    'creating object with default values'],class(obj),obj.rootdir);
            end
            % check if experiments are unique
            if ~obj.isUnique
                warning(sprintf('%s:Check',mfilename),'Experiments in object of class ''%s'' are not unique',class(obj));
            end
            % check number of properties
            if ~obj.isSync
                error(sprintf('%s:Check',mfilename),'Length of data in object of class ''%s'' is out of sync',class(obj));
            end
            % select all experiments
            select(obj,true(obj.numAbs,1));
            % set infopanel
            myinfo = {'NGS01Infotab_Property', 'NGS01Infotab_Experiment' 'NGS01Infotab_Selection',...
                'NGS01Infotab_Histogram','NGS01Infotab_Overview'};
            if ismember('Video',obj.myclass), myinfo{end+1} = 'NGS01Infotab_Video'; end
            obj.infopanel = myinfo;
        end
        
        function         delete(obj)
            % delete Class destructor
            
            notify(obj,'deleteObject');
        end
        
        function out = get.uuid(obj)
            out = obj.getUUID(obj.uid,obj.index);
        end
        
        function set.uuid(obj,value)
            if isa(value,'uint64') && numel(value) == obj.numAbs
                value     = value(:);
                % Option 1: see get.uuid
                % tmp       = bitshift(value,-32);
                % obj.index = uint32(value-tmp*2^32);
                % obj.uid   = uint32(tmp);
                % Option 2: see get.uuid
                tmp       = uint32(value/1e9);
                obj.index = uint32(value-uint64(tmp)*1e9);
                obj.uid   = tmp;
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for uuid');
            end
        end
        
        function out = get.isUnique(obj)
            tmp = obj.uuid;
            if numel(tmp) == numel(unique(tmp))
                out = true;
            else
                out = false;
            end
        end
        
        function out = get.ind(obj)
            out = find(obj.enable);
        end
        
        function out = get.rel(obj)
            tmp      = obj.enable;
            out      = NaN(size(tmp));
            out(tmp) = 1:sum(tmp);
        end
        
        function out = get.numAbs(obj)
            out = numel(obj.enable);
        end
        
        function out = get.numSel(obj)
            out = numel(find(obj.enable));
        end
        
        function out = get.memory(obj)
            
            % initialize private property that holds memory usage for each property in obj.myprop
            if isempty(obj.p_memory) || numel(obj.p_memory) ~= numel(obj.myprop2Set)
                obj.p_memory = NaN(size(obj.myprop2Set));
            end
            % find properties that are not up-to-date
            ind = reshape(find(isnan(obj.p_memory)),1,[]); %#ok<*PROP>
            for i = ind
                % create variable in current workspace and compute size, except for Video object
                % that has its own method to determine its memory usage
                curval = obj.(obj.myprop2Set{i});
                if isa(curval,'Video')
                    obj.p_memory(i) = sum([curval.memory]);
                else
                    fileInfo        = whos('curval','bytes');
                    obj.p_memory(i) = fileInfo.bytes/1024^2;
                end
            end
            out = obj.p_memory;
        end
        
        function out = get.vip2Numeric(obj)
            [~,ind] = ismember(obj.vip,obj.myprop);
            out     = obj.myprop2Numeric(ind);
        end
        
        function out = get.myprop(obj)
            if isempty(obj.myprop)
                % note: does not include private properties, exclude protected properties by
                % considering only the public properties
                mc    = metaclass(obj);
                props = [mc.Properties{:}];
                idx   = arrayfun(@(x) ~x.Constant && ischar(x.GetAccess) && strcmp(x.GetAccess,'public'),props);
                obj.myprop = setdiff({props(idx).Name},[obj.noprop(:)' obj.nopropsub(:)']);
            end
            out = obj.myprop;
        end
        
        function out = get.mypropSize(obj)
            if isempty(obj.mypropSize)
                obj.mypropSize = cell(size(obj.myprop));
                for i = 1:numel(obj.mypropSize)
                    obj.mypropSize{i}    = size(obj.(obj.myprop{i}));
                    obj.mypropSize{i}(1) = 1;
                end
            end
            out = obj.mypropSize;
        end
        
        function out = get.mydesc(obj)
            if isempty(obj.mydesc)
                % use the rather slow help function to query information on each property
                obj.mydesc = reshape(physicalProperties(obj,obj.myprop,true),size(obj.myprop));
            end
            out = obj.mydesc;
        end
        
        function out = get.myprop2Set(obj)
            if isempty(obj.myprop2Set)
                [obj.myprop2Set, obj.myprop2SetDefault] = prop2Set(obj);
            end
            out = obj.myprop2Set;
        end
        
        function out = get.myprop2SetDefault(obj)
            if isempty(obj.myprop2SetDefault)
                [obj.myprop2Set, obj.myprop2SetDefault] = prop2Set(obj);
            end
            out = obj.myprop2SetDefault;
        end
        
        function out = get.myprop2SetSize(obj)
            if isempty(obj.myprop2SetSize)
                obj.myprop2SetSize = cell(size(obj.myprop2Set));
                tmp                = obj.myprop2SetDefault;
                for i = 1:numel(obj.myprop2SetSize)
                    obj.myprop2SetSize{i} = size(tmp{i});
                end
            end
            out = obj.myprop2SetSize;
        end
        
        function out = get.myclass(obj)
            if isempty(obj.myclass)
                obj.myclass = cell(size(obj.myprop));
                for i = 1:numel(obj.myclass)
                    obj.myclass{i} = class(obj.(obj.myprop{i}));
                end
            end
            out = obj.myclass;
        end
        
        function out = get.myprop2Numeric(obj)
            if isempty(obj.myprop2Numeric)
                mc    = metaclass(obj);
                meth  = [mc.Methods{:}];
                meth  = {meth.Name};
                names = cellfun(@(x) sprintf('%s2Numeric',x),obj.myprop,'uniformOutput',false);
                idx   = ismember(names,meth);
                obj.myprop2Numeric      = cell(size(obj.myprop));
                obj.myprop2Numeric(idx) = cellfun(@str2func,names(idx),'UniformOutput',false);
            end
            out = obj.myprop2Numeric;
        end
        
        function out = get.isSync(obj)
            props = obj.myprop2Set;
            out   = true;
            for i = 1:numel(props)
                if size(obj.(props{i}),1) ~= obj.numAbs
                    out = false;
                    return;
                end
            end
        end
        
        function out = get.infoStruct(obj)
            idx = obj.enable;
            for i = 1:numel(obj.vip)
                if all(~idx)
                    curval = NaN;
                else
                    curval = get(obj,obj.vip{i});
                end
                out.(obj.vip{i}).min  = min(curval(:));
                out.(obj.vip{i}).mean = mean(curval(:));
                out.(obj.vip{i}).max  = max(curval(:));
                out.(obj.vip{i}).std  = std(curval(:));
            end
        end
        
        function out = get.info(obj)
            tmp   = obj.infoStruct;
            fn    = fieldnames(tmp);
            fn2   = fieldnames(tmp.(fn{1}));
            nChar = max(cellfun(@numel,fn));
            div   = repmat('-',1,nChar+14*4+1);
            out   = [sprintf('%s, %.2f MiB, Statistics on selected experiment(s) (%d of %d):\n', ...
                class(obj),sum(obj.memory),numel(obj.ind),obj.numAbs) sprintf('%s\n%*s ',div,nChar,' ')];
            for i = 1:numel(fn2)
                out = [out, sprintf('   %11s',upper(fn2{i}))]; %#ok<AGROW>
            end
            out = [out sprintf('\n%s\n',div)];
            for i = 1:numel(fn)
                out = [out, sprintf('%*s:',nChar,fn{i})]; %#ok<AGROW>
                for k = 1:numel(fn2)
                    out = [out, sprintf('   %+#11.4e',tmp.(fn{i}).(fn2{k}))]; %#ok<AGROW>
                end
                out = [out sprintf('\n')]; %#ok<AGROW>
            end
            out = [out sprintf('%s\n',div)];
            out = [out sprintf('Memory usage: %.2f MiB, Selected experiments: %d of %d\n', ...
                sum(obj.memory),numel(obj.ind),obj.numAbs)];
        end
        
        function out = get.liquids(obj)
            if isempty(obj.p_liquids)
                updateLiquids(obj);
            end
            out = obj.p_liquids;
        end
        
        function       set.liquids(obj,value)
            if istable(value) && all(ismember({'solvent' 'solute' 'name' 'lambertBeerAlpha'...
                    'massFraction' 'density' 'surfaceTension' 'date'}, value.Properties.VariableNames))
                obj.p_liquids = value;
            else
                error(sprintf('%s:Input',mfilename),'Unknown input for table with liquids');
            end
        end
        
        function       set.sel(obj,value)
            
            % check input
            % * Must be struct
            % * Do not allow specific names
            if ~(isstruct(value) && isscalar(value))
                error(sprintf('%s:Input',mfilename),'Expected structure as input, e.g. obj.sel.<name of selection> = <definition>');
            end
            fn = fieldnames(value);
            for i = 1:numel(fn) %#ok<*PROPLC>
                if ismember(fn{i},{'all','a','inverse','i','none','n',...
                        'today','daily','week','weekly','month','monthly','year','yearly'}) || ...
                        (numel(fn{i}) > 5 && strcmp(fn{i}(1:4),'last') && strcmp(fn{i}(end),'d') && ...
                        all(ismember(fn{i}(5:end-1),'1234567890')))
                    error(sprintf('%s:Input',mfilename),'Name of new selection ''%s'' is reserved by a builtin selection command',fn{i});
                elseif ismember(fn{i},obj.myprop) %#ok<MCSUP>
                    error(sprintf('%s:Input',mfilename),'Name of new selection ''%s'' is reserved by a physical property',fn{i});
                elseif ~(iscell(value.(fn{i})) || ischar(value.(fn{i})) || ...
                        (isnumeric(value.(fn{i})) && ~isempty(value.(fn{i})) && min(value.(fn{i})(:)) > 0) || ...
                        islogical(value.(fn{i})) || isempty(value.(fn{i})))
                    error(sprintf('%s:Input',mfilename),'Data type ''%s'' of new selection ''%s'' is not valid',...
                        class(value.(fn{i})),fn{i});
                end
            end
            obj.sel = value;
        end
        
        function       set.formatDate(obj,value)
            if ischar(value)
                obj.formatDate = value;
                fprintf('Expected string format for directories based on time (example for current time): ''%s'' \n', ...
                    datestr(datetime('now'),obj.formatDate));
            else
                error(sprintf('%s:Input',mfilename),'Format is not valid');
            end
        end
        
        function       set.formatUID(obj,value)
            if ischar(value)
                obj.formatUID = value;
                fprintf(['Expected string format for uids (example for an uid of ''42''): ',...
                    obj.formatUID,'\n'], 42);
            else
                error(sprintf('%s:Input',mfilename),'Format is not valid');
            end
        end
        
        function       set.formatIndex(obj,value)
            if ischar(value)
                obj.formatIndex = value;
                fprintf(['Expected string format for indices (example for an index of ''42''): ', ...
                    obj.formatIndex,'\n'], 42);
            else
                error(sprintf('%s:Input',mfilename),'Format is not valid');
            end
        end
        
        function       set.rootdir(obj,value)
            if isempty(value)
                obj.rootdir = '';
                fprintf('Root directory set to current directory (adapts dynamically)\n');
            elseif ischar(value) && exist(value,'dir') ~= 7
                error(sprintf('%s:Input',mfilename),'Root directory is not existing');
            elseif ischar(value) && exist(value,'dir') == 7
                obj.rootdir = value;
                fprintf('Root directory set to: ''%s''\n', obj.rootdir);
            else
                error(sprintf('%s:Input',mfilename),'Unknown input for root directroy');
            end
        end
        
        function out = get.rootdir(obj)
            if isempty(obj.rootdir)
                out = pwd;
            else
                out = obj.rootdir;
            end
        end
        
        function       set.parameterFile(obj,value)
            if isempty(value)
                obj.parameterFile = 'parameters.m';
                fprintf('Parameter file set to default ''%s''\n',obj.parameterFile);
            elseif ischar(value) && numel(value) > 1
                [~,~,ext] = fileparts(value);
                if ~strcmp(ext,'.m')
                    error(sprintf('%s:Input',mfilename),'Parameter file must be a MATLAB .m file');
                else
                    obj.parameterFile = value;
                    fprintf('Parameter file set to: ''%s''\n', obj.parameterFile);
                end
            else
                error(sprintf('%s:Input',mfilename),'Unknown input for parameter file');
            end
        end
        
        function       set.labbook(obj,value)
            if isempty(value)
                obj.labbook = 'Labbook.xlsx';
                fprintf('Labbok set to default ''%s''\n',obj.labbook);
            elseif ischar(value) && numel(value) > 1
                [~,~,ext] = fileparts(value);
                if ~strcmp(ext,'.xlsx')
                    error(sprintf('%s:Input',mfilename),'Parameter file must be an Excel .xlsx file');
                else
                    obj.labbook = value;
                    fprintf('Labbook set to: ''%s''\n', obj.labbook);
                end
            else
                error(sprintf('%s:Input',mfilename),'Unknown input for labbook');
            end
        end
        
        function       set.dataFilePrefix(obj,value)
            if isempty(value)
                obj.dataFilePrefix = 'data_';
                fprintf('Data file prefix set to default ''%s''\n',obj.dataFilePrefix);
            elseif ischar(value) && numel(value) > 1
                obj.dataFilePrefix = value;
                fprintf('Data file prefix et to: ''%s''\n', obj.dataFilePrefix);
            else
                error(sprintf('%s:Input',mfilename),'Unknown input for data file prefix');
            end
        end
        
        function       set.verbose(obj,value)
            if isempty(value)
                obj.verbose = Inf;
                fprintf('Verbosity set to default of %d\n',obj.verbose);
            elseif isnumeric(value) && isscalar(value)
                obj.verbose = double(round(value));
                fprintf('Verbosity set to %d\n',obj.verbose);
            else
                error(sprintf('%s:Input',mfilename),'Unknown input for verbose');
            end
        end
        
        function       set.time(obj,value)
            if isa(value,'datetime')
                obj.time = value(:);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for time');
            end
        end
        
        function       set.period(obj,value)
            if isa(value,'duration')
                obj.period = value(:);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for period');
            end
        end
        
        function       set.uid(obj,value)
            if isa(value,'uint32')
                obj.uid = value(:);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for uid');
            end
        end
        
        function       set.index(obj,value)
            if isa(value,'uint32')
                if any(value > uint32(1e9))
                    error(sprintf('%s:Input',mfilename),['Input results in UUID not being unique any ',...
                        'more in current implementation, consider to change implementation to bitshifting']);
                end
                obj.index = value(:);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for index');
            end
        end
        
        function       set.setName(obj,value)
            if isa(value,'categorical')
                obj.setName = value(:);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for setName');
            end
        end
        
        function       set.enable(obj,value)
            if isa(value,'logical')
                obj.enable = value(:);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for enable');
            end
        end
        
        function       set.userdata(obj,value)
            if iscell(value)
                obj.userdata = value(:);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for userdata');
            end
        end
        
        function       set.comment(obj,value)
            if iscell(value)
                obj.comment = value(:);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for comment');
            end
        end
        
        function       set.name(obj,value)
            if iscategorical(value)
                obj.name = value(:);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for name');
            end
        end
        
        function       set.version(obj,value)
            if isa(value,'double')
                obj.version = value(:);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for version');
            end
        end
        
        function       set.status(obj,value)
            if isa(value,'double')
                obj.status = value(:);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for status');
            end
        end
        
        function       set.options(obj,value)
            if iscell(value)
                obj.options = value(:);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for options');
            end
        end
        
        function       set.data(obj,value)
            if iscell(value)
                obj.data = value(:);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for data');
            end
        end
        
        function       set.user(obj,value)
            if iscategorical(value)
                obj.user = value(:);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for user');
            end
        end
        
        function out = get.t(obj)
            out = obj.time;
        end
        
        function       set.t(obj,value)
            obj.time = value;
        end
        
        function out = get.p(obj)
            out = obj.period;
        end
        
        function       set.p(obj,value)
            obj.period = value;
        end
        
        function out = get.u(obj)
            out = obj.uid;
        end
        
        function       set.u(obj,value)
            obj.uid = value;
        end
        
        function out = get.i(obj)
            out = obj.index;
        end
        
        function       set.i(obj,value)
            obj.index = value;
        end
        
        function out = get.sn(obj)
            out = obj.setName;
        end
        
        function       set.sn(obj,value)
            obj.setName = value;
        end
        
        function out = get.c(obj)
            out = obj.comment;
        end
        
        function       set.c(obj,value)
            obj.comment = value;
        end
        
        function out = get.n(obj)
            out = obj.name;
        end
        
        function       set.n(obj,value)
            obj.name = value;
        end
        
        function out = get.v(obj)
            out = obj.version;
        end
        
        function       set.v(obj,value)
            obj.version = value;
        end
        
        function out = get.o(obj)
            out = obj.options;
        end
        
        function       set.o(obj,value)
            obj.options = value;
        end
        
        function out = get.d(obj)
            out = obj.data;
        end
        
        function       set.d(obj,value)
            obj.data = value;
        end
        
        function out = get.ud(obj)
            out = obj.userdata;
        end
        
        function       set.ud(obj,value)
            obj.userdata = value;
        end
        
        function out = get.s(obj)
            out = obj.status;
        end
        
        function       set.s(obj,value)
            obj.status = value;
        end
        
        function out = get.dir(obj)
            % recompute properties if property is empty
            if isempty(obj.p_dir)
                rd        = obj.rootdir;
                obj.p_dir = categorical(reshape(arrayfun(@(x,y) fullfile(rd,datestr(x,obj.formatDate),...
                    sprintf(obj.formatUID,y)),obj.time,obj.uid,'UniformOutput',false),[],1));
            end
            out = obj.p_dir;
        end
        
        function out = get.uuidStr(obj)
            % recompute properties if property is empty
            if isempty(obj.p_uuidStr)
                nUID = ceil(log10(double(max(obj.uid))));
                nIND = ceil(log10(double(max(obj.index))));
                obj.p_uuidStr = arrayfun(@(u,i) sprintf('%0.*d-%0.*d',nUID,u,nIND,i),obj.uid,obj.index,'UniformOutput',false);
            end
            out = obj.p_uuidStr;
        end
        
        function       set.vip(obj,value)
            if iscellstr(value) && all(ismember(value,obj.myprop)) %#ok<MCSUP>
                obj.vip = value;
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for vip');
            end
        end
        
        function       set.infopanel(obj,value)
            if iscellstr(value) && all(cellfun(@(x) ~isempty(which(x)),value))
                obj.infopanel = value;
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for infopanel');
            end
        end
    end
    
    %% Methods for indexing/assignment and access control
    methods (Access = public, Hidden = false, Sealed = true)
        function out         = end(obj, k, ~)
            % end Overloads built-in function end function
            if k == 1
                % number of experiments
                out = obj.numAbs;
            else
                error(sprintf('%s:Indexing',mfilename),['Type of indexing is not supported for ',...
                    'object of class ''%s'''], class(obj));
            end
        end
        
        function out         = numArgumentsFromSubscript(obj,S,ctext)
            % numArgumentsFromSubscript Returns number of output arguments
            
            Snew = getSubstruct(obj,S,true,true);
            % If a function of a property is called in dot notation, we expect only one output. For
            % example: obj.video.play refers to the PLAY function of a property of the Video class
            % (assuming video was of the class Video). Otherwise, just return builtin value of the
            % referenced property. NOTE: this distinction has only to be made for physical
            % properties that allow for a dot notation at the end to call a function.
            if strcmp(Snew(end).type,'.') && ismember(Snew(1).subs,obj.myprop)
                % make a local copy of the value since it might be a dependent property that takes
                % time to compute each time it is referenced
                [isProp2Set, idxProp] = ismember(Snew(1).subs,obj.myprop2Set);
                if isProp2Set
                    val = obj.myprop2SetDefault{idxProp};
                else
                    val = obj.(Snew(1).subs);
                end
                % use ISA function to include derived classes as well, such as the BeamProfiler
                % class derived from the Video class
                if isa(val,'Video') || isa(val,'datetime') || isa(val,'duration') || ...
                        isa(val,'UC') || isa(val,'DimVar')
                    mc           = metaclass(val);
                    [idxOK, idx] = ismember(Snew(end).subs,{mc.MethodList.Name});
                    if idxOK
                        out = min(1,numel(mc.MethodList(idx).OutputNames));
                    else
                        out = builtin('numArgumentsFromSubscript', obj,Snew,ctext);
                    end
                else
                    out = builtin('numArgumentsFromSubscript', obj,Snew,ctext);
                end
            else
                mc           = metaclass(obj);
                [idxOK, idx] = ismember(Snew(1).subs,{mc.MethodList.Name});
                if idxOK
                    if numel(mc.MethodList(idx).OutputNames) && ...
                            strcmp(mc.MethodList(idx).OutputNames{1},'varargout')
                        out = 0;
                    else
                        out = min(1,numel(mc.MethodList(idx).OutputNames));
                    end
                else
                    out = builtin('numArgumentsFromSubscript', obj, Snew, ctext);
                end
            end
        end
        
        function varargout   = subsref(obj, S)
            % subsref Redefines subscripted reference for objects
            %
            % obj( <select experiment> ).<property name><further indexing>
            % * <select experiment>:    Current selection if omitted, otherwise input to findExp
            % * <further indexing>:   	Matlab indexing for cell, array, etc. working on selected
            %                           experiments
            %
            % Note: Calls starting with obj( <select experiment> ) set a new selection
            
            %
            % set selection and get new indexing
            S = getSubstruct(obj,S,true,true);
            %
            % return data
            if isempty(S)
                % user only selected different experiments, i.e. obj(<something>)
                [varargout{1:nargout}] = obj;
            else
                % user wants to index deeper into object
                [varargout{1:nargout}] = builtin('subsref', obj, S);
            end
        end
        
        function obj         = subsasgn(obj, S, B)
            % subsasgn Redefines subscripted assignment for objects
            
            %
            % set selection and get new indexing
            S = getSubstruct(obj,S,true,true);
            %
            % set new data
            if isempty(S)
                % user wants to set complete object and gave some selection, i.e. obj(<something>) =
                % <something else>
                if isa(B,class(obj)) && numel(B) == 1
                    warning(sprintf('%s:Indexing',mfilename), ...
                        ['Assignment of the complete object of class ''%s'' included a selection that was ignored, ',...
                        'since the complete object was assigned'], class(obj(1)));
                    obj = B;
                    notifyMe(obj,'resetNew');
                    return;
                else
                    error(sprintf('%s:Indexing',mfilename), ...
                        'Assigning the complete object of class ''%s'' requires the same kind of object as input', class(obj(1)));
                end
            elseif hIsPublicSetProperty(obj, S(1).subs) && ismember(S(1).subs,obj.myprop)
                resetEvent = 'resetData';
                % make a local copy of the value since it might be a dependent property that takes
                % time to compute each time it is referenced
                [isProp2Set, idxProp] = ismember(S(1).subs,obj.myprop2Set);
                if isProp2Set
                    val    = obj.myprop2SetDefault{idxProp};
                    siz    = obj.myprop2SetSize{idxProp};
                    siz(1) = obj.numAbs;
                else
                    val = obj.(S(1).subs);
                    siz = size(val);
                end
                % perform some checks and conversion to correct class if indexing goes not deep
                % into a property, e.g. not deep into a structure or cell
                if numel(S) <= 2
                    % do not allow deletion of elements, remove method should be used instead
                    if isempty(B) && strcmp(S(2).type,'()')
                        error(sprintf('%s:Indexing',mfilename), ...
                            ['Removing elements from a single physical properties ',...
                            '(or setting the complete property to an empty value) ',...
                            'is not supported for objects of class ''%s'' . Please, ',...
                            'use the REMOVE method to delete complete experiments'], class(obj));
                    end
                    % convert input for some specific properties
                    switch S(1).subs
                        case {'index','uid','u','i'}
                            if ~isa(B,'uint32') && isnumeric(B)
                                B = uint32(B);
                            elseif ~isa(B,'uint32')
                                error(sprintf('%s:Input',mfilename), ...
                                    ['Input of type ''%s'' is not supported for property ''%s'' of the class ''%s'', ',...
                                    'property is of type ''%s'' (any numeric input is converted to uint32)'],...
                                    class(B), S(1).subs, class(obj), class(val));
                            end
                            resetEvent = 'resetNew';
                        case {'time','t'}
                            if ~isa(B,'datetime') && isnumeric(B)
                                B = datetime(B,'ConvertFrom','datenum');
                            elseif ~isa(B,'datetime')
                                error(sprintf('%s:Input',mfilename), ...
                                    ['Input of type ''%s'' is not supported for property ''%s'' of the class ''%s'', ',...
                                    'property is of type ''%s'' (any numeric input is supposed to be a datenum and converted to datetime)'],...
                                    class(B), S(1).subs, class(obj), class(val));
                            end
                        case {'period','p'}
                            if ~isa(B,'duration') && isnumeric(B)
                                B = duration(B,0,0);
                            elseif ~isa(B,'duration')
                                error(sprintf('%s:Input',mfilename), ...
                                    ['Input of type ''%s'' is not supported for property ''%s'' of the class ''%s'', ',...
                                    'property is of type ''%s'' (any numeric input is supposed to be a datenum and converted to duration)'],...
                                    class(B), S(1).subs, class(obj), class(val));
                            end
                        case {'enable'}
                            if ~islogical(B) && isnumeric(B)
                                B = logical(B);
                            elseif ~islogical(B)
                                error(sprintf('%s:Input',mfilename), ...
                                    ['Input of type ''%s'' is not supported for property ''%s'' of the class ''%s'', ',...
                                    'property is of type ''%s'' (any numeric input is converted to logical)'],...
                                    class(B), S(1).subs, class(obj), class(val));
                            end
                        case {'comment' 'c'}
                            % check input and replace [] by '' to obtain a cellstr; split character
                            % input into cellstr (or cell of cellstr according to indexing)
                            wrongInput = false;
                            if iscell(B) && strcmp(S(2).type, '{}')
                                idx    = cellfun('isempty',B);
                                B(idx) = {''};
                                if ~iscellstr(B), wrongInput = true; end
                            elseif iscell(B) && strcmp(S(2).type, '()')
                                for i = 1:numel(B)
                                    if isempty(B{i}), B{i} = {''};
                                    elseif iscell(B{i}) && ~iscellstr(B{i})
                                        idx       = cellfun('isempty',B{i});
                                        B{i}(idx) = {''};
                                        if ~iscellstr(B{i}), wrongInput = true; break; end
                                    elseif iscellstr(B{i})
                                    else, wrongInput = true; break;
                                    end
                                end
                            elseif ischar(B)
                                if strcmp(S(2).type,'()'), B = {strsplit(B,{'\\' '\n' '\r'})};
                                elseif strcmp(S(2).type,'{}'), B = strsplit(B,{'\\' '\n' '\r'});
                                else, wrongInput = true;
                                end
                            else, wrongInput = true;
                            end
                            if wrongInput
                                error(sprintf('%s:Input',mfilename), ...
                                    ['Input of type ''%s'' is not supported for property ''%s'' of the class ''%s'', ',...
                                    'property is a cell of cellstr (i.e. one cellstr per experiment, which could not be obtained from input, {} missing?)'],...
                                    class(B), S(1).subs, class(val));
                            end
                        case {'name' 'n' 'user' 'setName' 'sn'}
                            % check input and replace [] by '' to obtain a cellstr and than convert
                            % to categorical
                            wrongInput = false;
                            if iscell(B) && strcmp(S(2).type, '()')
                                idx    = cellfun('isempty',B);
                                B(idx) = {''};
                                if ~iscellstr(B), wrongInput = true; end
                            end
                            if iscellstr(B)
                                B = categorical(B);
                            elseif ischar(B)
                                B = categorical({B});
                            end
                            if wrongInput
                                error(sprintf('%s:Input',mfilename), ...
                                    ['Input of type ''%s'' is not supported for property ''%s'' ',...
                                    'of the class ''%s'', property is a categorical'],...
                                    class(B), S(1).subs, class(obj));
                            end
                        case {'version','v','status' 's'}
                            if ~isa(B,'double') && isnumeric(B)
                                B = double(B);
                            elseif ~isa(B,'double')
                                error(sprintf('%s:Input',mfilename), ...
                                    ['Input of type ''%s'' is not supported for property ''%s'' of the class ''%s'', ',...
                                    'property is of type ''%s'' (any numeric input is converted to double)'],...
                                    class(B), S(1).subs, class(obj), class(val));
                            end
                        case {'userdata' 'ud' 'data' 'd' 'options' 'o'}
                            if ~((iscell(B) && strcmp(S(2).type, '()')) || strcmp(S(2).type, '{}'))
                                error(sprintf('%s:Input',mfilename), ...
                                    ['Input of type ''%s'' is not supported for property ''%s'' of the class ''%s'', ',...
                                    'property is of type ''%s'''],...
                                    class(B), S(1).subs, class(obj), class(val));
                            end
                        otherwise
                            % conversion for general properties
                            if iscell(val) && strcmp(S(2).type, '{}')
                                % do not perform a cast for {} indexing into a cell property
                            elseif isa(val,'datetime') && isfloat(B)
                                % convert double to datetime assuming a datenum input
                                B = datetime(B,'ConvertFrom','datenum');
                            elseif isa(val,'duration') && isfloat(B)
                                % convert double to duration assuming a datenum kind of input
                                B = duration(B,0,0);
                            elseif isa(val,'categorical') && (iscellstr(B) || ischar(B))
                                % do not convert
                            elseif ~isa(B,class(val))
                                B = cast(B,'like',val);
                            end
                    end
                end
                % if indexing refers to complete property and goes deep into property, i.e. into
                % an object array of all available experiments, remove the second indexing step,
                % note: this is for example necessary for datetime objects (changing the format
                % of a datetime array is only possible when applied to the complete array
                % without indexing, e.g. obj.time.Format instead of obj.time(:).Format).
                if numel(S) > 2 && all(strcmp(S(2).subs,':')) && ...
                        isequal(builtin('subsref', obj, S(1)),builtin('subsref', obj, S(1:2)))
                    S(2) = [];
                end
                % set value(s) in object with builtin method
                obj = builtin('subsasgn', obj, S, B);
                % check size of property to make sure it did not change
                if ~isequal(siz,size(obj.(S(1).subs)))
                    error(sprintf('%s:Indexing',mfilename),['Assignment lead to change in the ',...
                        'size of property ''%s'' in object of class ''%s'', which should not ',...
                        'happen. Please check!'], S(1).subs, class(obj));
                end
                notifyMe(obj,resetEvent,S(1).subs);
            elseif hIsPublicSetProperty(obj, S(1).subs)
                % use default reference scheme
                obj           = builtin('subsasgn', obj, S, B);
                obj.p_dir     = [];
                obj.p_uuidStr = [];
                notifyMe(obj,'resetSettings',S(1).subs);
            else
                % do not allow access to any non-public set property
                error(sprintf('%s:Indexing',mfilename), ...
                    '''%s'' is not a public property of the class ''%s''', S(1).subs, class(obj));
            end
        end
    end
    
    methods (Access = protected, Hidden = false, Sealed = true)
        function Snew = getSubstruct(obj,S,doSelect,doCheck)
            % getSubstruct Converts user indexing (based on selected experiment) into indexing for obj
            
            %
            % check for array of objects
            if numel(obj) > 1
                error(sprintf('%s:Indexing',mfilename), ...
                    'Array of objects are not supported for the class ''%s''', class(obj(1)));
            end
            %
            % set new selection
            if doSelect
                if strcmp(S(1).type, '()')
                    select(obj,S(1).subs{:});
                    S(1) = [];
                elseif strcmp(S(1).type, '{}')
                    error(sprintf('%s:Indexing',mfilename),['Type of indexing ''{}'' is not ',...
                        'supported for object of class ''%s'''], class(obj));
                end
            end
            if isempty(S), Snew = S; return; end
            %
            % check indexing
            if doCheck
                if strcmp(S(1).type, '.') && ~(hIsPublicMethod(obj, S(1).subs) || hIsPublicGetProperty(obj, S(1).subs))
                    % do not allow access to any non-public get property or method
                    error(sprintf('%s:Indexing',mfilename), ...
                        '''%s'' is not a public property or method of the class ''%s''', S(1).subs, class(obj));
                elseif ~strcmp(S(1).type, '.')
                    error(sprintf('%s:Indexing',mfilename), ...
                        'Type of indexing ''%s'' is not supported for object of class ''%s''', S(1).type, class(obj));
                end
            end
            %
            % return new substruct if access to a non-physical property or a method is required
            if strcmp(S(1).type,'.') && ~ismember(S(1).subs,obj.myprop)
                Snew = S;
                return;
            end
            %
            % get linear indices of experiment that are meant by the user, i.e. all selected
            % experiments or a subset of those, create new substruct for further indexing
            [idxOK,idxProp] = ismember(S(1).subs,obj.myprop);
            if idxOK
                siz    = obj.mypropSize{idxProp};
                siz(1) = obj.numAbs;
            else
                siz = size(obj.(S(1).subs));
            end
            if numel(S) == 1 || strcmp(S(2).type, '.')
                % all selected experiments are meant by the user, since no indexing for experiments
                % are given at all
                ind  = obj.ind;
                Snew = substruct('.',S(1).subs,'()',{ind});
                % make sure all all elements (second, third, etc. dimension) for each experiment are
                % returned in case the physical property has more than one element per experiments
                % and the user gave no input at all for this index
                if (siz(2) > 1 || numel(siz) > 2) && (numel(S) == 1 || strcmp(S(2).type, '.'))
                    Snew(2).subs(2:numel(siz)) = {':'};
                end
                % add any remaining indexing deeper into property
                if numel(S) > 1
                    Snew = [Snew S(2:end)];
                end
            elseif strcmp(S(2).type, '()') || strcmp(S(2).type, '{}')
                % a subset of selected experiments is meant by the user, since specific experiments
                % are given in the indexing
                if numel(S(2).subs) > 1 || (siz(2) == 1 && numel(siz) == 2) || ...
                        (isnumeric(S(2).subs{1}) && max(S(2).subs{1}) <= obj.numSel)
                    % first dimension of subs should be applied to selected experiments
                    tmp = substruct('()',S(2).subs(1));
                    ind = builtin('subsref',obj.ind,tmp);
                    S(2).subs{1} = ind;
                    Snew = [substruct('.',S(1).subs) S(2:end)];
                else
                    % user meant linear indexing or put a ':' as first index for a 2D
                    % matrix: create matrix of linear indices of all elements for that
                    % property, use current selection to pick the rows for the current
                    % selected experiments and, finally, the user input to get the elements
                    % requested by the user
                    tmp    = repmat({':'},1,numel(siz)); tmp{1} = obj.ind;
                    linIDX = reshape(1:prod(siz),siz);
                    linIDX = linIDX(tmp{:});
                    linIDX = builtin('subsref',linIDX,S(2));
                    S(2).subs{1} = linIDX;
                    Snew = [substruct('.',S(1).subs) S(2:end)];
                end
            else
                error(sprintf('%s:Indexing',mfilename), ...
                    'Property indexing or assignment of this kind is not supported for the object of class ''%s''', class(obj));
            end
        end
        
        function out  = hIsPublicGetProperty(obj, in)
            % hIsPublicGetProperty Determines if input string is the name of a public get property, case-sensitively.
            persistent publicProperties;
            if isempty(publicProperties)
                mc   = metaclass(obj(1));
                prop = [mc.Properties{:}];
                idx  = arrayfun(@(x) ischar(x.GetAccess) && strcmp(x.GetAccess,'public'),prop);
                publicProperties = {prop(idx).Name};
            end
            out = ismember(in, publicProperties);
        end
        
        function out  = hIsPublicSetProperty(obj, in)
            % hIsPublicSetProperty Determines if input string is the name of a public set property, case-sensitively.
            persistent publicProperties;
            if isempty(publicProperties)
                mc   = metaclass(obj(1));
                prop = [mc.Properties{:}];
                idx  = arrayfun(@(x) ischar(x.SetAccess) && strcmp(x.SetAccess,'public'),prop);
                publicProperties = {prop(idx).Name};
            end
            out = ismember(in, publicProperties);
        end
        
        function out  = hIsPublicMethod(obj, in)
            % hIsPublicMethod Determines if input string is the name of a public method, case-sensitively.
            persistent publicMethod ;
            if isempty(publicMethod)
                mc   = metaclass(obj(1));
                meth = [mc.MethodList];
                idx  = arrayfun(@(x) ischar(x.Access) && strcmp(x.Access,'public'),meth);
                publicMethod = {meth(idx).Name};
            end
            out = ismember(in, publicMethod);
        end
    end
    
    methods (Access = protected)
        function cpObj = copyElement(obj)
            % copyElement Override copyElement method from matlab.mixin.Copyable class
            
            % Make a shallow copy of all properties
            cpObj = copyElement@matlab.mixin.Copyable(obj);
            % Make a deep copy of public Video objects
            props  = obj.myprop2Set;
            defVal = obj.myprop2SetDefault;
            for i = 1:numel(props)
                if isa(defVal{i},'Video'), cpObj.(props{i}) = copy(obj.(props{i})); end
            end
            % reset new object
            reset(cpObj);
        end
    end
    
    %% Methods for conversion of non-numeric physical properties
    % Input to methods here is the object and the actual data that should be converted to a double
    methods (Access = protected, Hidden = false, Sealed = true)
        function out = time2Numeric(obj,data,~) %#ok<INUSL>
            % time2Numeric Transforms time: Convert to datenum
            out = datenum(data);
        end
        
        function out = t2Numeric(obj,data,~)
            % t2Numeric Transforms alias to time
            out = time2Numeric(obj,data);
        end
        
        function out = period2Numeric(obj,data,~) %#ok<INUSL>
            % period2Numeric Transforms duration: Convert to datenum
            out = datenum(data);
        end
        
        function out = p2Numeric(obj,data,~)
            % p2Numeric Transforms alias to period
            out = period2Numeric(obj,data);
        end
        
        function out = userdata2Numeric(obj,data,~) %#ok<INUSL>
            % userdata2Numeric Transforms userdata: Test if data is available
            out = double(cellfun(@(x) ~isempty(x),data));
        end
        
        function out = ud2Numeric(obj,data,~)
            % ud2Numeric Transforms alias to userdata
            out = userdata2Numeric(obj,data);
        end
        
        function out = name2Numeric(obj,data,~) %#ok<INUSL>
            % name2Numeric Transforms name: Return unique double for each name
            out = double(data);
        end
        
        function out = n2Numeric(obj,data,~)
            % n2Numeric Transforms alias to name
            out = name2Numeric(obj,data);
        end
        
        function out = comment2Numeric(obj,data,~) %#ok<INUSL>
            % comment2Numeric Transforms comment: Count number of lines
            out = cellfun(@numel,data);
        end
        
        function out = c2Numeric(obj,data,~)
            % c2Numeric Transforms alias to comment
            out = comment2Numeric(obj,data);
        end
        
        function out = options2Numeric(obj,data,~) %#ok<INUSL>
            % options2Numeric Transforms options: Test if options are available
            out = double(cellfun(@(x) ~isempty(x),data));
        end
        
        function out = o2Numeric(obj,data,~)
            % o2Numeric Transforms alias to options
            out = options2Numeric(obj,data);
        end
        
        function out = data2Numeric(obj,data,~) %#ok<INUSL>
            % data2Numeric Transforms data: Test if data is available
            out = double(cellfun(@(x) ~isempty(x),data));
        end
        
        function out = d2Numeric(obj,data,~)
            % d2Numeric Transforms alias to data
            out = double(data2Numeric(obj,data));
        end
        
        function out = user2Numeric(obj,data,~) %#ok<INUSL>
            % user2Numeric Transforms user: Return unique double for each user
            out = double(data);
        end
        
        function out = dir2Numeric(obj,data,~) %#ok<INUSL>
            % dir2Numeric Transforms dir: Return unique double for each dir
            out = double(data);
        end
        
        function out = enable2Numeric(obj,data,~) %#ok<INUSL>
            % enable2Numeric Transforms enable: Convert to double
            out = double(data);
        end
        
        function out = uid2Numeric(obj,data,~) %#ok<INUSL>
            % uid2Numeric Transforms uid: Convert to double
            out = double(data);
        end
        
        function out = u2Numeric(obj,data,~)
            % u2Numeric Transforms alias to uid
            out = uid2Numeric(obj,data);
        end
        
        function out = index2Numeric(obj,data,~) %#ok<INUSL>
            % index2Numeric Transforms index: Convert to double
            out = double(data);
        end
        
        function out = i2Numeric(obj,data,~)
            % i2Numeric Transforms alias to index
            out = index2Numeric(obj,data);
        end
        
        function out = setName2Numeric(obj,data,~) %#ok<INUSL>
            % setName2Numeric Transforms setName: Return unique double for each set name
            out = double(data);
        end
        
        function out = sn2Numeric(obj,data,~)
            % sn2Numeric Transforms alias to setName
            out = setName2Numeric(obj,data);
        end
        
        function out = uuid2Numeric(obj,data,~) %#ok<INUSL>
            % uuid2Numeric Transforms uuid: Convert to double
            out = double(data);
        end
        
        function out = uuidStr2Numeric(obj,data,ind) %#ok<INUSL>
            % uuidStr2Numeric Transforms uuidStr: Return NaN
            out = double(obj.uuid(ind));
        end
    end
    
    %% Methods for various class related tasks
    methods (Access = public, Hidden = false)
        function                 updateLiquids(obj,varargin)
            % updateLiquids Reads liquid properties from labbook (Excel file) and  updates property
            % 'liquids' of the object
            
            %
            % use input parser to process options
            opt               = inputParser;
            opt.StructExpand  = true;
            opt.KeepUnmatched = false;
            % filename of the labbook
            opt.addParameter('filename', fullfile(obj.rootdir,obj.labbook), @(x) ischar(x));
            % name of the sheet in the labbook
            opt.addParameter('sheet', 'Liquids', @(x) ischar(x));
            opt.parse(varargin{:});
            opt = opt.Results;
            %
            % read file and update class property
            if ~exist(opt.filename,'file') == 2
                warning(sprintf('%s:Input',mfilename),'File ''%s'' could not be found', opt.filename);
                return;
            end
            try
                obj.p_liquids = obj.labbookGetLiquids('filename',opt.filename,'sheet',opt.sheet);
            catch err
                warning(sprintf('%s:Input',mfilename),'File ''%s'' could not be read: %', opt.filename,err.getReport);
                name          = categorical({''});
                id            = NaN;
                obj.p_liquids = table(id,name);
                return;
            end
        end
        
        function                 store(obj,varargin)
            % store Stores data of selected experiments or given experiments in data file
            %    Optional input is given to findExp to work on specified experiments instead of
            %    current selection. The function only stores independent, non-constant physical
            %    properties in a file stored in the folder for each UID.
            
            p_store(obj, 0, true, varargin{:});
        end
        
        function                 storeRemoveUnknown(obj,varargin)
            % storeRemoveUnknown Stores data of selected experiments or given experiments in data
            % file and removes unknown properties in each data file
            %    Optional input is given to findExp to work on specified experiments instead of
            %    current selection. The function only stores independent, non-constant physical
            %    properties in a file stored in the folder for each UID.
            
            p_store(obj, 0, false, varargin{:});
        end
        
        function                 backup(obj,varargin)
            % store Stores data of selected experiments or given experiments in new backup file
            %    For optional input see the description of the store function
            
            p_store(obj, 1, true, varargin{:});
        end
        
        function                 backupClean(obj,varargin)
            % backupClean Removes any backup file and stores data of selected experiments or given experiments in new backup file
            %    For optional input see the description of the store function
            
            p_store(obj, 3, true, varargin{:});
        end
        
        function                 cleanBackups(obj,keepLast,varargin)
            % cleanBackups Removes any backup file or any but the last
            %    Optional input is given to findExp to work on specified experiments instead of
            %    current selection. The function only stores independent, non-constant physical
            %    properties in a file stored in the folder for each UID.
            
            %
            % get indices of experiments
            if nargin < 2 || isempty(keepLast), keepLast = true; end
            if numel(varargin) > 0
                ind = findExp(obj,true,varargin{:});
            else
                ind = obj.enable;
            end
            %
            % get UIDs to clean
            uids    = unique(obj.uid(ind));
            allGood = true;
            %
            % get independent Video properties
            props  = obj.myprop2Set;
            defVal = obj.myprop2SetDefault;
            idxVid = false(size(props));
            for k = 1:numel(props)
                if isa(defVal{k},'Video'), idxVid(k) = true; end
            end
            idxVid = reshape(find(idxVid),1,[]);
            %
            % store data uid by uid
            nMax   = ceil(log10(numel(uids)));
            bakdir = pwd;
            myWaitbar(obj,'start',sprintf('Cleaning backups of %d UID(s)...',numel(uids)));
            fprintf('%*d UID(s) are tried to be cleaned\n',nMax,numel(uids));
            
            
            for i = 1:numel(uids)
                %
                % check for waitbar
                if myWaitbar(obj,'check',sprintf('Canceled after %d of %d UID(s)\n',...
                        i-1,numel(uids))), break; end
                %
                % find all experiment of current UID
                idx   = obj.uid == uids(i);
                mydir = unique(obj.dir(idx));
                if numel(mydir) > 1
                    error(sprintf('%s:Input',mfilename),['Experiments of uid = %d seem to be stored ',...
                        'in different directories, which is not supported for object of class ''%s'''],...
                        uids(i),class(obj));
                end
                mydir = char(mydir(1));
                cd(mydir);
                dataFile = fullfile(mydir,sprintf('%s%s.BAKXX.mat',obj.dataFilePrefix,class(obj)));
                fprintf('  ''%s'': ',dataFile);
                % call cleanBackups function of Video objects
                for j = idxVid
                    tmp    = repmat({':'},1,ndims(defVal{j}));
                    tmp{1} = idx;
                    cleanBackups(obj.(props{j})(tmp{:}),keepLast);
                end
                %
                % remove every backup file
                dataFile = @(x) fullfile(mydir,sprintf('%s%s.BAK%0.2d.mat',obj.dataFilePrefix,class(obj),x));
                counter  = 0;
                while exist(dataFile(counter),'file') == 2
                    counter = counter + 1;
                end
                if counter > 0
                    if keepLast
                        if counter > 1
                            movefile(dataFile(counter-1),dataFile(0));
                        end
                        idxDelete = 1:(counter-2);
                    else
                        idxDelete = 0:(counter-1);
                    end
                else
                    idxDelete = [];
                end
                for j = idxDelete, delete(dataFile(j)); end
                fntest = dir(fullfile(mydir,sprintf('%s%s.BAK*.mat',obj.dataFilePrefix,class(obj)))); %#ok<CPROPLC>
                fntest([fntest.isdir]) = [];
                if numel(fntest) == double(keepLast)
                    fprintf('%3d backup file(s) removed\n',numel(idxDelete));
                else
                    str = sprintf('''%s'', ',fntest.name); str = str(1:end-2);
                    fprintf(['%3d backup file(s) removed, but some unexpected file(s) (%s) are still available, ',...
                        'possible due to discontinuous numbering of the file(s)\n'],numel(idxDelete),str);
                    allGood = false;
                end
                myWaitbar(obj,'update',i/double(numel(uids)));
            end
            cd(bakdir);
            myWaitbar(obj,'end');
            if ~allGood
                warning(sprintf('%s:Check',mfilename),['Some data file(s) could not be ',...
                    'cleaned without any issue, please check previous output to command line ',...
                    'for an explanation of the issue(s)']);
            else
                fprintf('%*d UID(s) were cleaned successfully\n',nMax,numel(uids));
            end
        end
        
        function                 recall(obj,varargin)
            % recall Recalls data of selected experiments or given experiments from data file
            %    Optional input is given to findExp to work on specified experiments instead of
            %    current selection. The function only recalls independent, non-constant physical
            %    properties in a file stored in the folder for each UID.
            
            % call workhorse function
            p_recall(obj,0,varargin{:});
        end
        
        function                 restore(obj,varargin)
            % restore Recalls data of selected experiments or given experiments from last backup file
            %    For optional input see the description of the recall function
            
            p_recall(obj,1,varargin{:});
        end
        
        function                 storeSelection(obj,filename)
            % storeSelection Stores selection property to a file
            
            % get filename
            if nargin < 2
                [fn, fp] = uiputfile('*.mat','Save selection(s) to a file','NGS01_selection.mat');
                if isequal(fn,0) || isequal(fp,0)
                    return;
                else
                    filename = fullfile(fp,fn);
                end
            end
            if ~ischar(filename)
                error(sprintf('%s:Input',mfilename),...
                    'Input is unexpected, expected a filename as char');
            end
            % save data
            tmp.NGS01.sel = obj.sel; %#ok<STRNU>
            save(filename,'-struct','tmp');
            fprintf('Selection(s) saved to file ''%s''\n',filename);
        end
        
        function                 loadSelection(obj,filename,askBeforeOverwrite)
            % loadSelection Loads selection property from a file
            
            % get filename
            if nargin < 2
                [fn, fp] = uigetfile('*.mat','Load selection(s) from a file','NGS01_selection.mat');
                if isequal(fn,0) || isequal(fp,0)
                    return;
                else
                    filename = fullfile(fp,fn);
                end
            end
            if nargin < 3
                askBeforeOverwrite = true;
            end
            if ~(ischar(filename) && islogical(askBeforeOverwrite) && isscalar(askBeforeOverwrite))
                error(sprintf('%s:Input',mfilename),...
                    'Input is unexpected, expected a filename as char and a logical scalar');
            end
            % check filename
            isOK = false;
            if exist(filename,'file') == 2
                tmp = load(filename);
                if isfield(tmp,'NGS01') && isfield(tmp.NGS01,'sel') && isstruct(tmp.NGS01.sel)
                    isOK = true;
                end
            end
            if isOK
                bak = obj.sel;
                try
                    fnOld = fieldnames(bak);
                    fnOld(ismember(fnOld,'prev')) =[];
                    fnNew = fieldnames(tmp.NGS01.sel);
                    if askBeforeOverwrite && any(ismember(fnNew,fnOld))
                        button = questdlg('This will overwrite some existing selection(s). Continue?', ...
                            'Overwrite selection?', 'Yes','No','No');
                        if ~strcmp(button,'Yes'); return; end
                    end
                    obj.sel = tmp.NGS01.sel;
                catch
                    obj.sel = bak;
                    isOK    = false;
                end
            end
            if isOK
                fprintf('Selection(s) loaded from file ''%s''\n',filename);
                notifyMe(obj,'resetSelection');
            else
                error(sprintf('%s:Input',mfilename),...
                    'Selection(s) could not be loaded from file ''%s''',filename);
            end
        end
        
        function                 unselect(obj,varargin)
            % unselect Unselects experiments based on given input, see findExp for further info
            ind = findExp(obj,false,varargin{:});
            if ~isequal(obj.enable,ind)
                obj.sel.prev   = {'uuid' obj.uuid(obj.enable)};
                obj.enable     = ind;
                notifyMe(obj,'resetSelection');
            end
        end
        
        function                 select(obj,varargin)
            % select Selects experiments based on given input, see findExp for further info
            ind = findExp(obj,true,varargin{:});
            if ~isequal(obj.enable,ind)
                obj.sel.prev   = {'uuid' obj.uuid(obj.enable)};
                obj.enable     = ind;
                notifyMe(obj,'resetSelection');
            end
        end
        
        function                 addObj(obj,varargin)
            % addObj Add objects' selected physical data to current object
            %
            % Example:
            % * Add all experiments of obj2 and obj3 to obj1
            %   obj1.addObj(obj2(:), obj3(:))
            
            if numel(obj) > 1 || nargin < 2
                error(sprintf('%s:Input',mfilename),['Method accepts a scalar object as ',...
                    'first input and multiple object(s) as further input']);
            end
            if ~all(cellfun(@(x) isa(x,class(obj)),varargin))
                error(sprintf('%s:Input',mfilename),...
                    'Method accepts objects of same class as input');
            end
            for i = 1:numel(varargin)
                if isequal(obj,varargin{i})
                    error(sprintf('%s:Input',mfilename),...
                        'Object can not be added to itself');
                end
            end
            % fix sync
            for k = 1:numel(varargin)
                if ~all(varargin{k}.isSync)
                    fixSync(varargin{k});
                    if ~all(varargin{k}.isSync)
                        error(sprintf('%s:Input',mfilename),...
                            'At least some objects are out of sync and it can *NOT* be fixed');
                    else
                        warning(sprintf('%s:Input',mfilename),...
                            'At least some objects have been out of sync, but it was fixed');
                    end
                end
            end
            % cat enable property first since obj.numAbs depends on in
            % cat physical properties that are not dependent or constant
            props  = obj.myprop2Set;
            siz    = obj.myprop2SetSize;
            for i = 1:numel(props)
                for k = 1:numel(varargin)
                    if varargin{k}.numSel > 0
                        tmp = repmat({':'},1,numel(siz{i})); tmp{1} = varargin{k}.ind;
                        obj.(props{i}) = cat(1,obj.(props{i}),varargin{k}.(props{i})(tmp{:}));
                    end
                end
            end
            notifyMe(obj,'resetNew',obj.myprop);
        end
        
        function                 extend(obj,varargin)
            % extend Extends object by given numbers of experiments using an existing experiment as template
            %    This can be used to first add dummy data and then, subsequently, set its properties
            %    to the desired values. The first input should be the number of experiments and the
            %    second input should be the index of the experiment that is used as template (if
            %    omitted the default values of the class definition are used to extend object)
            
            % see for specifying default values:
            % http://blogs.mathworks.com/loren/2009/05/05/nice-way-to-set-function-defaults/
            numvarargs = length(varargin);
            if numvarargs > 2
                error(sprintf('%s:Input',mfilename), ...
                    'Requires at most 2 inputs');
            end
            optargs               = {0 []};
            optargs(1:numvarargs) = varargin;
            [num,idx]             = optargs{:};
            %
            % check input
            if isempty(num) || num < 1
                warning(sprintf('%s:Extend',mfilename),['Function was called with empty input or a ',...
                    'number smaller than one ... doing nothing, but is this intended?']);
                return;
            elseif ~(~isempty(num) && isnumeric(num) && isscalar(num) && isreal(num) && num > 0 && ...
                    (isempty(idx) || (isnumeric(idx) && isscalar(idx) && isreal(idx) && idx > 0 && idx < obj.numAbs+1)))
                error(sprintf('%s:Input',mfilename),...
                    'Unexpected input, expected one or two scalar numeric input');
            end
            %
            % extend object...
            if isempty(idx)
                % ...with default values
                props  = obj.myprop2Set;
                defVal = obj.myprop2SetDefault;
                for i = 1:numel(props)
                    obj.(props{i}) = cat(1,obj.(props{i}),repmat(defVal{i},num,1));
                end
            else
                % ...with values from given index
                props  = obj.myprop2Set;
                defVal = obj.myprop2SetDefault;
                for i = 1:numel(props)
                    tmp = repmat({':'},1,ndims(defVal{i})); tmp{1} = idx;
                    obj.(props{i}) = cat(1,obj.(props{i}),repmat(obj.(props{i})(tmp{:}),num,1));
                end
            end
            %
            % reset
            notifyMe(obj,'resetNew',obj.myprop);
        end
        
        function                 remove(obj,varargin)
            % remove Removes selected experiments or given experiments from object
            %    Optional input is given to findExp to work on specified experiments instead of
            %    current selection, Note: One experiment needs to be available at least, therefore
            %    if all experiments are selected for removal, the first experiment is unchanged (and
            %    can be used as template to add new experiments)
            
            % get indices of experiments
            if numel(varargin) > 0
                ind = findExp(obj,true,varargin{:});
            else
                ind = obj.enable;
            end
            % keep at least one experiment
            if numel(find(ind)) == obj.numAbs
                ind(1) = false;
                warning(sprintf('%s:Remove',mfilename),...
                    'At least one experiment must remain as template in object, keeping first experiment');
            end
            % delete entries in properties that are not dependent or constant
            props  = obj.myprop2Set;
            siz    = obj.myprop2SetSize;
            for i = 1:numel(props)
                tmp = repmat({':'},1,numel(siz{i})); tmp{1} = ind;
                obj.(props{i})(tmp{:}) = [];
            end
            % Option 1: remove elements in p_dir manually, but fore recomputation for p_uuidStr,
            % since it might change for less experiments
            obj.p_dir(ind) = [];
            obj.p_uuidStr  = [];
            % Option 2: force recomputation of both properties next time they are used via the get
            % method of their public property
            %
            % obj.p_dir     = [];
            % obj.p_uuidStr = [];
            notifyMe(obj,'resetNew',obj.myprop);
        end
        
        function                 set(obj,varargin)
            % set Sets physical property(ies) of selected or specified experiment(s) to given values
            %    If the first optional input is a logical or numeric it is interpreted as a way to
            %    select specific experiments, it uses the subsasgn of the class to set the values
            
            % flatten input
            if numel(varargin) == 1 && iscell(varargin{1})
                varargin = varargin{1};
            end
            % find indices
            if numel(varargin) > 0 && islogical(varargin{1}) && numel(varargin{1}) == obj.numAbs
                idx         = varargin{1}(:);
                varargin(1) = [];
            elseif numel(varargin) > 0 && isnumeric(varargin{1}) && max(varargin{1}(:)) <= obj.numAbs && min(varargin{1}(:)) > 0
                idx                 = false(size(obj.enable));
                idx(varargin{1}(:)) = true;
                varargin(1)         = [];
            elseif numel(varargin) > 0 && isnumeric(varargin{1}) && (max(varargin{1}(:)) > obj.numAbs || min(varargin{1}(:)) < 0)
                error(sprintf('%s:Indexing',mfilename),'First input is interpreted as direct index to an experiment, but it is out of bounds');
            else
                idx = obj.enable;
            end
            % set data
            if mod(numel(varargin),2) < 1
                % even number ( >=2 ) of input arguments: set fields to values
                if ~iscellstr(varargin(1:2:end)) || ~all(ismember(varargin(1:2:end),obj.myprop))
                    error(sprintf('%s:Indexing',mfilename),'Unknown property to work on');
                end
                if any(~hIsPublicSetProperty(obj,varargin(1:2:end)))
                    % do not allow access to any non-public set property
                    error(sprintf('%s:Indexing',mfilename), ...
                        'Cannot set a non-public (SetAccess) property of the class ''%s''', class(obj));
                end
                % select experiments, set values and restore initial selection
                bak        = obj.enable;
                obj.enable = findExp(obj,true,idx);
                for i = 1:2:numel(varargin)
                    S   = substruct('.',varargin{i});
                    obj = subsasgn(obj, S, varargin{i+1});
                end
                obj.enable = bak;
            else
                error(sprintf('%s:Indexing',mfilename),'Unexpected input for given number of arguments');
            end
        end
        
        function out           = getTable(obj,varargin)
            % getTable Gets given property(ies) and returns their value as table
            %    Returns a table with numeric data of all given properties (uniform output mode),
            %    unless the last optional input is a scalar logical set to false, in which case a
            %    table with the complete data for each property is returned. If the first optional
            %    input is a logical or numeric it is interpreted as a way to select specific
            %    experiments.
            
            % flatten input
            if numel(varargin) == 1 && iscell(varargin{1})
                input = varargin{1};
            else
                input = varargin;
            end
            % find indices and select experiment
            if numel(input) > 0 && islogical(input{1}) && numel(input{1}) == obj.numAbs
                idx      = input{1}(:);
                input(1) = [];
            elseif numel(input) > 0 && isnumeric(input{1}) && max(input{1}(:)) <= obj.numAbs && min(input{1}(:)) > 0
                idx              = false(size(obj.enable));
                idx(input{1}(:)) = true;
                input(1)         = [];
            else
                idx = obj.enable;
            end
            bak        = obj.enable;
            obj.enable = findExp(obj,true,idx);
            % find uniform flag
            if numel(input) > 0 && islogical(input{end}) && isscalar(input{end})
                uniform    = input{end};
                input(end) = [];
            else
                uniform  = true;
            end
            % find properties
            if numel(input) == 1 && iscellstr(input{1})
                strProp  = input{1};
                input(1) = [];
            elseif numel(input) > 0 && iscellstr(input)
                strProp = input(:);
                input   = [];
            else
                strProp = obj.vip;
            end
            [indOK,indProp] = ismember(strProp,obj.myprop);
            if ~isempty(input) || ~all(indOK(:))
                error(sprintf('%s:Indexing',mfilename),'Unknown property to work on');
            end
            if any(~hIsPublicGetProperty(obj,strProp))
                % do not allow access to any non-public get property
                error(sprintf('%s:Indexing',mfilename), ...
                    'Cannot get a non-public (GetAccess) property of the class ''%s''', class(obj));
            end
            %
            % get description for properties
            descProp = physicalProperties(obj,strProp,true);
            %
            % create table
            out = table;
            if isempty(strProp), return; end
            %
            % populate table with values
            if uniform
                ind = obj.ind;
                for i = 1:numel(strProp)
                    if strcmp(strProp{i},'enable')
                        % special care for enable since we changed it in this function, we return it
                        % as before the call to this function was made
                        out.(strProp{i}) = double(bak(obj.ind));
                    else
                        if isempty(obj.myprop2Numeric{indProp(i)})
                            out.(strProp{i}) = obj.(strProp{i})(ind);
                        else
                            tmp = repmat({':'},1,numel(obj.mypropSize{indProp(i)})); tmp{1} = ind;
                            out.(strProp{i}) = obj.myprop2Numeric{indProp(i)}(obj,obj.(strProp{i})(tmp{:}),ind);
                            descProp{i}      = [descProp{i} ' (converted to numeric representation)'];
                        end
                    end
                end
            else
                for i = 1:numel(strProp)
                    if strcmp(strProp{i},'enable')
                        out.(strProp{i}) = bak(obj.ind);
                    else
                        S                = substruct('.',strProp{i});
                        out.(strProp{i}) = subsref(obj,S);
                    end
                end
            end
            %
            % add description
            if uniform
                out.Properties.Description = sprintf(['Exported data in numeric representation of ',...
                    '%d experiment(s) from class ''%s'''],numel(obj.ind),class(obj));
            else
                out.Properties.Description = sprintf(['Exported data of %d experiment(s) from ',...
                    'class ''%s'''],numel(obj.ind),class(obj));
            end
            out.Properties.VariableDescriptions = descProp;
            out.Properties.RowNames             = obj.uuidStr(obj.ind);
            % restore initial selection
            obj.enable = bak;
        end
        
        function [out, names]  = get(obj,varargin)
            % get Gets given property(ies) and returns its value
            %    Returns a numeric matrix with data of all given properties (uniform output mode),
            %    unless the last optional input is a scalar logical set to false, in which case a
            %    cell with a single entry for each property is returned. In uniform output mode
            %    properties are transformed to their numerical representation, where the maximum is
            %    returned to obtain a scalar value per experiment that is converted to a double
            %    value. If the first optional input is a logical or numeric it is interpreted as a
            %    way to select specific experiments. The second output argument contains the
            %    property names for each column of the output.
            
            % flatten input
            if numel(varargin) == 1 && iscell(varargin{1})
                input = varargin{1};
            else
                input = varargin;
            end
            % find indices and select experiment
            if numel(input) > 0 && islogical(input{1}) && numel(input{1}) == obj.numAbs
                idx      = input{1}(:);
                input(1) = [];
            elseif numel(input) > 0 && isnumeric(input{1}) && max(input{1}(:)) <= obj.numAbs && min(input{1}(:)) > 0
                idx              = false(size(obj.enable));
                idx(input{1}(:)) = true;
                input(1)         = [];
            else
                idx = obj.enable;
            end
            bak        = obj.enable;
            obj.enable = findExp(obj,true,idx);
            % find uniform flag
            if numel(input) > 0 && islogical(input{end}) && isscalar(input{end})
                uniform    = input{end};
                input(end) = [];
            else
                uniform  = true;
            end
            % find properties
            if numel(input) == 1 && iscellstr(input{1})
                strProp  = input{1};
                input(1) = [];
            elseif numel(input) > 0 && iscellstr(input)
                strProp = input(:);
                input   = [];
            else
                strProp = obj.vip;
            end
            [indOK,indProp] = ismember(strProp,obj.myprop);
            if ~isempty(input) || ~all(indOK(:))
                error(sprintf('%s:Indexing',mfilename),'Unknown property to work on');
            end
            if any(~hIsPublicGetProperty(obj,strProp))
                % do not allow access to any non-public get property
                error(sprintf('%s:Indexing',mfilename), ...
                    'Cannot get a non-public (GetAccess) property of the class ''%s''', class(obj));
            end
            if uniform
                out = zeros(numel(obj.ind),numel(strProp));
                if isempty(strProp)
                    return;
                end
                ind = obj.ind;
                for i = 1:numel(strProp)
                    if strcmp(strProp{i},'enable')
                        % special care for enable since we changed it in this function, we return it
                        % as before the call to this function was made
                        out(:,i) = double(bak(ind));
                    else
                        if isempty(obj.myprop2Numeric{indProp(i)})
                            out(:,i) = obj.(strProp{i})(ind);
                        else
                            dat = obj.(strProp{i});
                            tmp = repmat({':'},1,ndims(dat)); tmp{1} = ind;
                            out(:,i) = obj.myprop2Numeric{indProp(i)}(obj,dat(tmp{:}),ind);
                            clearvars dat
                        end
                    end
                end
            else
                out = cell(1,numel(strProp));
                if isempty(strProp)
                    return
                end
                for i = 1:numel(strProp)
                    if strcmp(strProp{i},'enable')
                        out{i} = bak(obj.ind);
                    else
                        S      = substruct('.',strProp{i});
                        out{i} = subsref(obj,S);
                    end
                end
            end
            % get names and restore initial selection
            names      = reshape(strProp,1,[]);
            obj.enable = bak;
        end
        
        function [out, status] = getFullFile(obj, basename, varargin)
            % getFullFile Returns full filename(s) based on basename for selected experiments
            %    Optional input is given to findExp to work on specified experiments instead of
            %    current selection, second output is false if a file could not be found, true
            %    otherwise or basename was empty
            
            % check input and get indices of experiments
            if nargin < 2 || ~(ischar(basename) || isempty(basename) || any(isnan(basename)))
                error(sprintf('%s:Iput',mfilename),'Unexpected input, expected at least a basename as char');
            end
            if numel(varargin) > 0
                ind = findExp(obj,true,varargin{:});
            else
                ind = obj.enable;
            end
            ind    = find(ind);
            out    = repmat({''},size(ind));
            status = true;
            if isempty(basename) || any(isnan(basename))
                return
            end
            % find files
            myDir = getDir(obj,ind);
            out   = cellfun(@(x) fullfile(x,basename),cellstr(myDir),'UniformOutput',false);
            if nargout > 1
                status = cellfun(@(x) exist(x,'file')==2,out);
            end
        end
        
        function [out, status] = getFile(obj, basename, varargin)
            % getFile Returns filename(s) based on basename for selected experiments
            %    Optional input is given to findExp to work on specified experiments instead of
            %    current selection, second output is false if a file could not be found, true
            %    otherwise or basename was empty
            %
            %    Notes:
            %    * Returns cell with input in case a file cannot be found or basename is
            %      empty
            %    * If the basename contains the wildcard '*' the file will be expanded in the
            %      directory of the experiments and the ith file be selected based on the index of
            %      the experiment, e.g. the 6th file will be selected for an experiment with index
            %      equal to six
            
            % check input and get indices of experiments
            if nargin < 2 || ~(ischar(basename) || isempty(basename) || any(isnan(basename)))
                error(sprintf('%s:Iput',mfilename),'Unexpected input, expected at least a basename as char');
            end
            if numel(varargin) > 0
                ind = findExp(obj,true,varargin{:});
            else
                ind = obj.enable;
            end
            ind    = find(ind);
            out    = repmat({''},size(ind));
            status = true;
            if isempty(basename) || any(isnan(basename))
                return
            end
            % find files
            myDir = getDir(obj,ind);
            if isempty(strfind(basename,'*'))
                for i = 1:numel(ind)
                    % check for file, only done ones for the same consecutive directory
                    if i == 1 || myDir(i) ~= myDir(i-1)
                        isThere = exist(fullfile(char(myDir(i)),basename),'file') == 2;
                    end
                    if isThere
                        out{i} = basename;
                    else
                        out{i} = basename;
                        status = false;
                    end
                end
            else
                for i = 1:numel(ind)
                    % get files, only done ones for the same consecutive directory
                    if i == 1 || myDir(i) ~= myDir(i-1)
                        myFil = dir(fullfile(char(myDir(i)),basename));%#ok<CPROPLC>
                    end
                    if numel(myFil) < obj.index(ind(i))
                        out{i} = basename;
                        status = false;
                    else
                        out{i} = myFil(obj.index(ind(i))).name;
                    end
                end
            end
        end
        
        function out           = getDir(obj,varargin)
            % getDir Returns directory of selected experiments
            %    Optional input is given to findExp to work on specified experiments instead of
            %    current selection
            %
            % Note: This is put into a function and not into a property, so that it can be
            % recomputed for just a selected number of experiments (cellfun with sprintf might be
            % slow for many experiments), also added as a property that is only recomputed on data
            % change.
            
            % get indices of experiments
            if numel(varargin) > 0
                ind = findExp(obj,true,varargin{:});
            else
                ind = obj.enable;
            end
            % return directory, use pwd if rootdir property is empty for an experiment
            ind = find(ind);
            out = categorical(reshape(arrayfun(@(x,y) fullfile(obj.rootdir,datestr(x,obj.formatDate),...
                sprintf(obj.formatUID,y)),obj.time(ind),obj.uid(ind),'UniformOutput',false),[],1));
        end
        
        function                 sort(obj,varargin)
            % sort Sorts selected experiments according to given properties
            %    Without additional input experiments are sorted according to uid and index in
            %    ascending order.  Optional input should be given in <property name> <sort order>
            %    style, where property name is a string and sort order is a numeric scalar where a
            %    negative value leads to a descending order of the corresponding property and vice
            %    versa, Note: If data is not sorted according to uid and index, this may lead to
            %    problems: obj('uid',1:2) should normally return uid 1 first and then 2, but if
            %    sorting is changed, this will not be the case.
            
            if obj.numSel < 1
                return
            end
            % flatten input and define default
            if numel(varargin) == 1 && iscell(varargin{1})
                varargin = varargin{1};
            elseif numel(varargin) < 1
                varargin = {'uid' 1 'index' 1};
            end
            % set data
            if mod(numel(varargin),2) < 1
                % even number ( >=2 ) of input arguments: set fields to values
                strProp = varargin(1:2:end);
                ordProp  = varargin(2:2:end);
                if ~iscellstr(strProp) || ~all(ismember(strProp,obj.myprop))
                    error(sprintf('%s:Input',mfilename),'Unknown property to work on');
                end
                if any(~hIsPublicGetProperty(obj,strProp))
                    % do not allow access to any non-public get property
                    error(sprintf('%s:Input',mfilename), ...
                        'Cannot get a non-public (GetAccess) property of the class ''%s''', class(obj));
                end
                try
                    if all(cellfun(@(x) ~isempty(x) && isnumeric(x) && isscalar(x) && isreal(x),ordProp))
                        ordProp = cell2mat(ordProp);
                    else
                        error(sprintf('%s:Input',mfilename),'Unknown ordering key to work with');
                    end
                catch
                    error(sprintf('%s:Input',mfilename),'Unknown ordering key to work with');
                end
                % get data and sorting index
                [dat, names] = get(obj,strProp);
                [~, idx]     = ismember(strProp,names);
                ordProp      = sign(ordProp(idx)).*(1:numel(names));
                [~,ordIdx]   = sortrows(dat,ordProp);
                if ~isequal(ordIdx(:),(1:numel(ordIdx))')
                    % order properties
                    props  = obj.myprop2Set;
                    siz    = obj.myprop2SetSize;
                    tmpInd = obj.ind;
                    for i = 1:numel(props)
                        tmp1 = repmat({':'},1,numel(siz{i})); tmp1{1} = tmpInd;
                        tmp2 = tmp1;                          tmp2{1} = tmpInd(ordIdx);
                        obj.(props{i})(tmp1{:}) = obj.(props{i})(tmp2{:});
                    end
                    % Option 1: order private properties manually
                    % obj.p_dir(tmpInd)     = obj.p_dir(tmpInd(ordIdx));
                    % obj.p_uuidStr(tmpInd) = obj.p_uuidStr(tmpInd(ordIdx));
                    % Option 2: notify data, since the subclass may have to perform additional steps
                    notifyMe(obj,'resetData');
                end
            else
                error(sprintf('%s:Input',mfilename),'Unexpected number input arguments, since it must be a multiple of two');
            end
        end
        
        function                 killWaitbar(obj)
            % killWaitbar Kills current waitbar of object (e.g. useful when it crashed)
            if ishandle(obj.hWaitbar)
                delete(obj.hWaitbar);
            end
        end
        
        function                 fixSync(obj)
            % fixSync Tries to reshape physical properties correctly to n x m scheme
            
            props  = obj.myprop2Set;
            siz    = obj.myprop2SetSize;
            change = false;
            for i = 1:numel(props)
                if size(obj.(props{i}),1) ~= obj.numAbs
                    tmp    = siz{i};
                    tmp(1) = obj.numAbs;
                    if abs(numel(obj.(props{i}))-prod(tmp)) < eps
                        obj.(props{i}) = reshape(obj.(props{i}),tmp);
                    elseif numel(obj.(props{i})) == obj.numAbs
                        obj.(props{i}) = reshape(obj.(props{i}),obj.numAbs,[]);
                    end
                    change = true;
                end
            end
            if change, notifyMe(obj,'resetData'); end
        end
        
        function                 reset(obj)
            % reset Resets storage properties with computational expensive results and forces a
            % re-computation next time they are used (those properties normally start with an 'p_').
            % Furthermore, it calls the corresponding method resetSub in the subclass and notifies
            % the event 'resetData'
            
            notifyMe(obj,'resetData');
        end
        
        function                 setDefaultNames(obj,varargin)
            % setDefaultNames Sets empty names of selected experiments or given experiments
            %    Optional input is given to findExp to work on specified experiments instead of
            %    current selection, default names are based on uid and index
            
            if numel(varargin) > 0
                ind = find(findExp(obj,true,varargin{:}));
            else
                ind = obj.ind;
            end
            idxFlag = cellfun('isempty',obj.name(ind));
            if any(idxFlag)
                obj.name(ind(idxFlag)) = obj.uuidStr(ind(idxFlag));
                notifyMe(obj,'resetData','name');
            end
        end
        
        function out           = findParameterFiles(obj, ignoreDat, startDate, endDate)
            % findParameterFiles Scans root directory for parameter files and returns cellstr with
            % path to parameter files, its date and uid. Optional input is a startDate and endDate
            % as datetime to exclude experiments. Each parameter file will be replaced in case a
            % valid data file is found instead.
            
            % check input
            narginchk(2,4);
            if nargin < 4, endDate   = []; end
            if nargin < 3, startDate = []; end
            if ~(isdatetime(startDate) || isempty(startDate)) || ~(isdatetime(endDate) || isempty(endDate))
                error(sprintf('%s:Input',mfilename),'Input is unexpected');
            end
            % scan root directory for subfolders that can be converted to a datetime according
            % to the given formateDate. Remove folders according to startDate and endDate.
            if exist(obj.rootdir,'file') ~= 7
                error(sprintf('%s:Input',mfilename),'Root directory ''%s'' is not existing',obj.rootdir);
            end
            % all files and directories in root dir
            tmp = dir(obj.rootdir); %#ok<CPROPLC>
            while ~isempty(tmp) && any(strcmp({'.','..'},tmp(1).name))
                tmp(1) = []; % remove . and ..
            end
            if ~isempty(tmp)
                tmp = tmp([tmp.isdir]);	% only directories
            else
                error(sprintf('%s:Input',mfilename),'Root directory ''%s'' is empty',obj.rootdir);
            end
            if ~isempty(tmp)
                idxOK = true(size(tmp));
                for i = 1:numel(tmp)   	% try to parse each directory name
                    try
                        % Note: MM stands for months in datetime but minutes for datestr that is
                        % used also in this class. Therefore first convert to datenum
                        curTime = datetime(datenum(tmp(i).name,obj.formatDate),'ConvertFrom','datenum');
                        if (~isempty(startDate) && curTime < startDate) || (~isempty(endDate) && curTime > endDate)
                            idxOK(i) = false;
                        end
                    catch
                        idxOK(i) = false;
                    end
                end
                tmp = tmp(idxOK);
            end
            % loop over directories again and try to find subfolders according to UID formatUID
            % that contain a parameterFile
            out      = cell(0,3);
            dataFile = sprintf('%s%s.mat',obj.dataFilePrefix,class(obj));
            if ~isempty(tmp)
                for i = 1:numel(tmp)
                    subDir = dir(fullfile(obj.rootdir,tmp(i).name));%#ok<CPROPLC>
                    while ~isempty(subDir) && any(strcmp({'.','..'},subDir(1).name))
                        subDir(1) = []; % remove . and ..
                    end
                    if ~isempty(subDir)
                        subDir = subDir([subDir.isdir]); % only directories
                        for j = 1:numel(subDir)          % check sub directories for name, parameter and data file
                            curUID = str2double(subDir(j).name);
                            tmpPar = fullfile(obj.rootdir,tmp(i).name,subDir(j).name,obj.parameterFile);
                            tmpDat = fullfile(obj.rootdir,tmp(i).name,subDir(j).name,dataFile);
                            isPar  = exist(tmpPar,'file') == 2 && numel(dir(tmpPar)) == 1; %#ok<CPROPLC>
                            isDat  = ~ignoreDat && exist(tmpDat,'file') == 2 && numel(dir(tmpDat)) == 1; %#ok<CPROPLC>
                            if ~isnan(curUID) && strcmp(subDir(j).name,sprintf(obj.formatUID,curUID)) && ...
                                    (isPar || isDat)
                                % prefer the data file over parameter file
                                if isDat, out{end+1,1} = tmpDat; %#ok<AGROW>
                                else,     out{end+1,1} = tmpPar; %#ok<AGROW>
                                end
                                out{end,2} = datetime(datenum(tmp(i).name,obj.formatDate),'ConvertFrom','datenum');
                                out{end,3} = curUID;
                            end
                        end
                    end
                end
            end
        end
        
        function res           = findExp(obj,doSelect,varargin)
            % findExp Finds logical indices of experiments based on given input
            %
            % First input argument
            %    Logical whether to perform a selection (true) or unselection (false)
            % Optional input argument(s) and the action performed
            %    * no input at all      Start GUI for selection
            %    * <char command>       A specific command or keyword from the following list:
            %        * 'all','a',':'    Select all experiments
            %        * 'none','n'       Select no experiments
            %        * 'inverse','i'    Inverse current selection
            %        * 'prev'           Previous selection (last before current)
            %        * 'today','daily'  Select experiments of today
            %        * 'lastXd'         Select the last x days, e.g. last5d means last 5 days
            %    * [1 2 4]              Use linear indexing, e.g. select 1st, 2nd and 4th experiment
            %    * [true false,..]      Use logical indexing to select experiments
            %    * <name of selection>  Use one or more user defined selection in obj.sel
            %    * <property name>, <condition> Select based on a given condition for a given
            %        physical property, where the condition can be
            %        * an allowed range for the property given by [min max] as row vector,
            %        * a single value in which case the property must be equal to that value (tested
            %          with abs(<property value> - <condition>) < eps),
            %        * a column vector with more than 1 element in which case the ismember function
            %          is used to find all experiments with values exactly matching the given ones,
            %        * or a function handle to test the property value for each experiment
            %        For numeric comparisons the property value is converted to the max (avoids NaN)
            %        of its numeric represenation, but note: in case the given property refers to
            %        data that is handled as cellstr (i.e. each experiment has a single string) and
            %        the condition is a cellstr or single char, the experiments with matching
            %        strings are selected (using the ismember function). If the condition is ':'
            %        every experiment is selected, but note: this means that the input (':') is not
            %        interpreted as a regular string, e.g. as a possible value in a physical.
            %        property that is stored in a cellstr. It's also possible to give a function
            %        handle to a test function that is supposed to work on the original data (and
            %        not on the max of the numeric representation) for each experiment.
            %    * It is also possible to combine any of the previous ways to select experiments,
            %        where the default logical operator is assume to be an AND. The operator can
            %        also be specified explicitly, i.e '-or', '-and', '-not' or '-xor'. This can be
            %        used to build long conditions to select specific experiments.
            %
            
            if nargin < 2, doSelect = true; end
            % flatten input
            if numel(varargin) == 1 && iscell(varargin{1}) % && ~iscellstr(varargin{1})
                varargin = varargin{1};
            end
            % find allowed names of selections and logical operators
            fnSelection = fieldnames(obj.sel);
            fnOperator  = {'-not' '-or' '-and' '-xor'};
            % process input
            if numel(varargin) < 1
                % no additional input: start gui including selection part
                show(obj);
                res = obj.enable;
                return;
            end
            %
            % multiple combination of selection names, commands, linear and logical indexing as well
            % as <property>,condition-pairs are possible. Scan the input one-by-one and determine
            % the case that needs to be handled each time.
            %
            % start with all experiments available for selection
            input = varargin;
            res   = true(size(obj.enable));
            % scan one-by-one
            while ~isempty(input)
                % determine current operator with the logical AND being the default
                if ~isempty(input{1}) && ischar(input{1}) && ismember(input{1},fnOperator)
                    operator  = input{1};
                    opIsGiven = true;
                    input(1)  = [];
                else
                    operator  = '-and';
                    opIsGiven = false;
                end
                % determine current case and apply selection
                if ~isempty(input{1}) && ischar(input{1}) && ismember(input{1},obj.myprop)
                    %
                    % a physical property is given, next input must be a condition
                    %
                    strProp     = input{1};
                    [~,indProp] = ismember(strProp,obj.myprop);
                    input(1)    = [];
                    % get the property value
                    val = obj.(strProp);
                    % determine current condition
                    if isempty(input)
                        error(sprintf('%s:Input',mfilename),['Unexpected input to select experiments, ',...
                            'the given property ''%s'' is not followed by any condition ',...
                            '(total number of experiments: %d)'],strProp, obj.numAbs);
                    elseif ~isempty(input{1}) && ( ...
                            (isfloat(input{1}) && numel(input{1}) > 0) || ...
                            isa(input{1}, 'function_handle') || ...
                            isa(input{1}, class(val)) || ...
                            ((isa(val,'categorical') || iscellstr(val)) && ...
                            (iscellstr(input{1}) || ischar(input{1}))) || ...
                            (ischar(input{1}) && strcmp(input{1},':')))
                        condition = input{1};
                        input(1)  = [];
                    elseif isempty(input{1})
                        % an empty input is given, which should lead to no selection at all
                        condition = [];
                        input(1)  = [];
                    else
                        error(sprintf('%s:Input',mfilename),['Unexpected input to select experiments, ',...
                            'input does not seem to be a valid condition for property ''%s'' ',...
                            '(total number of experiments: %d)'],strProp, obj.numAbs);
                    end
                    % process combination of property value and condition
                    if isempty(condition)
                        tmp = false(size(obj.enable));
                    elseif ischar(condition) && numel(condition) == 1 && strcmp(condition,':')
                        tmp = true(size(obj.enable));
                    elseif iscellstr(val) && (iscellstr(condition) || ischar(condition))
                        % find experiments with strings matching at least one entry in the condition
                        tmp = ismember(val,condition);
                    elseif isa(val,'categorical') && ischar(condition)
                        % find experiments based on categorical class support for comparison
                        tmp = val == condition;
                    elseif isa(val,'categorical') && iscellstr(condition)
                        % find experiments based on categorical class support for ismember
                        tmp = ismember(val,condition);
                    elseif isa(val,'datetime') && (isa(condition,'datetime') || numel(condition)==2)
                        % find experiments based on datetime class support for comparison
                        tmp = isbetween(val,condition(1),condition(2));
                    elseif isa(condition,'function_handle')
                        % function should evaluate to true or false for each single experiment
                        siz = repmat({':'},1,ndims(val)); siz{1} = 1;
                        testRun = condition(val(siz{:}));
                        if ~(islogical(testRun) && isscalar(testRun))
                            error(sprintf('%s:Input',mfilename),['Given condition did not evaluate ',...
                                'to logical indices of correct size']);
                        end
                        tmp = false(obj.numAbs,1);
                        for i = 1:obj.numAbs
                            siz{1} = i;
                            tmp(i) = condition(val(siz{:}));
                        end
                        clearvars dat
                    elseif isa(condition,class(val)) && iscolumn(val)
                        % condition is of same class as the property (which holds a scalar value per
                        % experiment), lets assume both support comparison and equal operators, as
                        % well as ismember function
                        if isscalar(condition)
                            tmp = val == condition;
                        elseif numel(condition) == 2 && isrow(condition)
                            tmp = val >= condition(1) & val <= condition(2);
                        elseif iscolumn(condition)
                            tmp = ismember(val,condition);
                        else
                            error(sprintf('%s:Input',mfilename),...
                                'Unexpected input as condition for property ''%s''',strProp);
                        end
                    elseif isfloat(condition)
                        % condition is a float that can be used to compare, etc. convert property to
                        % float too if necessary by <property>2Numeric function
                        %
                        % get value and compute max if necessary. Note: MAX (used to be MEAN) may
                        % not preserve the class of the data, which may make the cast necessary. A
                        % cast is also necessary if the condition is not of the same class as the
                        % property or if it involves some math in which case a cast to double seems
                        % to be the best option
                        if isempty(obj.myprop2Numeric{indProp})
                            curval = val;
                        else
                            curval = obj.myprop2Numeric{indProp}(obj,val,(1:obj.numAbs)');
                        end
                        if ~obj.ismyarray(curval)
                            error(sprintf('%s:Input',mfilename),['Conversion to floating value failed ',...
                                'for property ''%s'', check %s2Numeric function'],strProp,strProp);
                        end
                        if isscalar(condition)
                            tmp = abs(curval-condition) < eps;
                        elseif numel(condition) == 2 && isrow(condition)
                            tmp = curval >= min(condition) & curval <= max(condition);
                        elseif iscolumn(condition)
                            tmp = ismember(curval,condition);
                        else
                            error(sprintf('%s:Input',mfilename),...
                                'Unexpected input as condition for property ''%s''',strProp);
                        end
                    else
                        error(sprintf('%s:Input',mfilename),...
                            'Unexpected input as condition for property ''%s''',strProp);
                    end
                    if ~islogical(tmp) || numel(tmp) ~= obj.numAbs
                        error(sprintf('%s:Input',mfilename),['Given condition did not evaluate ',...
                            'to logical indices of correct size']);
                    end
                    % add current selection
                    res = applyOperator(res,operator,tmp);
                elseif ~isempty(input{1}) && ischar(input{1}) && ismember(input{1},fnSelection)
                    %
                    % a selection is given
                    %
                    strSel   = input{1};
                    input(1) = [];
                    % handle user defined selections as new input, Note: might lead to a
                    % infinite recursion, but user should take care of this
                    tmp = findExp(obj,true,obj.sel.(strSel));
                    % add current selection
                    res = applyOperator(res,operator,tmp);
                elseif ischar(input{1})
                    %
                    % single string as input that is not the name of a selection or a physical
                    % property: perform given action
                    %
                    task     = input{1};
                    input(1) = [];
                    if ismember(task,{'today','daily'}) || (numel(task) > 5 && strcmp(task(1:4),'last') && ...
                            strcmp(task(end),'d') && all(ismember(task(5:end-1),'1234567890')))
                        if ismember(task,{'today','daily'}), dur = 1;
                        else,dur = str2double(task(5:end-1));
                        end
                        % select last x days
                        d1  = datetime('now');
                        d1  = datetime(d1.Year,d1.Month,d1.Day+1);
                        d2  = datetime(d1.Year,d1.Month,d1.Day-dur);
                        tmp = findExp(obj,true,'time',sort([d2 d1]));
                        % add current selection
                        res = applyOperator(res,operator,tmp);
                    else
                        switch task
                            case {'all','a',':'}
                                res = applyOperator(res,operator,true(size(obj.enable)));
                            case {'none','n'}
                                res = applyOperator(res,operator,false(size(obj.enable)));
                            case {'inverse','invert','i'}
                                if opIsGiven
                                    error(sprintf('%s:Input',mfilename),['The inverse command should ',...
                                        'be given without any operator, since it only makes sense ',...
                                        'when applied directly to the current selection']);
                                else
                                    res = ~res;
                                end
                            otherwise
                                fnSel  = fieldnames(obj.sel);
                                strSel = sprintf('''%s'', ',fnSel{:});
                                strSel = strSel(1:end-2);
                                error(sprintf('%s:Input',mfilename),['Unknown input string ''%s'', ',...
                                    'possible builtin commands are ''all'' (''a'', '':''), ''none'' (''n''), ',...
                                    '''today'' (''daily''), ''inverse'' (''invert'',''i''), for other ways to ',...
                                    'select experiments have a look at the documentation of findExp, e.g. ',...
                                    'in order to select based on a physical property and a condition. ',...
                                    'Another option is to specify the name of an user defined selection, ',...
                                    'where currently the following names are valid: %s.'],task,strSel);
                        end
                    end
                elseif isempty(input{1}) || (isnumeric(input{1}) && isequal(input{1},0))
                    % empty value or zero means no selected experiment
                    res      = applyOperator(res,operator,false(size(obj.enable)));
                    input(1) = [];
                elseif islogical(input{1}) && numel(input{1}) == obj.numAbs
                    % logical indexing
                    res      = applyOperator(res,operator,input{1});
                    input(1) = [];
                elseif isnumeric(input{1}) && max(input{1}(:)) <= obj.numAbs && min(input{1}(:)) > 0
                    % linear indexing
                    tmp              = false(size(obj.enable));
                    tmp(input{1}(:)) = true;
                    res              = applyOperator(res,operator,tmp);
                    input(1)         = [];
                else
                    error(sprintf('%s:Input',mfilename),['Unexpected input to select ',...
                        'experiments, input does not seem to be a valid physical property ',...
                        '(total number of experiments: %d)'],obj.numAbs);
                end
            end
            % choose whether to select or unselect
            if ~doSelect
                tmp      = res;
                res      = obj.enable;
                res(tmp) = false;
            end
            
            function res = applyOperator(res,operator,tmp)
                %applyOperator Adds current case to selection based on current operator
                
                switch operator
                    case '-xor'
                        res = xor(res,tmp);
                    case '-and'
                        res = res & tmp;
                    case '-or'
                        res = res | tmp;
                    case '-not'
                        res = res & ~tmp;
                end
            end
        end
        
        function varargout     = physicalProperties(obj,varargin)
            % physicalProperties Shows information on physical properties and returns string with
            % information, in case the last input is a logical true the display of the information
            % is switched off
            
            noDisp   = false;
            propsAll = reshape([obj.myprop(:); {'gravity'; 'boltzmann'; 'planck'; 'speedOfLight'}],1,[]);
            if nargin > 1 && islogical(varargin{end})
                noDisp = varargin{end}; varargin = varargin(1:end-1);
            end
            if numel(varargin) == 1 && iscellstr(varargin{1})
                propsAll = varargin{1};
            elseif numel(varargin) > 0 && iscellstr(varargin)
                propsAll = varargin;
            elseif numel(varargin) > 0
                error(sprintf('%s:Input',mfilename),'Unknown input');
            end
            nargoutchk(0,3);
            % get information string on properties
            str = cell(numel(propsAll),1);
            for i = 1:numel(propsAll)
                tmp = strsplit(strtrim(help(sprintf('%s.%s',class(obj),propsAll{i}))),'\n');
                tmp = tmp{1};
                [token, remain] = strtok(tmp);
                if strcmp(token,propsAll{i})
                    remain = strtrim(remain);
                else
                    remain = tmp;
                end
                str{i} = remain;
            end
            % create final strings on properties
            nName = max(cellfun(@numel,propsAll));
            desc  = str;
            for i = 1:numel(str)
                str{i} = sprintf('%*s:  %s',nName,propsAll{i},str{i});
            end
            % print to command line
            if ~noDisp
                div   = repmat('-',1,max(cellfun(@numel,str)));
                fprintf('Physical properties of class ''%s''\n%s\n',class(obj),div)
                for i = 1:numel(str)
                    fprintf('%s\n',str{i});
                end
                fprintf('%s\n',div);
            end
            if nargout > 0
                varargout = {desc propsAll str};
                varargout = varargout(1:nargout);
            end
        end
        
        function                 disp(obj)
            % disp Displays object on command line
            
            newLineChar = char(10);
            spacing     = '     ';
            if isempty(obj)
                tmp = sprintf('%sEmpty object of class ''%s''',spacing,class(obj));
            elseif numel(obj) > 1
                tmp = [spacing, sprintf('Object array of class ''%s'', Size %s, %.2f MiB \n',...
                    class(obj),mat2str(size(obj)),sum(obj.memory))];
            else
                % Option 1: Show complete statistics
                % tmp = [spacing, obj.info];
                % Option 2: Show memory usage and selection
                tmp = [spacing sprintf('%s, Memory usage: %.2f MiB, Selected experiments: %d of %d\n', ...
                    class(obj),sum(obj.memory),numel(obj.ind),obj.numAbs)];
            end
            tmp = strrep(tmp, newLineChar, [newLineChar, spacing]);
            disp(tmp);
            if ~isequal(get(0,'FormatSpacing'),'compact')
                disp(' ');
            end
        end
        
        function varargout     = show(obj)
            % show Shows GUI with information on experiments
            
            nargoutchk(0,1);
            out = NGS01Info(obj);
            show(out);
            if nargout > 0, varargout = {out}; end
        end
        
        function [out, nExp, allGood, isUnknown] = readProperties(obj,filename,props,defVal,...
                includeName,excludeName,loadVideo,keepUnknown)
            % readProperties Reads a MAT file that should contain properties for the current object
            % and prepares them to be added to the object. It also accepts the properties as a
            % scalar structure instead of the filename.
            %
            % Input:
            %      filename: The fullpath of the file to read  or a scalar structure with class properties (char or struct)
            %         props: The properties to read from the file (cellstr)
            %        defVal: Default values for each element in props (cell)
            %      includeName, excludeName: Optional names of experiments to in- or exclude (cellstr)
            %     loadVideo: True/false whether to load Video objects from structure or conver to structure (logical)
            %   keepUnknown: True/false whether to return unknown properties as well (logical)
            %
            % Note: The function does not perform error checking of the given inputs
            %
            
            %
            % check input
            if nargin < 5, includeName = []; end
            if nargin < 6, excludeName = []; end
            if nargin < 7, loadVideo   = true; end
            if nargin < 8, keepUnknown = false; end
            allGood   = true;
            isUnknown = false;
            %
            % load data file, perform a first check and remove unknown data
            if ischar(filename)
                out = load(filename);
            else
                out = filename;
            end
            fn        = fieldnames(out);
            myrootdir = '';
            if isfield(out,'rootdir') && ischar(out.rootdir), myrootdir = out.rootdir; end
            idx = ~ismember(fn,props) & ~ismember(fn,'rootdir');
            if any(idx)
                str = sprintf('''%s'', ',fn{idx}); str = str(1:end-2);
                fprintf(['data contains unknown property(ies) (%s), consider to clean ',...
                    'the data source to save storage space, '] , str);
                isUnknown = true;
                allGood   = false;
            end
            idx = ismember(fn, props);
            if ~keepUnknown, out = rmfield(out,fn(~idx)); end
            fn  = fn(idx);
            if numel(fn) < 1
                fprintf('no physical property is available in the data at all, ');
                if ~keepUnknown, out = struct; end
                nExp    = 0;
                allGood = false;
                return;
            end
            idx = ismember(props,fn);
            if ~all(idx)
                str = sprintf('''%s'', ',props{~idx}); str = str(1:end-2);
                fprintf(['some physical independent properties (%s) are not ',...
                    'available in the data, '], str);
                allGood = false;
            end
            %
            % determine number of experiment available for all properties
            siz  = size(out.(fn{1}));
            nExp = siz(1);
            flag = false;
            for k = 1:numel(fn)
                siz  = size(out.(fn{k}));
                if siz(1) ~= nExp
                    fprintf(['number of experiments (%d) for property ''%s'' is not consistent ',...
                        'with expected number of experiments (%d) (reducing expected number ',...
                        'neglecting some experiments), '], siz(1), fn{k}, nExp);
                    nExp    = min(siz(1),nExp);
                    allGood = false;
                    flag    = true;
                end
            end
            %
            % include and exclude based on name
            if nExp > 0 && (~isempty(includeName) || ~isempty(excludeName)) && ismember('name',fn)
                curname = out.name(1:nExp);
                if ~isempty(includeName)
                    idxOk = reshape(ismember(curname,includeName),1,[]);
                else
                    idxOk = true(1,nExp);
                end
                if ~isempty(excludeName)
                    idxOk = reshape(~ismember(curname,excludeName),1,[]) & idxOk;
                else
                    idxOk = true(1,nExp) & idxOk;
                end
                idxData = reshape(find(idxOk),1,[]);
                nExp    = numel(idxData);
                flag    = true;
            else
                idxData = 1:nExp;
            end
            %
            % trim known data
            if flag && nExp > 0
                for k = 1:numel(fn)
                    tmp         = repmat({':'},1,ndims(out.(fn{k})));
                    tmp{1}      = idxData;
                    out.(fn{k}) = out.(fn{k})(tmp{:});
                end
            end
            if nExp < 1
                fprintf('no data available after filtering at all, ');
                if ~keepUnknown, out = struct; end
                nExp    = 0;
                allGood = false;
                return;
            end
            %
            % prepare and check data
            % * special care for Video objects to change their filename in case the rootdir changed
            % * special care for class property setName to convert numeric input to char
            % * convert cellstr to categorical and vice versa
            rd = obj.rootdir;
            for k = 1:numel(fn)
                [~,idx] = ismember(fn{k},props);
                siz     = size(out.(fn{k}));
                clas    = class(out.(fn{k}));
                defSiz  = size(defVal{idx});
                defClas = class(defVal{idx});
                skipMe  = false;
                % check data types or special property
                if (isa(defVal{idx},'Video') && (isa(out.(fn{k}),'Video') || ...
                        (isstruct(out.(fn{k})) && isfield(out.(fn{k}),'filename')))) || ...
                        (~obj.isVideo && isa(out.(fn{k}),'Video'))
                    % find video with non-empty filename and adjust prefix due to rootdir
                    idxOK          = find(~cellfun('isempty',{out.(fn{k}).filename}));
                    newFile        = cell(siz);
                    newFile(idxOK) = NGS01.fixFilename({out.(fn{k})(idxOK).filename},rd,myrootdir,false,false);
                    for v = reshape(idxOK,1,[])
                        out.(fn{k})(v).filename = newFile{v};
                    end
                    % make sure the Videos already stored do have a class field
                    if isstruct(out.(fn{k})) && ~isfield(out.(fn{k}),'class')
                        fprintf(['data contains Video data that was stored without specifying the ',...
                            'actual class, conversion is performed assuming class ''Video'', ']);
                        for v = 1:numel(out.(fn{k})), out.(fn{k})(v).class = 'Video'; end
                    end
                    % create video from structure
                    if obj.isVideo && loadVideo && ~isa(out.(fn{k}),'Video')
                        out.(fn{k}) = Video.loadobj(out.(fn{k}));
                        % query a few properties such that they are set and unlink video
                        out.(fn{k}).nFrames;
                        unlink(out.(fn{k}));
                    elseif (~loadVideo || ~obj.isVideo) && isa(out.(fn{k}),'Video')
                        out.(fn{k}) = saveobj(out.(fn{k}));
                    end
                elseif strcmp(fn{k},'setName') && isnumeric(out.(fn{k}))
                    % convert a numeric set index to a char in a categorical array
                    out.(fn{k}) = categorical(arrayfun(@(x) num2str(x),out.(fn{k}),'un',false));
                elseif isa(defVal{idx},'datetime') && isfloat(out.(fn{k}))
                    % convert float to datetime assuming the float is a datenum
                    out.(fn{k}) = datetime(out.(fn{k}),'ConvertFrom','datenum');
                    fprintf(['property ''%s'' was given as float but is now a datetime ',...
                        'according to the class definition but a conversion is possible ',...
                        'assuming the float is a datenum, '], fn{k});
                elseif isa(defVal{idx},'categorical') && iscellstr(out.(fn{k}))
                    % convert cellstring to categorical, this is necessary if the data type was
                    % changed in the class definition and old data is loaded
                    out.(fn{k}) = categorical(out.(fn{k}));
                    fprintf(['property ''%s'' was given as cellstr but is now a categorical ',...
                        'according to the class definition but a conversion is possible, '], fn{k});
                elseif iscellstr(defVal{idx}) && isa(out.(fn{k}),'categorical')
                    % convert categorical to cellstring
                    out.(fn{k}) = cellstr(out.(fn{k}));
                    fprintf(['property ''%s'' was given as categorical but is now a cellstr ',...
                        'according to the class definition but a conversion is possible, '], fn{k});
                elseif ~strcmp(defClas,clas)
                    fprintf(['property ''%s'' was given as ''%s'' but is now a ''%s'' ',...
                        'according to the class definition, trying to perform a cast, '], ...
                        fn{k},clas,defClas);
                    try
                        out.(fn{k}) = cast(out.(fn{k}),defClas);
                    catch err
                        fprintf('error while performing the cast (property ''%s'' is not loaded): %s, ',...
                            fn{k}, err.getReport);
                        if ~keepUnknown, out = rmfield(out,fn{k}); end
                        skipMe = true;
                    end
                end
                % check sizes
                if ~skipMe && ~isequal(siz(2:end), defSiz(2:end))
                    fprintf(['number of values per experiment (%d element(s)) for property ',...
                        '''%s'' is not consistent with class definition (%d element(s)) ',...
                        '(filling up with default values or deleting to match class definition), '], ...
                        prod(siz(2:end)),fn{k},prod(defSiz(2:end)));
                    if (~loadVideo || ~obj.isVideo) && isa(defVal{idx},'Video')
                        defVal{idx} = saveobj(defVal{idx});
                    end
                    tmp = repmat(defVal{idx},nExp,1);
                    if prod(siz(2:end)) > prod(defSiz(2:end))
                        % more data available per experiment in the file as compared to the class
                        for l = 1:size(tmp,1)
                            tmp(l,:) = out.(fn{k})(l,1:prod(defSiz(2:end)));
                        end
                    else
                        % less data available per experiment in the file as compared to the class
                        for l = 1:size(tmp,1)
                            tmp(l,1:prod(siz(2:end))) = out.(fn{k})(l,:);
                        end
                    end
                    out.(fn{k}) = tmp;
                end
            end
        end
    end
    
    methods (Access = protected, Hidden = false)
        function                 notifyMe(obj,event,varargin)
            % notifyMe Notifies about an event and takes care of class internal reaction to event
            
            switch event
                case {'resetData' 'resetNew'}
                    obj.p_dir     = [];
                    obj.p_uuidStr = [];
                    resetSub(obj,event,varargin{:});
                    resetMemoryStats(varargin{:});
                case 'resetMemory'
                    resetMemoryStats(varargin{:});
                case 'resetSelection'
                case 'resetSettings'
                    resetMemoryStats(varargin{:});
                otherwise
                    error(sprintf('%s:Input',mfilename),'Unknown event, please check!');
            end
            notify(obj,event);
            
            function resetMemoryStats(varargin)
                % flatten input
                if numel(varargin) == 1 && iscell(varargin{1})
                    input = varargin{1};
                else
                    input = varargin;
                end
                if isempty(input)
                    input = obj.myprop;
                end
                [indOk, ind]      = ismember(input,obj.myprop2Set);
                ind               = ind(indOk);
                obj.p_memory(ind) = NaN;
            end
        end
        
        function                 p_store(obj,mode,keepUnknown,varargin)
            % p_store Stores data of selected experiments or given experiments in data file
            %    Optional input is given to findExp to work on specified experiments instead of
            %    current selection. The function only stores independent, non-constant physical
            %    properties in a file stored in the folder for each UID.
            %
            %  mode values:
            %    0: store to normal file and call store function of Video objects
            %    1: store to backup file and call backup function of Video objects
            %    2: store to normal file and remove all but the last backup file
            %    3: store to backup file and remove all but the last backup file (also for Video)
            
            %
            % get indices of experiments
            if numel(varargin) > 0
                ind = findExp(obj,true,varargin{:});
            else
                ind = obj.enable;
            end
            %
            % get properties, their default value and UIDs to store
            props   = obj.myprop2Set;
            defVal  = obj.myprop2SetDefault;
            uids    = unique(obj.uid(ind));
            allGood = true;
            %
            % store data uid by uid
            nMax   = ceil(log10(numel(uids)));
            bakdir = pwd;
            myWaitbar(obj,'start',sprintf('Storing data of %d UID(s)...',numel(uids)));
            fprintf('%*d data file(s) are tried to be written\n',nMax,numel(uids));
            for i = 1:numel(uids)
                %
                % check for waitbar
                if myWaitbar(obj,'check',sprintf('Canceled after %d of %d UID(s)\n',...
                        i-1,numel(uids))), break; end
                %
                % find all experiment of current UID
                idx   = find(obj.uid == uids(i));
                mydir = unique(obj.dir(idx));
                if numel(mydir) > 1
                    error(sprintf('%s:Input',mfilename),['Experiments of uid = %d seem to be stored ',...
                        'in different directories, which is not supported for object of class ''%s'''],...
                        uids(i),class(obj));
                end
                mydir          = char(mydir(1));
                dataFileNormal = fullfile(mydir,sprintf('%s%s.mat',obj.dataFilePrefix,class(obj)));
                cd(mydir);
                if any(mode == [0 2])
                    % store to normal file
                    dataFile = dataFileNormal;
                    fprintf('  ''%s'': ',dataFile);
                elseif any(mode == [1 3])
                    % create a new backup file
                    counter  = 0;
                    dataFile = @(x) fullfile(mydir,sprintf('%s%s.BAK%0.2d.mat',obj.dataFilePrefix,class(obj),x));
                    while exist(dataFile(counter),'file') == 2
                        counter = counter + 1;
                    end
                    dataFile = dataFile(counter);
                    fprintf('  ''%s'': ',dataFile);
                    fntest   = dir(fullfile(mydir,sprintf('%s%s.BAK*.mat',obj.dataFilePrefix,class(obj)))); %#ok<CPROPLC>
                    fntest([fntest.isdir]) = [];
                    if numel(fntest) ~= counter
                        fprintf(['mismatch in number of backup files, possible due to discontinuous ',...
                            'numbering, next backup will be written to ''%s'', please check and ',...
                            'clean up manually, '],dataFile);
                        allGood = false;
                    end
                end
                %
                % read existing data file, the base of a normal or backup file is the normal file to
                % make sure any unknown data is copied to the backup file as well
                if exist(dataFileNormal,'file') && numel(dir(dataFileNormal)) == 1 %#ok<CPROPLC>
                    fprintf('reading existing data, ');
                    [dat, nExp, myGood] = readProperties(obj,dataFileNormal,props,defVal,[],[],false,keepUnknown);
                    allGood             = allGood && myGood;
                    % check uid in data file
                    if ~all(dat.uid == uids(i))
                        error(sprintf('%s:Input',mfilename),['Experiments in data file ''%s'' exhibit ',...
                            'a different or multiple UIDs, please check!'],dataFileNormal);
                    end
                    % find index in data file to store new data
                    [idxFound, idxDat] = ismember(obj.index(idx),dat.index);
                    idxDat(~idxFound)  = nExp + (1:sum(~idxFound));
                else
                    fprintf('creating new file, ');
                    dat     = struct;
                    idxDat  = 1:numel(idx);
                end
                %
                % copy data to temporary structure Note: special care is taken of properties that
                % hold a Video object, the object is converted to a structure such that the absolute
                % path of the videos can be changed to the current rootdir during loading the file.
                % This will also trigger the store method of the video class.
                for k = 1:numel(props)
                    % get data
                    tmp    = repmat({':'},1,ndims(defVal{k}));
                    tmpObj = tmp; tmpObj{1} = idx;
                    tmpDat = tmp; tmpDat{1} = idxDat;
                    if isa(defVal{k},'Video')
                        % convert video data to be stored as a structure, should also call the store
                        % object of a video object
                        tmpSet         = saveobj(obj.(props{k})(tmpObj{:}));
                        % remove the complete path such that the video are loaded correctly when
                        % opened from their folder
                        idxOK          = find(~cellfun('isempty',{tmpSet.filename}));
                        newFile        = cell(size(tmpSet));
                        newFile(idxOK) = NGS01.fixFilename({tmpSet(idxOK).filename},'',mydir,false);
                        for v = reshape(idxOK,1,[])
                            tmpSet(v).filename = newFile{v};
                        end
                        dat.(props{k})(tmpDat{:}) = tmpSet;
                        % make backup with the Video class function to disk
                        if mode == 1
                            backup2Disk(obj.(props{k})(tmpObj{:}));
                        elseif mode == 3
                            backup2DiskClean(obj.(props{k})(tmpObj{:}));
                        end
                    else
                        dat.(props{k})(tmpDat{:}) = obj.(props{k})(tmpObj{:});
                    end
                end
                %
                % store rootdir as fullpath and store file to disk
                dat.rootdir = fullpath(obj.rootdir); %#ok<STRNU>
                save(dataFile,'-struct','dat');
                %
                % remove everything but last backup file
                if any(mode == [2 3])
                    fprintf('%3d experiment(s) stored, ',numel(idxDat));
                    bakFile = dataFile;
                    % find last backup file
                    counter  = 0;
                    dataFile = @(x) fullfile(mydir,sprintf('%s%s.BAK%0.2d.mat',obj.dataFilePrefix,class(obj),x));
                    while exist(dataFile(counter),'file') == 2
                        counter = counter + 1;
                    end
                    if counter <= 1
                        % at maximum one backup available
                        counter = 0;
                    else
                        % move last bakup file to the first
                        movefile(dataFile(counter-1), dataFile(0));
                        % remove files
                        counter = 1;
                        while exist(dataFile(counter),'file') == 2
                            delete(dataFile(counter))
                            counter = counter + 1;
                        end
                        % no change to counter since the movefile command also removed one backup
                        % file
                    end
                    fntest = dir(fullfile(mydir,sprintf('%s%s.BAK*.mat',obj.dataFilePrefix,class(obj)))); %#ok<CPROPLC>
                    fntest([fntest.isdir]) = [];
                    if numel(fntest) ~= 1
                        fprintf(['mismatch in number of backup files, possible due to discontinuous ',...
                            'numbering, last backup was written to ''%s'', please check and ',...
                            'clean up manually, '],bakFile);
                        allGood = false;
                    end
                    fprintf('%3d backup file(s) removed\n',counter);
                else
                    fprintf('%3d experiment(s) stored\n',numel(idxDat));
                end
                myWaitbar(obj,'update',i/double(numel(uids)));
            end
            cd(bakdir);
            myWaitbar(obj,'end');
            if ~allGood
                warning(sprintf('%s:Check',mfilename),['Some data file(s) could not be ',...
                    'written without any issue, please check previous output to command line ',...
                    'for an explanation of the issue(s)']);
            else
                fprintf('%*d data file(s) were written successfully\n',nMax,numel(uids));
            end
        end
        
        function                 p_recall(obj,mode,varargin)
            % p_recall Recalls data of selected experiments or given experiments from data file
            %    Optional input is given to findExp to work on specified experiments instead of
            %    current selection. The function only recalls independent, non-constant physical
            %    properties in a file stored in the folder for each UID.
            %
            %    Please note: any unknown data in a backup file must be manually copied to the
            %    normal file, since during a recall of a backup file, the normal is untouched
            %
            %  mode values:
            %    0: restore from normal file and call recall function of Video objects
            %    1: restore from latest backup file and call backup function of Video objects
            
            %
            % get indices of experiments
            if numel(varargin) > 0
                ind = findExp(obj,true,varargin{:});
            else
                ind = obj.enable;
            end
            %
            % get properties and nd UIDs to store
            props   = obj.myprop2Set;
            defVal  = obj.myprop2SetDefault;
            uids    = unique(obj.uid(ind));
            allGood = true;
            %
            % recall data uid by uid
            nMax   = ceil(log10(numel(uids)));
            bakdir = pwd;
            myWaitbar(obj,'start',sprintf('Recalling data of %d UID(s)...',numel(uids)));
            fprintf('%*d data file(s) are tried to be recalled\n',nMax,numel(uids));
            for i = 1:numel(uids)
                %
                % check for waitbar
                if myWaitbar(obj,'check',sprintf('Canceled after %d of %d UID(s)\n',...
                        i-1,numel(uids))), break; end
                %
                % find all experiment of current UID
                idx   = find(obj.uid == uids(i));
                mydir = unique(obj.dir(idx));
                if numel(mydir) > 1
                    error(sprintf('%s:Input',mfilename),['Experiments of uid = %d seem to be stored ',...
                        'in different directories, which is not supported for object of class ''%s'''],...
                        uids(i),class(obj));
                end
                mydir = char(mydir(1));
                cd(mydir);
                if mode == 0
                    % recall from normal file
                    dataFile = fullfile(mydir,sprintf('%s%s.mat',obj.dataFilePrefix,class(obj)));
                    fprintf('  ''%s'': ',dataFile);
                elseif mode == 1
                    % find a backup file
                    counter  = 0;
                    dataFile = @(x) fullfile(mydir,sprintf('%s%s.BAK%0.2d.mat',obj.dataFilePrefix,class(obj),x));
                    while exist(dataFile(counter),'file') == 2
                        counter = counter + 1;
                    end
                    if counter == 0
                        % no backup file available, set name to first one which will lead to a
                        % warning that no backup file was found
                        dataFile = dataFile(counter);
                    else
                        % backup file available
                        dataFile = dataFile(counter-1);
                        fprintf('  ''%s'': ',dataFile);
                        fntest = dir(fullfile(mydir,sprintf('%s%s.BAK*.mat',obj.dataFilePrefix,class(obj)))); %#ok<CPROPLC>
                        fntest([fntest.isdir]) = [];
                        if numel(fntest) ~= counter
                            fprintf(['mismatch in number of backup files, possible due to discontinuous ',...
                                'numbering, next backup will be restored from ''%s'', please check and ',...
                                'clean up manually, '],dataFile);
                            allGood = false;
                        end
                    end
                end
                %
                % read data file
                if exist(dataFile,'file') && numel(dir(dataFile)) == 1 %#ok<CPROPLC>
                    fprintf('reading existing data, ');
                    [dat, ~, myGood,isUnkown] = readProperties(obj,dataFile,props,defVal,[],[],false,false);
                    allGood                   = allGood && myGood;
                    % warning about unknown data
                    if isUnkown && mode == 1
                        fprintf(['backup file contains unknown data, that needs be recalled and ',...
                            'restored manually, since it is NOT copied to the normal file, ']);
                        allGood = false;
                    end
                    % check uid in data file
                    if ~all(dat.uid == uids(i))
                        error(sprintf('%s:Input',mfilename),['Experiments in data file ''%s'' exhibit ',...
                            'a different or multiple UIDs, please check!'],dataFile);
                    end
                    % find index in data file to store new data
                    [idxFound, idxDat] = ismember(obj.index(idx),dat.index);
                    if ~all(idxFound)
                        fprintf(['data file does not seem contain all requested experiments, ',...
                            'recalling available data, ']);
                        allGood = false;
                    end
                    idxDat = idxDat(idxFound);
                    idx    = idx(idxFound);
                    if ~isempty(idxDat)
                        %
                        % copy data from temporary structure Note: special care is taken of
                        % properties that hold a Video object, where the recall function of the
                        % video is used, otherwise the handle object gets replaced.
                        fn = fieldnames(dat);
                        for k = 1:numel(fn)
                            myDat  = obj.(fn{k});
                            tmp    = repmat({':'},1,ndims(myDat));
                            tmpObj = tmp; tmpObj{1} = idx;
                            tmpDat = tmp; tmpDat{1} = idxDat;
                            if isa(myDat,'Video')
                                if mode == 1
                                    restore2Disk(myDat(tmpObj{:}));
                                else
                                    recall(myDat(tmpObj{:}));
                                end
                            else
                                obj.(fn{k})(tmpObj{:}) = dat.(fn{k})(tmpDat{:});
                            end
                        end
                    end
                else
                    fprintf('data file not available, ');
                    allGood = false;
                end
                fprintf('%3d experiment(s) recalled\n',numel(idxDat));
                myWaitbar(obj,'update',i/double(numel(uids)));
            end
            cd(bakdir);
            myWaitbar(obj,'end');
            if ~allGood
                warning(sprintf('%s:Check',mfilename),['Some data file(s) could not be ',...
                    'recalled without any issue, please check previous output to command line ',...
                    'for an explanation of the issue(s)']);
            else
                fprintf('%*d data file(s) were recalled successfully\n',nMax,numel(uids));
            end
        end
        
        function [props, val]  = prop2Set(obj)
            % prop2Set Returns often used properties that define the experiment and their default value
            
            mc    = metaclass(obj);
            props = [mc.Properties{:}];
            ind1  = ismember({props.Name},obj.myprop);
            ind2  = arrayfun(@(x) ~x.Constant && ~x.Dependent,props);
            props = props(ind1 & ind2);
            if nargout > 1
                val = cell(size(props));
                for i = 1:numel(props)
                    if props(i).HasDefault
                        val{i} = props(i).DefaultValue;
                        if ~obj.isVideo
                            if isa(val{i},'Video')
                                val{i} = saveobj(val{i});
                            end
                        end
                    else
                        error(sprintf('%s:Check',mfilename),['Class property ''%s'' does not define a ',...
                            'default value, please check!'],props(i).Name);
                    end
                end
            end
            props = {props.Name};
        end
        
        function out           = myWaitbar(obj,varargin)
            % myWaitbar Creates a waitbar, updates or deletes it
            %
            % Inputs:
            % First input is the mode: 'start', 'check', 'end' or 'update
            % Second input depends on mode
            % start:   Nothing or title of waitbar
            % check:   Nothing or string printed in command window if cancel button was pressed
            % end:     Nothing or string printed in command window
            % update:  Numeric 0 .. 1
            %
            % Output:
            % true/false whether waitbar was canceled
            
            out = false;
            if obj.verbose < 100
                return
            end
            persistent deltaT
            persistent deltaW
            if numel(varargin) < 1
                error(sprintf('%s:Input',mfilename),'Missing input for waitbar');
            end
            
            switch varargin{1}
                case 'start'
                    % create waitbar if no other waitbar is already running
                    if ~ishandle(obj.hWaitbar)
                        deltaT = tic;
                        deltaW = 0;
                        if numel(varargin) > 1
                            obj.hWaitbar = waitbar(0,'Please wait, estimated remaining time 00:00:00 (HH:MM:SS)',...
                                'Name', varargin{2},'CreateCancelBtn','setappdata(gcbf,''canceling'',1)','Resize','on');
                        else
                            obj.hWaitbar = waitbar(0,'Please wait, estimated remaining time 00:00:00',...
                                'CreateCancelBtn','setappdata(gcbf,''canceling'',1)','Resize','on');
                        end
                        setappdata(obj.hWaitbar,'canceling',0)
                    elseif isempty(deltaT)
                        % make sure deltaT is available, may lead to an error when toc is called
                        % with an empty value
                        deltaT = tic;
                        deltaW = 0;
                    end
                case 'check'
                    % check cancel button of waitbar
                    if ~isempty(obj.hWaitbar) && ishandle(obj.hWaitbar) && getappdata(obj.hWaitbar,'canceling')
                        delete(obj.hWaitbar);
                        out = true;
                        if numel(varargin) > 1
                            fprintf('%s',varargin{2});
                        end
                    end
                case 'update'
                    % update waitbar
                    if numel(varargin) < 2 || ~(isnumeric(varargin{2}) && isscalar(varargin{2}))
                        error(sprintf('%s:Input',mfilename),'Missing or wrong input for waitbar');
                    end
                    tend = toc(deltaT)/(varargin{2}-deltaW) * (1-varargin{2});
                    nH   = floor(tend/60^2);
                    nM   = floor((tend-nH*60^2)/60);
                    nS   = round(tend-nH*60^2-nM*60);
                    if ishandle(obj.hWaitbar)
                        waitbar(varargin{2},obj.hWaitbar,...
                            sprintf('Please wait, estimated remaining time %0.2d:%0.2d:%0.2d (HH:MM:SS)',...
                            nH,nM,nS),'Resize','on');
                    end
                    % reset base for time calculation
                    if toc(deltaT) > 0.1 * tend
                        deltaT = tic;
                        deltaW = varargin{2};
                    end
                case 'end'
                    % delete waitbar
                    if ishandle(obj.hWaitbar)
                        delete(obj.hWaitbar);
                        if numel(varargin) > 1
                            fprintf('%s',varargin{2});
                        end
                    end
                otherwise
                    error(sprintf('%s:Input',mfilename),'Unexpected input for waitbar');
            end
        end
    end
    
    %% Methods for abstract implementation in subclass
    methods (Access = protected, Hidden = false, Abstract = true)
        resetSub(obj, event, varargin)
        % resetSub Reset storage properties in subclass that hold computational expensive results,
        % see also reset method in the parent class NGS01
    end
    
    methods (Static = true, Access = public, Hidden = false, Abstract = true)
        out = readParameters(filename,varargin)
        % readParameters Supposed to run and process the output of parameter file (M file). The
        % function should return a structure with class properties, which are then processed again
        % by readProperties to check for the correct data types and sizes. Before this function is
        % called the working directory is set to the folder where the parameter file is located. The
        % only additional input argument besides the filename of the parameter file is the name of
        % the class calling this function. If an empty value is returned the data from the parameter
        % file is ignored.
    end
    
    %% Static class related methods
    methods (Static = true, Access = public, Hidden = false)
        function out                 = getUUID(uid,index)
            %getUUID Determine the UUID based on the given UID and the index, no error checking
            
            % Option 1: bitshift in dual system, but is not so nicely read in decimal system
            % out = bitshift(uint64(uid),32) + uint64(index);
            % Option 2: decimal shift, less experiments can be handled but easier to read
            out = 1e9 * uint64(uid) + uint64(index);
        end
        
        function [filename, isFound] = fixFilename(filename, newRoot, oldRoot, doCheck, doWarn)
            % fixFilename Takes a filename (char or cellstr) that holds the fullpath of a file as
            % set with a different rootdir and returns an updated filename with the current rootdir.
            % It also replaces the file separator and can perfom a check if the file actually
            % exists. If old root directory is empty, now replacement will take place. If new root
            % is emtpy, the old root is removed and a relative path is returned.
            
            %
            % check input
            narginchk(2,5);
            if nargin < 3, oldRoot = ''; end
            if nargin < 4, doCheck = true; end
            if nargin < 5, doWarn  = true; end
            if ~ischar(oldRoot)
                error(sprintf('%s:Input',mfilename),...
                    'Unknown input for old root directory');
            end
            if ~isempty(oldRoot), oldRoot = fullpath(oldRoot); end
            if ~isempty(newRoot), newRoot = fullpath(newRoot); end
            if ischar(filename)
                filename = NGS01.fixFilename({filename}, newRoot, oldRoot, doCheck);
                filename = filename{1};
                return;
            elseif ~iscellstr(filename)
                error(sprintf('%s:Input',mfilename),...
                    'Unknown input for the file name(s)');
            end
            %
            % process filename(s) one by one
            doReplace = ~isempty(oldRoot);
            nOld      = numel(oldRoot);
            newSep    = filesep;
            isFound   = false(size(filename));
            if strcmp(newSep,'/'), oldSep = '\'; else, oldSep='/'; end
            for i = 1:numel(filename)
                if doReplace
                    idx = strfind(filename{i},oldRoot);
                    if isempty(idx) || idx ~=1
                        if doWarn
                            warning(sprintf('%s:Input',mfilename),['Old root directory ''%s'' is not found ',...
                                'at the beginning of filename ''%s'''], oldRoot, filename{i});
                        end
                    else
                        filename{i} = fullfile(newRoot,strrep(filename{i}((nOld+1):end),oldSep,newSep));
                        % remove leading '/'
                        if isempty(newRoot) && strcmp(filename{i}(1),filesep)
                            filename{i} = filename{i}(2:end);
                        end
                    end
                else
                    filename{i} = strrep(filename{i},oldSep,newSep);
                end
                if doCheck
                    if ~(exist(filename{i},'file') && numel(dir(filename{i})) == 1)
                        if doWarn
                            warning(sprintf('%s:Input',mfilename), 'Filename ''%s'' not found',filename{i});
                        end
                    else
                        isFound(i) = true;
                    end
                end
            end
        end
    end
    
    %% Methods related to the experimental setup that are of general use for sub classes
    % Those function are put in seperated files in the class directory, since they are changed more
    % often and eventually by multiple users. Furthermore, it helps to split up between functions
    % that focus more on data processing (external code files) or more on data handling (in this
    % code file).
    methods (Static = true, Access = public, Hidden = false)
        out              = labbookGetLiquids(varargin)
        [data, x0, hFig] = calibrationCurveFit(data,varargin)
        out              = parameterFileRead(in,type)
        out              = dataFileRead(in,type)
        h                = sgsdf_2d(x,y,nx,ny,d,flag_coupling)
        [ x, y, m, a]    = myPowerLaw( x, y, m, a )
    end
end
