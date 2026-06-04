% Example: Plot correlation matrix with ROI labels
% This shows how to add AAL3 labels to your correlation matrix plots

clc
close all

% Load your correlation matrix
% Replace this with your actual file path
corr_file = 'C:\Users\sreya\Documents\College\Internship_fMRI\Data\sub-2202\ses-01\connectivity\ROI2ROI_FC_AAL3v1\CorrMat_sub-2202_bold_sess_run-01.mat';
data = load(corr_file);
CorrMat = data.CorrMat;

% Get ROI labels (excluding indices 35, 36, 81, 82)
roi_labels = get_AAL3_labels([35, 36, 81, 82]);

% Plot with labels
figure('Position', [100 100 1200 1000]);
imagesc(CorrMat)
colorbar
title('ROI-to-ROI Functional Connectivity')

% Set axis labels
set(gca, 'XTick', 1:length(roi_labels), 'XTickLabel', roi_labels, 'XTickLabelRotation', 90)
set(gca, 'YTick', 1:length(roi_labels), 'YTickLabel', roi_labels)

% Adjust font size so labels are readable
set(gca, 'FontSize', 6)

% Optional: set color limits for better visualization
clim([-1 1])  % Correlation range from -1 to 1
colormap('jet')

% Add grid for better readability
grid on
set(gca, 'GridColor', 'k', 'GridAlpha', 0.1)
