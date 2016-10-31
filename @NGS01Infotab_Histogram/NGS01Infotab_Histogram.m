classdef NGS01Infotab_Histogram < NGS01Infotab
    %@NGS01Infotab_Histogram Shows a histogram as info tab
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
        % ax Axes for histograms (axes)
        ax = gobjects(0);
        % hist Histogram objects (hist object)
        hist = gobjects(0);
        % strProp Properties to show for each axes (cellstr)
        strProp = {};
        % nBin Number of bins for each histogram (double)
        nBin = [];
        % showm True/false whether to include the origin (e.g. zero value) for a property
        showOrigin = true(0);
    end
    
    %% Constructor/Destructor, SET/GET
    methods
        function obj = NGS01Infotab_Histogram(data)
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
                obj.hist       = gobjects(nProp,1);
                obj.nBin       = repmat(10,size(obj.strProp));
                obj.showOrigin = true(nProp,1);
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
                    xdata     = get(obj.p_data,obj.strProp{i});
                    cm        = contextMenuSub(obj,i);
                    obj.ax(i) = axes('OuterPosition',[0 0 1 1],'Parent',obj.panel(i));
                    % allow for automatic BinMethod of more than nBin different values are available
                    if numel(xdata) > 1 && sum(abs(xdata-xdata(1)) > eps) > obj.nBin(i)
                        obj.hist(i) = histogram(obj.ax(i),xdata);
                    else
                        obj.hist(i) = histogram(obj.ax(i),xdata,obj.nBin(i));
                    end
                    title(obj.ax(i),obj.strProp{i},'Interpreter','none');
                    obj.hist(i).UIContextMenu  = cm;
                    obj.panel(i).UIContextMenu = cm;
                    obj.ax(i).UIContextMenu    = cm;
                end
                obj.main.UIContextMenu = contextMenuSub(obj,[]);
                % recover state
                if isfield(obj.state,'sub')
                    if isfield(obj.state.sub,'ax')
                        for i = 1:numel(obj.ax),obj.ax(i).FontSize = obj.state.sub.ax.FontSize; end
                    end
                    if isfield(obj.state.sub,'hist')
                        for i = 1:numel(obj.hist)
                            if isvalid(obj.hist(i))
                                obj.hist(i).Normalization = obj.state.sub.hist.Normalization;
                            end
                        end
                    end
                end
                if ~isgraphics(obj.main,'figure')
                    obj.main.Title = 'Histogram';
                else
                    obj.Name = 'Histogram';
                end
            end
        end
        
        function updateSub(obj,type)
            %updateSub Updates GUI
            
            %
            % Re-create figure if necessary
            if any(strcmp(type,{'all' 'new' 'settings'})), createSub(obj,true); end
            %
            % Update figure
            idxBad = false(size(obj.ax));
            for i = 1:numel(obj.ax)
                if isgraphics(obj.ax(i)) && isvalid(obj.ax(i))
                    xdata = get(obj.p_data,obj.strProp{i});
                    obj.hist(i).Data = xdata;
                    if numel(xdata) > 1 && sum(abs(xdata-xdata(1)) > eps) > obj.nBin(i)
                        obj.hist(i).BinMethod = 'auto';
                    else
                        obj.hist(i).NumBins = obj.nBin(i);
                    end
                else
                    idxBad(i) = true;
                end
                obj.ax(i).XLimMode = 'auto';
                if obj.showOrigin(i)
                    xlim = obj.ax(i).XLim;
                    if all(xlim > 0)
                        obj.ax(i).XLim = [0 max(xlim)];
                    elseif all(xlim < 0)
                        obj.ax(i).XLim = [min(xlim) 0];
                    end
                end
            end
            obj.ax(idxBad)         = [];
            obj.hist(idxBad)       = [];
            obj.nBin(idxBad)       = [];
            obj.strProp(idxBad)    = [];
            obj.showOrigin(idxBad) = [];
            set(obj.panel(idxBad),'UIContextMenu',[]);
        end
                
        function callbackSub(obj,type,src,dat) %#ok<INUSL>
            %callbackSub Handles callbacks and code snippets
            
            switch type
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
                case 'FontSize'
                    for i = 1:numel(obj.ax),obj.ax(i).FontSize = dat; end
            end
        end
        
        function closeSub(obj)
            %closeSub Closes GUI
            
            idxBad = false(size(obj.ax));
            obj.state.sub.ax.FontSize = 10;
            obj.state.sub.hist.Normalization = 'count';
            for i = 1:numel(obj.ax)
                if ~(isgraphics(obj.ax(i)) && isvalid(obj.ax(i)))
                    idxBad(i) = true;
                else
                    obj.state.sub.ax.FontSize = obj.ax(i).FontSize;
                    obj.state.sub.hist.Normalization = obj.hist(i).Normalization;
                end
            end
            obj.ax(idxBad)         = [];
            obj.hist(idxBad)       = [];
            obj.nBin(idxBad)       = [];
            obj.strProp(idxBad)    = [];
            obj.showOrigin(idxBad) = [];
            set(obj.panel(idxBad),'UIContextMenu',[]);
        end
        
        function hideSub(obj) %#ok<MANU>
            %hideSub Clean up when GUI is hidden
        end
        
        function cm  = contextMenuSub(obj,idxAx)
            %contextMenuSub Creates a context menu for axes
            
            % add a context menu to listbox to allow for larger font
            fig = Videoplayer.getParentFigure(obj.main);
            cm  = uicontextmenu('Parent',fig);
            if ~isempty(idxAx)
                cm1 = uimenu(cm, 'Label', sprintf('Limits (%d)',idxAx));
                uimenu(cm1, 'Label', 'Show origin', 'Callback', @(src,event) callbackSub(obj,'OriginOn',src,idxAx));
                uimenu(cm1, 'Label', 'Reset limit', 'Callback', @(src,event) callbackSub(obj,'OriginOff',src,idxAx));
            end
            cm1 = uimenu(cm, 'Label', 'Limits (all)');
            uimenu(cm1, 'Label', 'Show origin(s)', 'Callback', @(src,event) callbackSub(obj,'OriginOn',src,1:numel(obj.ax)));
            uimenu(cm1, 'Label', 'Reset limit(s)', 'Callback', @(src,event) callbackSub(obj,'OriginOff',src,1:numel(obj.ax)));
            cm1 = uimenu(cm, 'Label', 'Normalization (all)');
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
