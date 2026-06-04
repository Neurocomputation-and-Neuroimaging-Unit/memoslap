% DENOISING_PIPELINE.M
% Main script for resting-state fMRI denoising using CONN toolbox.
% Input: Path to pre-processed data with fMRIPrep
% Output: Denoised volumes in CONN's results folder.
% Reference: Wang et al. (2024)
% Author: Your Name
%Author Alireza Shahbabaie and Filip Niemann 

% prepare data. 
% data must be in BIDS format

% use unziped version of GM, WM and CSF masks conducted by fmriprep during

% fresh start( no variables and values)in MATLAB
clear
clc
%setpaths of CONN and SPM
addpath /usr/local/MATLAB/MATLAB_TOOLBOX/conn_la
addpath /usr/local/MATLAB/MATLAB_TOOLBOX/spm12
% 1. Project name (fixed)
Project = 'MeMoSLAP';

% 2. Define root paths (user must customize these)
% - Replace with relative paths or variables that auto-detect location
repo_root = fileparts(mfilename('fullpath')); % Auto-detects script location

% Default BIDS/derivatives structure (relative to repo root)
root_fmriprep = fullfile(repo_root, 'derivatives', 'fMRIPrep');
root_conn = fullfile(repo_root, 'derivatives', 'Conn_script_based');

% 3. Mask paths (store masks in repo's /masks/ folder)
mask_dir = fullfile(repo_root, 'masks');
lvifg_mask_path = fullfile(mask_dir, 'resampled_res-2_lvIFG_seed_6mm.nii');
rotc_mask_path = fullfile(mask_dir, 'resampled_rOTC_res-02.nii');
hippo_mask_path = fullfile(mask_dir, 'resampled_hippocampus_4mm_mask_res-02.nii');

% 4. Filename filters (shared across users)
struct_filter_name = '_acq-mprage_space-MNI152NLin6Asym*_desc-preproc_T1w.nii.gz';
func_filter_name = '_task-resting_dir-AP_space-MNI152NLin6Asym*_desc-preproc_bold.nii.gz';
timeseries_filter_name = '_task-resting_dir-AP_merg_desc-confounds_timeseries.tsv'; 
GM_filter_name = '_acq-mprage_space-MNI152NLin6Asym*_label-GM_probseg.nii';
WM_filter_name = '_acq-mprage_space-MNI152NLin6Asym*_label-WM_probseg.nii';
CSF_filter_name = '_acq-mprage_space-MNI152NLin6Asym*_label-CSF_probseg.nii';
% 5. Session naming (user may need to modify)
ses_1 = 'ses-1'; % Change to 'ses-01' if needed
ses_2 ='ses-2'; % Change to 'ses-01' if needed
ses_1_str ='ses_1'; % Change to 'ses_01' if needed
ses_2_str ='ses_2';% Change too 'ses-02' if needed

% ==============================================
batch.Setup.RT = 1;
% (Rest of your pipeline code here)

% Verify paths exist before proceeding
if ~exist(root_fmriprep, 'dir')
    error('fmriprep directory not found: %s', root_fmriprep);
end
if ~exist(root_conn, 'dir')
    mkdir(root_conn); % Create CONN directory if needed
end

batch.filename = fullfile(root_conn,'conn_rsfmri_denoising.mat');


%% Get files
% get all subjects in fmriprep folder, subjects are saved in list_sub.name
list_sub = dir(fullfile(root_fmriprep,'sub-*'));

list_sub = list_sub([list_sub.isdir]); % Only folders
%for debugging use only one subject
%list_sub=list_sub(1:2); %uncomment for debugging

% get anatomical
list_anat = dir(fullfile(root_fmriprep,'**',['sub*',struct_filter_name]));
anat_path = fullfile({list_anat.folder},{list_anat.name});
anat_path = sort(anat_path);

%anat_path = anat_path(1:2);  %uncomment for debugging
% get gm mask
gm_mask = dir(fullfile(root_fmriprep,'**',['sub*',GM_filter_name]));
gm_path = fullfile({gm_mask.folder},{gm_mask.name});
gm_path = sort(gm_path);
%gm_path = gm_path(1:2);  %uncomment for debugging

% get gm mask
wm_mask = dir(fullfile(root_fmriprep,'**',['sub*',WM_filter_name]));
wm_path = fullfile({wm_mask.folder},{wm_mask.name});
wm_path = sort(wm_path);
%wm_path = wm_path(1:2);  %uncomment for debugging

% get csf mask
csf_mask = dir(fullfile(root_fmriprep,'**',['sub*',CSF_filter_name]));
csf_path = fullfile({csf_mask.folder},{csf_mask.name});
csf_path = sort(csf_path);
%csf_path = csf_path(1:2);  %uncomment for debugging

% get functional
list_func_1 = dir(fullfile(root_fmriprep,'**',['sub*',ses_1,'*',func_filter_name]));
list_func_2 = dir(fullfile(root_fmriprep,'**',['sub*',ses_2,'*',func_filter_name]));
list_func = [list_func_1; list_func_2];
func_path = fullfile({list_func.folder},{list_func.name});
func_path = sort(func_path);
%func_path = func_path(1:4);  %uncomment for debugging

% get timeseries
list_timeseries = dir(fullfile(root_fmriprep,'**',['sub*',timeseries_filter_name]));
cov_path = fullfile({list_timeseries.folder},{list_timeseries.name});
cov_path = sort(cov_path);
%cov_path = cov_path(1:4);  %uncomment for debugging

%% set basic parameters for batch and check if data are complete
% Basic parameters
batch.Setup.isnew = 1;
batch.Setup.nsubjects = numel(list_sub);
batch.Setup.nsessions = 2;
batch.Setup.overwrite =1;
batch.Setup.analysis =1;    

% number anatomical image verification
if ~isequal(numel(list_sub),numel(anat_path))
    disp('anatomical images does not match subject count')
end

% number gm image verification
if ~isequal(numel(list_sub),numel(gm_path))
    disp('grey matter images does not match subject count')
end

% number wm image verification
if ~isequal(numel(list_sub),numel(wm_path))
    disp('white matter images does not match subject count')
end

% number csf image verification
if ~isequal(numel(list_sub),numel(csf_path))
    disp('csf images does not match subject count')
end

% number functional image verification
if ~isequal(numel(anat_path)*batch.Setup.nsessions,numel(func_path))
    disp('functional images does not match anatomical image count')
end

% number covariate file verification
if ~isequal(numel(cov_path),numel(func_path))
    disp('timeseries images does not match functional image count')
end

% session verification
for sub_idx = 1:numel(list_sub)
    subject_id = list_sub(sub_idx).name;
    ses_count = sum(contains(func_path, subject_id));
    if ses_count ~= 2
        warning('Subject %s has %d sessions (expected 2)', subject_id, ses_count);
    end
end

%% Initialize batch struct
batch.Setup.structurals = cell(1, numel(list_sub));
batch.Setup.functionals = cell(1, numel(list_sub));


% Initialize covariates
covariate_names = {'Global', 'csf', 'Motion','white_matter'};

% Initialize covariates files structure properly
batch.Setup.covariates.files = cell(1, numel(covariate_names));
for c = 1:numel(covariate_names)
    batch.Setup.covariates.files{c} = cell(1, numel(list_sub));
end

% get timeseries and create temporary csv files
% Create temporary directory for filtered CSV files
temp_dir = fullfile(root_conn, 'temp_covariates');
if ~exist(temp_dir, 'dir')
    mkdir(temp_dir);
end

%% set basic parameters for batch and check if data are complete
% Basic parameters
batch.Setup.isnew = 1;
batch.Setup.nsubjects = numel(list_sub);
batch.Setup.nsessions = 2;
batch.Setup.overwrite =1;

% number anatomical image verification
if ~isequal(numel(list_sub),numel(anat_path))
    disp('anatomical images does not match subject count')
end

% number gm image verification
if ~isequal(numel(list_sub),numel(gm_path))
    disp('grey matter images does not match subject count')
end

% number wm image verification
if ~isequal(numel(list_sub),numel(wm_path))
    disp('white matter images does not match subject count')
end

% number csf image verification
if ~isequal(numel(list_sub),numel(csf_path))
    disp('csf images does not match subject count')
end

% number functional image verification
if ~isequal(numel(anat_path)*batch.Setup.nsessions,numel(func_path))
    disp('functional images does not match anatomical image count')
end

% number covariate file verification
if ~isequal(numel(cov_path),numel(func_path))
    disp('timeseries images does not match functional image count')
end

% session verification
for sub_idx = 1:numel(list_sub)
    subject_id = list_sub(sub_idx).name;
    ses_count = sum(contains(func_path, subject_id));
    if ses_count ~= 2
        warning('Subject %s has %d sessions (expected 2)', subject_id, ses_count);
    end
end



%% Process each subject
for sub_idx = 1:numel(list_sub)

    subject_id = list_sub(sub_idx).name;

    % filter path that contain subject
    % Anatomical path
    idx_anat = contains(anat_path,subject_id);
    anat_path_subj = anat_path(idx_anat);

    % GM path
    idx_gm = contains(gm_path,subject_id);
    gm_path_subj = gm_path(idx_gm);

    % WM path
    idx_wm = contains(wm_path,subject_id);
    wm_path_subj = wm_path(idx_wm);

    % CSF path
    idx_csf = contains(csf_path,subject_id);
    csf_path_subj = csf_path(idx_csf);


    % functional path
    idx_func_ses1 = contains(func_path,subject_id) & contains(func_path,ses_1);
    func_path_subj_ses_1 = func_path(idx_func_ses1);

    idx_func_ses2 = contains(func_path,subject_id) & contains(func_path,ses_2);
    func_path_subj_ses_2 = func_path(idx_func_ses2);

    % covariate path
    idx_cov = contains(cov_path,subject_id);
    cov_path_subj = cov_path(idx_cov);


    % Get indices from timeseries.tsv file and create filtered CSV files
    [motion_indices, motion_csv_files] = get_indices_and_write_csv(Project, cov_path_subj, subject_id, "motion", temp_dir);
    [csf_indices, csf_csv_files] = get_indices_and_write_csv(Project, cov_path_subj, subject_id, "csf", temp_dir);
    [global_indices, global_csv_files] = get_indices_and_write_csv(Project, cov_path_subj, subject_id, "global", temp_dir);
    [wm_indices, wm_csv_files] = get_indices_and_write_csv(Project, cov_path_subj, subject_id,'white_matter', temp_dir);
    
    %% batch.Setup 

    % Structural file
    batch.Setup.structurals{sub_idx} = {anat_path_subj};
    
    % Functional files
    batch.Setup.functionals{sub_idx} = { ...
        func_path_subj_ses_1, ...
        func_path_subj_ses_2 ...
    };

    % Covariates setup - now using the filtered CSV files
    batch.Setup.covariates.names = {'Global', 'csf', 'Motion','white_matter'};
%% Process each subject - corrected covariates part
    % Corrected covariates files assignment
    for nses = 1:numel(global_csv_files)
    batch.Setup.covariates.files{1}{sub_idx}{nses} = global_csv_files{nses};  % Global
    batch.Setup.covariates.files{2}{sub_idx}{nses} = csf_csv_files{nses};     % CSF
    batch.Setup.covariates.files{3}{sub_idx}{nses} = motion_csv_files{nses};  % Motion
    batch.Setup.covariates.files{4}{sub_idx}{nses} = wm_csv_files{nses};  % WM
    end
    

    % Indices - now simple since we have 1 column per CSV
    batch.Setup.covariates.indices = { ...
        {1}, ... % Global (only 1 column in CSV)
        {1}, ... % CSF (only 1 column in CSV)
        {1:numel(motion_indices.ses_1.indices)}, ... % Motion (multiple columns)
        {1} ... % white matter (onley 1 column in csv
    };
    

        % Dimensions
    batch.Setup.covariates.dimensions = { ...
        1, ... % Global
        1, ... % CSF
        numel(motion_indices.ses_1.indices), ... % Motion
        1, ... % WM
    };
    
    % ROIs setup
        %% ROIs setup (updated)
        batch.Setup.rois.names = {'Grey Matter', 'White Matter', 'CSF', 'IFG', 'OTC','Hippocampus'};
        batch.Setup.rois.files{1}{sub_idx} = gm_path_subj; % GM
        batch.Setup.rois.files{2}{sub_idx} = wm_path_subj; % WM
        batch.Setup.rois.files{3}{sub_idx} = csf_path_subj; % CSF
        batch.Setup.rois.files{4}{sub_idx} = lvifg_mask_path; % IFG (same file for all subjects)
        batch.Setup.rois.files{5}{sub_idx} = rotc_mask_path; % OTC (same file for all subjects)
        batch.Setup.rois.files{6}{sub_idx} = hippo_mask_path; % Hippocampus (same file for all subjects)
        batch.Setup.rois.multiplelabels = 0;
        batch.Setup.rois.dimensions = {1, 1, 1, 1, 1, 1};
       

    
  % Condition
    %% Condition setup - corrected version
    batch.Setup.conditions.names = {'rest'};
    for nsub = 1:numel(list_sub)
        for nses = 1:batch.Setup.nsessions
            % Get duration from this subject's data
            if nses == 1
                ses_field = 'ses_1';
            else
                ses_field = 'ses_02';
            end
            
            % Initialize onsets and durations for all subjects/sessions
            if nsub == 1 && nses == 1
                batch.Setup.conditions.onsets{1} = cell(1, numel(list_sub));
                batch.Setup.conditions.durations{1} = cell(1, numel(list_sub));
            end
            
            % Set onset to 0 and calculate duration based on RT and number of volumes
            batch.Setup.conditions.onsets{1}{nsub}{nses} = 0;
            
            % Use motion indices to get number of volumes (more reliable than CSF)
            if exist('motion_indices', 'var') && isfield(motion_indices, ses_field)
                batch.Setup.conditions.durations{1}{nsub}{nses} = batch.Setup.RT * motion_indices.(ses_field).table_length;
            else
                % Fallback to a default value if motion indices not available
                batch.Setup.conditions.durations{1}{nsub}{nses} = Inf; % or use a known value
            end
        end
    end
end

%% batch.Denoising
% Debug: Verify denoising settings
%Denoising steps for Debugging 
%Step 1/7: Expanding conditions - Sets up experimental conditions 
%Step 2/7: Importing conditions/covariates - Loads your regressors
%Step 3/7: Updating Denoising variables (where you're stuck) - Prepares denoising parameters
%Step 4/7: Creating Denoising design matrices - Builds the GLM model
%Step 5/7: Estimating Denoising parameters (conn_process_5) - Computes the actual denoising
%Step 6/7: Applying Denoising - Removes noise from data
%Step 7/7: Saving results - Stores cleaned data

% if you have problesm in Step 5/7 open conn_process for debugging (line
% 1096)
% this means ROIs where not created 
% line 657 Creates ROI_Subject###_Session###.mat files (activation timecourses for each roi)
%this means DATA_Subject was not created 
% open conn_process

% Denoising
batch.Denoising.done = 1;
batch.Denoising.overwrite = 1;
batch.Denoising.filter = [0.01 Inf];
batch.Denoising.detrending = 1;

batch.Denoising.confounds.names = batch.Setup.covariates.names;
%batch.Denoising.confounds.dimensions = batch.Setup.covariates.dimensions;
batch.Denoising.confounds.dimensions = {1, 1, numel(motion_indices.ses_1.indices),1};
% change derivative and power if needed 
batch.Denoising.confounds.deriv = {0, 0, 1, 0};
batch.Denoising.confounds.power = {0, 0, 2, 0};

%check if motion dimension match
motion_dims_setup = batch.Setup.covariates.dimensions{3};
motion_dims_denoise = batch.Denoising.confounds.dimensions{3};
if ~isequal(motion_dims_setup, motion_dims_denoise)
    error('Motion dimensions mismatch! Setup: %d vs Denoising: %d',...
        motion_dims_setup, motion_dims_denoise);
end

disp('--- Denoising Configuration ---');
disp(batch.Denoising)
disp('Confounds:');
disp(batch.Denoising.confounds)

% Check if denoising is actually enabled
if ~batch.Denoising.done
    warning('Denoising is set to done=0! Changing to done=1');
    batch.Denoising.done = 1;
end

%Verify filter settings
if isempty(batch.Denoising.filter) || ~all(isfinite(batch.Denoising.filter))
    warning('Invalid filter settings! Using default [0.01 Inf]');
    batch.Denoising.filter = [0.01 Inf];
end

%% because incorrect covariate specification is the most common error for silent failure add verification code
% Debug: Verify covariates
disp('--- Covariates Implementation ---');
for c = 1:numel(batch.Denoising.confounds.names)
    fprintf('Covariate %d (%s):\n', c, batch.Denoising.confounds.names{c});
    fprintf('Dimensions: %s\n', mat2str(batch.Denoising.confounds.dimensions{c}));
    fprintf('Derivatives: %d\n', batch.Denoising.confounds.deriv{c});
    fprintf('Powers: %d\n', batch.Denoising.confounds.power{c});
    
    % Verify files exist
    for s = 1:min(3,numel(list_sub)) % Check first 3 subjects
        if numel(batch.Setup.covariates.files) >= c && ...
           numel(batch.Setup.covariates.files{c}) >= s
            fprintf('Subject %d files exist: %d\n', s, ...
                exist(batch.Setup.covariates.files{c}{s}{1}, 'file'));
        end
    end
end

%% batch.Analysis
%% Analysis
% Analysis setup to run ALL steps
batch.Analysis.done = 1;
batch.Analysis.overwrite = 1;
batch.Analysis.measure = 1; % Correlation
batch.Analysis.type = 'all'; % Changed from 3 to 'ROI-to-ROI' for clarity
batch.Analysis.sources = {'IFG', 'OTC','Hippocampus'}; % Seed ROI % Empty for ROI-to-ROI analysis
batch.Analysis.ROI_files = {'GM', 'WM', 'CSF'}; % All ROIs for ROI-to-ROI

% ADD THESE TWO LINES RIGHT HERE:
batch.Analysis.save = 1; % Saves individual subject results
batch.Analysis.keep = 1; % Keeps temporary analysis files

% Set up the GUI interaction option for ROI-to-ROI analysis
batch.Analysis.gui = 1; % Enable GUI interaction
batch.Analysis.gui_prompt = 1; % Ask user on each step
batch.Analysis.name = 'SBC_MeMoSLAP_rest'; % Name for this analysis

% Additional analysis parameters
batch.Analysis.weight = 2; % Fisher-transformed correlation coefficients
batch.Analysis.modulation = 0; % No modulation
batch.Analysis.symmetric = 1; % Symmetric matrices
batch.Analysis.scale = 1; % Scale to correlation units


%% Save and run
batch_file = fullfile(root_conn,'conn_rsfmri_denoising.mat');
save(batch_file, 'batch');

% Display for debugging:
disp('--- Analysis Configuration ---');
disp(['Analysis type: ', batch.Analysis.type]);
disp(['GUI enabled: ', num2str(batch.Analysis.gui)]);
disp(['GUI prompts: ', num2str(batch.Analysis.gui_prompt)]);
disp(['ROIs included: ', strjoin(batch.Analysis.ROI_files, ', ')]);

% First run setup steps (0-5)
setup_batch = batch;
setup_batch.Analysis.done = 0; % Don't run analysis yet
conn_batch(setup_batch);

% Then run the ROI-to-ROI analysis with GUI interaction
analysis_batch = batch;
analysis_batch.Setup.done = 1; % Mark setup as already done
analysis_batch.Denoising.done = 1; % Mark denoising as already done
conn_batch(analysis_batch);


%% Clean up temporary files
% Move cleanup to the very end and add verification
try
    conn_batch(batch,'setup');
    % Verify processing completed successfully before cleanup

    % csv file path is saved in batch so don't delete
    %if exist(fullfile(root_conn,'conn_rsfmri.mat'), 'file')
    %    rmdir(temp_dir, 's');
    %end
catch ME
    warning('Keeping temp files for debugging due to error');
end

%% define functions
function [indices, csv_files] = get_indices_and_write_csv(Project, cov_path, subject_id, covariate_column, temp_dir)
    if strcmp(Project,'VerFlu')    
    sessions = {'ses-01', 'ses-02'};
    elseif strcmp(Project,'MeMoSLAP')
    sessions = {'ses-1', 'ses-2'};
    end
    
    
    indices = struct();
    csv_files = cell(1, numel(sessions));
    
    for i = 1:numel(sessions)
        ses = sessions{i};
        ses_field = strrep(ses, '-', '_');
        idx = contains(cov_path,ses);    
        confound_file = cov_path(idx);
        
        if exist(confound_file{1}, 'file')
            T = readtable(confound_file{1}, 'FileType', 'text', 'Delimiter', '\t');
            colnames = T.Properties.VariableNames;

            % Determine which columns to select
            if strcmp(covariate_column, 'motion')
                is_cov = startsWith(colnames, 'trans') | startsWith(colnames, 'rot');
                contains_deriv = contains(colnames, 'derivative') | contains(colnames, 'power') | contains(colnames, 'wm');
                select_cols = is_cov & ~contains_deriv;
            else
                is_cov = startsWith(colnames, covariate_column);
                contains_deriv = contains(colnames, 'derivative') | contains(colnames, 'power') | contains(colnames, 'wm');
                select_cols = is_cov & ~contains_deriv;
            end
            
            idx = find(select_cols);
            
            % Create filtered table with only selected columns
            filtered_table = T(:, idx);
            
            % Create CSV filename
            csv_filename = fullfile(temp_dir, sprintf('%s_%s_%s.csv', subject_id, ses, covariate_column));
            
            % Write to CSV
            writetable(filtered_table, csv_filename);
            fprintf('Created filtered CSV: %s\n', csv_filename);
            
            % Store CSV path for CONN
            csv_files{i} = csv_filename;
            
            % Check for NaN/Inf
            nan_or_inf = false(1, numel(idx));
            for j = 1:numel(idx)
                col_data = table2array(T(:, idx(j)));
                nan_or_inf(j) = any(isnan(col_data)) || any(isinf(col_data));
            end
            
            if any(nan_or_inf)
                fprintf('Session %s: WARNING: NaN or Inf detected in columns: %s\n', ...
                    ses, strjoin(colnames(idx(nan_or_inf)), ', '));
            end
            
            % Get table length from CSF column if available
            if ismember('csf', colnames)
                table_length = height(T);
            else
                table_length = NaN;
            end

            % Store indices
            indices.(ses_field).indices = idx;
            indices.(ses_field).names = colnames(idx);
            indices.(ses_field).nan_or_inf = nan_or_inf;
            indices.(ses_field).table_length = table_length;
            
        else
            warning('File not found: %s', confound_file);
            indices.(ses_field).indices = [];
            indices.(ses_field).names = {};
            indices.(ses_field).nan_or_inf = [];
            indices.(ses_field).table_length = NaN;
            csv_files{i} = '';
        end
    end
end
