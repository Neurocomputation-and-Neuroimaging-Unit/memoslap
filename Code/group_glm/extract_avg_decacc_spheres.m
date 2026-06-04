%% ── USER-DEFINED PATHS ──────────────────────────────────────────────────────
SPM_path          = 'C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm12-main';
sphere_dir        = 'C:\Users\sreya\Documents\College\Internship_fMRI\Data\rois_sreya';
output_dir        = 'E:\memoslap\restingstate\2ndLevel\Decoding Accuracy';
decodingmaps_dir  = 'E:\memoslap\restingstate\single_sub_accuracy_maps';  % root folder; sub-XXXX\ses-XX appended below
%% ─────────────────────────────────────────────────────────────────────────────

addpath(SPM_path);

subject_ids = [2202, 2204, 2205, 2206, 2207, 2210, 2211, 2212, 2214, ...
               2216, 2217, 2219, 2220, 2221, 2222, 2223, 2225, 2226, 2227, ...
               2228, 2231, 2232, 2233, 2234, 2235, 2236, 2237, 2239, 2241, ...
               2242, 2243, 2246, 2247, 2248, 2250, 2252, 2254, 2255, 2256, 2257];

sessions      = {'ses-03', 'ses-04'};
decoding_file = 'late_bins678.nii';          % filename pattern (same for every subject/session)

% Format subject IDs
SJin    = arrayfun(@(x) sprintf('sub-%04d', x), subject_ids, 'UniformOutput', false);
SJnum   = arrayfun(@(x) sprintf('%04d',     x), subject_ids, 'UniformOutput', false);  % for file paths (no "sub-" prefix)

% ── Discover sphere masks ────────────────────────────────────────────────────
sphere_files = dir(fullfile(sphere_dir, 'earlyWM_rS2_spmClust.nii'));
n_spheres    = numel(sphere_files);
if n_spheres == 0
    error('No sphere_clust*.nii files found in:\n  %s', sphere_dir);
end

% ── Build column names ───────────────────────────────────────────────────────
% Per-session columns  : clust1_rSPL_ses-03, clust1_rSPL_ses-04
% Per-cluster averages : clust1_rSPL
col_names     = {};
avg_col_names = {};

for sp = 1:n_spheres
    [~, sphere_name, ~] = fileparts(sphere_files(sp).name);   % sphere_clust1_rSPL
    clust_label         = strrep(sphere_name, 'sphere_', ''); % clust1_rSPL

    for se = 1:numel(sessions)
        col_names{end+1} = sprintf('%s_%s', clust_label, sessions{se});
    end
    avg_col_names{end+1} = clust_label;   % average column added later
end

all_col_names = [col_names, avg_col_names];

% ── Preallocate results table ────────────────────────────────────────────────
n_subs   = numel(SJin);
results  = array2table(NaN(n_subs, numel(all_col_names)), ...
                       'VariableNames', all_col_names);
results  = addvars(results, SJin(:), 'Before', 1, 'NewVariableNames', 'subject_id');

% ── Main loop ────────────────────────────────────────────────────────────────
for sj = 1:n_subs
    fprintf('Processing: %s\n', SJin{sj});

    for sp = 1:n_spheres
        % Load sphere mask once per subject×sphere
        [~, sphere_name, ~] = fileparts(sphere_files(sp).name);
        clust_label         = strrep(sphere_name, 'sphere_', '');

        sphere_hdr  = spm_vol(fullfile(sphere_dir, sphere_files(sp).name));
        sphere_mask = spm_read_vols(sphere_hdr) > 0;

        session_vals = NaN(1, numel(sessions));   % collect per-session averages

        for se = 1:numel(sessions)
            % Build full path to decoding accuracy map
            % Expected: decodingmaps_dir\sub-XXXX\ses-XX\sub-XXXX_late_bins678.nii
            nii_path = fullfile(decodingmaps_dir, ...
                                SJin{sj}, ...
                                sessions{se}, ...
                                sprintf('%s_%s', SJin{sj}, decoding_file));

            if ~isfile(nii_path)
                warning('File not found for %s %s:\n  %s', SJin{sj}, sessions{se}, nii_path);
                continue;
            end

            % Load decoding accuracy map
            dec_hdr  = spm_vol(nii_path);
            dec_vol  = spm_read_vols(dec_hdr);

            % Extract mean within sphere
            masked_vals      = dec_vol(sphere_mask);
            avg_acc          = mean(masked_vals(~isnan(masked_vals)));
            session_vals(se) = avg_acc;

            % Write per-session column
            col_name              = sprintf('%s_%s', clust_label, sessions{se});
            results.(col_name)(sj) = avg_acc;
        end

        % Write cross-session average column
        results.(clust_label)(sj) = mean(session_vals, 'omitnan');
    end
end

% ── Save ─────────────────────────────────────────────────────────────────────
output_file = fullfile(output_dir, 'avg_decoding_per_sphere_rS2_spmClust_latebin.csv');
writetable(results, output_file);
fprintf('Saved results to: %s\n', output_file);