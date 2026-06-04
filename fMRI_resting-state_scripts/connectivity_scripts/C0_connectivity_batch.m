% function C0_connectivity_batch

% This is a Batch-Script to compute connectivity matrices for all subjects
% The pre-processed data for each run is taken individually
% connectivity matrices are saved in the current folder
% Alternatively one can use the CMs struct from the workspace for plotting
% and further processing

clc
% clear all
close all
addpath('C:\Users\saraw\Desktop\BIDS\fMRI_resting-state_BAUSTELLE-main')
%#####################################################
%#################### INPUT ##########################
%#####################################################

%SPM-path
SPM_path  = 'C:\Users\saraw\Desktop\BA\EXPRA2019_HIVR\Toolboxes\spm12';
addpath(SPM_path);
addpath(genpath('C:\Users\saraw\Desktop\BA\EXPRA2019_HIVR\Toolboxes\hMRI-toolbox-0.4.0'))

%data source directory
src_dir      = 'C:\Users\saraw\Desktop\BIDS\test11';

%subject identifiers
cd(src_dir)
pb=dir('sub*');
for i=1:length(pb)
    SJs(1,i)={pb(i).name};
end

excludeSJ = []; % zb. unvollständige datensätze

%session & run identifiers
sessNum = 0;
if exist([src_dir filesep SJs{1} filesep 'ses-1'])==7
    cd([src_dir filesep SJs{1}])
    sd = dir('ses*')
    sessNum = length(sd);
    for sess = 1:sessNum
        sessions(1, sess) = {sd(sess).name};
    end
    for sb = 1:numel(SJs)
        cd([src_dir filesep SJs{sb} filesep sessions{1} filesep 'func']);
        rd = dir('sub*.nii')
        for r = 1:length(rd)
            runs(sb, r) = {rd(r).name};
        end
    end
else
    for sb = 1:numel(SJs)
        cd([src_dir filesep SJs{sb} filesep 'func']);
        rd = dir('sub*.nii')
        for r = 1:length(rd)
            runs(sb, r) = {rd(r).name};
        end
    end
end

%specify filter for finding functional data
prefix_func='wFh01l08_Rhclqg_m0.4ar';

% specify full path to the ROI NIFTI file (atlas)
% L:\Arbeit\Dropbox\Matlab-toolbox\spm12\tpm\labels_Neuromorphometrics.nii
atlas = 'C:\Users\saraw\Desktop\BA\EXPRA2019_HIVR\Toolboxes\spm12\toolbox\AAL3\AAL3v1.nii'; %full path

%define grey matter mask
gm_mask= 'C:\Users\saraw\Desktop\BIDS\test11\brain_mask.nii';

% selection of analysis steps to be performed
analysis_switch = [6];

%# step 1  reslice atlas with ROIs
%  choose reference subject and run (used only for reslicing)
    ref_sub=1;
    ref_run=1;
    
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
seed_ROI='C:\Users\saraw\Desktop\BA\EXPRA2019_HIVR\Toolboxes\spm12\toolbox\Anatomy\PMaps\PSC_2.nii';

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
if ismember(1,analysis_switch)
    %specify subject and run
    if sessNum > 0 && exist([src_dir filesep SJs{ref_sub} filesep 'ses-1' filesep 'func'])
        for ses = 1:sessNum
            sub_run_path= [src_dir filesep SJs{ref_sub} filesep 'ses-' num2str(ses) filesep 'func'];
            f = spm_select('List', sub_run_path, ['^' prefix_func runs{ref_sub, ref_run} ]);
            C1_check_reslice([sub_run_path filesep f], atlas);
        end
    else
         sub_run_path= [src_dir filesep SJs{ref_sub} filesep 'ses-' num2str(ses) filesep 'func'];
         f = spm_select('List', sub_run_path, ['^' prefix_func runs{ref_sub, ref_run} ]);
         C1_check_reslice([sub_run_path filesep f], atlas);
    end
end

%% Cut Data
if ismember(2,analysis_switch)
    C2_Cut_data(src_dir,SJs,runs,prefix_func,segment_size,segment_overlap,segment_start,sessNum);
end

%% ROI2ROI functional connectivity
if ismember(3,analysis_switch)
    C3_ROI2ROI_conn_masked(SJs,runs,src_dir,prefix_func,atlas,ROI_values,sessNum,sess_wise);
end

%% seed-based analysis
if ismember(4,analysis_switch)
    C4_ROI2voxel_conn_masked(SJs,runs,src_dir,prefix_func,atlas,seed_ROI,gm_mask,sessNum);
end

%% calculate ECM maps
if ismember(5,analysis_switch)
    C5_fast_ecm(SJs,runs,src_dir,prefix_func,gm_mask,ztransform,smooth,kernel_size,sessNum);
end

%% within-SJ variation (over session)
if ismember(6,analysis_switch)
    C6_interSJ_var(src_dir,SJs,corr_matrix_folder,corr_matrix_include,sessNum,rois);
end

