classdef Testing < NGS01
    %Testing Class to read minimum information from experiments at NGS01 setup and store all
    % remaining data in the data property
    %
    %----------------------------------------------------------------------------------
    %   Copyright 2016 Alexander Ludwig Klein, alexludwigklein@gmail.com
    %
    %   Physics of Fluids, University of Twente
    %----------------------------------------------------------------------------------
    
    %% Properties
    properties (GetAccess = public, Constant = true)
        % nopropsub Properties in subclass that do not reflect a physical property (cellstr)
        nopropsub = {};
    end
    
    %% Constructor and SET/GET
    methods
        function obj = Testing(varargin)
            % Testing Class constructor
            
            % call parent class constructor
            obj     = obj@NGS01(1,varargin{:});
            obj.vip = { 'name' 'uid' 'time' } ;
        end
    end
    
    %% Methods
    methods (Access = public, Hidden = false, Sealed = true)
    end
    
    %% Implementation of abstract methods from parent class
    methods (Access = protected, Hidden = false)
        function obj =resetSub(obj,event,varargin) %#ok<INUSD>
        end
    end
    
    methods (Static = true, Access = public, Hidden = false)
        function out = readParameters(in,varargin)
            % readParameters Process parameters from parameter file or run file immediately
            
            if ischar(in), in = feval(in,varargin{1}); end
            % result of call should be a structure array with parameters for each experiment, the
            % parameters are transformed to class properties and stored in the output structure
            if ~isstruct(in)
                error(sprintf('%s:Input',mfilename),'Expected a structure as return, please check!');
            end
            fn   = fieldnames(in);
            out  = struct;
            nExp = numel(in);
            for j = 1:numel(fn)
                % only process the general properites
                switch fn{j}
                    case {'version' 'period' 'status' 'time' 'enable'}
                        % general properties of all NGS01 classes
                        out.(fn{j}) = cat(1,in.(fn{j}));
                        in          = rmfield(in,fn{j});
                    case {'comment' 'name' 'user' 'options' 'userdata'}
                        % general properties of all NGS01 classes
                        out.(fn{j}) = cell(nExp,1);
                        for i = 1:nExp
                            out.(fn{j}){i} = in(i).(fn{j});
                        end
                        in = rmfield(in,fn{j});
                end
            end
            % everything else goes into the data property
            out.data = cell(nExp,1);
            for i = 1:nExp
                out.data{i} = in(i);
            end
        end
    end
end
