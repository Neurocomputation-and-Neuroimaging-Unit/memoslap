% C7_ICC_reliability.m
clear all; clc;

%#####################################################
%#################### INPUT ##########################
%#####################################################
subject_ids     = [2202, 2204, 2205, 2206, 2207, 2210, 2211, 2212, 2214, 2216, 2217, 2219, 2220, 2221, 2223, 2225, 2226, 2227, 2228, 2231, 2232, 2233, 2234, 2235, 2236, 2237, 2239, 2241, 2242, 2243, 2248, 2252, 2254, 2255, 2257];
src_dir         = 'E:\memoslap\restingstate\nifti_bids';
fc_folder       = 'connectivity\ROI2ROI_FC_AAL3v1';
fc_include      = 'bold';
sessions        = [1, 2];
rois            = 166;
icc_threshold   = 0.6;
out_dir         = fullfile(src_dir, 'group_ICC');
%#####################################################

n     = length(subject_ids);
n_ses = length(sessions);

if ~exist(out_dir, 'dir'), mkdir(out_dir); end

fprintf('\n========================================================\n')
fprintf('ICC RELIABILITY ANALYSIS\n')
fprintf('Subjects: %d | Sessions: %d | ROIs: %d\n', n, n_ses, rois)
fprintf('Output: %s\n', out_dir)
fprintf('========================================================\n')

%% ============================================================
%  PART 1: ACROSS-SESSION ICC
%% ============================================================
fprintf('\n--- PART 1: Across-session ICC ---\n')

FC_ses = NaN(n, n_ses, rois, rois);

for s = 1:n
    SJ = sprintf('sub-%d', subject_ids(s));
    for ss = 1:n_ses
        session  = sprintf('ses-%02d', sessions(ss));
        ses_path = fullfile(src_dir, SJ, session, fc_folder);
        if ~exist(ses_path, 'dir'), continue; end
        c = dir(fullfile(ses_path, ['*' fc_include '*.mat']));
        if isempty(c), continue; end
        run_stack = NaN(length(c), rois, rois);
        for f = 1:length(c)
            d = load(fullfile(c(f).folder, c(f).name));
            if isfield(d, 'CorrMat')
                run_stack(f,:,:) = d.CorrMat;
            end
        end
        FC_ses(s, ss, :, :) = squeeze(mean(run_stack, 1, 'omitnan'));
    end
end

for ss = 1:n_ses
    n_loaded = sum(~isnan(squeeze(FC_ses(:,ss,1,2))));
    fprintf('Session %d: %d/%d subjects loaded\n', sessions(ss), n_loaded, n);
end

% ICC across sessions
icc_ses   = NaN(rois, rois);
ci_lo_ses = NaN(rois, rois);
ci_hi_ses = NaN(rois, rois);

fprintf('Computing session ICC...\n')
for i = 1:rois
    for j = i+1:rois
        Y     = squeeze(FC_ses(:, :, i, j));
        valid = ~any(isnan(Y), 2);
        Y     = Y(valid, :);
        if size(Y,1) < 3, continue; end
        if size(Y,2) < 2, continue; end
        try
            [r, LB, UB]    = ICC(Y, 'A-1');
            icc_ses(i,j)   = r;
            ci_lo_ses(i,j) = LB;
            ci_hi_ses(i,j) = UB;
        catch
        end
    end
end

% Symmetrise
icc_ses   = icc_ses   + icc_ses'   - diag(diag(icc_ses));
ci_lo_ses = ci_lo_ses + ci_lo_ses' - diag(diag(ci_lo_ses));
ci_hi_ses = ci_hi_ses + ci_hi_ses' - diag(diag(ci_hi_ses));

% Report
icc_s_vals = icc_ses(triu(true(rois),1));
icc_s_vals = icc_s_vals(~isnan(icc_s_vals));
fprintf('\n[SESSIONS] ICC Summary (n=%d pairs)\n', numel(icc_s_vals))
fprintf('  Mean ICC:          %.3f\n', mean(icc_s_vals))
fprintf('  Median ICC:        %.3f\n', median(icc_s_vals))
fprintf('  Excellent >0.75:   %d (%.1f%%)\n', sum(icc_s_vals>0.75),                        100*mean(icc_s_vals>0.75))
fprintf('  Good   0.6-0.75:   %d (%.1f%%)\n', sum(icc_s_vals>=0.6 & icc_s_vals<=0.75),     100*mean(icc_s_vals>=0.6 & icc_s_vals<=0.75))
fprintf('  Moderate 0.4-0.6:  %d (%.1f%%)\n', sum(icc_s_vals>=0.4 & icc_s_vals<0.6),       100*mean(icc_s_vals>=0.4 & icc_s_vals<0.6))
fprintf('  Poor    <0.4:      %d (%.1f%%)\n', sum(icc_s_vals<0.4),                          100*mean(icc_s_vals<0.4))

%% ============================================================
%  PART 2: ACROSS-RUN ICC (within each session)
%% ============================================================
fprintf('\n--- PART 2: Across-run ICC (per session) ---\n')

icc_run   = NaN(n_ses, rois, rois);
ci_lo_run = NaN(n_ses, rois, rois);
ci_hi_run = NaN(n_ses, rois, rois);

for ss = 1:n_ses
    session = sprintf('ses-%02d', sessions(ss));
    fprintf('Computing run ICC for %s...\n', session)

    max_runs = 0;
    for s = 1:n
        SJ       = sprintf('sub-%d', subject_ids(s));
        ses_path = fullfile(src_dir, SJ, session, fc_folder);
        c        = dir(fullfile(ses_path, ['*' fc_include '*.mat']));
        max_runs = max(max_runs, length(c));
    end

    FC_run = NaN(n, max_runs, rois, rois);

    for s = 1:n
        SJ       = sprintf('sub-%d', subject_ids(s));
        ses_path = fullfile(src_dir, SJ, session, fc_folder);
        if ~exist(ses_path, 'dir'), continue; end
        c = dir(fullfile(ses_path, ['*' fc_include '*.mat']));
        for f = 1:length(c)
            d = load(fullfile(c(f).folder, c(f).name));
            if isfield(d, 'CorrMat')
                FC_run(s, f, :, :) = d.CorrMat;
            end
        end
    end

    n_loaded = sum(~isnan(squeeze(FC_run(:,1,1,2))));
    fprintf('  %s: %d/%d subjects loaded\n', session, n_loaded, n)

    icc_tmp   = NaN(rois, rois);
    ci_lo_tmp = NaN(rois, rois);
    ci_hi_tmp = NaN(rois, rois);

    for i = 1:rois
        for j = i+1:rois
            Y     = squeeze(FC_run(:, :, i, j));
            valid = ~any(isnan(Y), 2);
            Y     = Y(valid, :);
            if size(Y,1) < 3, continue; end
            if size(Y,2) < 2, continue; end
            try
                [r, LB, UB]    = ICC(Y, 'A-1');
                icc_tmp(i,j)   = r;
                ci_lo_tmp(i,j) = LB;
                ci_hi_tmp(i,j) = UB;
            catch
            end
        end
    end

    % Symmetrise
    icc_tmp   = icc_tmp   + icc_tmp'   - diag(diag(icc_tmp));
    ci_lo_tmp = ci_lo_tmp + ci_lo_tmp' - diag(diag(ci_lo_tmp));
    ci_hi_tmp = ci_hi_tmp + ci_hi_tmp' - diag(diag(ci_hi_tmp));

    icc_run(ss,:,:)   = icc_tmp;
    ci_lo_run(ss,:,:) = ci_lo_tmp;
    ci_hi_run(ss,:,:) = ci_hi_tmp;

    icc_r_vals = icc_tmp(triu(true(rois),1));
    icc_r_vals = icc_r_vals(~isnan(icc_r_vals));
    fprintf('\n[RUNS - %s] ICC Summary (n=%d pairs)\n', session, numel(icc_r_vals))
    fprintf('  Mean ICC:          %.3f\n', mean(icc_r_vals))
    fprintf('  Median ICC:        %.3f\n', median(icc_r_vals))
    fprintf('  Excellent >0.75:   %d (%.1f%%)\n', sum(icc_r_vals>0.75),                        100*mean(icc_r_vals>0.75))
    fprintf('  Good   0.6-0.75:   %d (%.1f%%)\n', sum(icc_r_vals>=0.6 & icc_r_vals<=0.75),     100*mean(icc_r_vals>=0.6 & icc_r_vals<=0.75))
    fprintf('  Moderate 0.4-0.6:  %d (%.1f%%)\n', sum(icc_r_vals>=0.4 & icc_r_vals<0.6),       100*mean(icc_r_vals>=0.4 & icc_r_vals<0.6))
    fprintf('  Poor    <0.4:      %d (%.1f%%)\n', sum(icc_r_vals<0.4),                          100*mean(icc_r_vals<0.4))
end

%% ============================================================
%  PLOTS
%% ============================================================

% Session ICC matrix
figure('Name','ICC Across Sessions','Position',[100 100 700 600]);
imagesc(icc_ses, [0 1]); colormap(hot); colorbar;
title('ICC(A-1) Across Sessions'); xlabel('ROI'); ylabel('ROI');

% Session distribution
figure('Name','ICC Distribution Sessions','Position',[810 100 500 400]);
histogram(icc_s_vals, 50, 'FaceColor',[0.2 0.5 0.8]);
xline(0.4,  'r--', 'Poor|Moderate',  'LabelVerticalAlignment','bottom');
xline(0.6,  'r-',  'Moderate|Good',  'LabelVerticalAlignment','bottom');
xline(0.75, 'g-',  'Good|Excellent', 'LabelVerticalAlignment','bottom');
xlabel('ICC(A-1)'); ylabel('Number of ROI pairs');
title('FC Reliability Across Sessions');

% Session reliability mask
figure('Name','Reliability Mask Sessions','Position',[100 720 700 600]);
imagesc(icc_ses >= icc_threshold);
colormap([0.85 0.85 0.85; 0.2 0.7 0.3]);
title(sprintf('Session reliability mask (ICC >= %.2f)', icc_threshold));
xlabel('ROI'); ylabel('ROI'); colorbar;

% Run ICC per session
for ss = 1:n_ses
    session    = sprintf('ses-%02d', sessions(ss));
    icc_tmp    = squeeze(icc_run(ss,:,:));
    icc_r_vals = icc_tmp(triu(true(rois),1));
    icc_r_vals = icc_r_vals(~isnan(icc_r_vals));

    figure('Name', sprintf('ICC Across Runs %s', session), 'Position',[100+ss*50 100 700 600]);
    imagesc(icc_tmp, [0 1]); colormap(hot); colorbar;
    title(sprintf('ICC(A-1) Across Runs - %s', session));
    xlabel('ROI'); ylabel('ROI');

    figure('Name', sprintf('ICC Distribution Runs %s',session), 'Position',[810+ss*50 100 500 400]);
    histogram(icc_r_vals, 50, 'FaceColor',[0.8 0.4 0.2]);
    xline(0.4,  'r--', 'Poor|Moderate',  'LabelVerticalAlignment','bottom');
    xline(0.6,  'r-',  'Moderate|Good',  'LabelVerticalAlignment','bottom');
    xline(0.75, 'g-',  'Good|Excellent', 'LabelVerticalAlignment','bottom');
    xlabel('ICC(A-1)'); ylabel('Number of ROI pairs');
    title(sprintf('FC Reliability Across Runs - %s', session));

    figure('Name', sprintf('Reliability Mask Runs %s',session), 'Position',[100+ss*50 720 700 600]);
    imagesc(icc_tmp >= icc_threshold);
    colormap([0.85 0.85 0.85; 0.2 0.7 0.3]);
    title(sprintf('Run reliability mask %s (ICC >= %.2f)', session, icc_threshold));
    xlabel('ROI'); ylabel('ROI'); colorbar;
end

%% ============================================================
%  SAVE
%% ============================================================
save(fullfile(out_dir, 'ICC_sessions.mat'), 'icc_ses', 'ci_lo_ses', 'ci_hi_ses', 'icc_s_vals');
save(fullfile(out_dir, 'ICC_runs.mat'),     'icc_run', 'ci_lo_run', 'ci_hi_run');

fprintf('\n========================================================\n')
fprintf('Saved to: %s\n', out_dir)
fprintf('  ICC_sessions.mat\n')
fprintf('  ICC_runs.mat\n')
fprintf('========================================================\n')