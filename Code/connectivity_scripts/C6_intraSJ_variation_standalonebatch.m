% C6_intraSJ_variation_batch
% Analyze within-subject variation in ROI2ROI connectivity
% Toggle compare_sessions and compare_runs to choose which analyses to run

clc
close all

%#####################################################
%#################### INPUT ##########################
%#####################################################

% List all subject IDs to process
subject_ids = [2202, 2204, 2205, 2206, 2207, 2210, 2211, 2212, 2214, 2216, 2217, 2219, 2220, 2221, 2223, 2225, 2226, 2227, 2228, 2231, 2232, 2233, 2234, 2235, 2236, 2237, 2239, 2241, 2242, 2243, 2245, 2248, 2252, 2254, 2255, 2257];  % add as many as needed

% Sessions to include
sessions_to_include = [1, 2];

% Choose which analyses to run
compare_sessions = 1;  % 1 = compare between sessions (ses-01 vs ses-02), 0 = skip
compare_runs     = 1;  % 1 = compare between runs (run-01 vs run-02), 0 = skip

% Paths and parameters
src_dir = 'E:\memoslap\restingstate\nifti_bids';
corr_matrix_folder = 'connectivity\ROI2ROI_FC_AAL3v1';
corr_matrix_include = 'bold';
rois = 166;

%#####################################################
%#################### INPUT end ######################
%#####################################################

fprintf('\n========================================================\n')
fprintf('BATCH VARIATION ANALYSIS\n')
fprintf('Subjects: %d | Sessions: %s | Runs: %s\n', ...
    length(subject_ids), ...
    iif(compare_sessions, 'Yes', 'No'), ...
    iif(compare_runs, 'Yes', 'No'))
fprintf('========================================================\n')

failed = {};

for s = 1:length(subject_ids)
    
    subject_id = subject_ids(s);
    SJ = sprintf('sub-%d', subject_id);
    
    fprintf('\n>>> Processing %d/%d: %s\n', s, length(subject_ids), SJ)
    
    try
        % Create output directory
        output_dir = fullfile(src_dir, SJ, 'intraSJ_var');
        if ~exist(output_dir, 'dir')
            mkdir(output_dir);
        end
        
        %% ANALYSIS 1: Between-session variation
        if compare_sessions
            fprintf('  Analyzing between-session variation...\n')
            
            all_matrices = {};
            
            % Collect all matrices across sessions
            for sess = 1:length(sessions_to_include)
                session = sprintf('ses-%02d', sessions_to_include(sess));
                ses_path = fullfile(src_dir, SJ, session, corr_matrix_folder);
                
                if ~exist(ses_path, 'dir')
                    warning('    Session folder not found: %s', ses_path);
                    continue
                end
                
                c = dir(fullfile(ses_path, ['*' corr_matrix_include '*.mat']));
                
                if isempty(c)
                    warning('    No files found in %s', ses_path);
                    continue
                end
                
                for f = 1:length(c)
                    all_matrices{end+1} = fullfile(c(f).folder, c(f).name);
                end
                
                fprintf('    Session %s: found %d file(s)\n', session, length(c));
            end
            
            if length(all_matrices) >= 2
                % Load all matrices and stack
                corr_data = zeros(length(all_matrices), rois, rois);
                for i = 1:length(all_matrices)
                    data = load(all_matrices{i});
                    if ~isfield(data, 'CorrMat')
                        error('CorrMat not found in: %s', all_matrices{i});
                    end
                    corr_data(i, :, :) = data.CorrMat;
                end
                
                % Compute std across sessions
                var_sessions = std(corr_data, 0, 1);
                
                % Save
                save(fullfile(output_dir, ['intraSJ_var_sessions_' SJ '.mat']), 'var_sessions', '-mat');
                fprintf('    ✓ Saved: intraSJ_var_sessions_%s.mat\n', SJ);
                
                % Plot
                figure('Name', [SJ ' - Session Variation']);
                imagesc(reshape(var_sessions, [rois, rois]))
                colorbar
                title(sprintf('Between-session variation: %s', SJ))
                xlabel('ROI')
                ylabel('ROI')
            else
                warning('    Need at least 2 files for session analysis. Found %d.', length(all_matrices));
            end
        end
        
        %% ANALYSIS 2: Between-run variation (within each session)
        if compare_runs
            fprintf('  Analyzing between-run variation...\n')
            
            for sess = 1:length(sessions_to_include)
                session = sprintf('ses-%02d', sessions_to_include(sess));
                ses_path = fullfile(src_dir, SJ, session, corr_matrix_folder);
                
                if ~exist(ses_path, 'dir')
                    continue
                end
                
                c = dir(fullfile(ses_path, ['*' corr_matrix_include '*.mat']));
                
                if length(c) < 2
                    warning('    Session %s: need at least 2 runs. Found %d.', session, length(c));
                    continue
                end
                
                % Load all runs
                run_data = zeros(length(c), rois, rois);
                for f = 1:length(c)
                    data = load(fullfile(c(f).folder, c(f).name));
                    run_data(f, :, :) = data.CorrMat;
                end
                
                % Compute std across runs
                var_runs = std(run_data, 0, 1);
                
                % Save
                save(fullfile(output_dir, ['intraSJ_var_runs_' SJ '_' session '.mat']), 'var_runs', '-mat');
                fprintf('    ✓ Saved: intraSJ_var_runs_%s_%s.mat\n', SJ, session);
                
                % Plot
                figure('Name', [SJ ' - ' session ' Run Variation']);
                imagesc(reshape(var_runs, [rois, rois]))
                colorbar
                title(sprintf('Between-run variation: %s %s', SJ, session))
                xlabel('ROI')
                ylabel('ROI')
                
                % Add ROI labels at intervals
                roi_labels = get_AAL3_labels([35, 36, 81, 82]);
                tick_positions = 10:10:length(roi_labels);  % [10, 20, 30, 40, ...]
                tick_labels = roi_labels(tick_positions);   % Only labels at those positions
                
                set(gca, 'XTick', tick_positions, 'XTickLabel', tick_labels, 'XTickLabelRotation', 90)
                set(gca, 'YTick', tick_positions, 'YTickLabel', tick_labels)
                set(gca, 'FontSize', 8)
                
            end
        end
        
        fprintf('  ✓ Finished: %s\n', SJ)
        
    catch ME
        warning('  ✗ Failed: %s - %s\n', SJ, ME.message)
        failed{end+1} = sprintf('%s: %s', SJ, ME.message);
    end
    
end

% Summary
fprintf('\n========================================================\n')
fprintf('Batch complete. %d/%d processed.\n', length(subject_ids) - length(failed), length(subject_ids))
if ~isempty(failed)
    fprintf('Failed:\n')
    for i = 1:length(failed)
        fprintf('  %s\n', failed{i})
    end
end
fprintf('========================================================\n')

% Helper function
function out = iif(condition, true_val, false_val)
    if condition
        out = true_val;
    else
        out = false_val;
    end
end
