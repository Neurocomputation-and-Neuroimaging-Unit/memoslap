% ttest_2ndlevel_runs.m
% Second-level paired t-test comparing FC correlation maps between runs/sessions.
% Change only the four lines under INPUT to switch between comparisons.

clear all; clc;

%% ========================= INPUT =========================================

subject_ids = [2202, 2204, 2205, 2206, 2207, 2210, 2211, 2212, 2214, 2215, ...
               2216, 2217, 2218, 2219, 2220, 2221, 2223, 2225, 2226, 2227, ...
               2228, 2229, 2230];

src_dir     = 'E:\memoslap\restingstate\nifti_bids';
conn_folder = 'ROI2voxel_FC_rPCC_roi_seed_for_DMN';

% SPM path
SPM_path = 'C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm12-main';
addpath(SPM_path);

% --- CHANGE THESE LINES FOR EACH COMPARISON ------------------------------
%
%  Comparisons to run:
%   Run 1 ses-01 vs Run 1 ses-02  ->  ses_A='ses-01', run_A='run-01', ses_B='ses-02', run_B='run-01'
%   Run 2 ses-01 vs Run 2 ses-02  ->  ses_A='ses-01', run_A='run-02', ses_B='ses-02', run_B='run-02'
%   Run 1 vs Run 2 within ses-01  ->  ses_A='ses-01', run_A='run-01', ses_B='ses-01', run_B='run-02'
%   Run 1 vs Run 2 within ses-02  ->  ses_A='ses-02', run_A='run-01', ses_B='ses-02', run_B='run-02'
%   Avg ses-01 vs Avg ses-02      ->  ses_A='ses-01', run_A='avg',    ses_B='ses-02', run_B='avg'

ses_A = 'ses-01';  run_A = 'run-01';   % Group A (scan 1)
ses_B = 'ses-02';  run_B = 'run-01';   % Group B (scan 2)

out_dir = ['E:\memoslap\restingstate\2nd_level\' ses_A '_' run_A '_vs_' ses_B '_' run_B];

% =========================================================================

%% Build scan lists
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

scans_A = {};
scans_B = {};

for s = 1:length(subject_ids)
    SJ = sprintf('sub-%d', subject_ids(s));

    if strcmp(run_A, 'avg')
        fA = avg_maps(src_dir, SJ, ses_A, conn_folder, out_dir);
    else
        fA = get_corrmap(src_dir, SJ, ses_A, run_A, conn_folder);
    end

    if strcmp(run_B, 'avg')
        fB = avg_maps(src_dir, SJ, ses_B, conn_folder, out_dir);
    else
        fB = get_corrmap(src_dir, SJ, ses_B, run_B, conn_folder);
    end

    if isempty(fA) || isempty(fB)
        fprintf('WARNING: skipping %s — file missing\n', SJ);
        continue;
    end

    scans_A{end+1} = [fA ',1'];
    scans_B{end+1} = [fB ',1'];
end

fprintf('Running paired t-test on %d subjects.\n', length(scans_A));

%% SPM paired t-test
matlabbatch{1}.spm.stats.factorial_design.dir                             = {out_dir};
matlabbatch{1}.spm.stats.factorial_design.des.pt.scans1                   = scans_A';
matlabbatch{1}.spm.stats.factorial_design.des.pt.scans2                   = scans_B';
matlabbatch{1}.spm.stats.factorial_design.des.pt.gmsca                    = 0;
matlabbatch{1}.spm.stats.factorial_design.des.pt.ancova                   = 0;
matlabbatch{1}.spm.stats.factorial_design.cov                             = struct('c',{},'cname',{},'iCFI',{},'iCC',{});
matlabbatch{1}.spm.stats.factorial_design.multi_cov                       = struct('files',{},'iCFI',{},'iCC',{});
matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none              = 1;
matlabbatch{1}.spm.stats.factorial_design.masking.im                      = 1;
matlabbatch{1}.spm.stats.factorial_design.masking.em                      = {''};
matlabbatch{1}.spm.stats.factorial_design.globalc.g_omit                  = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_no          = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm                 = 1;

fprintf('Specifying GLM...\n');
spm_jobman('run', matlabbatch);
clear matlabbatch;

%% Model estimation
matlabbatch{1}.spm.stats.fmri_est.spmmat = {fullfile(out_dir, 'SPM.mat')};

fprintf('Estimating GLM...\n');
spm_jobman('run', matlabbatch);
clear matlabbatch;

fprintf('Done: %s_%s  vs  %s_%s\n', ses_A, run_A, ses_B, run_B);

%% ========================= HELPER FUNCTIONS ==============================

function f = get_corrmap(src_dir, SJ, ses_label, run_label, conn_folder)
    conn_dir = fullfile(src_dir, SJ, ses_label, 'connectivity', conn_folder);
    hits     = dir(fullfile(conn_dir, sprintf('corrMap_*%s*.nii', run_label)));
    if isempty(hits)
        hits = dir(fullfile(conn_dir, 'corrMap_*.nii'));
    end
    if isempty(hits)
        warning('No corrMap found for %s %s %s', SJ, ses_label, run_label);
        f = '';
    else
        f = fullfile(hits(1).folder, hits(1).name);
    end
end

function avg_file = avg_maps(src_dir, SJ, ses_label, conn_folder, out_dir)
    f1 = get_corrmap(src_dir, SJ, ses_label, 'run-01', conn_folder);
    f2 = get_corrmap(src_dir, SJ, ses_label, 'run-02', conn_folder);
    if isempty(f1) || isempty(f2)
        avg_file = '';
        return;
    end
    avg_dir = fullfile(out_dir, 'avg_maps');
    if ~exist(avg_dir, 'dir'), mkdir(avg_dir); end

    avg_file = fullfile(avg_dir, sprintf('avg_%s_%s.nii', SJ, ses_label));

    matlabbatch{1}.spm.util.imcalc.input      = {f1; f2};
    matlabbatch{1}.spm.util.imcalc.output     = avg_file;
    matlabbatch{1}.spm.util.imcalc.outdir     = {''};
    matlabbatch{1}.spm.util.imcalc.expression = '(i1 + i2) / 2';
    matlabbatch{1}.spm.util.imcalc.options.dmtx  = 0;
    matlabbatch{1}.spm.util.imcalc.options.mask  = 0;
    matlabbatch{1}.spm.util.imcalc.options.interp = 1;
    matlabbatch{1}.spm.util.imcalc.options.dtype  = 16; % float32
    spm_jobman('run', matlabbatch);
end