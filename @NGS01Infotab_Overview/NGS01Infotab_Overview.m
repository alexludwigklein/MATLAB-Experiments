classdef NGS01Infotab_Overview < NGS01Infotab
    %@NGS01Infotab_Overview Shows an overview as info tab
    %
    %----------------------------------------------------------------------------------
    %   Copyright 2016 Alexander Ludwig Klein, alexludwigklein@gmail.com
    %
    %   Physics of Fluids, University of Twente
    %----------------------------------------------------------------------------------
    
    %% Properties
    properties (GetAccess = protected, SetAccess = protected, Transient = true)
        % panel Panels for axes (uipanel)
        panel = gobjects(0);
        % ax Axes for plots (axes)
        ax = gobjects(0);
        % line Line objects (line object)
        line = gobjects(0);
        % strProp Properties to show for each axes (cellstr)
        strProp = {};
        % showOrigin True/false whether to include the origin (e.g. zero value) for a property
        showOrigin = true(0);
    end
    
    %% Constructor/Destructor, SET/GET
    methods
        function obj = NGS01Infotab_Overview(data)
            obj = obj@NGS01Infotab(data);
        end
    end
    
    %% Methods
    methods (Access = protected, Hidden = false)
        function createSub(obj,reUse)
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
                obj.showOrigin = true(nProp,1);
                nMax           = obj.p_data.numSel;
                % Create panels
                k = 1;
                for i = 1:nRow
                    for j = 1:nCol
                        obj.panel(k) = uipanel('parent',obj.main,'Position',[(j-1)/nCol 1-i/nRow 1/nCol 1/nRow],...
                            'Units','Normalized');
                        k            = k + 1;
                    end
                end
                % create graphs
                for i = 1:nProp
                    ydata       = get(obj.p_data,obj.strProp{i});
                    cm          = contextMenuSub(obj,i);
                    obj.ax(i)   = axes('OuterPosition',[0 0 1 1],'Parent',obj.panel(i));
                    obj.line(i) = plot(obj.ax(i),1:numel(ydata),ydata,'-ob');
                    title(obj.ax(i),obj.strProp{i},'Interpreter','none');
                    obj.line(i).UIContextMenu  = cm;
                    obj.panel(i).UIContextMenu = cm;
                    obj.ax(i).UIContextMenu    = cm;
                end
                if numel(obj.ax) > 0
                    obj.main.UserData.mylink = linkprop(obj.ax,'XLim');
                    if nMax == 1, nMax = 2; end
                    xlim(obj.ax(1),[1 nMax]);
                end
                % recover state
                if isfield(obj.state,'sub')
                    if isfield(obj.state.sub,'ax')
                        for i = 1:numel(obj.ax),obj.ax(i).FontSize = obj.state.sub.ax.FontSize; end
                    end
                end
                % set name in GUI
                if ~isgraphics(obj.main,'figure')
                    obj.main.Title = 'Overview';
                else
                    obj.Name = 'Overview';
                end
            end
            % set datacursor mode
            callbackSub(obj,'PBDatacursor');
            datacursormode(Videoplayer.getParentFigure(obj.main),'off');
        end
        
        function updateSub(obj,type)
            %updateSub Updates GUI
            
            %
            % Re-create figure if necessary
            if any(strcmp(type,{'all' 'new' 'settings'})), createSub(obj,true); end
            %
            % Update figure
            idxBad = false(size(obj.ax));
            nMax   = obj.p_data.numSel;
            for i = 1:numel(obj.ax)
                if isgraphics(obj.ax(i)) && isvalid(obj.ax(i))
                    ydata = get(obj.p_data,obj.strProp{i});
                    set(obj.line(i),'XData',1:numel(ydata),'YData',ydata);
                    obj.ax(i).YLimMode = 'auto';
                    if obj.showOrigin(i)
                        ylim = obj.ax(i).YLim;
                        if all(ylim > 0)
                            obj.ax(i).YLim = [0 max(ylim)];
                        elseif all(ylim < 0)
                            obj.ax(i).YLim = [min(ylim) 0];
                        end
                    end
                else
                    idxBad(i) = true;
                end
            end
            obj.ax(idxBad)         = [];
            obj.line(idxBad)       = [];
            obj.strProp(idxBad)    = [];
            obj.showOrigin(idxBad) = [];
            set(obj.panel(idxBad),'UIContextMenu',[]);
            if numel(obj.ax) > 0
                if nMax == 1, nMax = 2; end
                xlim(obj.ax(1),[1 nMax]);
            end
        end
        
        function closeSub(obj)
            %closeSub Closes GUI
            
            idxBad = false(size(obj.ax));
            obj.state.sub.ax.FontSize = 10;
            for i = 1:numel(obj.ax)
                if ~(isgraphics(obj.ax(i)) && isvalid(obj.ax(i)))
                    idxBad(i) = true;
                else
                    obj.state.sub.ax.FontSize = obj.ax(i).FontSize;
                end
            end
            obj.ax(idxBad)         = [];
            obj.line(idxBad)       = [];
            obj.strProp(idxBad)    = [];
            obj.showOrigin(idxBad) = [];
            set(obj.panel(idxBad),'UIContextMenu',[]);
        end
        
        function hideSub(obj) %#ok<MANU>
            %hideSub Clean up figure
        end
        
        function callbackSub(obj,type,src,dat) %#ok<INUSL>
            %callbackSub Handles callbacks and code snippets
            
            switch type
                case 'PBDatacursor'
                    dcm           = datacursormode(Videoplayer.getParentFigure(obj.main));
                    dcm.UpdateFcn = @(dummy,event_obj) updateDatatip(obj,event_obj);
                    if strcmp(dcm.Enable,'on')
                        dcm.Enable = 'off';
                    else
                        dcm.Enable = 'on';
                    end
                case 'OriginOn'
                    obj.showOrigin(dat) = true;
                    updateSub(obj,'selection');
                case 'OriginOff'
                    obj.showOrigin(dat) = false;
                    updateSub(obj,'selection');
                case 'FontSize'
                    for i = 1:numel(obj.ax),obj.ax(i).FontSize = dat; end
            end
        end

        function cm  = contextMenuSub(obj,idxAx)
            %contextMenuSub Creates  a context menu for axes
            
            % add a context menu to listbox to allow for larger font
            fig = Videoplayer.getParentFigure(obj.main);
            cm  = uicontextmenu('Parent',fig);
            cm1 = uimenu(cm, 'Label', sprintf('Limits (%d)',idxAx));
            uimenu(cm1, 'Label', 'Show origin', 'Callback', @(src,event) callbackSub(obj,'OriginOn',src,idxAx));
            uimenu(cm1, 'Label', 'Reset limit', 'Callback', @(src,event) callbackSub(obj,'OriginOff',src,idxAx));
            cm1 = uimenu(cm, 'Label', 'Limits (all)');
            uimenu(cm1, 'Label', 'Show origin(s)', 'Callback', @(src,event) callbackSub(obj,'OriginOn',src,1:numel(obj.ax)));
            uimenu(cm1, 'Label', 'Reset limit(s)', 'Callback', @(src,event) callbackSub(obj,'OriginOff',src,1:numel(obj.ax)));
            cm1 = uimenu(cm, 'Label', 'Set font size to','Separator','on');
            for i = 10:2:40
                uimenu(cm1, 'Label', num2str(i), 'Callback',...
                    @(src,dat) callbackSub(obj,'FontSize','ax',i));
            end
        end
                
        function str = updateDatatip(obj,event_obj)
            %updateDatatip Returns string for data tip in overview plot
            
            pos = event_obj.Position;
            idx = round(pos(1));
            str = {sprintf('UUID: %s',obj.p_data.uuidStr{idx}), ...
                sprintf('Ind (abs): %d',obj.p_data.ind(idx)),...
                sprintf('Ind (rel): %d',idx),...
                sprintf('Value: %.4g',pos(2))};
        end
    end
end
