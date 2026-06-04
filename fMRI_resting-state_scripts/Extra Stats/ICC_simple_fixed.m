% ICC_simple_fixed.m
clear all; clc;

addpath('C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm12-main');

% Load atlas once
atlas_file = ('C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm12-main\AAL3\AAL3v1.nii')
V_atlas  = spm_vol(atlas_file);
atlas_img = spm_read_vols(V_atlas);

%% INPUT
subject_ids = [2202, 2204, 2205, 2206, 2207, 2210, 2211, 2212, 2214, ...
               2216, 2217, 2219, 2220, 2221, 2222, 2223, 2225, 2226, 2227, ...
               2228, 2231, 2232, 2233, 2234, 2235, 2236, 2237, 2239, 2241, ...
               2242, 2243, 2246, 2247, 2248, 2250, 2252, 2254, 2255, 2256, 2257];
src_dir      = 'E:\memoslap\restingstate\nifti_bids';
fc_folder    = 'connectivity\ROI2ROI_FC_AAL3v1';
fc_include   = 'bold';
rois         = 166;
out_dir      = fullfile(src_dir, 'group_ICC');
if ~exist(out_dir,'dir'), mkdir(out_dir); end

n = length(subject_ids);

%% LOAD DATA: FC_all (n x 2ses x 2runs x rois x rois)
FC_all = NaN(n, 2, 2, rois, rois);
for s = 1:n
    SJ = sprintf('sub-%d', subject_ids(s));
    for ss = 1:2
        session  = sprintf('ses-%02d', ss);
        for r = 1:2
            run      = sprintf('run-%02d', r);
            ses_path = fullfile(src_dir, SJ, session, fc_folder);
            if ~exist(ses_path,'dir'), continue; end
            c = dir(fullfile(ses_path, ['*' fc_include '*' run '*.mat']));
            if isempty(c)
                c_all = dir(fullfile(ses_path, ['*' fc_include '*.mat']));
                if length(c_all) >= r, c = c_all(r); end
            end
            if isempty(c), continue; end
            d = load(fullfile(c(1).folder, c(1).name));
            if isfield(d,'CorrMat'), FC_all(s,ss,r,:,:) = d.CorrMat; end
        end
    end
end
fprintf('Loaded. FC_all size: [%s]\n', num2str(size(FC_all)));

mask = triu(true(rois), 1);

%% PART 1: BETWEEN-SESSION ICC
fprintf('Running Part 1: between-session ICC...\n')

icc_ses   = NaN(rois, rois);
ci_lo_ses = NaN(rois, rois);
ci_hi_ses = NaN(rois, rois);

for ri = 1:rois
    for rj = ri+1:rois
        ses1 = mean([FC_all(:,1,1,ri,rj), FC_all(:,1,2,ri,rj)], 2, 'omitnan');
        ses2 = mean([FC_all(:,2,1,ri,rj), FC_all(:,2,2,ri,rj)], 2, 'omitnan');
        Y = [ses1, ses2];
        ok = ~any(isnan(Y),2);
        Y = Y(ok,:);
        if size(Y,1) < 3, continue; end
        [rv, lb, ub] = ICC(Y, 'C-1');
        icc_ses(ri,rj)   = rv;
        ci_lo_ses(ri,rj) = lb;
        ci_hi_ses(ri,rj) = ub;
    end
end

% symmetrise: replace NaN with 0 before adding transpose
tmp = icc_ses;   tmp(isnan(tmp)) = 0;   icc_ses   = tmp + tmp' - diag(diag(tmp));
tmp = ci_lo_ses; tmp(isnan(tmp)) = 0;   ci_lo_ses = tmp + tmp' - diag(diag(tmp));
tmp = ci_hi_ses; tmp(isnan(tmp)) = 0;   ci_hi_ses = tmp + tmp' - diag(diag(tmp));

s_vals = icc_ses(mask); s_vals = s_vals(~isnan(s_vals));
fprintf('[SESSION ICC] N=%d  Mean=%.3f  Median=%.3f\n', numel(s_vals), mean(s_vals), median(s_vals))

V_atlas   = spm_vol('C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm12-main\AAL3\AAL3v1.nii');
atlas_img = spm_read_vols(V_atlas);

roi_icc_ses = NaN(rois, 1);
for ri = 1:rois
    vals = icc_ses(ri, :);
    vals(ri) = NaN;
    roi_icc_ses(ri) = mean(vals(~isnan(vals)));
end

icc_vol = zeros(size(atlas_img));
for ri = 1:rois
    icc_vol(atlas_img == ri) = roi_icc_ses(ri);
end

V_out        = V_atlas;
V_out.fname  = fullfile(out_dir, 'ICC_session_MNI.nii');
V_out.dt     = [spm_type('float32'), 0];
V_out.descrip = 'Mean session ICC per ROI';
spm_write_vol(V_out, icc_vol);
fprintf('Wrote MNI ICC map: %s\n', V_out.fname);

fprintf('  Excellent>0.75: %.1f%%  Good: %.1f%%  Moderate: %.1f%%  Poor: %.1f%%\n', ...
    100*mean(s_vals>0.75), 100*mean(s_vals>=0.6&s_vals<=0.75), ...
    100*mean(s_vals>=0.4&s_vals<0.6), 100*mean(s_vals<0.4))

%% PART 2: BETWEEN-RUN ICC per session
fprintf('Running Part 2: between-run ICC per session...\n')

% Use separate matrices instead of 3D array — avoids 3D assignment bug
icc_run_ses1   = NaN(rois,rois);  icc_run_ses2   = NaN(rois,rois);
ci_lo_run_ses1 = NaN(rois,rois);  ci_lo_run_ses2 = NaN(rois,rois);
ci_hi_run_ses1 = NaN(rois,rois);  ci_hi_run_ses2 = NaN(rois,rois);

for ss = 1:2
    icc_tmp   = NaN(rois,rois);
    ci_lo_tmp = NaN(rois,rois);
    ci_hi_tmp = NaN(rois,rois);

    for ri = 1:rois
        for rj = ri+1:rois
            Y = [FC_all(:,ss,1,ri,rj), FC_all(:,ss,2,ri,rj)];
            ok = ~any(isnan(Y),2);
            Y = Y(ok,:);
            if size(Y,1) < 3, continue; end
            [rv, lb, ub] = ICC(Y, 'C-1');
            icc_tmp(ri,rj)   = rv;
            ci_lo_tmp(ri,rj) = lb;
            ci_hi_tmp(ri,rj) = ub;
        end
    end

    % symmetrise
    tmp = icc_tmp;   tmp(isnan(tmp)) = 0;   icc_tmp   = tmp + tmp' - diag(diag(tmp));
    tmp = ci_lo_tmp; tmp(isnan(tmp)) = 0;   ci_lo_tmp = tmp + tmp' - diag(diag(tmp));
    tmp = ci_hi_tmp; tmp(isnan(tmp)) = 0;   ci_hi_tmp = tmp + tmp' - diag(diag(tmp));

    % store in separate matrices
    if ss == 1
        icc_run_ses1   = icc_tmp;
        ci_lo_run_ses1 = ci_lo_tmp;
        ci_hi_run_ses1 = ci_hi_tmp;
    else
        icc_run_ses2   = icc_tmp;
        ci_lo_run_ses2 = ci_lo_tmp;
        ci_hi_run_ses2 = ci_hi_tmp;
    end

    r_vals = icc_tmp(mask); r_vals = r_vals(~isnan(r_vals));
    %spm_write_vol - I want to put back the ICC values in the brain in mni
    %space so that I can visualise it as peaks in the brain 
    fprintf('[RUN ICC ses-%02d] N=%d  Mean=%.3f  Median=%.3f\n', ss, numel(r_vals), mean(r_vals), median(r_vals))

    % --- Write ICC map to MNI space NIfTI ---
    V_atlas  = spm_vol(atlas_file);          % reuse already-loaded atlas header
    atlas_img = spm_read_vols(V_atlas);      % atlas label volume
    
    % For each ROI, compute its mean ICC with all other ROIs
    roi_icc_mean = NaN(rois, 1);
    for ri = 1:rois
        vals = icc_tmp(ri, :);               % row = all connections of ROI ri
        vals(ri) = NaN;                      % exclude self
        roi_icc_mean(ri) = mean(vals(~isnan(vals)));
    end
    
    % Build a brain volume: assign mean ICC to each voxel by its AAL3 label
    icc_vol = zeros(size(atlas_img));
    for ri = 1:rois
        icc_vol(atlas_img == ri) = roi_icc_mean(ri);
    end
    
    % Write NIfTI using spm_write_vol
    V_out        = V_atlas;                  % copy header from atlas
    V_out.fname  = fullfile(out_dir, sprintf('ICC_run_ses%02d_MNI.nii', ss));
    V_out.dt     = [spm_type('float32'), 0];
    V_out.descrip = sprintf('Mean run ICC ses-%02d per ROI', ss);
    spm_write_vol(V_out, icc_vol);
    fprintf('Wrote MNI ICC map: %s\n', V_out.fname);
    fprintf('  Excellent>0.75: %.1f%%  Good: %.1f%%  Moderate: %.1f%%  Poor: %.1f%%\n', ...
        100*mean(r_vals>0.75), 100*mean(r_vals>=0.6&r_vals<=0.75), ...
        100*mean(r_vals>=0.4&r_vals<0.6), 100*mean(r_vals<0.4))
end

%% PART 3: POOLED RUN ICC
fprintf('Running Part 3: pooled run ICC...\n')

% Average the two session matrices directly
icc_pooled   = (icc_run_ses1   + icc_run_ses2)   / 2;
ci_lo_pooled = (ci_lo_run_ses1 + ci_lo_run_ses2) / 2;
ci_hi_pooled = (ci_hi_run_ses1 + ci_hi_run_ses2) / 2;

p_vals = icc_pooled(mask); p_vals = p_vals(~isnan(p_vals));
fprintf('[RUN ICC pooled] N=%d  Mean=%.3f  Median=%.3f\n', numel(p_vals), mean(p_vals), median(p_vals))
fprintf('  Excellent>0.75: %.1f%%  Good: %.1f%%  Moderate: %.1f%%  Poor: %.1f%%\n', ...
    100*mean(p_vals>0.75), 100*mean(p_vals>=0.6&p_vals<=0.75), ...
    100*mean(p_vals>=0.4&p_vals<0.6), 100*mean(p_vals<0.4))

%% SAVE
r1_vals = icc_run_ses1(mask); r1_vals = r1_vals(~isnan(r1_vals));
r2_vals = icc_run_ses2(mask); r2_vals = r2_vals(~isnan(r2_vals));

save(fullfile(out_dir,'ICC_sessions.mat'),       'icc_ses','ci_lo_ses','ci_hi_ses','s_vals');
save(fullfile(out_dir,'ICC_runs_ses1.mat'),       'icc_run_ses1','ci_lo_run_ses1','ci_hi_run_ses1','r1_vals');
save(fullfile(out_dir,'ICC_runs_ses2.mat'),       'icc_run_ses2','ci_lo_run_ses2','ci_hi_run_ses2','r2_vals');
save(fullfile(out_dir,'ICC_runs_pooled.mat'),     'icc_pooled','ci_lo_pooled','ci_hi_pooled','p_vals');

%% EXPORT SUMMARY TO CSV
% Get upper triangle indices
[row_idx, col_idx] = find(mask);

% Build table
T = table(...
    row_idx, col_idx, ...
    icc_ses(mask), ci_lo_ses(mask), ci_hi_ses(mask), ...
    icc_run_ses1(mask), ci_lo_run_ses1(mask), ci_hi_run_ses1(mask), ...
    icc_run_ses2(mask), ci_lo_run_ses2(mask), ci_hi_run_ses2(mask), ...
    icc_pooled(mask), ci_lo_pooled(mask), ci_hi_pooled(mask), ...
    'VariableNames', { ...
        'ROI_i', 'ROI_j', ...
        'ICC_session', 'CI_lo_session', 'CI_hi_session', ...
        'ICC_run_ses1', 'CI_lo_run_ses1', 'CI_hi_run_ses1', ...
        'ICC_run_ses2', 'CI_lo_run_ses2', 'CI_hi_run_ses2', ...
        'ICC_run_pooled', 'CI_lo_pooled', 'CI_hi_pooled' ...
    });

writetable(T, fullfile(out_dir, 'ICC_results.csv'));
fprintf('CSV saved to %s\n', fullfile(out_dir, 'ICC_results.csv'));

V_atlas   = spm_vol('C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm12-main\AAL3\AAL3v1.nii');
atlas_img = spm_read_vols(V_atlas);

roi_icc_pooled = NaN(rois, 1);
for ri = 1:rois
    vals = icc_pooled(ri, :);
    vals(ri) = NaN;
    roi_icc_pooled(ri) = mean(vals(~isnan(vals)));
end

icc_vol = zeros(size(atlas_img));
for ri = 1:rois
    icc_vol(atlas_img == ri) = roi_icc_pooled(ri);
end

V_out        = V_atlas;
V_out.fname  = fullfile(out_dir, 'ICC_run_pooled_MNI.nii');
V_out.dt     = [spm_type('float32'), 0];
V_out.descrip = 'Mean run ICC pooled per ROI';
spm_write_vol(V_out, icc_vol);
fprintf('Wrote MNI ICC map: %s\n', V_out.fname);

fprintf('Done. Results saved to %s\n', out_dir)

%% ROI-LEVEL ICC (one value per ROI, like SPL/S1 reporting style)

roi_files = {
    'E:\memoslap\restingstate\rois_sreya\earlyWM_rS2.nii';
    'E:\memoslap\restingstate\rois_sreya\lateWM_lSPL_spmClust.nii';
    'E:\memoslap\restingstate\rois_sreya\lateWM_rSPL_spmClust.nii';
    'E:\memoslap\restingstate\rois_sreya\rPCC_roi_seed_for_DMN.nii'
};
roi_names = {'earlyWM_rS2', 'lateWM_lSPL', 'earlyWM_rSPL', 'rPCC_DMN'};

results = struct();

%% ROI-LEVEL ICC (one value per ROI, like SPL/S1 reporting style)
roi_files = {
    'E:\memoslap\restingstate\rois_sreya\earlyWM_rS2.nii';
    'E:\memoslap\restingstate\rois_sreya\lateWM_lSPL_spmClust.nii';
    'E:\memoslap\restingstate\rois_sreya\lateWM_rSPL_spmClust.nii';
    'E:\memoslap\restingstate\rois_sreya\rPCC_roi_seed_for_DMN.nii'
};
roi_names = {'earlyWM_rS2', 'lateWM_lSPL', 'earlyWM_rSPL', 'rPCC_DMN'};

results = struct();

for k = 1:length(roi_files)
    V_roi    = spm_vol(roi_files{k});
    roi_img  = spm_read_vols(V_roi);
    roi_mask = roi_img > 0;
    overlapping_labels = unique(atlas_img(roi_mask));
    aal_idx  = overlapping_labels(overlapping_labels > 0);

    fprintf('\nROI: %s → AAL3 indices: %s\n', roi_names{k}, num2str(aal_idx'));

    icc_vals   = [];
    ci_lo_vals = [];
    ci_hi_vals = [];
    for q = 1:length(aal_idx)
        ri = aal_idx(q);
        row_icc = icc_ses(ri, :);   row_icc(ri)   = NaN;
        row_lo  = ci_lo_ses(ri, :); row_lo(ri)    = NaN;
        row_hi  = ci_hi_ses(ri, :); row_hi(ri)    = NaN;
        icc_vals   = [icc_vals,   row_icc];
        ci_lo_vals = [ci_lo_vals, row_lo];
        ci_hi_vals = [ci_hi_vals, row_hi];
    end

    valid      = ~isnan(icc_vals);
    icc_vals   = icc_vals(valid);
    ci_lo_vals = ci_lo_vals(valid);
    ci_hi_vals = ci_hi_vals(valid);

    % mean and its CI
    icc_mean    = mean(icc_vals);
    ci_lo_mean  = mean(ci_lo_vals);
    ci_hi_mean  = mean(ci_hi_vals);

    % max and its CI
    [icc_max, max_idx] = max(icc_vals);
    ci_lo_max   = ci_lo_vals(max_idx);
    ci_hi_max   = ci_hi_vals(max_idx);

    fprintf('  Mean ICC = %.3f, 95%% CI [%.3f, %.3f]\n', icc_mean, ci_lo_mean, ci_hi_mean);
    fprintf('  Max ICC  = %.3f, 95%% CI [%.3f, %.3f]\n', icc_max,  ci_lo_max,  ci_hi_max);

    results(k).name      = roi_names{k};
    results(k).icc_mean  = icc_mean;
    results(k).ci_lo_mean = ci_lo_mean;
    results(k).ci_hi_mean = ci_hi_mean;
    results(k).icc_max   = icc_max;
    results(k).ci_lo_max = ci_lo_max;
    results(k).ci_hi_max = ci_hi_max;
end

%% Save as CSV
T_roi = table(...
    {results.name}', ...
    [results.icc_mean]', [results.ci_lo_mean]', [results.ci_hi_mean]', ...
    [results.icc_max]',  [results.ci_lo_max]',  [results.ci_hi_max]', ...
    'VariableNames', {'ROI', 'ICC_mean', 'CI_lo_mean', 'CI_hi_mean', ...
                             'ICC_max',  'CI_lo_max',  'CI_hi_max'});

writetable(T_roi, fullfile(out_dir, 'ICC_ROI_level.csv'));
fprintf('\nROI-level ICC saved to %s\n', fullfile(out_dir, 'ICC_ROI_level.csv'));