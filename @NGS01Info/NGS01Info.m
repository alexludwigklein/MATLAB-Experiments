classdef NGS01Info < handle
    %NGS01Info Creates an info and selection GUI for the NGS01 class
    %
    %----------------------------------------------------------------------------------
    %   Copyright 2016 Alexander Ludwig Klein, alexludwigklein@gmail.com
    %
    %   Physics of Fluids, University of Twente
    %----------------------------------------------------------------------------------
    
    % todo: howto save selections?
    
    %% Properties
    properties (GetAccess = public, SetAccess = public, Dependent = true)
        % splitup Splitup ratio between the two main panels (scalar double)
        splitup
        % data Data object with n experiments (1 x NGS01 subclass)
        data
        % isLive True/false whether object should update automatically (logical)
        isLive
    end
    
    properties (GetAccess = public, SetAccess = protected, Dependent = true)
        % isGUI True/false whether main figure is currently open (logical)
        isGUI
        % mytab current tab on display
        mytab
        % name Name of experiment in playlist (n x cellstr)
        name
        % uuid Uuid's of experiments in playlist (n x uint64)
        uuid
        % enable Enabled experiments in GUI (n x logical)
        enable
    end
    
    properties (GetAccess = public, SetAccess = public, Transient = true)
        % userdata Arbitrary user data (arbitrary)
        userdata
    end
    
    properties (GetAccess = protected, SetAccess = protected, Transient = true)
        % main Main figure, uitab or uipanel (figure, uitab, uipanel)
        main      = [];
        % tab Info tabs (cell with NGS01Infotab subclass)
        tab       = {};
        % ui User interface objects, e.g. buttons (struct)
        ui        = struct;
        % p_data Storage for data
        p_data    = [];
        % p_name Storage for name
        p_name    = {};
        % p_uuid Storage for uuid
        p_uuid    = uint64.empty;
        % p_enable Storage for enable
        p_enable    = logical.empty;
        % listener Listeners to make object go live (struct)
        listener  = struct;
        % state State of GUI during reset (struct)
        state     = struct;
    end
    
    %% Constructor/Destructor, SET/GET
    methods
        function obj   = NGS01Info(data)
            %NGS01Info Class constructor taking the data object as first argument
            
            if nargin == 1 && isnumeric(data)
                % accepts single numeric input to create an array of objects
                obj       = NGS01Infotab;
                obj(data) = NGS01Infotab;
            elseif nargin > 0
                % set data property by set method that should take care of the initialisation
                if ismember('NGS01',superclasses(data))
                    obj.data   = data;
                    obj.isLive = true;
                else
                    error(sprintf('%s:Input',mfilename),'First input should be a subclass of NGS01 or numeric input to create an array of objects');
                end
            end
        end
        
        function         delete(obj)
            %delete Class destructor
            
            if ~isempty(obj.main), close(obj.main); end
            obj.isLive = false;
            obj.p_data = [];
        end
        
        function value = get.isLive(obj)
            value = ~isempty(fieldnames(obj.listener));
        end
        
        function         set.isLive(obj,value)
            if (islogical(value) || isnumeric(value)) && isscalar(value)
                value = logical(value);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for the property');
            end
            if value && ~isempty(obj.p_data)
                % delete current listeners
                fn = fieldnames(obj.listener);
                for k = 1:numel(fn), delete(obj.listener.(fn{k})); end
                % create new listeners
                obj.listener                = struct;
                obj.listener.resetNew       = event.listener(obj.p_data,'resetNew',       @(src,event) update(obj,'new'));
                obj.listener.resetData      = event.listener(obj.p_data,'resetData',      @(src,event) update(obj,'data'));
                obj.listener.resetSettings  = event.listener(obj.p_data,'resetSettings',  @(src,event) update(obj,'settings'));
                obj.listener.resetSelection = event.listener(obj.p_data,'resetSelection', @(src,event) update(obj,'selection'));
                obj.listener.deleteObject   = event.listener(obj.p_data,'deleteObject',   @(src,event) delete(obj));
                % set live status of all tabs
                for k = 1:numel(obj.tab), obj.tab{k}.isLive = false; end
                if ~isempty(obj.mytab), obj.mytab.isLive = true;end
                % update GUI
                update(obj,'all');
            else
                % delete current listeners and set live status of all tabs
                fn = fieldnames(obj.listener);
                for k = 1:numel(fn), delete(obj.listener.(fn{k})); end
                obj.listener = struct;
                for k = 1:numel(obj.tab)
                    obj.tab{k}.isLive = false;
                end
                % update GUI to make sure it reflects the current settings
                update(obj,'all');
            end
        end
        
        function value = get.data(obj)
            value = obj.p_data;
        end
        
        function         set.data(obj,value)
            if ismember('NGS01',superclasses(value))
                bakLive      = isempty(obj.p_data) || obj.isLive;
                obj.isLive   = false;
                obj.p_data   = value;
                obj.p_name   = {};
                obj.p_uuid   = uint64.empty;
                obj.p_enable = logical.empty;
                obj.isLive   = bakLive;
                update(obj,'all');
            elseif isempty(value)
                close(obj);
                obj.isLive   = false;
                obj.p_data   = [];
                obj.p_name   = {};
                obj.p_uuid   = uint64.empty;
                obj.p_enable = logical.empty;
                update(obj,'all');
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for the property');
            end
        end
        
        function value = get.splitup(obj)
            if obj.isGUI && isfield(obj.ui,'panelMain') && isvalid(obj.ui.panelMain)
                value = obj.ui.panelMain.Position(3);
            elseif isfield(obj.state,'splitup') && obj.state.splitup < 1
                value = obj.state.splitup;
            else
                value = 0.8;
            end
        end
        
        function         set.splitup(obj,value)
            if isnumeric(value) && isscalar(value) && value > 0 && value < 1
                if obj.isGUI
                    obj.ui.panelMain.Position(3) = value;
                    obj.ui.panelSide.Position    = [value 0 1-value 1];
                    obj.state.splitup            = value;
                else
                    obj.state.splitup = value;
                end
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for the property');
            end
        end
        
        function value = get.isGUI(obj)
            value = ~isempty(obj.main) && isgraphics(obj.main);
        end
        
        function value = get.name(obj)
            if isempty(obj.p_data)
                obj.p_name   = {};
                obj.p_uuid   = uint64.empty;
                obj.p_enable = logical.empty;
            else
                if isempty(obj.p_name) || isempty(obj.p_uuid) || isempty(obj.p_enable)
                    % get uuidStr and uuid without triggering a selection change
                    tmp = get(obj.p_data,true(obj.p_data.numAbs,1),'uuidStr','uuid','enable',false);
                    obj.p_name   = tmp{1};
                    obj.p_uuid   = tmp{2};
                    obj.p_enable = tmp{3};
                    nDig = 1+ceil(log10(numel(obj.p_name)));
                    for k = 1:numel(obj.p_name)
                        obj.p_name{k} = sprintf('%0.*d: %s',nDig,k,obj.p_name{k});
                    end
                end
            end
            value = obj.p_name;
        end
        
        function value = get.uuid(obj)
            if isempty(obj.p_uuid)
                % query name which should reset uuid too
                obj.name;
            end
            value = obj.p_uuid;
        end
        
        function value = get.enable(obj)
            if isempty(obj.p_enable)
                % query name which should reset enable too
                obj.name;
            end
            value = obj.p_enable;
        end
        
        function value = get.mytab(obj)
            value = [];
            if ~isempty(obj.tab) && obj.isGUI
                idx   = obj.ui.tabgroup.SelectedTab.UserData.idxTab;
                value = obj.tab{idx};
            end
        end
    end
    
    %% Methods for public tasks
    methods (Access = public, Hidden = false, Sealed = true)
        function show(obj,varargin)
            %show Opens GUI, wrapper for create function
            
            create(obj,varargin{:});
        end
        
        function create(obj,parent,reUse)
            %create (Re-)creates info and selection GUI
            
            if nargin < 3, reUse = true; end
            if nargin < 2, parent = []; end
            if numel(obj) > 1
                for i = 1:numel(obj), create(obj(i),parent,reUse); end
                return;
            end
            if isempty(obj.p_data)
                error(sprintf('%s:Input',mfilename),'Please add data to show GUI');
            end
            % 
            % Check if we need to clean the figure
            redoUI = false;
            if reUse
                strTab = cell(size(obj.tab));
                for k = 1:numel(strTab), strTab{k} = class(obj.tab{k}); end
                if ~isequal(obj.p_data.infopanel(:),strTab(:))
                    for k = 1:numel(obj.tab)
                        delete(obj.tab{k});
                    end
                    obj.tab = {};
                    if obj.isGUI,delete(obj.main.Children); redoUI = true; end
                end
            end
            %
            % Make sure a figure is available
            if ~reUse && obj.isGUI, delete(obj.main); obj.main = []; end
            if ~obj.isGUI
                if isempty(parent)
                    %
                    % Create single new figure
                    if ~isempty(fieldnames(obj.state)) && strcmp(obj.state.parent,'matlab.ui.Figure')
                        windowStyle = obj.state.WindowStyle;
                        position    = obj.state.Position;
                    else
                        tmp         = groot;
                        position    = get(tmp,'DefaultFigurePosition');
                        windowStyle = get(tmp,'DefaultFigureWindowStyle');
                    end
                    obj.main = figure('numbertitle', 'off', 'Visible','on',...
                        'name', 'Information and selection', ...
                        'Visible','off',...
                        'menubar','none', ...
                        'toolbar','figure', ...
                        'WindowStyle',windowStyle,...
                        'resize', 'on', ...
                        'DeleteFcn',@(src,dat) close(obj),...
                        'HandleVisibility','callback');
                    if strcmp(windowStyle,'normal')
                        obj.main.Position = position;
                    end
                elseif isgraphics(parent,'figure')
                    obj.main = uipanel('parent',parent,'Position',[0 0 1 1], 'Tag',sprintf('%s',class(obj)),...
                        'Units','Normalized','Title', 'Information and selection',...
                        'DeleteFcn',@(src,dat) close(obj));
                    if ~isempty(fieldnames(obj.state)) && strcmp(obj.state.parent,class(obj.main))
                        obj.main.Units    = obj.state.Units;
                        obj.main.Position = obj.state.Position;
                    end
                elseif isgraphics(parent,'uitabgroup')
                    obj.main = uitab(parent, 'Tag',sprintf('%s',class(obj)),...
                        'Units','Normalized','Title', 'Information and selection',...
                        'DeleteFcn',@(src,dat) close(obj));
                    if ~isempty(fieldnames(obj.state)) && strcmp(obj.state.parent,class(obj.main))
                        obj.main.Units    = obj.state.Units;
                        obj.main.Position = obj.state.Position;
                    end
                end
                redoUI = true;
            end
            % 
            % Create ui elements
            if redoUI
                %
                % Create main and side panel
                obj.ui.panelMain = uipanel('parent',obj.main,'Position',[0 0 obj.splitup 1], ...
                    'Tag','panelMain','Units','Normalized');
                obj.ui.panelSide = uipanel('parent',obj.main,'Position',[obj.splitup 0 1-obj.splitup 1],'BorderType','none', ...
                    'Tag','panelSide','Units','Normalized','SizeChangedFcn', @(src,dat) sizeChangedPanelSide(obj,src,dat));
                %
                % Create uitabgroup in main panel and create tabs
                obj.ui.tabgroup = uitabgroup(obj.ui.panelMain,'Position',[0 0 1 1],'Units','Normalized',...
                    'Tag','tabgroup','SelectionChangedFcn',@(src,dat) callbackMain(obj,'newTab',src,dat));
                if isempty(obj.tab)
                    % initialise tabs
                    obj.tab = cell(size(obj.p_data.infopanel));
                    for k = 1:numel(obj.p_data.infopanel)
                        func       = str2func(obj.p_data.infopanel{k});
                        obj.tab{k} = func(obj.p_data);
                        create(obj.tab{k},obj.ui.tabgroup,reUse);
                        obj.tab{k}.main.UserData.idxTab = k;
                    end
                else
                    % re-create tabs
                    for k = 1:numel(obj.tab)
                        create(obj.tab{k},obj.ui.tabgroup,reUse);
                        obj.tab{k}.main.UserData.idxTab = k;
                    end
                end
                %
                % Create GUI in side panel
                obj.ui.panelSideListbox = uipanel('parent',obj.ui.panelSide,'Position',[0 0.1 1 0.9], ...
                    'Tag','panelSideListbox','Units','Normalized');
                obj.ui.panelSideControl = uipanel('parent',obj.ui.panelSide,'Position',[0 0 1 0.1], ...
                    'Tag','panelSideControl','Units','Normalized');
                obj.ui.LBExperiments = uicontrol(obj.ui.panelSideListbox,'Units','normalized',...
                    'Style','listbox','Tag','LBExperiments', 'Min',1,'Max',10, 'String',{'outdated'},...
                    'KeyPressFcn', @(src,dat) callbackKeyPress(obj,src,dat),...
                    'callback', @(src,dat) callbackMain(obj,'LBExperiments',src,dat),...
                    'Value',1,'Position',[0 0.4 1 0.6], 'ToolTipString','Select none, one or more experiment(s)');
                obj.ui.LBSelection = uicontrol(obj.ui.panelSideListbox,'Units','normalized',...
                    'Style','listbox','Tag','LBSelection', 'Min',1,'Max',10, 'String',fieldnames(obj.p_data.sel),...
                    'callback', @(src,dat) callbackMain(obj,'LBSelection',src,dat),...
                    'Value',[],'Position',[0 0 1 0.4], 'ToolTipString','Select based on none, one or more selection(s) of experiments');
                obj.ui.PBUpdate = uicontrol(obj.ui.panelSideControl,'Units','normalized','Style','pushbutton',...
                    'String','Update','Tag','PBUpdate','Callback', @(src,dat) callbackMain(obj,'PBUpdate',src,dat),...
                    'UserData',[1 1], 'ToolTipString','Update GUI with current selection (return key)');
                obj.ui.CLive = uicontrol(obj.ui.panelSideControl,'Units','normalized','Style','checkbox',...
                    'String','Live','Tag','CLive','Value',obj.isLive,...
                    'Callback', @(src,dat) callbackMain(obj,'CLive',src,dat),'UserData',[1 2],...
                    'ToolTipString','Enable live update of GUI on data or selection change');
                obj.ui.ESelection = uicontrol(obj.ui.panelSideControl,'Units','normalized','Style','Edit',...
                    'String','1','Tag','ESelection','Callback', @(src,dat) callbackMain(obj,'ESelection',src,dat),...
                    'UserData',[2 0],'ToolTipString','Number of selected experiments in data object');
                % add a context menu to the listboxes
                obj.ui.LBExperiments.UIContextMenu = contextMenuLB01(obj,'LBExperiments');
                obj.ui.LBSelection.UIContextMenu   = contextMenuLB01(obj,'LBSelection');
                obj.ui.ESelection.UIContextMenu    = contextMenuLB01(obj,'ESelection');
                %
                % Make sure the positions are set and GUI is updated
                drawnow;
                sizeChangedPanelSide(obj,obj.ui.panelSide);
                update(obj,'all');
                % make current tab live
                if ~isempty(obj.mytab), obj.mytab.isLive = obj.isLive; end
            end
            % recover state
            if isfield(obj.state,'ui')
                fn = fieldnames(obj.ui);
                for i = 1:numel(fn)
                    if isfield(obj.state.ui,fn{i})
                        obj.ui.(fn{i}).FontSize = obj.state.ui.(fn{i}).FontSize;
                    end
                end
            end
            obj.main.Visible = 'on';
            if isgraphics(obj.main,'figure'),figure(obj.main); end
        end
        
        function sizeChangedPanelSide(obj,src,dat) %#ok<INUSD>
            %sizeChangedPanelSide Adjusts GUI in case of a size change
            
            %
            % Return if called to early
            if ~isfield(obj.ui,'panelSideControl') || ~isfield(obj.ui,'panelSideListbox') || ...
                    ~isvalid(obj.ui.panelSideControl) || ~isvalid(obj.ui.panelSideListbox)
                return;
            end
            %
            % Settings for size in pixels
            pbW  = 50;
            pbH  = 25;
            spW  = 10;
            spH  = 10;
            %
            % Get size of panel in pixels
            bak       = src.Units;
            src.Units = 'pixel';
            pos       = src.Position;
            src.Units = bak;
            %
            % Resize GUI
            maxW = 2; % number of uicontrols in control panel in horizontal direction
            maxH = 2; % number of uicontrols in control panel in vertical direction
            % reduce button size and spacing if window gets to small, always do it in vertical
            % if maxW*pbW+(maxW+1)*spW > pos(3)
            ratio = spW/pbW;
            pbW   = max(1,pos(3)/((maxW*(1+ratio)+ ratio)));
            spW   = max(1,ratio * pbW);
            % end
            if maxH*pbH+(maxH+1)*spH > pos(4)-100 % reserve 100 pix for the listboxes
                ratio = spH/pbH;
                pbH   = max(1,(pos(4)-100)/((maxH*(1+ratio)+ ratio)));
                spH   = max(1,ratio * pbH);
            end
            useH = (pos(4)-(maxH*pbH+(maxH+1)*spH))/pos(4); % relative size of control panel
            % distribute panels but keep control panel constant in height
            obj.ui.panelSideControl.Position = [0 0 1 1-useH];
            obj.ui.panelSideListbox.Position = [0 1-useH 1 useH];
            % set uicontrols in control panel
            fn = fieldnames(obj.ui);
            for i = 1:numel(fn)
                switch fn{i}
                    case {'PBUpdate','CLive','ESelection'}
                        obj.ui.(fn{i}).Units    = 'pixels';
                        mypos                   = obj.ui.(fn{i}).UserData;
                        if any(mypos < 1)
                            obj.ui.(fn{i}).Position = [spW mypos(1)*spH+(mypos(1)-1)*pbH pos(3)-2*spW pbH];
                        else
                            obj.ui.(fn{i}).Position = [mypos(2)*spW+(mypos(2)-1)*pbW mypos(1)*spH+(mypos(1)-1)*pbH pbW pbH];
                        end
                        obj.ui.(fn{i}).Units    = 'normalized';
                    otherwise
                        % nothing
                end
            end
        end
        
        function update(obj,type)
            %update Updates info and selection GUI, type can be 'all', 'new', 'data', 'settings', 'selection'
            %
            %       new : New experiments are added to data object or uid/index is changed
            %      data : Data is changed of existing experiments    
            %  settings : Non-physical property, i.e. a setting, was changed
            % selection : Selection is changed of existing experiments 
            %       all : Everything may have changed
            
            if nargin < 2, type = 'all'; end
            if numel(obj) > 1
                for i = 1:numel(obj), update(obj(i),type); end
                return;
            end
            %
            % Return if no GUI is open
            if ~obj.isGUI, return; end
            %
            % unselect everything in the selection listbox to not change the actual selection in the
            % data object
            if strcmp(type,'selection')
                obj.ui.LBSelection.Value = [];
            end
            %
            % Update own ui elements
            if any(strcmp(type,{'all' 'new'}))
                % make sure the figure can be used
                create(obj,true);
                % reset names, etc. of experiment(s)
                obj.p_name   = {};
                obj.p_uuid   = uint64.empty;
                obj.p_enable = logical.empty;
                % reset listbox
                obj.ui.LBExperiments.String = obj.name;
                obj.ui.LBExperiments.Value  = find(obj.enable);
            end
            setLBExperiments(obj);
            obj.ui.ESelection.String = sprintf('%d / %d',sum(obj.enable),numel(obj.enable));
            obj.ui.CLive.Value       = obj.isLive;
            %
            % get selection stored in object
            sel   = obj.p_data.sel;
            fnSel = fieldnames(sel); 
            if ~(numel(fnSel) == numel(obj.ui.LBSelection.String) && ...
                    all(ismember(fnSel,obj.ui.LBSelection.String)))
                strSel = obj.ui.LBSelection.String;
                strSel = strSel(obj.ui.LBSelection.Value);
                idx    = find(ismember(fnSel,strSel));
                obj.ui.LBSelection.String = fnSel;
                obj.ui.LBSelection.Value  = idx;
            end
            if ~isempty(obj.ui.LBSelection.Value)
                strSel = obj.ui.LBSelection.String;
                strSel = strSel(obj.ui.LBSelection.Value);
                setLBExperiments(obj,getIndexFromSelection(obj,strSel));
            end
            %
            % Call update function of active tab if it is not live already
            if ~isempty(obj.mytab) && ~obj.mytab.isLive
                update(obj.mytab,type);
            end
            %
            % get focus back
            % if isgraphics(obj.main,'figure'), figure(obj.main); end
        end
        
        function close(obj)
            %close Runs when GUI is closed
            
            if numel(obj) > 1
                for i = 1:numel(obj), close(obj(i)); end
                return;
            end
            if ~isempty(obj.main)
                % store state of GUI
                obj.state          = struct;
                obj.state.parent   = class(obj.main);
                obj.state.Units    = obj.main.Units;
                obj.state.Position = obj.main.Position;
                obj.state.splitup  = obj.splitup;
                if isgraphics(obj.main,'figure')
                    obj.state.WindowStyle = obj.main.WindowStyle;
                else
                    obj.state.WindowStyle = 'normal';
                end
                fn = fieldnames(obj.ui); fn = fn(~ismember(fn,'tabgroup'));
                for i = 1:numel(fn)
                    obj.state.ui.(fn{i}).FontSize = obj.ui.(fn{i}).FontSize;
                end
            end
            % call of close function of subclass should be performed with its CloseRequestFcn 
            % delete graphics
            delete(obj.main);
            obj.main = [];
        end
    end
    
    %% Methods for private tasks
    methods (Access = protected, Hidden = false, Sealed = true)
        function          setLBExperiments(obj,ind)
            %setLBExperiments Sets current selection from data object or given input in listbox
            
            if nargin < 2
                myuuid = get(obj.p_data,'uuid',false);
                myuuid = myuuid{1};
                logind = ismember(obj.uuid,myuuid);
                ind    = find(logind);
            else
                logind      = false(size(obj.enable));
                logind(ind) = true;
            end
            obj.p_enable               = logind;
            obj.ui.LBExperiments.Value = ind;
        end
        
        function myuuid = getLBExperiments(obj,setData)
            %getLBExperiments Gets uuid's of current selection from this object and sets the data object if requested
        
            myuuid = obj.uuid(obj.enable);
            if setData
                select(obj.p_data,{'uuid',myuuid});
            end
        end
        
        function ind    = getIndexFromSelection(obj,strSel)
            %getIndexFromSelection Returns indices in object for given selection names store in object
            
            ind    = [];
            sel    = obj.p_data.sel;
            fnSel  = fieldnames(sel);
            fnSel  = fnSel(ismember(fnSel,strSel));
            for i = 1:numel(fnSel)
                ind = union(ind,find(findExp(obj.p_data,true,sel.(fnSel{i}))));
            end
        end
               
        function cm     = contextMenuLB01(obj,type)
            % Create a context menu for experiments and selection listbox
            
            % add a context menu to listbox to allow for larger font
            fig = Videoplayer.getParentFigure(obj.main);
            cm  = uicontextmenu('Parent',fig);
            uimenu(cm, 'Label', 'Update', 'Callback',...
                @(src,dat) callbackMain(obj,'PBUpdate',src,dat));
            if strcmp(type,'LBExperiments')
                obj.ui.LBExperiments.UserData.moveSelection = 0;
                uimenu(cm, 'Label', 'Move selection to ... (next click)','Separator','on','Callback',...
                    @(src,dat) callbackMain(obj,'MoveSelection',type,dat));
                uimenu(cm, 'Label', 'Select all','Callback', @(src,dat) callbackMain(obj,'All',type,dat));
                uimenu(cm, 'Label', 'Select none','Callback', @(src,dat) callbackMain(obj,'None',type,dat));
                uimenu(cm, 'Label', 'Invert selection','Callback', @(src,dat) callbackMain(obj,'Invert',type,dat));
                uimenu(cm, 'Label', 'Delete experiment(s)','Separator','on','Callback',...
                    @(src,dat) callbackMain(obj,'DeleteExperiments',type,dat));
                uimenu(cm, 'Label', 'Store experiment(s)','Separator','off','Callback',...
                    @(src,dat) callbackMain(obj,'StoreExperiments',type,dat));
                uimenu(cm, 'Label', 'Recall experiment(s)','Separator','off','Callback',...
                    @(src,dat) callbackMain(obj,'RecallExperiments',type,dat));
                uimenu(cm, 'Label', 'Export data object to workspace','Separator','on','Callback',...
                    @(src,dat) callbackMain(obj,'ExportExperiments',type,dat));
            end
            if strcmp(type,'LBSelection')
                obj.ui.LBSelection.UserData.saveSelection = false;
                uimenu(cm, 'Label', 'Save current selection to ... (next click)','Separator','on','Callback',...
                    @(src,dat) callbackMain(obj,'SaveSelection',type,dat));
                uimenu(cm, 'Label', 'New selection','Callback', @(src,dat) callbackMain(obj,'New',type,dat));
                uimenu(cm, 'Label', 'Rename selection','Callback', @(src,dat) callbackMain(obj,'Rename',type,dat));
                uimenu(cm, 'Label', 'Order selection(s)','Callback', @(src,dat) callbackMain(obj,'Order',type,dat));                
                uimenu(cm, 'Label', 'Delete selection(s)','Callback', @(src,dat) callbackMain(obj,'Delete',type,dat));
                uimenu(cm, 'Label', 'Load selection(s) ...','Separator','on','Callback',...
                    @(src,dat) callbackMain(obj,'LoadSelections',type,dat));
                uimenu(cm, 'Label', 'Store selection(s) ...','Separator','off','Callback',...
                    @(src,dat) callbackMain(obj,'StoreSelections',type,dat));
            end
            cm1 = uimenu(cm, 'Label', 'Set font size to','Separator','on');
            for i = 10:2:40
                uimenu(cm1, 'Label', num2str(i), 'Callback',...
                    @(src,dat) callbackMain(obj,'FontSize',type,i));
            end
            cm1 = uimenu(cm, 'Label', 'Set split up to','Separator','on');
            for i = 50:5:95
                uimenu(cm1, 'Label', sprintf('%d%%',i), 'Callback',...
                    @(src,dat) callbackMain(obj,'SplitUp',src,i/100));
            end
        end

        function          callbackMain(obj,type,src,dat)
            %callbackMain Handles callbacks and function for some ui objects
            
            switch type
                case 'newTab'
                    % reset live state of tabs
                    if ~isempty(dat.OldValue)
                        idxOld = dat.OldValue.UserData.idxTab;
                        obj.tab{idxOld}.isLive = false;
                        hide(obj.tab{idxOld});
                    else
                        for k = 1:numel(obj.tab)
                            obj.tab{k}.isLive = false;
                            hide(obj.tab{k});
                        end
                    end
                    idxNew = dat.NewValue.UserData.idxTab;
                    obj.tab{idxNew}.isLive = obj.isLive;
                    % update tab competly since it may have missed a data change (it may not have
                    % been live during a change)
                    if ~isempty(obj.mytab),update(obj.mytab,'all'); end
                case 'ESelection'
                    obj.ui.ESelection.String = sprintf('%d / %d',sum(obj.enable),numel(obj.enable));
                case 'CLive'
                    obj.isLive = obj.ui.CLive.Value;
                case 'PBUpdate'
                    getLBExperiments(obj,true);
                    update(obj,'all');
                case 'SaveSelection'
                    obj.ui.(src).UserData.saveSelection = true;
                case 'New'
                    % add new selection
                    obj.ui.LBSelection.Value = [];
                    sel    = obj.p_data.sel;
                    k      = 1;
                    strSel = @(x) sprintf('Selection_%d',x); 
                    while isfield(sel,strSel(k))
                        k = k + 1;
                    end
                    strSel = strSel(k);
                    myuuid = getLBExperiments(obj,false);
                    sel.(strSel)   = {'uuid',myuuid};
                    obj.p_data.sel = sel;
                    % reset listbox in case the GUI is not live
                    fnSel                     = fieldnames(sel);
                    obj.ui.LBSelection.String = fnSel;
                    obj.ui.LBSelection.Value  = find(strcmp(strSel,fnSel));
                case 'Rename'
                    % make sure a single entry is selected
                    strSel = obj.ui.LBSelection.String;
                    strSel = strSel(obj.ui.LBSelection.Value);
                    if numel(strSel) ~= 1
                        warndlg('Please select a single selection to rename','Warning')
                        return;
                    end
                    strOld = strSel{1};
                    % ask for new name
                    prompt     = {'Enter a valid variable name'};
                    strname    = 'Rename selection';
                    defaultans = {strOld};
                    doAgain    = true;
                    while doAgain
                        answer = inputdlg(prompt,strname,[1 40],defaultans);
                        if isempty(answer), return;end
                        strNew = matlab.lang.makeValidName(answer{1});
                        if ~strcmp(strNew,answer{1})
                            defaultans = {strNew};
                        else
                            doAgain = false;
                        end
                    end
                    % replace selection
                    sel = obj.p_data.sel;
                    if ~ismember(strOld,fieldnames(sel))
                        warndlg(sprtinf('Selection ''%s'' not available any more in data object',strOld),'Warning')
                        return;
                    end
                    dat            = sel.(strOld);
                    sel            = rmfield(sel,strOld);
                    sel.(strNew)   = dat;
                    obj.p_data.sel = sel;
                    % reset listbox in case the GUI is not live
                    fnSel                     = fieldnames(sel);
                    obj.ui.LBSelection.String = fnSel;
                    obj.ui.LBSelection.Value  = find(strcmp(strNew,fnSel));
                case 'Delete'
                    % add new selection
                    strSel = obj.ui.LBSelection.String;
                    strSel = strSel(obj.ui.LBSelection.Value);
                    sel    = obj.p_data.sel;
                    nSel   = numel(fieldnames(sel));
                    for k = 1:numel(strSel)
                        if isfield(sel,strSel{k})
                            sel = rmfield(sel,strSel{k});
                        end
                    end
                    fnSel = fieldnames(sel);
                    if nSel ~= numel(fnSel)
                        obj.p_data.sel = sel;
                    end
                    % reset listbox in case the GUI is not live
                    obj.ui.LBSelection.String = fnSel;
                    obj.ui.LBSelection.Value  = [];
                case 'Order'
                    sel            = obj.p_data.sel;
                    sel            = orderfields(sel);
                    obj.p_data.sel = sel;
                    % reset listbox in case the GUI is not live
                    fnSel                     = fieldnames(sel);
                    obj.ui.LBSelection.String = fnSel;
                    obj.ui.LBSelection.Value  = [];
                case 'LBSelection'
                    hObject = obj.ui.LBSelection;
                    % save selection
                    if hObject.UserData.saveSelection
                        hObject.UserData.saveSelection = false;
                        if numel(hObject.Value) == 1
                            strSel = hObject.String;
                            strSel = strSel{hObject.Value};
                            sel    = obj.p_data.sel;
                            myuuid = getLBExperiments(obj,false);
                            sel.(strSel)   = {'uuid',myuuid};
                            obj.p_data.sel = sel;
                        end
                    end
                    % show selection
                    if ~isempty(hObject.Value)
                        strSel = hObject.String;
                        strSel = strSel(hObject.Value);
                        setLBExperiments(obj,getIndexFromSelection(obj,strSel));
                    end
                    if obj.isLive, getLBExperiments(obj,true); end
                    % rename on double click
                    fig = Videoplayer.getParentFigure(obj.main);
                    if strcmp(fig.SelectionType,'open') && numel(hObject.Value) == 1
                        callbackMain(obj,'Rename');
                    end
                case 'LoadSelections'
                    loadSelection(obj.p_data);
                case 'StoreSelections'
                    storeSelection(obj.p_data);
                case 'MoveSelection'
                    obj.ui.(src).UserData.moveSelection = 1;
                case 'DeleteExperiments'
                    % get experiments
                    myuuid = getLBExperiments(obj,false);
                    % ask for confirmation
                    if isempty(myuuid), return; end
                    if numel(myuuid) >= numel(obj.uuid)
                        warndlg('Please do not delete all experiments','Warning')
                        return;
                    end
                    button = questdlg(sprintf('This will delete %d experiment(s). Continue?',numel(myuuid)), ...
                        'Delete experiments?', 'Yes','No','No');
                    if ~strcmp(button,'Yes'); return; end
                    % delete from data
                    remove(obj.p_data,{'uuid',myuuid});
                    % update after such a change if GUI is not live
                    if ~obj.isLive, update(obj,'all'); end
                case 'ExportExperiments'
                    export2wsdlg({'Export data object:'},{'data'},{obj.p_data},...
                        'Export data object to base workspace');
                case 'StoreExperiments'
                    % get experiments
                    myuuid = getLBExperiments(obj,false);
                    % ask for confirmation
                    if isempty(myuuid), return; end
                    button = questdlg(sprintf('This will store %d selected experiments to disk. Continue?',numel(myuuid)), ...
                        'Delete experiments?', 'Yes','No','No');
                    if ~strcmp(button,'Yes'); return; end
                    % store data
                    store(obj.p_data,{'uuid',myuuid});
                case 'RecallExperiments'
                    % get experiments
                    myuuid = getLBExperiments(obj,false);
                    % ask for confirmation
                    if isempty(myuuid), return; end
                    button = questdlg(sprintf('This will recall %d selected experiments from disk. Continue?',numel(myuuid)), ...
                        'Delete experiments?', 'Yes','No','No');
                    if ~strcmp(button,'Yes'); return; end
                    % store data
                    recall(obj.p_data,{'uuid',myuuid});                    
                case 'All'
                    setLBExperiments(obj,1:numel(obj.enable));
                    if obj.isLive, getLBExperiments(obj,true); end
                case 'None'
                    setLBExperiments(obj,[]);
                    if obj.isLive, getLBExperiments(obj,true); end
                case 'Invert'
                    setLBExperiments(obj,find(~obj.enable));
                    if obj.isLive, getLBExperiments(obj,true); end
                case 'LBExperiments'
                    obj.ui.LBSelection.Value = [];
                    hObject = obj.ui.LBExperiments;
                    if hObject.UserData.moveSelection == 1
                        hObject.UserData.moveSelection = 0;
                        if isempty(hObject.Value)
                            setLBExperiments(obj);
                        else
                            idxNew = hObject.Value(1);
                            idxOld = find(obj.enable);
                            idxNew = idxOld - min(idxOld) + idxNew;
                            idxNew(idxNew<1 | idxNew > numel(obj.enable)) = [];
                            obj.p_enable         = false(size(obj.uuid));
                            obj.p_enable(idxNew) = true;
                            hObject.Value = find(obj.enable);
                        end
                    elseif hObject.UserData.moveSelection == 2
                        hObject.UserData.moveSelection = 0;
                        hObject.Value = find(obj.p_enable);
                    end
                    setLBExperiments(obj,hObject.Value);
                    if obj.isLive
                        % set selection
                        getLBExperiments(obj,true);
                        % get focus back
                        if isgraphics(obj.main,'figure'), figure(obj.main); end
                    end
                case 'FontSize'
                    obj.ui.(src).FontSize = dat;
                case 'SplitUp'
                    obj.splitup = dat;
            end
        end
        
        function          callbackKeyPress(obj,hObject,hData) %#ok<INUSL>
            %callbackKeyPress Handles keys pressed in list box

            switch hData.Key
                case 'return'
                    myReturn;
                case {'uparrow' 'downarrow'}
                    myUpDownArrow;
            end
            
            function myReturn
                if numel(hData.Modifier) < 1
                    callbackMain(obj,'PBUpdate');
                elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                    % nothing
                end
            end
            
            function myUpDownArrow
                if strcmp(hData.Key,'uparrow'), step = -1;
                else,                           step = 1;
                end
                if numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'}) && ...
                        ~isempty(obj.ui.LBExperiments.Value)
                    % move selection by its own blocksize
                    step = step * (max(obj.ui.LBExperiments.Value)-min(obj.ui.LBExperiments.Value) + 1);
                    doUpdate = true;
                else
                    doUpdate = false;
                end
                % mark selection to be moved selection when its callback is executed next
                if ~isempty(obj.ui.LBExperiments.Value)
                    idxNew = obj.ui.LBExperiments.Value + step;
                    idxNew(idxNew<1 | idxNew > numel(obj.p_enable)) = [];
                    obj.p_enable         = false(size(obj.uuid));
                    obj.p_enable(idxNew) = true;
                    obj.ui.LBExperiments.UserData.moveSelection = 2;
                    % callback is not executed, do it manually
                    if doUpdate, callbackMain(obj,'LBExperiments');end
                end
            end
        end
    end
    
    %% Static methods
    methods (Static = true, Access = public, Hidden = false, Sealed = true)
    end
    
    methods (Static = true, Access = protected, Hidden = false, Sealed = true)
    end
end

