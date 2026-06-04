clear all; clc;

%% ========================= INPUT =========================================
subject_ids = [2202, 2204, 2205, 2206, 2207, 2210, 2211, 2212, 2214, ...
               2216, 2217, 2219, 2220, 2221, 2222, 2223, 2225, 2226, 2227, ...
               2228, 2231, 2232, 2233, 2234, 2235, 2236, 2237, 2231, 2241, 2242, 2243, 2246, 2247, 2248, 2250, 2252, 2254, 2255, 2256, 2257];

src_dir    = 'E:\memoslap\restingstate\nifti_bids';
output_dir = 'E:\memoslap\restingstate\2ndLevel\2ndLevel_FlexFact_Interaction_earlyWM_rS2_spmClust';
conn_folder = 'ROI2voxel_FC_earlyWM_rS2_spmClust';

SPM_path = 'C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm12-main';
addpath(SPM_path);

%% ========================= SETUP =========================================
SJin     = arrayfun(@(id) sprintf('sub-%d', id), subject_ids, 'UniformOutput', false);
sessions = {'ses-01', 'ses-02'};
runs     = {'run-01', 'run-02'};

% Create output directory if it doesn't exist
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% ========================= FACTORIAL DESIGN ==============================
matlabbatch{1}.spm.stats.factorial_design.dir = {output_dir};

% Factor 1: Subject (independent)
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(1).name     = 'Subject';
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(1).dept     = 0;
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(1).variance = 0;
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(1).gmsca    = 0;
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(1).ancova   = 0;

% Factor 2: Session (dependent)
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(2).name     = 'Session';
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(2).dept     = 1;
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(2).variance = 0;
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(2).gmsca    = 0;
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(2).ancova   = 0;

% Factor 3: Run (dependent)
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(3).name     = 'Run';
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(3).dept     = 1;
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(3).variance = 0;
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(3).gmsca    = 0;
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(3).ancova   = 0;

%% ========================= PER-SUBJECT SCAN LIST =========================
% 4 conditions per subject:
%   cond 1 = ses-01 / run-01
%   cond 2 = ses-01 / run-02
%   cond 3 = ses-02 / run-01
%   cond 4 = ses-02 / run-02

for sj = 1:numel(SJin)

    fNames = {};
    conds  = [];

    for se = 1:numel(sessions)
        for ru = 1:numel(runs)

            scan_dir = fullfile(src_dir, SJin{sj}, sessions{se}, ...
                                'connectivity', conn_folder);

            % Match corrMap file containing the specific run tag
            filt = sprintf('corrMap_.*%s.*\\.nii$', runs{ru});
            f    = spm_select('List', scan_dir, filt);

            if isempty(f)
                error('No corrMap file found for %s %s %s in:\n  %s', ...
                      SJin{sj}, sessions{se}, runs{ru}, scan_dir);
            end

            fs     = [strtrim(fullfile(scan_dir, f)) ',1'];
            fNames = [fNames; {fs}];

            % conds: one row per scan, [session_level, run_level]
            conds  = [conds; se ru];

        end
    end

    matlabbatch{1}.spm.stats.factorial_design.des.fblock.fsuball.fsubject(sj).scans = fNames;
    matlabbatch{1}.spm.stats.factorial_design.des.fblock.fsuball.fsubject(sj).conds = conds;

end

%% ========================= MAIN EFFECTS ==================================
matlabbatch{1}.spm.stats.factorial_design.des.fblock.maininters{1}.fmain.fnum = 1; % Subject
%matlabbatch{1}.spm.stats.factorial_design.des.fblock.maininters{2}.fmain.fnum = 2; % Session
%matlabbatch{1}.spm.stats.factorial_design.des.fblock.maininters{3}.fmain.fnum = 3; % Run
matlabbatch{1}.spm.stats.factorial_design.des.fblock.maininters{2}.inter.fnums = [2 3]; % Interaction
%% ========================= MASKING / SCALING =============================
matlabbatch{1}.spm.stats.factorial_design.cov       = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
matlabbatch{1}.spm.stats.factorial_design.multi_cov = struct('files', {}, 'iCFI', {}, 'iCC', {});
matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1;
matlabbatch{1}.spm.stats.factorial_design.masking.im         = 1;
matlabbatch{1}.spm.stats.factorial_design.masking.em         = {''};
matlabbatch{1}.spm.stats.factorial_design.globalc.g_omit     = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm    = 1;

%% ========================= MODEL ESTIMATION ==============================
matlabbatch{2}.spm.stats.fmri_est.spmmat           = {fullfile(output_dir, 'SPM.mat')};
matlabbatch{2}.spm.stats.fmri_est.write_residuals  = 0;
matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

%% ========================= RUN ===========================================
spm('defaults', 'FMRI');
spm_jobman('run', matlabbatch);
clear matlabbatch