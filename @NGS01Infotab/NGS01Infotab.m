classdef NGS01Infotab < handle
    %NGS01Infotab Abstract class for tabs in info and selection GUI implemented in class NGS01Info
    %
    %----------------------------------------------------------------------------------
    %   Copyright 2016 Alexander Ludwig Klein, alexludwigklein@gmail.com
    %
    %   Physics of Fluids, University of Twente
    %----------------------------------------------------------------------------------
    
    %% Properties
    properties (GetAccess = public, SetAccess = public, Dependent = true)
        % data Data object with n experiments (1 x NGS01 subclass)
        data
        % isLive True/false whether object should update automatically (logical)
        isLive
    end
    
    properties (GetAccess = public, SetAccess = protected, Dependent = true)
        % isGUI True/false whether main is currently open (logical)
        isGUI
    end
    
    properties (GetAccess = public, SetAccess = public, Transient = true)
        % userdata Arbitrary user data (arbitrary)
        userdata
    end
    
    properties (GetAccess = {?NGS01Infotab,?NGS01Info}, SetAccess = {?NGS01Infotab,?NGS01Info}, Transient = true)
        % main Main figure, uitab or uipanel (figure, uitab, uipanel)
        main      = [];
        % ui User interface objects, e.g. buttons (struct)
        ui        = struct;
        % listener Listeners to make object go live (struct)
        listener  = struct;
        % state State of GUI during reset (struct)
        state     = struct;
        % p_data Storage for data
        p_data    = [];
    end
    
    %% Constructor/Destructor, SET/GET
    methods
        function obj   = NGS01Infotab(data)
            %NGS01Infotab Class constructor taking the data object as first argument
            
            if nargin == 1 && isnumeric(data)
                %
                % accepts single numeric input to create an array of objects
                obj       = NGS01Infotab;
                obj(data) = NGS01Infotab;
            elseif nargin > 0
                if ismember('NGS01',superclasses(data))
                    obj.p_data = data;
                else
                    error(sprintf('%s:Input',mfilename),['First input should be a subclass ',...
                        'of NGS01 or numeric input to create an array of objects']);
                end
            end
        end
        
        function         delete(obj)
            %delete Class destructor
            
            if ~isempty(obj.main), delete(obj.main); end
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
                obj.listener.resetNew       = event.listener(obj.p_data,'resetNew',       @(src,event) update(obj,'new'));
                obj.listener.resetData      = event.listener(obj.p_data,'resetData',      @(src,event) update(obj,'data'));
                obj.listener.resetSettings  = event.listener(obj.p_data,'resetSettings',  @(src,event) update(obj,'settings'));
                obj.listener.resetSelection = event.listener(obj.p_data,'resetSelection', @(src,event) update(obj,'selection'));
                obj.update;
            else
                fn = fieldnames(obj.listener);
                for k = 1:numel(fn)
                    delete(obj.listener.(fn{k}));
                end
                obj.listener = struct;
            end
        end
        
        function value = get.data(obj)
            value = obj.p_data;
        end
        
        function         set.data(obj,value)
            if ismember('NGS01',superclasses(value))
                obj.p_data = value;
                update(obj);
            elseif isempty(value);
                obj.p_data = [];
                update(obj);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for the property');
            end
        end
        
        function value = get.isGUI(obj)
            value = ~isempty(obj.main) && isgraphics(obj.main);
        end
    end
    
    %% Methods for public tasks
    methods (Access = public, Hidden = false, Sealed = true)
        function create(obj,parent,reUse)
            %create (Re-)creates infotab
            
            if nargin < 3, reUse = true; end
            if nargin < 2, parent = []; end
            if numel(obj) > 1
                for i = 1:numel(obj), create(obj(i),parent,reUse); end
                return;
            end
            %
            % Make sure a figure is available
            if ~reUse && obj.isGUI, delete(obj.main); obj.main = []; end
            if ~obj.isGUI
                reUse = false;
                if isempty(parent)
                    % create single new figure
                    obj.main = figure('numbertitle', 'off', 'Visible','on',...
                        'name', sprintf('%s',class(obj)), ...
                        'menubar','none', ...
                        'toolbar','figure', ...
                        'resize', 'on', ...
                        'DeleteFcn',@(src,dat) close(obj),...
                        'HandleVisibility','on');
                elseif isgraphics(parent,'figure')
                    obj.main = uipanel('parent',parent,'Position',[0 0 1 1], 'Tag',sprintf('%s',class(obj)),...
                        'Units','Normalized','Title', sprintf('%s',class(obj)),'DeleteFcn',@(src,dat) close(obj));
                elseif isgraphics(parent,'uitabgroup')
                    obj.main = uitab(parent, 'Tag',sprintf('%s',class(obj)),...
                        'Units','Normalized','Title', sprintf('%s',class(obj)),'DeleteFcn',@(src,dat) close(obj));
                end
                if ~isempty(fieldnames(obj.state)) && strcmp(obj.state.main.parent,class(obj.main)) && ...
                        ~isgraphics(obj.main,'uitab');
                    obj.main.Units    = obj.state.main.Units;
                    obj.main.Position = obj.state.main.Position;
                end
            end
            if isempty(obj.p_data)
                obj.ui.NODATA = uicontrol(obj.main,'Units','normalized','style','text',...
                    'string',{'No data available' sprintf('Please, add data to object of class ''%s'' to enable visualization',class(obj))},...
                    'tag','NODATA','Position',[0 0 1 0.8]);
            else
                if isfield(obj.ui,'NODATA')
                    delete(obj.ui.NODATA);
                    obj.ui = rmfield(obj.ui,'NODATA');
                end
                % call create function of subclass
                createSub(obj,reUse);
            end
            update(obj);
        end
        
        function update(obj,type)
            %update Updates infotab, type can be 'all', 'new', 'data', 'settings', 'selection'
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
            if isempty(obj.data) || ~obj.isGUI, return; end
            %
            % Call update function of subclass
            updateSub(obj,type);
        end
        
        function close(obj)
            %close Runs when GUI is closed
            
            if numel(obj) > 1
                for i = 1:numel(obj), close(obj(i)); end
                return;
            end
            % store state of GUI
            if ~isempty(obj.main)
                obj.state               = struct;
                obj.state.main.parent   = class(obj.main);
                obj.state.main.Units    = obj.main.Units;
                obj.state.main.Position = obj.main.Position;
                % call subclass
                closeSub(obj);
                % delete graphics
            end
            delete(obj.main);
            obj.main = [];
        end
        
        function hide(obj)
            %hide Runs when GUI is not on display

            fig = Videoplayer.getParentFigure(obj.main);
            Videoplayer.disableInteractiveModes(fig);
            hideSub(obj);
        end
    end
    
    %% Methods for abstract implementation in subclass
    methods (Access = protected, Hidden = false, Abstract = true)
        createSub(obj,reUse)
        %createSub Create GUI in existing figure, uipanel or uitab
        updateSub(obj,type)
        %updateSub Update GUI, type can be 'all', 'new', 'data', 'settings', 'selection'
        closeSub(obj)
        %closeSub Close GUI
        hideSub(obj)
        %hideSub Called when GUI is not on display
    end
    
    %% Methods for private tasks
    methods (Access = protected, Hidden = false, Sealed = true)
    end
    
    %% Static methods
    methods (Static = true, Access = public, Hidden = false, Sealed = true)
    end
    
    methods (Static = true, Access = protected, Hidden = false, Sealed = true)
    end
end
