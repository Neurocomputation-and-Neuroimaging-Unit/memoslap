% C6_interSJ_var_standalone
% Standalone script to analyse within-subject variation across sessions.
% Run this AFTER all sessions have been processed by C0_connectivity_batch_new.
% It collects ROI2ROI connectivity matrices from all sessions and computes
% the standard deviation across them.

clc

%#####################################################
%#################### INPUT ##########################
%#####################################################

subject_id = 2202;          % subject number
sessions_to_include = [1, 2];  % list all sessions you want to include

src_dir = 'C:\Users\sreya\Documents\College\Internship_fMRI\Data';
corr_matrix_folder  = 'connectivity\ROI2ROI_FC_AAL3v1';   % folder name inside each session dir
corr_matrix_include = 'bold_sess';            % identifier string to match matrix files
rois = 166;                                   % number of ROIs in the connectivity matrix

%#####################################################
%#################### INPUT end ######################
%#####################################################

SJ = sprintf('sub-%d', subject_id);

fprintf('Collecting connectivity matrices for %s\n', SJ)
fprintf('Sessions: %s\n', num2str(sessions_to_include))

all_matrices = {};   % store all found files across sessions

% collect all connectivity matrix files across sessions
for s = 1:length(sessions_to_include)
    session = sprintf('ses-%02d', sessions_to_include(s));
    ses_path = fullfile(src_dir, SJ, session, corr_matrix_folder);

    if ~exist(ses_path, 'dir')
        warning('Folder not found for session %s, skipping: %s', session, ses_path);
        continue
    end

    c = dir(fullfile(ses_path, ['*' corr_matrix_include '*']));

    if isempty(c)
        warning('No files matching "%s" found in %s, skipping.', corr_matrix_include, ses_path);
        continue
    end

    for f = 1:length(c)
        all_matrices{end+1} = fullfile(c(f).folder, c(f).name);
    end

    fprintf('Session %s: found %d file(s)\n', session, length(c));
end

if isempty(all_matrices)
    error('No connectivity matrix files found across any session. Check your inputs.');
end

fprintf('Total files collected: %d\n', length(all_matrices));

% load all matrices and stack them
corr_data = zeros(length(all_matrices), rois, rois);

for i = 1:length(all_matrices)
    fprintf('Loading: %s\n', all_matrices{i});
    data = load(all_matrices{i});
    if ~isfield(data, 'CorrMat')
        error('CorrMat variable not found in file: %s', all_matrices{i});
    end
    corr_data(i, :, :) = data.CorrMat;
end

% compute standard deviation across sessions/files
var_data = std(corr_data, 0, 1);

% save output in subject folder
output_dir = fullfile(src_dir, SJ);
save(fullfile(output_dir, ['intraSJ_var_' SJ '.mat']), 'var_data', '-mat');
fprintf('Saved variation data to: %s\n', fullfile(output_dir, ['intraSJ_var_' SJ '.mat']));

% plot
figure;
imagesc(reshape(var_data, [rois, rois]))
colorbar
title(sprintf('Within-subject variation across sessions: %s', SJ))
xlabel('ROI')
ylabel('ROI')
