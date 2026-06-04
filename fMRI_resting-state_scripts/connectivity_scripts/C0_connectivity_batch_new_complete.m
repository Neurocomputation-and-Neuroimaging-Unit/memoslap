% C0_connectivity_batch_new
% Batch script to compute connectivity matrices for a single subject/session.
% Connectivity matrices are saved in the current folder.
% Alternatively, use the CMs struct from the workspace for plotting and further processing.
function C0_connectivity_batch_new_complete(subject_id, session_id, analysis_switch, label, seed_ROI, prefix_func, atlas)

%#####################################################
%#################### INPUT ##########################
%#####################################################

% % User inputs — specify which subject and session to run
% subject_id = 2202;  % Enter subject number
% session_id = 1;     % Enter session number
% label = '_atlasPCC_DMN';  % set to '' to disable labeling of output

% SPM path
SPM_path = 'C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm12-main';
addpath(SPM_path);

% Scripts path
addpath('C:\Users\sreya\Documents\College\Internship_fMRI\Code\connectivity_scripts');

% % Toolboxes
% addpath('C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\GRETNA-2.0.0_release')

% Data source directory
src_dir = 'E:\memoslap\restingstate\nifti_bids';

% Construct subject and session identifiers from inputs
SJ      = sprintf('sub-%d', subject_id);
session = sprintf('ses-%02d', session_id);

% Define paths
ses_dir    = fullfile(src_dir, SJ, session);
run_dir    = fullfile(ses_dir, 'func');
struct_dir = fullfile(ses_dir, 'anat');

% Output directory - create connectivity parent folder in session directory
connectivity_dir = fullfile(ses_dir, 'connectivity');
if ~exist(connectivity_dir, 'dir')
    mkdir(connectivity_dir);
end
out_dir = connectivity_dir;  % Pass connectivity folder to analysis functions

% Get runs
cd(run_dir);
rd = dir([prefix_func 'ses-*bold.nii']);  % Find preprocessed functional files
if isempty(rd)
    error('No functional files found in %s. Check that .nii files are unzipped.', run_dir);
end
runs = {};
for r = 1:length(rd)
    % Strip prefix from filename to get base run name
    runs{r} = strrep(rd(r).name, prefix_func, '');
end

% Display info
fprintf('Analyzing Data\n')
fprintf('Subject:  %s\n', SJ)
fprintf('Session:  %s\n', session)
fprintf('Runs:\n')
for r = 1:length(runs)
    fprintf('  %s\n', runs{r})
end

% Specify filter for finding functional data
% This should match the final prefix after all preprocessing steps
% prefix_func = 's8wFh01l08_Rhclqg_m0.4ar';

% Specify full path to the ROI NIfTI file (atlas)
% atlas = 'C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm12-main\AAL3\AAL3v1.nii';

% Define brain mask — find the brain mask for MNI space
% gm_files = dir(fullfile(struct_dir, 'rc1*.nii'));
% if isempty(gm_files)
%     error('Resliced GM mask (rc1*.nii) not found in %s. Run preprocessing step 10 first.', struct_dir);
% end
brain_mask = 'C:\Users\sreya\Documents\College\Internship_fMRI\Data\brain_mask.nii';
% fprintf('Using brain mask: %s\n', brain_mask.name);

% % Selection of analysis steps to be performed
% % e.g. [1], [3], [1 2 3], etc.
% analysis_switch = [4 5];

%# step 0  Reslice ROI/mask files to MNI space (optional)
%  Use this if your seed ROI or any mask is not in MNI space
%  Add as many files as needed to the list
files_to_reslice = {
    'C:\Users\sreya\Documents\College\Internship_fMRI\Data\rois_sreya\PCC_roi_seed_for_DMN.nii'
    % 'C:\path\to\another\file.nii'   % add more files here if needed
};

%# step 1  Reslice atlas with ROIs
ref_run = 1;  % reference run used for reslicing

%# step 2  Cut functional data
segment_size    = 150;  % segment size in datapoints
segment_overlap = 0;    % overlap between segments in datapoints
segment_start   = 1;    % starting datapoint

%# step 3  ROI2ROI — calculate between-ROI functional connectivity
ROI_values = [1:170]';              % Atlas ROIs to include
ROI_values([35, 36, 81, 82]) = [];  % which ROIs of the atlas to exclude, empty in AAL3

%# step 4  Seed-based analysis (full-brain seed-based connectivity)
% Specify seed region based on atlas ROI indices or a file path, e.g.:
%   parahippocampus:  seed_ROI = [170, 171];
%   calcarine / V1:   seed_ROI = [108, 109];
%   vmPFC:            seed_ROI = [146,147,178,179,104,105,124,125,136,137];
%   from file:        seed_ROI = 'C:\...\seed_region.nii';
% seed_ROI = 'C:\Users\sreya\Documents\College\Internship_fMRI\Data\rois_sreya\rPCC_roi_seed_for_DMN.nii';
% seed_ROI = [39, 40];  % update as needed

%# step 5  Calculate ECMs (using fastECM)
ztransform  = 0;        % 1 = yes / 0 = no
smooth      = 1;        % 1 = yes / 0 = no
kernel_size = [6 6 6];

% %# step 6  Analysis of variation (within subject, over sessions)
% corr_matrix_folder = 'ROI2ROI_FC_AAL3v1';              % folder containing connectivity matrices
% corr_matrix_include = 'bold_sess';                     % identifier string to select which files to include
% rois = 166;                                            % number of ROIs in the connectivity matrix

%#####################################################
%#################### INPUT end ######################
%#####################################################

%% Step 0.1 — Reslice ROI/mask files to MNI space (optional)
if ismember(0.1, analysis_switch)
    % use first functional file as MNI reference
    ref_func_name = spm_select('List', run_dir, ['^' prefix_func runs{ref_run}]);
    ref_func = [run_dir filesep strtrim(ref_func_name(1,:)) ',1'];
    for fi = 1:length(files_to_reslice)
        fprintf('Reslicing to MNI space: %s\n', files_to_reslice{fi});
        V_file = spm_vol(files_to_reslice{fi});
        V_func = spm_vol(strtok(ref_func, ','));
        if any(V_file.dim ~= V_func(1).dim)
            B_reslice_masks_to_functional(ref_func, files_to_reslice(fi));
            [fp, fn, fe] = fileparts(files_to_reslice{fi});
            fprintf('Resliced file saved as: %s\n', fullfile(fp, ['r' fn fe]));
        else
            fprintf('Dimensions already match, no reslicing needed for: %s\n', files_to_reslice{fi});
        end
    end
end

%% Step 1 — Reslice atlas to match functional data
if ismember(1, analysis_switch)
    f = spm_select('List', run_dir, ['^' prefix_func runs{ref_run}]);
    if isempty(f)
        error('No functional file found in %s matching prefix "%s" and run "%s".', ...
              run_dir, prefix_func, runs{ref_run});
    end
    C1_check_reslice([run_dir filesep f], atlas);
end

%% Step 2 — Cut functional data into segments
if ismember(2, analysis_switch)
    C2_Cut_data_new(run_dir, runs, prefix_func, segment_size, segment_overlap, segment_start);
end

%% Step 3 — ROI2ROI functional connectivity
if ismember(3, analysis_switch)
    C3_ROI2ROI_conn_masked_new(SJ, runs, run_dir, prefix_func, atlas, ROI_values, label, out_dir);
end

%% Step 4 — Seed-based analysis
if ismember(4, analysis_switch)
    C4_ROI2voxel_conn_masked_new_nogretna(SJ, runs, run_dir, prefix_func, atlas, seed_ROI, brain_mask, label, out_dir);
end

%% Step 5 — Calculate ECM maps
if ismember(5, analysis_switch)
    C5_fast_ecm_new(SJ, runs, run_dir, prefix_func, brain_mask, ztransform, smooth, kernel_size, label, out_dir);
end

%% Step 6 — Within-subject variation (over sessions)
if ismember(6, analysis_switch)
    C6_interSJ_var_new(src_dir, SJ, session, corr_matrix_folder, corr_matrix_include, rois);
end

fprintf('\n========================================\n')
fprintf('Connectivity analysis complete!\n')
fprintf('Results saved to: %s\n', out_dir)
fprintf('========================================\n')

end
