% C7_variance_significance.m
% Test if FC variance across runs/sessions is significant across subjects
% Non-significant = good (stable FC)

clear all; clc;

%#####################################################
%#################### INPUT ##########################
%#####################################################

subject_ids     = [2202, 2204, 2205, 2206, 2207, 2210, 2211, 2212, 2214, 2216, 2217, 2219, 2220, 2221, 2223, 2225, 2226, 2227, 2228, 2231, 2232, 2233, 2234, 2235, 2236, 2237, 2239, 2241, 2242, 2243, 2248, 2252, 2254, 2255, 2257]; % your full list
src_dir         = 'E:\memoslap\restingstate\nifti_bids';
sessions        = [1, 2];
rois            = 166;

%#####################################################

n = length(subject_ids);
all_ses = NaN(n, rois, rois);
all_run = NaN(n, rois, rois);

% Load variance matrices saved by C6
for s = 1:n
    SJ  = sprintf('sub-%d', subject_ids(s));
    dir = fullfile(src_dir, SJ, 'intraSJ_var');

    f = fullfile(dir, ['intraSJ_var_sessions_' SJ '.mat']);
    if exist(f,'file')
        d = load(f);
        all_ses(s,:,:) = reshape(d.var_sessions, rois, rois);
    end

    tmp = NaN(length(sessions), rois, rois);
    for ss = 1:length(sessions)
        f2 = fullfile(dir, sprintf('intraSJ_var_runs_%s_ses-%02d.mat', SJ, sessions(ss)));
        if exist(f2,'file')
            d = load(f2);
            tmp(ss,:,:) = reshape(d.var_runs, rois, rois);
        end
    end
    all_run(s,:,:) = squeeze(nanmean(tmp,1));
end

% Run t-test + FDR for sessions and runs
for type = {'sessions','runs'}
    label = type{1};
    if strcmp(label,'sessions'), data = all_ses; else, data = all_run; end

    % One-sample t-test per ROI pair (H0: variance = 0)
    p_mat = ones(rois,rois);
    for i = 1:rois
        for j = i+1:rois
            v = squeeze(data(:,i,j));
            v = v(~isnan(v));
            if length(v) >= 3
                [~, p_mat(i,j)] = ttest(v);
            end
        end
    end

    % FDR correction (Benjamini-Hochberg)
    idx = find(triu(ones(rois),1));
    p   = p_mat(idx);
    [ps, si] = sort(p);
    fdr = ps .* numel(p) ./ (1:numel(p))';
    for k = numel(p)-1:-1:1, fdr(k) = min(fdr(k),fdr(k+1)); end
    p_fdr = ones(size(p)); p_fdr(si) = fdr;
    p_fdr_mat = ones(rois,rois);
    p_fdr_mat(idx) = p_fdr;
    p_fdr_mat = p_fdr_mat + p_fdr_mat' - eye(rois);

    % Report
    n_sig = sum(p_fdr < 0.05);
    n_tot = numel(p_fdr);
    fprintf('\n[%s] Significant pairs (FDR p<0.05): %d / %d (%.1f%%)\n', ...
        label, n_sig, n_tot, 100*n_sig/n_tot);
    if n_sig/n_tot < 0.05
        fprintf('  --> GOOD: variance is mostly non-significant\n');
    else
        fprintf('  --> WARNING: more significant variance than expected\n');
    end

    % Plot
    figure('Name', label);
    imagesc(p_fdr_mat < 0.05);
    colormap([0.9 0.9 0.9; 1 0.2 0.2]);
    title(sprintf('[%s] Red = significant variance (bad) | Grey = stable (good)', label));
    xlabel('ROI'); ylabel('ROI'); colorbar;
end