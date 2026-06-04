%% Repeated-measures ANOVA for session and run effects on RS-FC
% Data structure: FC_all (n x 2ses x 2runs x rois x rois)
% For each ROI, extract connectivity values and run rmANOVA

clear; clc; close all;

% Load your extracted connectivity values
% You need a (35 x 4) matrix per ROI where columns = [S1R1, S1R2, S2R1, S2R2]
% Extract from your corrMaps — same way you did for ICC

%% Define ROIs
roi_files = {
    'E:\memoslap\restingstate\rois_sreya\earlyWM_rS2.nii';
    'E:\memoslap\restingstate\rois_sreya\lateWM_lSPL_spmClust.nii';
    'E:\memoslap\restingstate\rois_sreya\lateWM_rSPL_spmClust.nii';
    'E:\memoslap\restingstate\rois_sreya\rPCC_roi_seed_for_DMN.nii'
};
roi_names = {'rS2', 'lSPL', 'rSPL', 'rPCC_DMN'};

src_dir   = 'E:\memoslap\restingstate\nifti_bids';
fc_folder = 'connectivity\ROI2ROI_FC_AAL3v1';
fc_include = 'bold';

subject_ids = [2202, 2204, 2205, 2206, 2207, 2210, 2211, 2212, 2214, ...
               2216, 2217, 2219, 2220, 2221, 2222, 2223, 2225, 2226, 2227, ...
               2228, 2231, 2232, 2233, 2234, 2235, 2236, 2237, 2239, 2241, ...
               2242, 2243, 2246, 2247, 2248, 2250, 2252, 2254, 2255, 2256, 2257];
n = length(subject_ids);

%% Load atlas
atlas_file = 'C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm12-main\AAL3\AAL3v1.nii';
V_atlas    = spm_vol(atlas_file);
atlas_img  = spm_read_vols(V_atlas);

%% Load FC_all (reuse from ICC script if already in workspace)
% If not loaded, rerun loading block from ICC_simple_fixed.m
% FC_all: (n x 2 x 2 x 166 x 166)

rois = 166;
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

%% ANOVA per ROI
results_anova = struct();

for k = 1:length(roi_files)

    % Get AAL3 indices overlapping with ROI mask
    V_roi   = spm_vol(roi_files{k});
    roi_img = spm_read_vols(V_roi);
    roi_mask = roi_img > 0;
    overlapping_labels = unique(atlas_img(roi_mask));
    aal_idx = overlapping_labels(overlapping_labels > 0);

    fprintf('\nROI: %s → AAL3 indices: %s\n', roi_names{k}, num2str(aal_idx'));

    % Extract mean connectivity across AAL3 regions in ROI
    % Average over all pairs involving these AAL indices
    fc_data = NaN(n, 2, 2); % subjects x sessions x runs
    for s = 1:n
        for ss = 1:2
            for r = 1:2
                vals = [];
                for ri = aal_idx'
                    row = squeeze(FC_all(s, ss, r, ri, :));
                    row(aal_idx) = NaN; % exclude within-ROI
                    vals = [vals; row(~isnan(row))];
                end
                fc_data(s, ss, r) = mean(vals, 'omitnan');
            end
        end
    end

    % Reshape to (n x 4): [S1R1, S1R2, S2R1, S2R2]
    Y = [fc_data(:,1,1), fc_data(:,1,2), fc_data(:,2,1), fc_data(:,2,2)];

    % Remove subjects with any NaN
    ok = ~any(isnan(Y), 2);
    Y  = Y(ok, :);
    fprintf('  Subjects included: %d\n', sum(ok));

    % Build repeated-measures model
    t = array2table(Y, 'VariableNames', {'S1R1','S1R2','S2R1','S2R2'});

    within = table([1;1;2;2], [1;2;1;2], ...
        'VariableNames', {'Session','Run'});
    within.Session = categorical(within.Session);
    within.Run     = categorical(within.Run);

    rm  = fitrm(t, 'S1R1-S2R2 ~ 1', 'WithinDesign', within);
    tbl = ranova(rm, 'WithinModel', 'Session*Run');

    fprintf('  Session:     F = %.3f, p = %.3f\n', tbl.F(3), tbl.pValue(3));
    fprintf('  Run:         F = %.3f, p = %.3f\n', tbl.F(5), tbl.pValue(5));
    fprintf('  Session×Run: F = %.3f, p = %.3f\n', tbl.F(7), tbl.pValue(7));

    results_anova(k).name       = roi_names{k}; 
    results_anova(k).F_session  = tbl.F(3);
    results_anova(k).p_session  = tbl.pValue(3);
    results_anova(k).F_run      = tbl.F(5);
    results_anova(k).p_run      = tbl.pValue(5);
    results_anova(k).F_interact = tbl.F(7);
    results_anova(k).p_interact = tbl.pValue(7);
    results_anova(k).df1        = tbl.DF(3);  % numerator df = 1 (from Session row)
    results_anova(k).df2        = tbl.DF(4);  % denominator df = 34 (from Error(Session) row)
end

%% Save to CSV
T_anova = table(...
    {results_anova.name}', ...
    [results_anova.F_session]',  [results_anova.p_session]', ...
    [results_anova.F_run]',      [results_anova.p_run]', ...
    [results_anova.F_interact]', [results_anova.p_interact]', ...
    'VariableNames', {'ROI', ...
        'F_Session', 'p_Session', ...
        'F_Run',     'p_Run', ...
        'F_Session_x_Run', 'p_Session_x_Run'});

out_dir = fullfile(src_dir, 'group_ICC');
writetable(T_anova, fullfile(out_dir, 'ANOVA_session_run.csv'));
fprintf('\nANOVA results saved.\n');