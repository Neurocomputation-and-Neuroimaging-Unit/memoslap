% function C0_connectivity_batch
% This is a Batch-Script to compute connectivity matrices for all subjects
% The pre-processed data for each run is taken individually
% connectivity matrices are saved in the current folder
% Alternatively one can use the CMs struct from the workspace for plotting
% and further processing
clc
% clear all
close all

%#####################################################
%#################### INPUT ##########################
%#####################################################
% User inputs - similar to preprocessing pipeline
subject_id = 2202;  % Enter subject number
session_id = 2;     % Enter session number

% SPM-path
SPM_path = 'C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm12-main';
addpath(SPM_path);

% data source directory and scripts
src_dir = 'C:\Users\sreya\Documents\College\Internship_fMRI\Data';
addpath(('C:\Users\sreya\Documents\College\Internship_fMRI\Code\preproc_scripts'));

% Construct subject and session identifiers from inputs
SJ = sprintf('sub-%d', subject_id);
session = sprintf('ses-%02d', session_id);

% Define paths
ses_dir = fullfile(src_dir, SJ, session);
run_dir = fullfile(ses_dir, 'func');
struct_dir = fullfile(ses_dir, 'anat');

% Get runs
cd(run_dir);
rd = dir('ses-*.nii');  % Find all functional files
for r = 1:length(rd)
    runs{r} = rd(r).name;
end

% Display info
fprintf('Analyzing Data\n')
fprintf('Subject: %s \n', SJ)
fprintf('Session: %s \n', session)
fprintf('Runs: \n')
for r = 1:length(runs)
    fprintf('%s \n', runs{r})
end

% specify filter for finding functional data
% This should match the final prefix after all your preprocessing steps
prefix_func = 's8wFh01l08_Rhclqg_m0.4ar';

% specify full path to the ROI NIFTI file (atlas)
atlas = 'C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm12-main\AAL3\AAL3v1.nii';

% define grey matter mask - find the resliced GM mask from step 10
gm_files = dir(fullfile(struct_dir, 'rc1*.nii'));
if isempty(gm_files)
    error('Resliced GM mask (rc1*.nii) not found in %s', struct_dir);
end
gm_mask = fullfile(struct_dir, gm_files(1).name);
fprintf('Using GM mask: %s\n', gm_files(1).name);

% selection of analysis steps to be performed
analysis_switch = [1];

% step 1 reslice atlas with ROIs
% choose reference subject and run (used only for reslicing)
ref_run = 1;

%# step 2 Cut functional data    
    %specify segment size
    segment_size=150;  % in datapoints
    segment_overlap=0; % in datapoints
    segment_start=1;
    
%# step 3  ROI2ROI, calculate between-ROI functional connectivity
%  specify which ROIs of the atlas to include
    ROI_values = [1:166]';
    sess_wise = 1;          %one analysis per session instead of per sj? actually recommended so you don't overwrite everything...

%# step 4  seed-based analysis (for full-brain seed-based connectivity)
%  specify seed-region based on atlas-regions or file
%
%  e.g. for labels_Neuromorphometrics.nii
%  parahippocampus:  seed_ROI=[170, 171];
%  calcarine sulcus / V1: seed_ROI=[108, 109];
%  vmPFC: seed_ROI=[146,147,178,179,104,105,124,125,136,137];
%
%  or specify file: e.g. seed_ROI='H:\Ganzfeld\Data\ECM_flexFact_fastECM_Fh01l08_Rhclq_sm0.4wrax3f4d\seed_Pcun_ECM_pre_vs_ganz.nii';
%seed_ROI='C:\Users\saraw\Desktop\BA\EXPRA2019_HIVR\Toolboxes\spm12\toolbox\Anatomy\PMaps\PSC_2.nii';

%# step 5  calculate ECMs (using fastECM)
ztransform=0;   % 1=yes / 0=no
smooth=1;       % 1=yes / 0=no
kernel_size = [6 6 6];

%# step 6 analysis of varation (within sj, over session)
corr_matrix_folder = ['ROI2ROI_FC_AAL3v1_sess_wise'];    %specify path to folder with corr_matrices
corr_matrix_include = 'bold_sess'; %fast version: just put in an identifyer for which files you want to include
rois = 166; %number of rois in corr_matrix

%#####################################################
%#################### INPUT end ######################
%#####################################################

%% reslice the atlas to match functional data, if necessary
if ismember(1, analysis_switch)
    % Use the already-constructed run_dir path for the reference run
    f = spm_select('List', run_dir, ['^' prefix_func runs{ref_run}]);
    if isempty(f)
        error('No functional file found in %s matching prefix %s', run_dir, prefix_func);
    end
    C1_check_reslice([run_dir filesep f], atlas);
end

%% Cut Data
if ismember(2,analysis_switch)
    C2_Cut_data(src_dir,SJ,runs,prefix_func,segment_size,segment_overlap,segment_start,sessNum);
end
