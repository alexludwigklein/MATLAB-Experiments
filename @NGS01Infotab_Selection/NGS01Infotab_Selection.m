classdef NGS01Infotab_Selection < NGS01Infotab
    %@NGS01Infotab_Selection Shows graph for each physical property and allows for selecting
    %
    %----------------------------------------------------------------------------------
    %   Copyright 2016 Alexander Ludwig Klein, alexludwigklein@gmail.com
    %
    %   Physics of Fluids, University of Twente
    %----------------------------------------------------------------------------------
    
    %% Properties
    properties (GetAccess = protected, SetAccess = protected, Transient = true)
        % panelControl Control panel (uipanel)
        panelControl = gobjects(0);
        % panel Panels for axes (uipanel)
        panel = gobjects(0);
        % ax Axes for plots (axes)
        ax = gobjects(0);
        % line Line objects (line object)
        line = gobjects(0);
        % strProp Properties to show for each axes (cellstr)
        strProp = {};
        % xlim XLim for each axis
        xlim = {};
        % ylim YLim for each axis
        ylim = {};
        % uuidStr Stores uuidStr of data object (cellstr)
        uuidStr
        % showm True/false whether to include the origin (e.g. zero value) for a property
        showOrigin = false(0);
    end
    
    %% Constructor/Destructor, SET/GET
    methods
        function obj = NGS01Infotab_Selection(data)
            obj = obj@NGS01Infotab(data);
        end
    end
    
    %% Methods
    methods (Access = protected, Hidden = false)
        function       createSub(obj,reUse)
            %createSub Creates initial GUI
            
            %
            % Determine properties to show
            newProp = obj.p_data.vip;
            %
            % Clean figure and rebuild if necessary
            if ~(reUse && numel(newProp) == numel(obj.ax) && all(isvalid(obj.ax)) && ...
                    all(isgraphics(obj.ax,'axes')) && all(ismember(newProp,obj.strProp)))
                delete(obj.main.Children);
                obj.strProp    = newProp;
                nProp          = numel(obj.strProp);
                nCol           = ceil(sqrt(nProp));
                nRow           = ceil(nProp/nCol);
                obj.panel      = gobjects(nProp,1);
                obj.ax         = gobjects(nProp,1);
                obj.line       = gobjects(nProp,2);
                obj.ylim       = cell(nProp,1);
                obj.xlim       = cell(nProp,1);
                obj.showOrigin = false(nProp,1);
                %
                % Create panels
                bak            = obj.main.Units;
                obj.main.Units = 'pixels';
                figPos         = obj.main.Position;
                obj.main.Units = bak;
                pbW  = max(40,(figPos(3)-60)/4);
                pbH  = 25;
                k    = 1;
                useH = (figPos(4)-45)/figPos(4);
                for i = 1:nRow
                    for j = 1:nCol
                        obj.panel(k) = uipanel('parent',obj.main,'Position',[(j-1)/nCol 1-i*useH/nRow 1/nCol useH/nRow],...
                            'Units','Normalized');
                        k            = k + 1;
                    end
                end
                %
                % Create axes
                scaleXLim = obj.p_data.numAbs * 1e3;
                for i = 1:nProp
                    obj.ax(i) = axes('OuterPosition',[0 0 1 1],'Parent',obj.panel(i));
                    tmp = obj.ax(i).Position;
                    obj.ax(i).Position(2) = tmp(2)/4;
                    obj.ax(i).Position(4) = tmp(4) + tmp(2)*3/4;
                end
                plotSelect(obj,1:nProp,true);
                % add some selection aid
                for i = 1:nProp
                    obj.ax(i).XLim = [-1 1]*scaleXLim;
                    obj.xlim{i}    = obj.ax(i).XLim;
                    obj.ylim{i}    = obj.ax(i).YLim;
                    line(0.2*[-1 -1]*scaleXLim,obj.ylim{i}+[-1 1]*abs(diff(obj.ylim{i})),'Color',0.5*[1 1 1],'Parent',obj.ax(i)); %#ok<CPROPLC>
                    line(0.2*[+1 +1]*scaleXLim,obj.ylim{i}+[-1 1]*abs(diff(obj.ylim{i})),'Color',0.5*[1 1 1],'Parent',obj.ax(i)); %#ok<CPROPLC>
                    % store information
                    tmpCM = contextMenuSelect(obj,i);
                    set(obj.ax(i),'uicontextmenu',tmpCM,'XTick',[],'Userdata',...
                        struct('imroi',{{}},'type',{{}}),'YLim',obj.ylim{i});
                    obj.panel(i).UIContextMenu = tmpCM;
                    title(obj.ax(i),obj.strProp{i},'Interpreter','none');
                end
                %
                % Create ui controls
                obj.panelControl = uipanel('parent',obj.main,'Position',[0 0 1 1-useH],...
                    'Units','Normalized','sizeChangedFcn',@(src,dat) sizeChangedSub(obj,src,dat));
                obj.ui.button   = uicontrol(obj.panelControl,'Units','pixel','style','pushbutton',...
                    'string','Apply All ROI(s)','position',[10 10 pbW pbH], 'callback',...
                    @(src,event) callbackSub(obj,'apply',src,[]),...
                    'ToolTipString','Apply all region of interests (ROI) to select experiments');
                obj.ui.button(2) = uicontrol(obj.panelControl,'Units','pixel','style','pushbutton',...
                    'string','Clear All ROI(s)','position',[20+pbW 10 pbW pbH], 'callback',...
                    @(src,event) callbackSub(obj,'clearall',src,[]),...
                    'ToolTipString','Clear all region of interests (ROI)');
                obj.ui.button(3) = uicontrol(obj.panelControl,'Units','pixel','style','pushbutton',...
                    'string','Reset All Zoom(s)','position',[30+2*pbW 10 pbW pbH], 'callback',...
                    @(src,event) callbackSub(obj,'resetAllZoom',src,[]),...
                    'ToolTipString','Reset zoom of all axes');
                obj.ui.button(4) = uicontrol(obj.panelControl,'Units','pixel','Style','pushbutton',...
                    'String','Datacursor','Tag','PBDatacursor','Callback', @(src,dat) callbackSub(obj,'PBDatacursor',src,[]),...
                    'ToolTipString','Toggle data cursor mode',...
                    'Position',[40+3*pbW 10 pbW pbH]);
                set(obj.ui.button,'Units','Normalized');
                sizeChangedSub(obj);
                % recover state
                if isfield(obj.state,'sub')
                    if isfield(obj.state.sub,'ax')
                        for i = 1:numel(obj.ax),obj.ax(i).FontSize = obj.state.sub.ax.FontSize; end
                    end
                end
                updateOrigin(obj,1:numel(obj.ax));
                % set name in GUI
                if ~isgraphics(obj.main,'figure')
                    obj.main.Title = 'Selection';
                else
                    obj.Name = 'Selection';
                end
            end
            % set datacursor mode
            callbackSub(obj,'PBDatacursor');
            datacursormode(Videoplayer.getParentFigure(obj.main),'off');
        end
        
        function       updateSub(obj,type)
            %updateSub Updates GUI
            
            %
            % Re-create figure if necessary
            if any(strcmp(type,{'all' 'new' 'settings'}))
                createSub(obj,true);
            end
            %
            % Update figure
            idxBad                 = ~(isgraphics(obj.ax) & isvalid(obj.ax));
            obj.ax(idxBad)         = [];
            obj.line(idxBad,:)     = [];
            obj.xlim(idxBad)       = [];
            obj.ylim(idxBad)       = [];
            obj.strProp(idxBad)    = [];
            obj.showOrigin(idxBad) = [];
            set(obj.panel(idxBad),'UIContextMenu',[]);
            plotSelect(obj,1:numel(obj.ax),any(strcmp(type,{'all' 'new' 'settings' 'data'})));
            updateOrigin(obj,1:numel(obj.ax));
        end
        
        function       closeSub(obj)
            %closeSub Closes GUI
            
            idxBad = false(size(obj.ax));
            obj.state.sub.ax.FontSize = 10;
            for i = 1:numel(obj.ax)
                if ~(isgraphics(obj.ax(i)) && isvalid(obj.ax(i)))
                    idxBad(i) = true;
                else
                    obj.state.sub.ax.FontSize = obj.ax(i).FontSize;
                    axdata = obj.ax(i).UserData;
                    if ~isempty(axdata) && ~isempty(axdata.imroi)
                        for l = 1:numel(axdata.imroi)
                            if isvalid(axdata.imroi{l})
                                axdata.imroi{l}.delete;
                            end
                        end
                        axdata.imroi  = {};
                        axdata.type   = {};
                        obj.ax(i).UserData = axdata;
                    end
                end
            end
            obj.ax(idxBad)         = [];
            obj.line(idxBad,:)     = [];
            obj.xlim(idxBad)       = [];
            obj.ylim(idxBad)       = [];
            obj.strProp(idxBad)    = [];
            obj.showOrigin(idxBad) = [];
            set(obj.panel(idxBad),'UIContextMenu',[]);
        end
        
        function       hideSub(obj) %#ok<MANU>
            %hideSub Clean up figure
        end
        
        function       sizeChangedSub(obj,src,dat) %#ok<INUSD>
            %sizeChangedSub Resizes panels
            
            bak            = obj.main.Units;
            obj.main.Units = 'pixels';
            figPos         = obj.main.Position;
            obj.main.Units = bak;
            nProp          = numel(obj.strProp);
            nCol           = ceil(sqrt(nProp));
            nRow           = ceil(nProp/nCol);
            k              = 1;
            useH           = (figPos(4)-45)/figPos(4);
            if figPos(4) > 200
                for i = 1:nRow
                    for j = 1:nCol
                        obj.panel(k).Position = [(j-1)/nCol 1-i*useH/nRow 1/nCol useH/nRow];
                        k = k + 1;
                    end
                end
                obj.panelControl.Units = 'pixels';
                obj.panelControl.Position(4) = 45;
                obj.panelControl.Units = 'normalized';
            end
        end
        
        function       callbackSub(obj,type,src,dat) %#ok<INUSL>
            %callbackSub Handles callbacks and code snippets
            
            %
            % perform action
            switch type
                case 'PBDatacursor'
                    dcm           = datacursormode(Videoplayer.getParentFigure(obj.main));
                    dcm.UpdateFcn = @(dummy,event_obj) updateDatatip(obj,event_obj);
                    if strcmp(dcm.Enable,'on')
                        dcm.Enable = 'off';
                    else
                        dcm.Enable = 'on';
                    end
                case 'clear'
                    clearROIFromAxes(obj.ax(dat));
                case 'clearall'
                    % clear all ROIs
                    for k = 1:numel(obj.ax)
                        clearROIFromAxes(obj.ax(k));
                    end
                case 'apply'
                    % apply ROI and create new selection
                    ind = true(obj.p_data.numAbs,1);
                    for i = 1:numel(obj.ax)
                        axdata = obj.ax(i).UserData;
                        if ~isempty(axdata) && ~isempty(axdata.imroi)
                            indAdd = false(obj.p_data.numAbs,1);
                            indDel = false(obj.p_data.numAbs,1);
                            anyAdd = false;
                            anyDel = false;
                            toDel  = [];
                            for k = 1:numel(axdata.imroi)
                                if isvalid(axdata.imroi{k})
                                    pos = axdata.imroi{k}.getPosition;
                                    if pos(1) < 0 && pos(1)+pos(3) > 0
                                        % rectangle is active
                                        switch axdata.type{k}
                                            case 'add'
                                                indAdd = indAdd | findExp(obj.p_data,true,obj.strProp{i}, [pos(2) pos(2)+pos(4)]);
                                                anyAdd = true;
                                            case 'del'
                                                indDel = indDel | findExp(obj.p_data,true,obj.strProp{i}, [pos(2) pos(2)+pos(4)]);
                                                anyDel = true;
                                        end
                                    end
                                else
                                    toDel(end+1) = k; %#ok<AGROW>
                                end
                            end
                            axdata.imroi(toDel) = [];
                            if anyAdd, ind = and(ind,indAdd); end
                            if anyDel, ind = and(ind,~indDel); end
                        end
                    end
                    % select data
                    obj.p_data(ind);
                case 'resetZoom'
                    obj.ax(dat).XLim = obj.xlim{dat};
                    obj.ax(dat).YLim = obj.ylim{dat};
                case 'resetAllZoom'
                    for k = 1:numel(obj.ax)
                        obj.ax(k).XLim = obj.xlim{k};
                        obj.ax(k).YLim = obj.ylim{k};
                    end
                case {'del' 'add'}
                    % add new ROI
                    h = imrect(obj.ax(dat));
                    obj.ax(dat).XLim = obj.xlim{dat};
                    obj.ax(dat).YLim = obj.ylim{dat};
                    if strcmp(type,'del')
                        h.setColor('blue');
                    else
                        h.setColor('red');
                    end
                    obj.ax(dat).UserData.imroi{end+1} = h;
                    obj.ax(dat).UserData.type{end+1}  = type;
                case 'FontSize'
                    for i = 1:numel(obj.ax),obj.ax(i).FontSize = dat; end
                case 'OriginOn'
                    obj.showOrigin(dat) = true;
                    updateOrigin(obj,dat);
                case 'OriginOff'
                    obj.showOrigin(dat) = false;
                    updateOrigin(obj,dat);
            end
            
            function clearROIFromAxes(myax)
                % clearROIFromAxes Removes ROI(s) from given axes
                
                mydat = myax.UserData;
                if ~isempty(mydat) && ~isempty(mydat.imroi)
                    for l = 1:numel(mydat.imroi)
                        if isvalid(mydat.imroi{l})
                            mydat.imroi{l}.delete;
                        end
                    end
                    mydat.imroi   = {};
                    mydat.type    = {};
                    myax.UserData = mydat;
                end
            end
        end
        
        function       updateOrigin(obj,idx)
            %updateOrigin Updates axes limits to include or not include the origin
            
            for i = reshape(idx,1,[])
                obj.ax(i).XLim = obj.xlim{i};
                obj.ax(i).YLim = obj.ylim{i};
                if obj.showOrigin(i)
                    lim = obj.ax(i).YLim;
                    if all(lim > 0)
                        obj.ax(i).YLim = [0 max(lim)];
                    elseif all(lim < 0)
                        obj.ax(i).YLim = [min(lim) 0];
                    end
                end
            end
        end
        
        function str = updateDatatip(obj,event_obj)
            %updateDatatip Returns string for data tip in overview plot
            
            pos = event_obj.Position;
            idx = round(pos(1));
            str = {sprintf('UUID: %s',obj.uuidStr{idx}), ...
                sprintf('Ind (abs): %d',idx),...
                sprintf('Value: %.4g',pos(2))};
        end
        
        function cm  = contextMenuSelect(obj,idxAx)
            %contextMenuSelect Creates a context menu for axes
            
            % add a context menu to listbox to allow for larger font
            fig = Videoplayer.getParentFigure(obj.main);
            cm  = uicontextmenu('Parent',fig);
            uimenu(cm, 'Label', 'Add Select ROI', 'Callback',...
                @(src,event) callbackSub(obj,'add',src,idxAx));
            uimenu(cm, 'Label', 'Add Unselect ROI', 'Callback',...
                @(src,event) callbackSub(obj,'del',src,idxAx));
            uimenu(cm, 'Label', 'Apply All ROI(s)', 'Callback',...
                @(src,event) callbackSub(obj,'apply',src,idxAx));
            uimenu(cm, 'Label', 'Clear Axes ROI(s)','Separator','on','Callback',...
                @(src,event) callbackSub(obj,'clear',src,idxAx));
            uimenu(cm, 'Label', 'Reset Axes Zoom','Callback',...
                @(src,event) callbackSub(obj,'resetZoom',src,idxAx));
            uimenu(cm, 'Label', 'Clear All ROI(s)','Separator','on','Callback',...
                @(src,event) callbackSub(obj,'clearall',src,idxAx));
            uimenu(cm, 'Label', 'Reset All Zoom(s)','Callback',...
                @(src,event) callbackSub(obj,'resetAllZoom',src,idxAx));
            cm1 = uimenu(cm, 'Label', 'Set font size to','Separator','on');
            for i = 10:2:40
                uimenu(cm1, 'Label', num2str(i), 'Callback',...
                    @(src,dat) callbackSub(obj,'FontSize','ax',i));
            end
            cm1 = uimenu(cm, 'Label', sprintf('Limits (%d)',idxAx),'Separator','on');
            uimenu(cm1, 'Label', 'Show origin', 'Callback', @(src,event) callbackSub(obj,'OriginOn',src,idxAx));
            uimenu(cm1, 'Label', 'Reset limit', 'Callback', @(src,event) callbackSub(obj,'OriginOff',src,idxAx));
            cm1 = uimenu(cm, 'Label', 'Limits (all)');
            uimenu(cm1, 'Label', 'Show origin(s)', 'Callback', @(src,event) callbackSub(obj,'OriginOn',src,1:numel(obj.ax)));
            uimenu(cm1, 'Label', 'Reset limit(s)', 'Callback', @(src,event) callbackSub(obj,'OriginOff',src,1:numel(obj.ax)));
        end
        
        function [x1,y1,x2,y2] = plotSelect(obj,idxAx,reset)
            %plotSelect Plots or updates given property to axes for selectGUI
            
            xdata  = (1:obj.p_data.numAbs)';
            lin    = get(obj.p_data,true(obj.p_data.numAbs,1),'enable',false);
            lin    = lin{1};
            x1     = [NaN; xdata(lin); NaN];
            x2     = [NaN; xdata(~lin); NaN];
            idxBak = reshape(idxAx,1,[]);
            for idxAx = idxBak
                tmp    = get(obj.p_data,true(obj.p_data.numAbs,1),obj.strProp{idxAx},false);
                tmp    = tmp{1};
                if ~all(isgraphics(obj.line(idxAx,:))), isUpdate = false; else, isUpdate = true; end
                if iscolumn(tmp) && ((isa(tmp,'datetime')) || (isa(tmp,'duration')))
                    ydata = get(obj.p_data,true(obj.p_data.numAbs,1),obj.strProp{idxAx},false);
                    ydata = ydata{1};
                    y1    = [min(ydata)-duration(0,0,1); ydata(lin); max(ydata)+duration(0,0,1)];
                    y2    = [min(ydata)-duration(0,0,1); ydata(~lin); max(ydata)+duration(0,0,1)];
                    if isUpdate, y1 = datenum(y1); y2 = datenum(y2);end
                else
                    ydata = get(obj.p_data,true(obj.p_data.numAbs,1),obj.strProp{idxAx});
                    y1    = [NaN; ydata(lin); NaN];
                    y2    = [NaN; ydata(~lin); NaN];
                end
                if isUpdate
                    if isvalid(obj.line(idxAx,1)), set(obj.line(idxAx,1),'XData',x1,'YData',y1); end
                    if isvalid(obj.line(idxAx,2)), set(obj.line(idxAx,2),'XData',x2,'YData',y2); end
                else
                    obj.line(idxAx,:) = plot(obj.ax(idxAx),x1,y1,'or',x2,y2,'xb');
                end
                % reset axes limits and get new names
                if reset || ~isUpdate
                    obj.uuidStr = get(obj.p_data,true(obj.p_data.numAbs,1),'uuidStr',false);
                    obj.uuidStr = obj.uuidStr{1};
                    try %#ok<TRYNC>
                        myYLim = [min(min(y1(:)),min(y2(:))) max(max(y1(:)),max(y2(:)))];
                        if abs(diff(myYLim)) < eps
                            myYLim = myYLim + [-1*eps eps];
                        end
                        obj.ax(idxAx).YLim = myYLim;
                        obj.ylim{idxAx}    = myYLim;
                    end
                end
            end
        end
    end
end
