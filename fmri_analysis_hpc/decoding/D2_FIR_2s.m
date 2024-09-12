function D2_FIR(data_dir, onsets, SJs, TR, WMdelay, currPrefix, runs, excludeSJ, fir_out, condnames, sessions, hm)
% This script implements a FIR model as commonly used in Time-resolved
% Decoding.
% Each time-bin of a WM-delay phase is modelled individually
% The WM-delay is of 12seconds duration, which results in 6 bins (TR=2s)
% The underlying directory-structure is explained in the Tutorial
%
% Copyright: Timo Torsten Schmidt, Freie Universität Berlin

%% Loop over Subjects
for sj = 1:numel(SJs)

    if ismember(sj, excludeSJ)
        continue;
    else
        % Composition of the Subject directory
        sj_dir = fullfile(data_dir, SJs{sj});
        
        % SPM defaults
        spm('defaults','fmri');
        global defaults;
        global UFp;
        spm_jobman('initcfg');
        % OUTPUT Directory (as subdirectory of the SJ directory)
        tgt_dir = fullfile(sj_dir,sessions{sj},['FIR_' fir_out]);
        if ~exist(tgt_dir, 'dir')
            mkdir(tgt_dir)
        end
    
        %******************************************************************
        %               Setting FIR parameter
        % *****************************************************************
        % Output directory
        jobs{1}.stats{1}.fmri_spec.dir = cellstr(tgt_dir);
        % timing parameters
        jobs{1}.stats{1}.fmri_spec.timing.units     = 'secs';
        jobs{1}.stats{1}.fmri_spec.timing.RT        = TR;
        jobs{1}.stats{1}.fmri_spec.timing.fmri_t    = 16;
        jobs{1}.stats{1}.fmri_spec.timing.fmri_t0   = 1;
        % FIR-SPECIFICATION
        jobs{1}.stats{1}.fmri_spec.bases.fir.length = 6; %WMdelay; % seconds
        jobs{1}.stats{1}.fmri_spec.bases.fir.order  = 3; %WMdelay/TR;  % time-bins
        % Other Specifications
        jobs{1}.stats{1}.fmri_spec.fact              = struct('name', {}, 'levels', {});
        jobs{1}.stats{1}.fmri_spec.volt              = 1;
        jobs{1}.stats{1}.fmri_spec.global            = 'None';
        jobs{1}.stats{1}.fmri_spec.mask              = {''};
        jobs{1}.stats{1}.fmri_spec.cvi               = 'None';
    
        % *****************************************************************
        %            Specify the Desing/Conditions/Onsets
        % *****************************************************************
        % CONDITON NAMES
        % condnames = {'WM1', 'WM2', 'WM3', 'WM4'};
    
        % TODO
        % get all runIDs from file names in 'func' folder
        nifti_dir = fullfile(sj_dir, sessions{sj}, 'func');
        runIDs = 1:4;

        % Loop over Sessions, as the logfiles (with onset data) are saved
        % separately per session
        for s = 1:size(runs,2)
            runID = runIDs(s);
            % high-pass cut-off (might also be reasonable at 300 for this design
            jobs{1}.stats{1}.fmri_spec.sess(s).hpf     = 300; %300; %128;
            % Allocation of Data (EPIs/Images) for the current Session
            % TODO get rid of hardcoded file names here
            %filename = fullfile(nifti_dir, sprintf('%s_task-pain_run-%i_bold.nii', SJs{sj}, runID));
            filename = fullfile(nifti_dir, [currPrefix runs{sj,runID}]);
            % use 'expand' to read 4d nifti file
            f = spm_select('expand', filename); %%%%%%%%%%%%%%%%%%%% for 4d ??????
            %jobs{1}.stats{1}.fmri_spec.sess(s).scans   = cellstr([f, repmat(',1', size(f,1),1)]);
            jobs{1}.stats{1}.fmri_spec.sess(s).scans   = cellstr(f);
    
            % The consecutive codes does not have to be understood neccessarily
            % It is highly specific to the way the onsets were coded in the
            % Logfiles
            % load logfiles - there is one per run
            % TODO actual file names are probably different, also probably tsv
            % files
            % WM1
            
            % Motion
            cov=1;
            multi_reg={''};
            if hm                
                n=1;
                k = strfind(runs{sj, runID}, '.nii')
                f1=spm_select('List', nifti_dir, ['^rp_' runs{sj, runID}(1:k-1) '.txt']);
                %while isempty(f1)
                %    n=n+1;
                %    f1=spm_select('List', nifti_dir, ['^rp_' runs{sj, runID}(1:k) '.txt']);
                %end                
                if ~isempty(f1)
                    multi_reg(cov,1)={[nifti_dir filesep f1]};
                    cov=cov+1;
                else
                    display('################################################################################')
                    display(['############### ' nifti_dir ': Headmotion Parameters do not exsist #############'])
                    display('################################################################################')
                end
            end
            
            jobs{1}.stats{1}.fmri_spec.sess(s).multi_reg = multi_reg; % multiple regressors

            for c = 1:numel(condnames)
                onsets_temp = onsets{sj,s,c};
                jobs{1}.stats{1}.fmri_spec.sess(s).cond(c).name     = condnames{c};
                jobs{1}.stats{1}.fmri_spec.sess(s).cond(c).onset    = onsets_temp;
                jobs{1}.stats{1}.fmri_spec.sess(s).cond(c).duration = 0;
                jobs{1}.stats{1}.fmri_spec.sess(s).cond(c).tmod     = 0;
                jobs{1}.stats{1}.fmri_spec.sess(s).cond(c).pmod     = struct('name', {}, 'param', {}, 'poly', {});
            end

        end
    
        % Create model
        fprintf(['Creating GLM\n'])
        spm_jobman('run', jobs);
        clear jobs
    
        %  Model Estimation
        load(fullfile(tgt_dir, 'SPM.mat'));
        fprintf(['Estimating GLM \n']);
        cd(tgt_dir);
        SPM = spm_spm(SPM);
        clear SPM;
    end
end
end