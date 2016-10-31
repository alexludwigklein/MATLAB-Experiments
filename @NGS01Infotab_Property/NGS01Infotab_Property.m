classdef NGS01Infotab_Property < NGS01Infotab
    %@NGS01Infotab_Property Shows properties as info tab
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
        % ax Axes for histogram (axes)
        ax = gobjects(0);
        % nBin Number of bins for histogram (double)
        nBin = 10;
        % hist Histogram object (hist object)
        hist = gobjects(0);
        % panel Panels for sub elements of gui
        panel = gobjects(0);
        % showOrigin True/false whether to include the origin (e.g. zero value) for a property
        showOrigin = false(0);
    end
    
    %% Constructor/Destructor, SET/GET
    methods
        function obj = NGS01Infotab_Property(data)
            obj = obj@NGS01Infotab(data);
        end
        
        function value = get.splitup(obj)
            if obj.isGUI && ~isempty(obj.panel) && all(isgraphics(obj.panel)) && all(isvalid(obj.panel))
                value = NaN(numel(obj.panel),1);
                for i = 1:numel(obj.panel)
                    value(i) = obj.panel(i).Position(3);
                end
                obj.state.sub.splitup = value;
            elseif isfield(obj.state,'sub') && isfield(obj.state.sub,'splitup') && all(obj.state.sub.splitup < 1)
                value = obj.state.sub.splitup;
            else
                value = [0.2 0.2 0.6];
                obj.state.sub.splitup = value;
            end
        end
        
        function         set.splitup(obj,value)
            if isnumeric(value) && numel(value) == numel(obj.panel) && min(value) > 0 && max(value) < 1
                obj.state.sub.splitup = reshape(value,1,[]);
                if obj.isGUI
                    for i = 1:numel(obj.panel)
                        obj.panel(i).Position = [sum(obj.state.sub.splitup(1:(i-1))) 0 obj.state.sub.splitup(i) 1];
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
                        'Position',[sum(splitUp(1:(i-1))) 0 splitUp(i) 1]);
                end
                % panel 1 for VIP
                obj.panel(1).Title = 'VIProperty';
                obj.ui.LBVip = uicontrol(obj.panel(1),'Units','normalized',...
                    'Style','listbox','Tag','LBVip', 'Min',1,'Max',10, 'String',{'outdated'},...
                    'callback', @(src,dat) callbackSub(obj,'LBVip',src,dat),...
                    'Value',1,'Position',[0 0 1 1], 'ToolTipString','Select multiple physical properties to show in GUI, etc. (VIP)');
                obj.ui.LBVip.UIContextMenu = contextMenuSub(obj,'LBVip');
                % panel 2 for single propery
                obj.panel(2).Title = 'Property';
                obj.ui.LBProp = uicontrol(obj.panel(2),'Units','normalized',...
                    'Style','listbox','Tag','LBProp', 'Min',1,'Max',1, 'String',{'outdated'},...
                    'callback', @(src,dat) callbackSub(obj,'LBProp',src,dat),...
                    'Value',1,'Position',[0 0 1 1], 'ToolTipString','Select a single physical properties to analyse here, etc. (VIP)');
                obj.ui.LBProp.UIContextMenu      = contextMenuSub(obj,'LBProp');
                obj.ui.LBProp.UserData.lastValue = 1;
                % panel 3 for information on selected property
                obj.ui.EStat = uicontrol(obj.panel(3),'Units','normalized','Style','Edit','Min',1,'Max',3,...
                    'String','1','Tag','EStat','Callback', @(src,dat) callbackSub(obj,'EStat',src,dat),...
                    'Position',[0 0.85 1 0.15],'ToolTipString','Statistics on selected property');
                obj.ui.TStat = uitable(obj.panel(3),'Units','normalized','Position',[0 0.70 1 0.15]);
                obj.ui.EStat.UIContextMenu = contextMenuSub(obj,'EStat');
                obj.ui.TStat.UIContextMenu = contextMenuSub(obj,'TStat');
                cm     = contextMenuHist(obj,1);
                obj.ax = axes('Parent',obj.panel(3),'OuterPosition',[0 0 1 0.70],...
                    'Units','normalized','NextPlot','Add','UIContextMenu',cm);
                obj.showOrigin = true;
                obj.hist       = histogram(obj.ax,NaN);
                obj.hist(2)    = histogram(obj.ax,NaN);
                obj.hist(1).UIContextMenu = cm;
                obj.hist(2).UIContextMenu = cm;
                legend(obj.ax ,'All data','Selection');
                obj.ax.Title.Interpreter  = 'none';
                obj.ax.XLabel.Interpreter = 'none';
                obj.ax.YLabel.Interpreter = 'none';
                % recover state
                if isfield(obj.state,'sub')
                    fn = fieldnames(obj.ui);
                    for i = 1:numel(fn)
                        if isfield(obj.state.sub,fn{i})
                            obj.ui.(fn{i}).FontSize = obj.state.sub.(fn{i}).FontSize;
                        end
                    end
                    if isfield(obj.state.sub,'ax')
                        obj.ax.FontSize = obj.state.sub.ax.FontSize;
                    end
                    if isfield(obj.state.sub,'hist')
                        for i = 1:2,obj.hist(i).Normalization = obj.state.sub.hist(i).Normalization; end
                    end
                end
                % force update
                updateSub(obj,'all')
                % set name
                if ~isgraphics(obj.main,'figure')
                    obj.main.Title = 'Property';
                else
                    obj.Name = 'Property';
                end
            end
        end
        
        function updateSub(obj,type)
            %updateSub Updates GUI
            
            %
            % Initialise
            if any(strcmp(type,{'all' 'new' 'settings'}))
                myprop  = obj.p_data.myprop;
                strProp = obj.ui.LBProp.String;
                idxProp = obj.ui.LBProp.Value;
                if ~isequal(strProp(:),myprop(:))
                    obj.ui.LBVip.Value               = [];
                    obj.ui.LBProp.Value              = 1;
                    obj.ui.LBProp.UserData.lastValue = 1;
                    obj.ui.LBVip.String              = myprop;
                    obj.ui.LBProp.String             = myprop;
                end
                obj.ui.LBVip.Value = find(ismember(myprop,obj.p_data.vip));
                idx = find(ismember(myprop,strProp(idxProp)),1);
                if ~isempty(idx), obj.ui.LBProp.Value  = idx; end
            else
                strProp = obj.ui.LBVip.String;
                strProp = strProp(obj.ui.LBVip.Value);
                if ~isequal(strProp(:),obj.p_data.vip(:)), obj.p_data.vip = strProp; end
            end
            %
            % show correct information
            strProp = obj.ui.LBProp.Value;
            if isempty(strProp)
                obj.ui.EStat.String     = {'Please, select a property'};
                obj.ui.TStat.Data       = {};
                obj.ui.TStat.ColumnName = {};
                obj.ui.TStat.RowName    = {};
                obj.ax.Title.String     = 'Please, select a property';
                obj.ax.XLabel.String    = 'Please, select a property';
                obj.ax.YLabel.String    = 'Please, select a property';
                obj.hist(1).Data        = NaN;
                obj.hist(2).Data        = NaN;
            else
                obj.ui.EStat.String    = cell(2,1);
                obj.ui.EStat.String{1} = sprintf('%s: memory usage %.2f MiB',class(obj.p_data),sum(obj.p_data.memory));
                obj.ui.EStat.String{2} = obj.p_data.mydesc{strProp};
                strProp                = obj.ui.LBProp.String{strProp};
                % update histogram and statistics 1
                xdata               = get(obj.p_data,true(obj.p_data.numAbs,1),strProp);
                obj.hist(1).Data    = xdata;
                if numel(xdata) > 1 && sum(abs(xdata-xdata(1)) > eps) > obj.nBin
                    obj.hist(1).BinMethod = 'auto';
                else
                    obj.hist(1).NumBins = obj.nBin;
                end
                obj.ax.XLimMode = 'auto';
                if obj.showOrigin
                    xlim = obj.ax.XLim;
                    if all(xlim > 0)
                        obj.ax.XLim = [0 max(xlim)];
                    elseif all(xlim < 0)
                        obj.ax.XLim = [min(xlim) 0];
                    end
                end
                dat      = NaN(2,5);
                dat(1,:) = [numel(xdata),min(xdata),mean(xdata),max(xdata),std(xdata)];
                % update histogram and statistics 2
                xdata = xdata(obj.p_data.ind);
                obj.hist(2).Data    = xdata;
                if numel(xdata) > 1 && sum(abs(xdata-xdata(1)) > eps) > obj.nBin
                    obj.hist(2).BinMethod = 'auto';
                else
                    obj.hist(2).NumBins = obj.nBin;
                end
                dat(2,:)             = [numel(xdata),min(xdata),mean(xdata),max(xdata),std(xdata)];
                obj.ax.Title.String  = sprintf('Histogram for ''%s''',strProp);
                obj.ax.XLabel.String = strProp;
                obj.ax.YLabel.String = 'count';
                % update table
                obj.ui.TStat.Data       = dat;
                obj.ui.TStat.ColumnName = {'#' 'min','mean','max','std'};
                obj.ui.TStat.RowName    = {'ALL', 'SEL'};
            end
        end
        
        function callbackSub(obj,type,src,dat)
            %callbackSub Handles callbacks and code snippets
            
            switch type
                case {'LBProp' 'EStat'}
                    if isempty(obj.ui.LBProp.Value)
                        obj.ui.LBProp.Value = obj.ui.LBProp.UserData.lastValue;
                    else
                        obj.ui.LBProp.UserData.lastValue = obj.ui.LBProp.Value;
                    end
                    if obj.isLive, updateSub(obj,'selection'); end
                case 'LBVip'
                    hObject = obj.ui.LBVip;
                    if hObject.UserData.moveSelection
                        hObject.UserData.moveSelection = false;
                        if isempty(hObject.Value)
                            hObject.Value = find(ismember(hObject.String,obj.p_data.vip));
                        else
                            idxNew = hObject.Value(1);
                            idxOld = find(ismember(hObject.String,obj.p_data.vip));
                            idxNew = idxOld - min(idxOld) + idxNew;
                            idxNew(idxNew<1 | idxNew > numel(hObject.String)) = [];
                            hObject.Value = idxNew;
                        end
                    end
                    if obj.isLive, updateSub(obj,'selection'); end
                case 'MoveSelection'
                    obj.ui.(src).UserData.moveSelection = true;
                case 'All'
                    obj.ui.(src).Value = 1:numel(obj.ui.(src).String);
                    if obj.isLive, updateSub(obj,'selection'); end
                case 'None'
                    obj.ui.(src).Value = [];
                    if obj.isLive, updateSub(obj,'selection'); end
                case 'Invert'
                    obj.ui.(src).Value = setdiff(1:numel(obj.ui.(src).String),obj.ui.(src).Value);
                    if obj.isLive, updateSub(obj,'selection'); end
                case 'FontSize'
                    if strcmp(src,'ax')
                        obj.ax.FontSize = dat;
                    else
                        obj.ui.(src).FontSize = dat;
                    end
                case 'OriginOn'
                    obj.showOrigin(dat) = true;
                    updateSub(obj,'selection');
                case 'OriginOff'
                    obj.showOrigin(dat) = false;
                    updateSub(obj,'selection');
                case 'Normalization'
                    for i = 1:numel(obj.hist)
                        obj.hist(i).Normalization = dat;
                    end
            end
        end
        
        function closeSub(obj)
            %closeSub Closes GUI
            
            if ~isempty(obj.main)
                fn = fieldnames(obj.ui);
                for i = 1:numel(fn)
                    obj.state.sub.(fn{i}).FontSize = obj.ui.(fn{i}).FontSize;
                end
                obj.state.sub.ax.FontSize = obj.ax.FontSize;
                obj.state.sub.splitup     = obj.splitup;
                for i = 1:2,obj.state.sub.hist(i).Normalization = obj.hist(i).Normalization; end
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
            if strcmp(type,'LBVip')
                obj.ui.LBVip.UserData.moveSelection = false;
                uimenu(cm, 'Label', 'Move selection to ... (next click)','Callback',...
                    @(src,dat) callbackSub(obj,'MoveSelection',type,dat));
                uimenu(cm, 'Label', 'Select all','Callback', @(src,dat) callbackSub(obj,'All',type,dat));
                uimenu(cm, 'Label', 'Select none','Callback', @(src,dat) callbackSub(obj,'None',type,dat));
                uimenu(cm, 'Label', 'Invert selection','Callback', @(src,dat) callbackSub(obj,'Invert',type,dat));
                strSep = 'on';
            else
                strSep = 'off';
            end
            cm1 = uimenu(cm, 'Label', 'Set font size to','Separator',strSep);
            for i = 10:2:40
                uimenu(cm1, 'Label', num2str(i), 'Callback',...
                    @(src,dat) callbackSub(obj,'FontSize',type,i));
            end
        end
        
        function cm = contextMenuHist(obj,idxAx)
            %contextMenuHist Creates a context menu for axes
            
            % add a context menu to listbox to allow for larger font
            fig = Videoplayer.getParentFigure(obj.main);
            cm  = uicontextmenu('Parent',fig);
            cm1 = uimenu(cm, 'Label','Limits');
            uimenu(cm1, 'Label', 'Show origin', 'Callback', @(src,event) callbackSub(obj,'OriginOn',src,idxAx));
            uimenu(cm1, 'Label', 'Reset limit', 'Callback', @(src,event) callbackSub(obj,'OriginOff',src,idxAx));
            cm1 = uimenu(cm, 'Label', 'Normalization');
            uimenu(cm1, 'Label', 'Count',       'Callback', @(src,event) callbackSub(obj,'Normalization',src,'count'));
            uimenu(cm1, 'Label', 'Probability', 'Callback', @(src,event) callbackSub(obj,'Normalization',src,'probability'));
            cm1 = uimenu(cm, 'Label', 'Set font size to','Separator','on');
            for i = 10:2:40
                uimenu(cm1, 'Label', num2str(i), 'Callback',...
                    @(src,dat) callbackSub(obj,'FontSize','ax',i));
            end
        end
    end
end
