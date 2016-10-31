classdef NGS01Infotab_Dummy < NGS01Infotab
    %@NGS01Infotab_Dummy Very simple implementation of a dummy function to test NGS01Infotab
    %
    %----------------------------------------------------------------------------------
    %   Copyright 2016 Alexander Ludwig Klein, alexludwigklein@gmail.com
    %
    %   Physics of Fluids, University of Twente
    %----------------------------------------------------------------------------------
    
    methods
        function obj = NGS01Infotab_Dummy(data)
            obj = obj@NGS01Infotab(data);
        end
    end
    
    methods (Access = protected, Hidden = false)
        function createSub(obj,reUse)
            if ~reUse || ~isfield(obj.ui,'text') || ~isvalid(obj.ui.text)
                if isfield(obj.ui,'text'), delete(obj.ui.text); end
                obj.ui.text = uicontrol(obj.main,'Units','normalized','style','text',...
                    'string','',...
                    'tag','NODATA','Position',[0 0 1 0.8]);
            end
            if ~isgraphics(obj.main,'figure')
               obj.main.Title = 'Dummy';
            else
                obj.Name = 'Dummy';
            end
        end
        
        function updateSub(obj,type)
            obj.ui.text.String = sprintf('selected %d of %d experiments, type: %s',obj.data.numSel,obj.data.numAbs,type);
        end
        
        function closeSub(obj) %#ok<MANU>
        end
        
        function         hideSub(obj) %#ok<MANU>
        end
    end
end

