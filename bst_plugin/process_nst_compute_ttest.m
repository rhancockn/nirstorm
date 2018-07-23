function varargout = process_nst_compute_ttest( varargin )
% process_nst_compute_ttest
% Compute a ttest according to a spm-like constrast vector using 
% t = cB / sqrt( c Cov(B) c^T )  
%
% B, cov(B) and the corresponding degrree of freedom are estimated inprocess_nst_compute_glm.
% 
% 
% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Edouard Delaire, 2018
%  
eval(macro_method);
end



%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Compute ttest';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'NIRS - wip';
    sProcess.Index       = 1402;
    sProcess.isSeparator = 0;
    sProcess.Description = 'https://github.com/Nirstorm/nirstorm/wiki/%5BWIP%5D-GLM-implementation';
    % todo add a new tutorials
    
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'matrix'};
    sProcess.OutputTypes = {'data','raw'};
    
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
   
    
    sProcess.options.Contrast.Comment = 'Contrast vector';
    sProcess.options.Contrast.Type    = 'text';
    sProcess.options.Contrast.Value   = '[-1 1]';
    
    sProcess.options.Student.Comment={' One-tailed or two-tailed hypothesis? <br /> One tail','two tail'};
    sProcess.options.Student.Type ='radio';
    sProcess.options.Student.Value=1;
    sProcess.options.Student.Hidden  = 0;

    
    
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) 
    Comment = sProcess.Comment;
    Comment = [ Comment ' C = ' sProcess.options.Contrast.Value ]; 
end

function OutputFiles = Run(sProcess, sInputs)
    OutputFiles={};
    
    % parse input : 
    for i=1:length(sInputs) 
        name= strsplit(sInputs(i).Comment,' ');
        if( strcmp(name(1), 'covB') == 1)
            covB=in_bst_data(sInputs(i).FileName);
            
            name= strsplit(cell2mat(name(end)),'=');
            name= strsplit(cell2mat(name(end)),'_');

            df=str2num(cell2mat(name(1)));
        elseif ( strcmp(name(1), 'B') == 1)
            B=in_bst_data(sInputs(i).FileName);
        else
           %bst_report('Error', sProcess, sInputs, [ 'The file ' sInputs(i).FileName ' is not recognized. Please only input the B and covB matrix' ]);
        end    
    end
    n_cond=size(B.Value',1);
    n_chan=size(B.Value',2);
    
    % exctract the constrast vector. 
    if( strcmp( sProcess.options.Contrast.Value(1),'[') && strcmp( sProcess.options.Contrast.Value(end),']') )
        % The constrast vector is in a SPM-format : 
        % sProcess.options.Contrast.Value = '[1,0,-1]'
        C=strsplit( sProcess.options.Contrast.Value(2:end-1),',');
        C=str2num(cell2mat(C));
    else 
        C=[];
        % Parse the input 
        % Accepted form are : 'X event1 Y event2' 
        % where X,Y is a sign(+,-), a signed number(-1,+1) or a decimal(+0.5,-0.5)
        % event12 are the name of regressor present in the design matrix
        % A valid input can be '- rest + task' ( spaces are important)
        
        expression='[-+]((\d+.\d+)|((\d)+)|)\s+\w+';
        [startIndex,endIndex] = regexp( sProcess.options.Contrast.Value , expression ); 

        for(i=1:length(startIndex))
            word=sProcess.options.Contrast.Value(startIndex(i):endIndex(i)); % can be '-rest','+rest'..
            
            [evt_ind_start,evt_ind_end]=regexp(word, '\s+\w+' );            
            evt_name=word(evt_ind_start+1:evt_ind_end);

            
            % Find the weight of the regressor 
            if strcmp(word(1:evt_ind_start-1),'+')
                evt_coef=1;
            elseif strcmp(word(1:evt_ind_start-1),'-')
                evt_coef=-1;
            else
                evt_coef=str2double(word(1:evt_ind_start));
            end
            
            
            %Find the position of the regressor            
            ind=find(strcmp(B.Description,evt_name))
            if( isempty(ind) )
               bst_report('Error', sProcess, sInputs, [ 'Event ' evt_name ' has not been found']);
               return;
            end
            
            C(ind)=evt_coef;
        end
        
        

        if isempty(C)
            bst_report('Error', sProcess, sInputs, 'The format of the constrast vector (eg [-1 1] ) is not recognized');
            return
        end
   end
    
    % Add zero padding for the trend regressor 
    if length(C) < n_cond
       C= [C zeros(1, n_cond - length(C)) ]; 
    end    
     
    B.Value=C*B.Value';
    t=zeros(1,n_chan);
    
    for i = 1:n_chan
        t(i)= B.Value(i) / sqrt( C*covB.Value(:,:,i)*transpose(C) ) ; 
    end
    
    if(  sProcess.options.Student.Value == 1)
        p=tcdf(-abs(t), df);
    else
        p=2*tcdf(-abs(t), df);
    end    
    df=ones(n_chan,1)*df;
    
    
    % Saving the output.
    iStudy = sInputs.iStudy;


    % === OUTPUT STRUCTURE ===
    % Initialize output structure
    sOutput = db_template('statmat');
    sOutput.pmap         = [p;p]';
    sOutput.tmap         = [t;t]';
    sOutput.df           = df;
    sOutput.ChannelFlag= ones(1,n_chan);
    sOutput.Correction   = 'no';
    sOutput.Type         = 'data';
    sOutput.Time         = [1];
    sOutput.ColormapType = 'stat2';
    sOutput.DisplayUnits = 'F';
    sOutput.Options.SensorTypes = 'NIRS';

    
    % Formating a readable comment such as -Rest +Task
    comment='T-test : ';
    for i=1:n_cond
        if ( C(i) < 0)
            if( C(i) == -1 )
                comment=[  comment  ' - ' cell2mat(B.Description(i)) ' '];
            else
                comment=[  comment num2str(C(i)) ' ' cell2mat(B.Description(i)) ' '];
            end
        elseif ( C(i) > 0 )
            if( C(i) == 1)
                comment=[  comment  ' + ' cell2mat(B.Description(i)) ' '];  
            else
                comment=[  comment  ' + ' num2str(C(i)) ' ' cell2mat(B.Description(i)) ' '];
            end 
        end     
    end    
    
    sOutput.Comment=comment;
    sOutput = bst_history('add', sOutput, B.History, '');

    sOutput = bst_history('add', sOutput, 'ttest computation', comment);
    OutputFiles{1} = bst_process('GetNewFilename', fileparts(sInputs(1).FileName), 'pdata_ttest_matrix');
    save(OutputFiles{1}, '-struct', 'sOutput');
    db_add_data(iStudy, OutputFiles{1}, sOutput);

end
