% C6_run_batch
% Batch runner for within-subject variation analysis
% Analyzes variation separately for:
%   1) Between sessions (ses-01 vs ses-02) - test-retest reliability
%   2) Between runs (run-01 vs run-02) - within-session stability
% Run this AFTER connectivity analysis (steps 1-5) is complete for all subjects

clc
close all

%#####################################################
%#################### INPUT ##########################
%#####################################################

% List all subject IDs to process
subject_ids = [2600, 2601, 2602];  % add as many as needed

% Sessions to include
sessions_to_include = [1, 2];  % ses-01 and ses-02

% Data source directory
src_dir = 'C:\Users\sreya\Documents\College\Internship_fMRI\Data';

% Folder containing connectivity matrices (inside each session directory)
corr_matrix_folder = 'connectivity\ROI2ROI_FC_AAL3v1';

% Number of ROIs in the connectivity matrix
rois = 166;

%#####################################################
%#################### INPUT end ######################
%#####################################################

% Track progress
total = length(subject_ids);
count = 0;
failed = {};

for s = 1:length(subject_ids)
    
    subject_id = subject_ids(s);
    SJ = sprintf('sub-%d', subject_id);
    count = count + 1;
    
    fprintf('\n========================================================\n')
    fprintf('Running %d/%d: %s\n', count, total, SJ)
    fprintf('========================================================\n')
    
    try
        output_dir = fullfile(src_dir, SJ, 'intraSJ_var');
        if ~exist(output_dir, 'dir')
            mkdir(output_dir);
        end
        
        %% ANALYSIS 1: Between-session variation (ses-01 vs ses-02)
        fprintf('  Analysis 1: Between-session variation\n')
        
        session_matrices = {};
        for sess = 1:length(sessions_to_include)
            session = sprintf('ses-%02d', sessions_to_include(sess));
            ses_path = fullfile(src_dir, SJ, session, corr_matrix_folder);
            
            if ~exist(ses_path, 'dir')
                warning('    Session folder not found, skipping: %s', ses_path);
                continue
            end
            
            % Get all connectivity matrices from this session (all runs)
            c = dir(fullfile(ses_path, '*bold_sess*.mat'));
            
            if isempty(c)
                warning('    No connectivity files found in %s', ses_path);
                continue
            end
            
            % Average across runs within this session
            session_corr = zeros(rois, rois);
            for f = 1:length(c)
                data = load(fullfile(c(f).folder, c(f).name));
                if ~isfield(data, 'CorrMat')
                    error('CorrMat variable not found in file: %s', c(f).name);
                end
                session_corr = session_corr + data.CorrMat;
            end
            session_corr = session_corr / length(c);
            
            session_matrices{end+1} = session_corr;
            fprintf('    Session %s: averaged %d run(s)\n', session, length(c));
        end
        
        if length(session_matrices) >= 2
            % Stack sessions and compute std
            session_data = zeros(length(session_matrices), rois, rois);
            for i = 1:length(session_matrices)
                session_data(i, :, :) = session_matrices{i};
            end
            
            var_sessions = std(session_data, 0, 1);
            
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
            warning('    Need at least 2 sessions for between-session analysis. Found %d.', length(session_matrices));
        end
        
        %% ANALYSIS 2: Between-run variation (within each session)
        fprintf('  Analysis 2: Between-run variation (within sessions)\n')
        
        for sess = 1:length(sessions_to_include)
            session = sprintf('ses-%02d', sessions_to_include(sess));
            ses_path = fullfile(src_dir, SJ, session, corr_matrix_folder);
            
            if ~exist(ses_path, 'dir')
                continue
            end
            
            % Get all runs from this session
            c = dir(fullfile(ses_path, '*bold_sess*.mat'));
            
            if length(c) < 2
                warning('    Session %s: need at least 2 runs for within-session analysis. Found %d.', session, length(c));
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
            
            % Save with session-specific name
            save(fullfile(output_dir, ['intraSJ_var_runs_' SJ '_' session '.mat']), 'var_runs', '-mat');
            fprintf('    ✓ Saved: intraSJ_var_runs_%s_%s.mat\n', SJ, session);
            
            % Plot
            figure('Name', [SJ ' - ' session ' Run Variation']);
            imagesc(reshape(var_runs, [rois, rois]))
            colorbar
            title(sprintf('Between-run variation: %s %s', SJ, session))
            xlabel('ROI')
            ylabel('ROI')
        end
        
        fprintf('✓ Finished: %s\n', SJ)
        
    catch ME
        warning('✗ Failed: %s\n', SJ)
        disp(ME.message)
        disp('Stack trace:')
        for i = 1:length(ME.stack)
            fprintf('  File: %s, Line: %d, Function: %s\n', ...
                ME.stack(i).file, ME.stack(i).line, ME.stack(i).name);
        end
        failed{end+1} = sprintf('%s: %s', SJ, ME.message);
    end
    
end

% Summary
fprintf('\n========================================================\n')
fprintf('Batch complete. %d/%d processed.\n', count - length(failed), total)
if ~isempty(failed)
    fprintf('Failed runs:\n')
    for i = 1:length(failed)
        fprintf('  %s\n', failed{i})
    end
end
fprintf('========================================================\n')