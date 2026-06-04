function C6_interSJ_var(src_dir, SJ, corr_matrix_folder, corr_matrix_include, rois)
% Analyse within-subject variation across sessions for a single subject.
% Loads all session connectivity matrices found in the corr_matrix_folder
% and computes the standard deviation across sessions.

sj_path = fullfile(src_dir, SJ, corr_matrix_folder);

if ~exist(sj_path, 'dir')
    error('Connectivity matrix folder not found: %s', sj_path);
end

cd(sj_path)

% find all session connectivity matrix files for this subject
c = dir(['*' corr_matrix_include '*']);

if isempty(c)
    error('No connectivity matrix files found matching "%s" in %s', corr_matrix_include, sj_path);
end

sessNum = length(c);
fprintf('Found %d session file(s) for %s\n', sessNum, SJ);

corr_data = zeros(sessNum, rois, rois);

for ses = 1:sessNum
    corr = load([c(ses).folder filesep c(ses).name]);
    this_data = corr.CorrMat;
    corr_data(ses, :, :) = this_data;
end

% compute standard deviation across sessions
var_data = std(corr_data, 0, 1);

save([sj_path filesep 'intraSJ_var_SJ_' SJ '.mat'], 'var_data', '-mat');

imagesc(reshape(var_data, [rois, rois]))
title(['Within-subject variation: ' SJ])
