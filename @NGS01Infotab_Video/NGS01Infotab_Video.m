classdef NGS01Infotab_Video < NGS01Infotab
    %@NGS01Infotab_Video Shows video playlist as info tab
    %
    %----------------------------------------------------------------------------------
    %   Copyright 2016 Alexander Ludwig Klein, alexludwigklein@gmail.com
    %
    %   Physics of Fluids, University of Twente
    %----------------------------------------------------------------------------------
    
    %% Properties
    properties (GetAccess = public, SetAccess = protected, Transient = true)
        % playlist Playlist for videos (Videoplaylist)
        playlist =[];
    end
    
    properties (GetAccess = protected, SetAccess = protected, Transient = true)
        % videoprop Class property(ies) that holds video object(s) (cellstr)
        videoprop = {};
        % panel Panel(s) for playlist(s) (panel)
        panel = gobjects(0);
    end
    
    %% Constructor/Destructor, SET/GET
    methods
        function obj = NGS01Infotab_Video(data)
            obj = obj@NGS01Infotab(data);
        end
        
        function delete(obj)
            if ~isempty(obj.playlist)
                for i = 1:numel(obj.playlist)
                    delete(obj.playlist(i).player);
                    delete(obj.playlist(i));
                end
            end
        end
    end
    
    %% Methods
    methods (Access = protected, Hidden = false)
        function createSub(obj,reUse) %#ok<INUSD>
            %createSub Creates initial GUI
            
            %
            % Check for videos if not set otherwise before
            if isempty(obj.videoprop)
                idx = ismember(obj.p_data.myclass,'Video') | ismember(obj.p_data.myclass,'BeamProfile') ;
                obj.videoprop = obj.p_data.myprop(idx);
            end
            if isempty(obj.videoprop), return; end
            mynum = numel(obj.videoprop);
            %
            % Create ui controls in background
            obj.ui.PBUndocked = uicontrol(obj.main,'Units','normalized','Style','pushbutton',...
                'String','Video playlist is not docked to this GUI - press here to show or re-create it',...
                'Tag','PBUndocked','Callback', @(src,dat) callbackSub(obj,'PBUndocked',src,dat),...
                'Position',[0.1 0.55 0.8 0.2],'FontSize',12);
            obj.ui.CLiveSub = uicontrol(obj.main,'Units','normalized','Style','checkbox',...
                'String','Keep playlist live when switching tab','Tag','CLiveSub','Value',obj.isLive,...
                'Callback', @(src,dat) callbackSub(obj,'CLiveSub',src,dat),...
                'Position',[0.1 0.35 0.8 0.2],'HorizontalAlignment','center','FontSize',16);
            obj.panel = gobjects(mynum);
            for i = 1:mynum
                obj.panel(i) = uipanel('parent',obj.main,'Position',[(i-1)/mynum 0 1/mynum 1],...
                    'Units','Normalized','Title',obj.videoprop{i});
            end
            %
            % Create a playlist
            if isempty(obj.playlist) || ~all(isvalid(obj.playlist))
                for i = 1:numel(obj.playlist), delete(obj.playlist(i)); end
                obj.playlist = Videoplaylist((obj.p_data.(obj.videoprop{1}))',[],[],obj.panel(1));
                for i = 2:mynum
                    obj.playlist(i) = Videoplaylist((obj.p_data.(obj.videoprop{i}))',[],[],obj.panel(i));
                end
            end
            %
            % Set Name
            if ~isgraphics(obj.main,'figure')
                obj.main.Title = 'Video';
            else
                obj.Name = 'Video';
            end
        end
        
        function updateSub(obj,type) %#ok<INUSD>
            %updateSub Updates GUI
            
            if isempty(obj.videoprop), return; end
            for i = 1:numel(obj.videoprop)
                obj.playlist(i).vid = (obj.p_data.(obj.videoprop{i}))';
            end
            obj.ui.CLiveSub  = obj.isLive;
        end
        
        function closeSub(obj)
            %closeSub Closes GUI
            
            if isempty(obj.videoprop), return; end
            if ~isempty(obj.playlist)
                for i = 1:numel(obj.videoprop)
                    if isvalid(obj.playlist(i))
                        if ~isempty(obj.playlist(i).player) && isvalid(obj.playlist(i).player)
                            delete(obj.playlist(i).player);
                        end
                        delete(obj.playlist(i));
                    end
                end
            end
            obj.playlist = [];
        end
        
        function hideSub(obj)
            %hideSub Clean up figure
            
            if isempty(obj.videoprop), return; end
            % force live playlist if it is not docked in this GUI, e.g. if uitab holds no uipanel,
            % this is only done if the info object is live (found out by locking for CLive
            % uicontrol)
            fig = Videoplayer.getParentFigure(obj.main);
            h   = findall(fig,'Type','uicontrol','Tag','CLive');
            if isempty(findall(obj.main,'type','uipanel')) && ~isempty(h) && h.Value
                obj.isLive      = true;
                obj.ui.CLiveSub = obj.isLive;
            else
                obj.isLive      = false;
                obj.ui.CLiveSub = obj.isLive;
            end
        end
        
        function callbackSub(obj,type,src,dat) %#ok<INUSD>
            %callbackSub Handles callbacks and code snippets
            
            switch type
                case 'PBUndocked'
                    if ~isempty(obj.playlist), show(obj.playlist); end
            end
        end
    end
end
