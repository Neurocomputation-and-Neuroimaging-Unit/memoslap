clc
clear all
close all

SPM_path = 'C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm12-main';
addpath(SPM_path);

subject_ids = [2202, 2204, 2205, 2206, 2207, 2210, 2211, 2212, 2214, ...
               2216, 2217, 2219, 2220, 2221, 2222, 2223, 2225, 2226, 2227, ...
               2228, 2231, 2232, 2233, 2234, 2235, 2236, 2237, 2239, 2241, 2242, 2243, 2246, 2247, 2248, 2250, 2252, 2254, 2255, 2256, 2257];

src_dir     = 'E:\memoslap\restingstate\nifti_bids';
output_dir  = 'E:\memoslap\restingstate\2ndLevel\2ndLevel_FlexFact_Interaction_rPCC_roi_seed_for_DMN\final results';
conn_folder = 'ROI2voxel_FC_rPCC_roi_seed_for_DMN';
sphere_dir  = 'E:\memoslap\restingstate\2ndLevel\2ndLevel_FlexFact_Interaction_earlyWM_rS2\final results';  % folder containing sphere_clust*.nii files

sessions = {'ses-01', 'ses-02'};
runs     = {'run-01', 'run-02'};

% Format subject IDs as strings
SJin = arrayfun(@(x) sprintf('sub-%04d', x), subject_ids, 'UniformOutput', false);

% Find all sphere NIfTI files
sphere_files = dir(fullfile(sphere_dir, 'sphere*.nii'));
%sphere_files = dir('E:\memoslap\restingstate\2ndLevel\2ndLevel_FlexFact_Interaction_lateWM_lSPL_spmClust.nii');
n_spheres    = length(sphere_files);

if n_spheres == 0
    error('No sphere_clust*.nii files found in:\n  %s', sphere_dir);
end

% Build column names from sphere filenames: sphere_clust1_rSPL -> clust1_rSPL_ses01_run01 etc.
col_names = {};
for sp = 1:n_spheres
    [~, sphere_name, ~] = fileparts(sphere_files(sp).name);  % e.g. sphere_clust1_rSPL
    clust_label = strrep(sphere_name, 'sphere_', '');         % e.g. clust1_rSPL
    for se = 1:numel(sessions)
        for ru = 1:numel(runs)
            col_names{end+1} = sprintf('%s_%s_%s', clust_label, sessions{se}, runs{ru});
        end
    end
end

% Preallocate results table
n_subs = numel(SJin);
n_cols = length(col_names);
results = array2table(NaN(n_subs, n_cols), 'VariableNames', col_names, 'RowNames', SJin);

% Loop over subjects
for sj = 1:n_subs
    fprintf('Processing: %s\n', SJin{sj});

    for sp = 1:n_spheres

        % Load sphere mask
        [~, sphere_name, ~] = fileparts(sphere_files(sp).name);
        clust_label = strrep(sphere_name, 'sphere_', '');

        sphere_hdr  = spm_vol(fullfile(sphere_dir, sphere_files(sp).name));
        sphere_mask = spm_read_vols(sphere_hdr) > 0;  % logical mask

        for se = 1:numel(sessions)
            for ru = 1:numel(runs)

                scan_dir = fullfile(src_dir, SJin{sj}, sessions{se}, ...
                                    'connectivity', conn_folder);

                % Match corrMap file for this run
                filt = sprintf('corrMap_.*%s.*\\.nii$', runs{ru});
                f    = spm_select('List', scan_dir, filt);

                if isempty(f)
                    warning('No corrMap file found for %s %s %s in:\n  %s', ...
                             SJin{sj}, sessions{se}, runs{ru}, scan_dir);
                    continue;
                end

                % Load correlation map
                corr_hdr  = spm_vol(fullfile(scan_dir, strtrim(f(1,:))));
                corr_vol  = spm_read_vols(corr_hdr);

                % Apply sphere mask and get average correlation
                masked_vals = corr_vol(sphere_mask);
                avg_corr    = mean(masked_vals(~isnan(masked_vals)));

                % Store in results table
                col_name = sprintf('%s_%s_%s', clust_label, sessions{se}, runs{ru});
                results{SJin{sj}, col_name} = avg_corr;

            end
        end
    end
end

% Save table
output_file = fullfile(output_dir, 'avg_corr_per_sphere.csv');

% Compute average correlation across all sessions and runs for each cluster
for sp = 1:n_spheres
    [~, sphere_name, ~] = fileparts(sphere_files(sp).name);
    clust_label = strrep(sphere_name, 'sphere_', '');

    % Find all columns belonging to this cluster
    clust_cols = col_names(startsWith(col_names, clust_label));

    % Average across those columns
    results.(clust_label) = mean(results{:, clust_cols}, 2, 'omitnan');
end

writetable(results, output_file, 'WriteRowNames', true);
fprintf('Saved results to: %s\n', output_file);