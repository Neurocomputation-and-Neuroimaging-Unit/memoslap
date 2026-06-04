function glm_hpc(subject_id, session_id, analysis_steps, prefix)
% GLM HPC
% -------------------------------------------------------------------------
% subject_id: double

control_analysis = 0;
analysis_switch = analysis_steps; %[1,2,3]; % 1 2 3 4 5
currPrefix = prefix; %'s8wr';  
%'' when bids and unpreprocessed; 
%ra/ar if already slicetime-corrected and realigned
%'' if doing normalization of accuracy maps
%w if aready normalized
% watch order of prefixes!

% Change details here:
ntask = session_id; 

beta_dir = '1st_level_stimuli13_buttonPress';
condnames = {'stimuli','buttonPress'};
duration = zeros(size(condnames));                                          % epoch duration; for single events set 0
%duration(1:4) = 5.5;

%# step 3:  contrasts 
analysisfolder = beta_dir;
cnames = condnames;
%very basic, adjust yourself, maybe model response regressor?
%cvecs  = {[ 1  0  0  0  0  0 ], ...   % 1
%          [ 0  1  0  0  0  0 ], ...   % 2
%          [ 0  0  1  0  0  0 ], ...   % 3
%          [ 0  0  0  1  0  0 ], ...   % 4
%          [ 0  0  0  0  1  0 ], ...   % 5
%          [ 0  0  0  0  0  1 ]};      % 6
% cvecs = {[ 1  0  0  0 ], ...
%          [ 0  1  0  0 ], ...
%          [ 0  0  1  0 ], ...
%          [ 0  0  0  1 ]};
 cvecs = {[ 1  0 ], ...
          [ 0  1 ]};
% cvecs = {[ 1 -1 ]};
% cvecs = {[ 1 ]};
del=1; % Delete existing contrasts (1=yes)
% were multiple regressors included in 1st level (step 1)?
n_hm=6;   % number of head motion parameters from realignment (step 4 in B0_preprocessing)
n_cc=0;   % number of CompCorr WM and CSF principal components (step 8 in B0_preprocessing)
    % if >0, "zeros" will be appended in design matrix

hpf      = 128;                                                             % High-pass filter cut-off; default 128 sec
% include multiple regressors (1=yes)
% if 1 (yes), 'hm' and/or 'cc' will be appended to outputfolder_1st
hm=1;   % head motion parameters from realignment (step 4 in B0_preprocessing)
cc=0;   % CompCorr WM and CSF principal components (step 8 in B0_preprocessing)

% Set paths
% -------------------------------------------------------------------------

src_dir      = '/scratch/grum90/memoslap_phase2/analysis_bids/';
logDir 	     = '/scratch/grum90/memoslap_phase2/logs/';

addpath(genpath('/home/grum90/memoslap_phase2/')); 
addpath(genpath('/scratch/grum90/toolboxes/hMRI-toolbox-0.6.0'));
SPM_path = '/scratch/grum90/toolboxes/spm12_vM/';            
addpath(SPM_path);

% Get data
% -------------------------------------------------------------------------
cd(src_dir) 
SJ = sprintf('sub-22%02d', subject_id);

% session & run identifiers
%session = sprintf('%s_ses-task%d', SJ, ntask);
session = sprintf('ses-%02d', 2+ntask);
ses_dir = fullfile(src_dir, SJ, session);

% get runs
run_dir = fullfile(ses_dir, 'func');
nifti_files = dir(fullfile(run_dir, ['sub-', '*bold.nii'])); %look for all functional nifti files
for r = 1:length(nifti_files)
    runs{r} = nifti_files(r).name;
end

fprintf('GLM Analysis\n')
fprintf('========================\n\n')
fprintf('\nSubject: %s \n', SJ)
fprintf('\nSesssion: %s \n', session)
fprintf('\nRuns: \n')
for r = 1:size(runs,2)
    fprintf('%s \n', runs{r})
end

% anatomy identifier
ana = ['anat'];
struct_dir = fullfile(ses_dir, ana);

anat_files = dir(fullfile(struct_dir, ['sub-', '*T1w.nii'])); %look for all anat nifti files

fprintf('\nAnatomy files: \n')
for i = 1:size(anat_files,1)
    fprintf('%s \n', anat_files(i).name)
end

% now we get the data from the json file 
json_files = (dir(fullfile(run_dir, '**', ['task', '*json'])));             % extract all json files, althoguh they should have the same info 

if isequal(size(json_files), [0, 1]) 
    json_files = (dir(fullfile(run_dir, '**', ['sub-', '*bold.json'])));
end

json_file = [json_files(1).folder, filesep, json_files(1).name];            % we select the first json file to extract metadata from 
TR_json = get_metadata_val(json_file,'RepetitionTime') / 1000;              % repetition time in sec
slice_timing = get_metadata_val(json_file,'SliceTiming');                   % extract slice timing
n_slices_json = height(slice_timing);                                       % compute number of slices from slice timing
[~,y]= sort(slice_timing);                                                  % compute slice order 
slice_order = y';

% now get the same info from nifti header  
nifti_file_metadata = [nifti_files(1).folder, filesep, nifti_files(1).name]; 
info = niftiinfo(nifti_file_metadata);
TR_nifti = info.PixelDimensions(4); 
n_slices_nifti = info.ImageSize(3);
vox_size=repmat(info.PixelDimensions(1),1,3);

% compare json and nifti header 
if round(TR_nifti, 4) ~= round(TR_json, 4)
    warning ("TR does not match between json file and nifti") 
end 
if n_slices_json ~= n_slices_nifti
    warning ("Number of slices does not match between json file and nifti") 
end 

n_slices = n_slices_json; % number of slices
tr=TR_json; % repetition time in sec.

fmri_t = n_slices; % Microtime resolution; If you have performed slice-timing correction, change this parameter to match the number of slices specified there; otherwise, set default 16
fmri_t0	= slice_order(round(length(slice_order)/2));

%%

for n = analysis_switch
    switch n

		case 1 % Logfiles / Onsets
        % -----------------------------------------------------------------

        % get logfiles
        oruns=dir(fullfile(logDir, sprintf('%s_ses-task', SJ), sprintf('%s_ses-%d_task-DMTS_run*.tsv', SJ, ntask)));
        rmlogs =[];
        for itemp = 1:numel(oruns)
            try
                temp = tdfread([oruns(itemp).folder filesep oruns(itemp).name]);
            catch err
                if err.identifier == 'MATLAB:repmat:invalidReplications'
                    temp.subject_number = [];
		    warning('Check logfile. Error: MATLAB:repmat:invalidReplications')
                else
                    warning('Some Logfiles are not recognized. Skipping..')
                end
            end
            if size(temp.trial_onset,1) < 48
                warning('Some Logfiles have short runs. Skipping..')
                rmlogs = [rmlogs, itemp];
            end
        end
        oruns(rmlogs) = [];

        % sanity checks
        % 4 logfiles expected
        if numel(oruns) ~= size(runs,2)
            error('Found %d full logfiles but expected 4.', numel(oruns))
        end
        % see if remaining logs are numbered 1-X
        temp = [];
        for itemp = 1:numel(oruns)
            temp = [temp, str2num(oruns(itemp).name(30))];
        end 
        if ~isequal(sort(temp), 1:size(runs,2)) 
            error('Found unexpected numbering of logfiles. Expected 1-%d', size(runs,2)) 
        end
        
        % iterate through runs
	fprintf('\nLogfiles:\n')
        for r=1:size(runs,2)
            % print name of logfile
            fprintf('%s \n', [oruns(r).folder filesep oruns(r).name])

            % read logfile
            this_log = tdfread([oruns(r).folder filesep oruns(r).name]);
                
            % extract targets as numbers for WM delay
            % condition
            conditions = nan(1,48);
            for i = 1:48
                target_label = sprintf('stimulus_%d', this_log.target_cue(i));
                nonTarget_label = sprintf('stimulus_%d', 3-this_log.target_cue(i));
                conditions(i) = this_log.(target_label)(i);
                control_conditions(i) = this_log.(nonTarget_label)(i);
		if conditions(i) ~= this_log.target_label(i)
		    error('Wrong Target Label!')
		end
            end
            if sum(conditions==1)~=12 | sum(conditions==2)~=12 | sum(conditions==3)~=12 | sum(conditions==4)~=12
                error('Wrong number of conditions!')
            end
            if sum(control_conditions==1)~=12 | sum(control_conditions==2)~=12 | sum(control_conditions==3)~=12 | sum(control_conditions==4)~=12
                error('Wrong number of non-conditions!')
            end

            use_onset = this_log.trial_onset./1000;

            if control_analysis == 1
                % Non-Target Conditions
                % ---------------------
                % Even Onset
                %onsets{r,1} = use_onset(control_conditions==1);
                %onsets{r,2} = use_onset(control_conditions==2);
                %onsets{r,3} = use_onset(control_conditions==3);
                %onsets{r,4} = use_onset(control_conditions==4);

            elseif control_analysis == 0
                % Target Conditions
                % ----------------------
                % Even Onset
                %onsets{r,1} = use_onset(conditions==1);
                %onsets{r,2} = use_onset(conditions==2);
                %onsets{r,3} = use_onset(conditions==3);
                %onsets{r,4} = use_onset(conditions==4);

                % All Stimuli
                % ---------------------------------------------
                %onsets{r,1} = sort([(this_log.timing_stim_1/1000); (this_log.timing_stim_2/1000); (this_log.timing_mask/1000); (this_log.timing_stim_3/1000); (this_log.timing_stim_4/1000)]);

                % Stimuli 1 & 3
                % ---------------------------------------------
                onsets{r,1} = sort([(this_log.timing_stim_1/1000); (this_log.timing_stim_3/1000)]);

                % Motor
                % ---------------------------------------------
                onsets{r,2} = (this_log.timing_response_window + this_log.reaction_time)/1000;
		    end 
	    end %end if
		
        case 2 % glm
        % -----------------------------------------------------------------
             
        fprintf('\nStep 3, 1st level glm: %s\n', SJ)
	fprintf('GLM: %s\n', beta_dir)
        C2_glm_1stLevel(ses_dir, beta_dir, currPrefix, tr, fmri_t, fmri_t0, hpf, runs, condnames, onsets, duration, hm, cc);

		% contrasts
		case 3
        % -----------------------------------------------------------------

	    display('Running Contrasts')
        C3_contrast_1stLevel(ses_dir, analysisfolder, cnames, cvecs, del, n_hm, n_cc, runs);

    end
end
            
