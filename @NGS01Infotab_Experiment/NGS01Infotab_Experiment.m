classdef NGS01Infotab_Experiment < NGS01Infotab
    %@NGS01Infotab_Experiment Shows experiments as info tab
    %
    %----------------------------------------------------------------------------------
    %   Copyright 2016 Alexander Ludwig Klein, alexludwigklein@gmail.com
    %
    %   Physics of Fluids, University of Twente
    %----------------------------------------------------------------------------------
    
    %% Properties
    properties (GetAccess = public, SetAccess = public, Dependent = true)
        % splitup Splitup ratio between the panels (scalar double)
        splitup
    end
    
    properties (GetAccess = protected, SetAccess = protected, Transient = true)
        % panel Panels for sub elements of gui
        panel = gobjects(0);
    end
    
    %% Constructor/Destructor, SET/GET
    methods
        function obj = NGS01Infotab_Experiment(data)
            obj = obj@NGS01Infotab(data);
        end
        
        function value = get.splitup(obj)
            if obj.isGUI && ~isempty(obj.panel) && all(isgraphics(obj.panel)) && all(isvalid(obj.panel))
                value = NaN(numel(obj.panel),1);
                for i = 1:numel(obj.panel)
                    value(i) = obj.panel(i).Position(4);
                end
                obj.state.sub.splitup = value;
            elseif isfield(obj.state,'sub') && isfield(obj.state.sub,'splitup') && all(obj.state.sub.splitup < 1)
                value = obj.state.sub.splitup;
            else
                value = [0.4 0.4 0.2];
                obj.state.sub.splitup = value;
            end
        end
        
        function         set.splitup(obj,value)
            if isnumeric(value) && numel(value) == numel(obj.panel) && min(value) > 0 && max(value) < 1
                obj.state.sub.splitup = reshape(value,1,[]);
                if obj.isGUI
                    for i = 1:numel(obj.panel)
                        obj.panel(i).Position = [0 sum(obj.state.sub.splitup(1:(i-1))) 1 obj.state.sub.splitup(i)];
                    end
                end
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for the property');
            end
        end
    end
    
    %% Methods
    methods (Access = protected, Hidden = false)
        function createSub(obj,reUse)
            %createSub Creates initial GUI
            
            %
            % Clean figure and rebuild if necessary
            if ~reUse
                delete(obj.main.Children);
                % create panels
                splitUp   = obj.splitup;
                obj.panel = gobjects(size(splitUp));
                for i = 1:numel(obj.panel)
                    obj.panel(i) = uipanel('parent',obj.main,'Tag','panelMain','Units','Normalized',...
                        'Position',[0 sum(splitUp(1:(i-1))) 1 splitUp(i)]);
                end
                % panel 1 for VIP
                obj.panel(1).Title = 'VIProperty';
                obj.ui.table = uitable(obj.panel(1),'Units','normalized','Position',[0 0 1 1]);
                % panel 2 for comment
                obj.panel(2).Title = 'Comment';
                obj.ui.EComment = uicontrol(obj.panel(2),'Units','normalized','Style','Edit','Min',1,'Max',3,...
                    'String','1','Tag','EComment','Callback', @(src,dat) callbackSub(obj,'EComment',src,dat),...
                    'Position',[0 0 1 1],'ToolTipString','Comment of experiment');
                obj.ui.EComment.UserData.uuid    = uint64.empty;
                obj.ui.EComment.UserData.uuidStr = '';
                obj.ui.EComment.UserData.comment = {};
                obj.ui.EComment.UIContextMenu    = contextMenuSub(obj,'EComment');
                % panel 3 for information on selected experiments
                obj.ui.EInfo = uicontrol(obj.panel(3),'Units','normalized','Style','Edit',...
                    'String','1','Tag','EInfo','Callback', @(src,dat) callbackSub(obj,'EInfo',src,dat),...
                    'Position',[0 0.5 1 0.5],'ToolTipString','Information on selected experiment(s)');
                obj.ui.EDir = uicontrol(obj.panel(3),'Units','normalized','Style','Edit',...
                    'String','1','Tag','EDir','Callback', @(src,dat) callbackSub(obj,'EDir',src,dat),...
                    'Position',[0.05 0 1 0.5],'ToolTipString','Directory of experiment(s)');
                obj.ui.PBDir = uicontrol(obj.panel(3),'Units','normalized','Style','pushbutton',...
                    'String','>','Tag','PBDir','Callback', @(src,dat) callbackSub(obj,'PBDir',src,dat),...
                    'ToolTipString','Change to directory',...
                    'Position',[0 0 0.05 0.5]);
                obj.ui.EInfo.UIContextMenu = contextMenuSub(obj,'EInfo');
                obj.ui.EDir.UIContextMenu  = contextMenuSub(obj,'EDir');
                obj.ui.table.UIContextMenu = contextMenuSub(obj,'table');
                % recover state
                if isfield(obj.state,'sub')
                    fn = fieldnames(obj.ui);
                    for i = 1:numel(fn)
                        if isfield(obj.state.sub,fn{i})
                            obj.ui.(fn{i}).FontSize = obj.state.sub.(fn{i}).FontSize;
                        end
                    end
                end
                % force update
                updateSub(obj,'all')
                % set name
                if ~isgraphics(obj.main,'figure')
                    obj.main.Title = 'Experiment';
                else
                    obj.Name = 'Experiment';
                end
            end
        end
        
        function updateSub(obj,type) %#ok<INUSD>
            %updateSub Updates GUI
            
            maxExp   = 1000;
            propInfo = {'name','uid','index','time','status','version','dir'};
            %
            % Determine strings for the information and comment panel
            nExp = obj.p_data.numSel;
            if nExp >= maxExp
                strInfo = sprintf('%d experiments selected, please try with less than %d',obj.p_data.numSel,maxExp);
                strDir  = obj.p_data.rootdir;
                strCom  = {};
                uuidCom = uint64.empty;
                uuidStr = '';
            else
                % create single entry for each info property
                datAll  = get(obj.p_data,propInfo{:},false);
                str     = cell(size(datAll));
                for i = 1:numel(datAll)
                    tmp = unique(datAll{i});
                    if numel(tmp) ~= 1
                        switch propInfo{i}
                            case 'dir'
                                str{i} = obj.p_data.rootdir;
                            otherwise
                                str{i} = 'multiple';
                        end
                    else
                        switch propInfo{i}
                            case {'name' 'dir'}
                                str{i} = char(tmp(1));
                            case {'uid','index','status','version'}
                                str{i} = num2str(tmp);
                            case 'time'
                                str{i} = datestr(tmp);
                        end
                    end
                end
                strInfo = sprintf('Name: %s, UID: %s, Index: %s, Time: %s, Status: %s, Version: %s', ...
                    str{1:end-1});
                strDir = str{end};
                % str for comment
                if nExp > 1
                    % show comment if it is the same for all experiments, otherwise indicate that
                    % experiments with multiple and different comments are selected
                    tmp     = get(obj.p_data,'comment',false); 
                    tmp     = tmp{1};
                    allSame = true;
                    counter = 1;
                    while allSame && counter <= nExp
                       if ~isequal(tmp{counter},tmp{1}), allSame = false; end
                       counter = counter + 1;
                    end
                    if allSame
                        strCom  = tmp{1};
                        uuidCom = obj.p_data.uuid;
                        uuidStr = get(obj.p_data,'uuidStr',false);
                        uuidStr = uuidStr{1};
                    else
                        strCom  = {'multiple experiments with different comments are selected'};
                        uuidCom = uint64.empty;
                        uuidStr = '';
                    end
                elseif nExp == 1
                    strCom  = get(obj.p_data,'comment',false);
                    strCom  = strCom{1}{1};
                    uuidStr = get(obj.p_data,'uuidStr',false);
                    uuidStr = uuidStr{1}{1};
                    uuidCom = obj.p_data.uuid;
                else
                    strCom  = {};
                    uuidStr = {};
                    uuidCom = [];
                end
            end
            obj.ui.EInfo.String              = strInfo;
            obj.ui.EDir.String               = strDir;
            obj.ui.EComment.String           = strCom;
            obj.ui.EComment.UserData.uuid    = uuidCom;
            obj.ui.EComment.UserData.uuidStr = uuidStr;
            obj.ui.EComment.UserData.comment = strCom;
            %
            % Set content of table
            if nExp > maxExp
                obj.ui.table.Data       = {};
                obj.ui.table.ColumnName = {};
                obj.ui.table.RowName    = {};
            else
                vip     = obj.p_data.vip;
                dat     = cell(obj.p_data.numSel,numel(vip));
                format  = cell(size(vip));
                for i = 1:numel(vip)
                    tmp = obj.p_data.(vip{i});
                    if iscellstr(tmp) && isvector(tmp)
                        dat(:,i)  = tmp;
                        format{i} = 'char';
                    elseif isa(tmp,'categorical') && isvector(tmp)
                        dat(:,i)  = cellstr(tmp);
                        format{i} = 'char';
                    elseif isa(tmp,'datetime')  && isvector(tmp)
                        for k = 1:size(dat,1)
                            dat{k,i} = datestr(tmp(k));
                        end
                        format{i} = 'char';
                    else
                        dat(:,i)  = num2cell(get(obj.p_data,vip{i}));
                        format{i} = 'numeric';
                    end
                end
                obj.ui.table.ColumnFormat = reshape(format,1,[]);
                obj.ui.table.ColumnName   = obj.p_data.vip;
                obj.ui.table.RowName      = obj.p_data.uuidStr;
                obj.ui.table.Data         = dat;
            end
        end
        
        function callbackSub(obj,type,src,dat)
            %callbackSub Handles callbacks and code snippets
            
            switch type
                case {'EInfo' 'EDir'}
                    if obj.isLive, updateSub(obj,'selection'); end
                case 'EComment'
                    uuid = obj.ui.EComment.UserData.uuid;
                    if isempty(uuid);
                        % restore values if no UUID is available for comment
                        updateSub(obj,'selection');
                    else
                        % ask to store comment if it is new
                        comNew = obj.ui.EComment.String;
                        if ischar(comNew), comNew = {comNew}; end
                        if ~isequal(comNew,obj.ui.EComment.UserData.comment)
                            if numel(uuid) == 1
                                button = questdlg(sprintf(['Select and replace comment for ''%s''. ',...
                                    'Continue?'], obj.ui.EComment.UserData.uuidStr), ...
                                    'Replace comment?', 'Yes','No','No');
                            else
                                button = questdlg(sprintf(['Select and replace comment for %d ',...
                                    'experiments (''%s'' ... ''%s''). Continue?'],...
                                    numel(uuid), obj.ui.EComment.UserData.uuidStr{[1 end]}), ...
                                    'Replace comments?', 'Yes','No','No');
                            end
                            if ~strcmp(button,'Yes'); updateSub(obj,'selection'); return; end
                            obj.p_data('uuid',uuid).comment = repmat({comNew},numel(uuid),1);
                        end
                    end
                case 'PBDir'
                    if ~isempty(obj.ui.EDir.String) && exist(obj.ui.EDir.String,'dir') == 7
                        cd(obj.ui.EDir.String);
                    end
                case 'FontSize'
                    obj.ui.(src).FontSize = dat;
            end
        end
        
        function closeSub(obj)
            %closeSub Closes GUI
            
            if ~isempty(obj.main)
                fn = fieldnames(obj.ui);
                for i = 1:numel(fn)
                    obj.state.sub.(fn{i}).FontSize = obj.ui.(fn{i}).FontSize;
                end
                obj.state.sub.splitup     = obj.splitup;
            end
            delete(obj.main);
            obj.main = [];
        end
        
        function hideSub(obj) %#ok<MANU>
            %hideSub Clean up when GUI is hidden
        end
        
        function cm = contextMenuSub(obj,type)
            %contextMenuSub Creates a context menu for listboxes and edit text
            
            % add a context menu to listbox to allow for larger font
            fig = Videoplayer.getParentFigure(obj.main);
            cm  = uicontextmenu('Parent',fig);
            cm1 = uimenu(cm, 'Label', 'Set font size to');
            for i = 10:2:40
                uimenu(cm1, 'Label', num2str(i), 'Callback',...
                    @(src,dat) callbackSub(obj,'FontSize',type,i));
            end
        end
    end
end
