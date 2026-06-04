%% =========================================================
%  SCRIPT 1: MULTIPLE REGRESSION — ITERATIVE MODEL BUILDING
%  Brain-behavior relationships | LH & RH | All DVs
%  Includes age & sex as optional covariates
%  All outputs saved to results/ folder
%% =========================================================
%
%  OUTPUT FILES SAVED:
%  - results/descriptives.txt         — means, SDs, ranges
%  - results/correlations_LH.txt      — predictor correlations LH
%  - results/correlations_RH.txt      — predictor correlations RH
%  - results/model_comparison_*.txt   — AIC/BIC tables per model
%  - results/coefficients_*.txt       — final model coefficients
%  - results/summary_all_models.txt   — one-page summary table
%  - figures/distributions_LH.png
%  - figures/distributions_RH.png
%  - figures/scatterplots_LH.png
%  - figures/scatterplots_RH.png
%  - figures/aicbic_LH_PerfAcc.png    — AIC/BIC bar charts
%  - figures/aicbic_RH_PerfAcc.png
%
%% =========================================================

clear; clc; close all;

%% =========================================================
%  CONFIG — UPDATE THESE TO MATCH YOUR COLUMN NAMES
%% =========================================================

% --- File path ---
data_file = 'E:\memoslap\restingstate\2ndLevel\Multiple Regression\all_average_conn_dec_perf.csv';   % <-- update this

% --- Dependent variables ---
DV_perf      = 'perf_average';

% --- Left hemisphere ---
LH_conn1     = 'connectivity_lIFG_lSPL_spmClust';
LH_conn2     = 'connectivity_lSFG_lSPL_spmClust';
LH_dec_early = 'decoding_earlybin_lSPL_spmClust';
LH_dec_late  = 'decoding_latebin_lSPL_spmClust';

% --- Right hemisphere ---
RH_conn1     = 'connectivity_rIFG_rSPL_spmClust';
RH_conn2     = 'connectivity_rSFG_rSPL_spmClust';
RH_dec_early = 'decoding_earlybin_rSPL_spmClust';
RH_dec_late  = 'decoding_latebin_rSPL_spmClust';

% --- Covariates ---
% Set to true to include age and sex in models
include_covariates = false;
covariate_age = 'Age';

% --- Output directory ---
out_dir = 'E:\memoslap\restingstate\2ndLevel\Multiple Regression\results_noage';
fig_dir = 'E:\memoslap\restingstate\2ndLevel\Multiple Regression\figures_noage';

%% =========================================================
%  SETUP — create output folders
%% =========================================================

if ~exist(out_dir, 'dir'), mkdir(out_dir); end
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

% Log file — captures all printed output
diary(fullfile(out_dir, 'full_output_log.txt'));
diary on;

fprintf('=================================================\n');
fprintf('  MULTIPLE REGRESSION ANALYSIS\n');
fprintf('  Run date: %s\n', datestr(now));
fprintf('=================================================\n\n');

%% =========================================================
%  LOAD DATA
%% =========================================================

T = readtable(data_file);

fprintf('Data loaded: %d subjects, %d variables\n', height(T), width(T));
fprintf('Columns: %s\n\n', strjoin(T.Properties.VariableNames, ', '));

% % Encode sex as categorical dummy if needed
% if include_covariates
%     if iscell(T.(covariate_sex)) || ischar(T.(covariate_sex))
%         fprintf('NOTE: Sex column is string — converting to numeric (0/1)\n');
%         T.(covariate_sex) = double(categorical(T.(covariate_sex))) - 1;
%     end
% end

%% =========================================================
%  HELPER FUNCTIONS
%% =========================================================

% AIC and BIC from fitlm object
getAICBIC = @(m) deal( ...
    -2 * m.LogLikelihood + 2 * m.NumCoefficients, ...
    -2 * m.LogLikelihood + m.NumCoefficients * log(m.NumObservations));

% Build covariate string for formula
if include_covariates
    cov_str = sprintf('%s + ', covariate_age);
else
    cov_str = '';
end

% Save figure helper
save_fig = @(fname) exportgraphics(gcf, fullfile(fig_dir, fname), 'Resolution', 200);

%% =========================================================
%  SECTION 1: PRELIMINARY CHECKS
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 1: PRELIMINARY CHECKS\n');
fprintf('=================================================\n\n');

% --- Variables to check ---
if include_covariates
    vars_LH = {DV_perf, covariate_age, LH_conn1, LH_conn2, LH_dec_early, LH_dec_late};
    vars_RH = {DV_perf, covariate_age, RH_conn1, RH_conn2, RH_dec_early, RH_dec_late};
else
    vars_LH = {DV_perf, LH_conn1, LH_conn2, LH_dec_early, LH_dec_late};
    vars_RH = {DV_perf, RH_conn1, RH_conn2, RH_dec_early, RH_dec_late};
end

% --- Descriptive statistics ---
fid = fopen(fullfile(out_dir, 'descriptives.txt'), 'w');
fprintf(fid, 'DESCRIPTIVE STATISTICS\nGenerated: %s\n\n', datestr(now));
header = sprintf('%-22s  %-8s  %-8s  %-8s  %-8s  %-8s\n', ...
    'Variable','Mean','SD','Min','Max','N');
fprintf(header); fprintf(fid, header);
sep = [repmat('-',1,65) '\n'];
fprintf(sep); fprintf(fid, sep);

all_vars = unique([vars_LH, vars_RH], 'stable');
for i = 1:length(all_vars)
    v = T.(all_vars{i});
    n = sum(~isnan(v));
    row = sprintf('%-22s  %-8.3f  %-8.3f  %-8.3f  %-8.3f  %-8d\n', ...
        all_vars{i}, mean(v,'omitnan'), std(v,'omitnan'), min(v), max(v), n);
    fprintf(row); fprintf(fid, row);
end
fclose(fid);
fprintf('\nDescriptives saved to %s/descriptives.txt\n', out_dir);

% --- Check covariates vs DVs ---
if include_covariates
    fprintf('\n--- Covariate correlations with DVs ---\n');
    fprintf('(If p < 0.05, covariates are relevant to include)\n\n');
    dvs_to_check = {DV_perf, LH_dec_early, LH_dec_late, RH_dec_early, RH_dec_late};
    covs = {covariate_age};
    fprintf('%-20s  %-20s  %-8s  %-8s\n', 'Covariate', 'DV', 'rho', 'p');
    fprintf('%s\n', repmat('-',1,60));
    for c = 1:length(covs)
        for d = 1:length(dvs_to_check)
            [r,p] = corr(T.(covs{c}), T.(dvs_to_check{d}), ...
                'type','Spearman','rows','complete');
            sig = '';
            if p < 0.05, sig = ' *'; end
            if p < 0.01, sig = ' **'; end
            fprintf('%-20s  %-20s  %-8.3f  %-8.4f%s\n', ...
                covs{c}, dvs_to_check{d}, r, p, sig);
        end
    end
end

% --- Distributions ---
figure('Name','Distributions - Left Hemisphere', ...
       'Position',[50 50 1400 350], 'Color','w');
colors_LH = repmat([0.18 0.45 0.75], length(vars_LH), 1);
for i = 1:length(vars_LH)
    subplot(1, length(vars_LH), i);
    histogram(T.(vars_LH{i}), 10, 'FaceColor', colors_LH(i,:), ...
              'EdgeColor','w', 'FaceAlpha',0.85);
    title(strrep(vars_LH{i},'_','\_'), 'FontSize',10);
    xlabel('Value','FontSize',8); ylabel('Count','FontSize',8);
    box off;
end
sgtitle('Variable Distributions — Left Hemisphere', 'FontSize',13, 'FontWeight','bold');
save_fig('distributions_LH.png');
fprintf('\nFigure saved: %s/distributions_LH.png\n', fig_dir);

figure('Name','Distributions - Right Hemisphere', ...
       'Position',[50 450 1400 350], 'Color','w');
colors_RH = repmat([0.78 0.25 0.18], length(vars_RH), 1);
for i = 1:length(vars_RH)
    subplot(1, length(vars_RH), i);
    histogram(T.(vars_RH{i}), 10, 'FaceColor', colors_RH(i,:), ...
              'EdgeColor','w', 'FaceAlpha',0.85);
    title(strrep(vars_RH{i},'_','\_'), 'FontSize',10);
    xlabel('Value','FontSize',8); ylabel('Count','FontSize',8);
    box off;
end
sgtitle('Variable Distributions — Right Hemisphere', 'FontSize',13, 'FontWeight','bold');
save_fig('distributions_RH.png');
fprintf('Figure saved: %s/distributions_RH.png\n', fig_dir);

% --- Scatterplots: predictors vs DV ---
preds_LH = {LH_conn1, LH_conn2, LH_dec_early, LH_dec_late};
preds_RH = {RH_conn1, RH_conn2, RH_dec_early, RH_dec_late};

figure('Name','Scatterplots - LH vs PerfAcc', ...
       'Position',[50 50 1200 300], 'Color','w');
for i = 1:length(preds_LH)
    subplot(1,4,i);
    scatter(T.(preds_LH{i}), T.(DV_perf), 45, [0.18 0.45 0.75], 'filled', ...
            'MarkerFaceAlpha',0.7);
    lsline; box off;
    xlabel(strrep(preds_LH{i},'_','\_'),'FontSize',9);
    ylabel(strrep(DV_perf,'_','\_'),'FontSize',9);
    [r,p] = corr(T.(preds_LH{i}), T.(DV_perf), 'type','Spearman','rows','complete');
    title(sprintf('\\rho=%.2f, p=%.3f', r, p), 'FontSize',9);
end
sgtitle('LH Predictors vs Performance Accuracy','FontSize',12,'FontWeight','bold');
save_fig('scatterplots_LH.png');
fprintf('Figure saved: %s/scatterplots_LH.png\n', fig_dir);

figure('Name','Scatterplots - RH vs PerfAcc', ...
       'Position',[50 400 1200 300], 'Color','w');
for i = 1:length(preds_RH)
    subplot(1,4,i);
    scatter(T.(preds_RH{i}), T.(DV_perf), 45, [0.78 0.25 0.18], 'filled', ...
            'MarkerFaceAlpha',0.7);
    lsline; box off;
    xlabel(strrep(preds_RH{i},'_','\_'),'FontSize',9);
    ylabel(strrep(DV_perf,'_','\_'),'FontSize',9);
    [r,p] = corr(T.(preds_RH{i}), T.(DV_perf), 'type','Spearman','rows','complete');
    title(sprintf('\\rho=%.2f, p=%.3f', r, p), 'FontSize',9);
end
sgtitle('RH Predictors vs Performance Accuracy','FontSize',12,'FontWeight','bold');
save_fig('scatterplots_RH.png');
fprintf('Figure saved: %s/scatterplots_RH.png\n', fig_dir);

% --- Predictor correlation matrices (text + heatmap figure) ---
for hemi = {'LH','RH'}
    h = hemi{1};
    if strcmp(h,'LH')
        pred_mat   = [T.(LH_conn1), T.(LH_conn2), T.(LH_dec_early), T.(LH_dec_late)];
        pred_names = {LH_conn1, LH_conn2, LH_dec_early, LH_dec_late};
        fname      = 'correlations_LH.txt';
        fig_fname  = 'corrmatrix_LH.png';
        hmap_color = [0.18 0.45 0.75];
    else
        pred_mat   = [T.(RH_conn1), T.(RH_conn2), T.(RH_dec_early), T.(RH_dec_late)];
        pred_names = {RH_conn1, RH_conn2, RH_dec_early, RH_dec_late};
        fname      = 'correlations_RH.txt';
        fig_fname  = 'corrmatrix_RH.png';
        hmap_color = [0.78 0.25 0.18];
    end

    [R_mat, P_mat] = corr(pred_mat, 'type','Spearman','rows','complete');

    % Save text version
    fid = fopen(fullfile(out_dir, fname), 'w');
    fprintf(fid, 'PREDICTOR CORRELATIONS — %s\nSpearman rho (p-value)\n\n', h);
    fprintf(fid, '%-20s', '');
    for j = 1:length(pred_names), fprintf(fid,'%-22s', pred_names{j}); end
    fprintf(fid,'\n');
    for i = 1:length(pred_names)
        fprintf(fid,'%-20s', pred_names{i});
        for j = 1:length(pred_names)
            fprintf(fid,'%-22s', sprintf('r=%.3f (p=%.3f)', R_mat(i,j), P_mat(i,j)));
        end
        fprintf(fid,'\n');
    end
    fprintf(fid,'\nNOTE: |r| > 0.7 between predictors may indicate multicollinearity.\n');
    fclose(fid);
    fprintf('Correlations saved: %s/%s\n', out_dir, fname);

    % Save heatmap figure
    np = length(pred_names);
    figure('Position',[100 100 520 440], 'Color','w');
    imagesc(R_mat);
    clim([-1 1]);

    % Diverging colormap: blue=negative, white=zero, red=positive
    n_colors = 256;
    cmap_r = [linspace(0,1,n_colors/2), ones(1,n_colors/2)]';
    cmap_g = [linspace(0,1,n_colors/2), linspace(1,0,n_colors/2)]';
    cmap_b = [ones(1,n_colors/2),       linspace(1,0,n_colors/2)]';
    colormap([cmap_r, cmap_g, cmap_b]);
    cb = colorbar;
    cb.Label.String = 'Spearman \rho';
    cb.Label.FontSize = 10;

    % Axis labels
    tick_labels = strrep(pred_names,'_','\_');
    xticks(1:np); xticklabels(tick_labels); xtickangle(25);
    yticks(1:np); yticklabels(tick_labels);
    ax = gca; ax.FontSize = 9;

    % Annotate each cell with rho and significance stars
    for i = 1:np
        for j = 1:np
            if i == j
                txt = '—';
            else
                stars = '';
                if P_mat(i,j) < 0.001, stars = '***';
                elseif P_mat(i,j) < 0.01, stars = '**';
                elseif P_mat(i,j) < 0.05, stars = '*';
                end
                txt = sprintf('%.2f%s', R_mat(i,j), stars);
            end
            % White text on dark cells, black on light cells
            text_color = 'k';
            if abs(R_mat(i,j)) > 0.6, text_color = 'w'; end
            text(j, i, txt, 'HorizontalAlignment','center', ...
                 'FontSize',9, 'FontWeight','bold', 'Color',text_color);
        end
    end

    title(sprintf('Predictor Correlation Matrix — %s', h), ...
          'FontSize',12, 'FontWeight','bold');
    subtitle('* p<.05   ** p<.01   *** p<.001', 'FontSize',8);
    axis square;

    save_fig(fig_fname);
    fprintf('Figure saved: %s/%s\n', fig_dir, fig_fname);
end

%% =========================================================
%  ITERATIVE BUILDING — GENERIC FUNCTION
%% =========================================================

function [models, aics, bics, step_labels] = run_iterative(...
        T, DV, conn1, conn2, dec_early, dec_late, cov_str, getAICBIC)

    % Step 0: Null
    mdl0 = fitlm(T, sprintf('%s ~ 1', DV));
    [a0,b0] = getAICBIC(mdl0);

    % Step 1: Covariates only
    if ~isempty(cov_str)
        f1 = sprintf('%s ~ %s1', DV, cov_str);
        lbl1 = 'Age';
    else
        f1 = sprintf('%s ~ 1', DV);
        lbl1 = 'Null';
    end
    mdl1 = fitlm(T, f1);
    [a1,b1] = getAICBIC(mdl1);

    % Step 2: conn1 only
    f2 = sprintf('%s ~ %s%s', DV, cov_str, conn1);
    mdl2 = fitlm(T, f2);
    [a2,b2] = getAICBIC(mdl2);

    % Step 3: conn2 only
    f3 = sprintf('%s ~ %s%s', DV, cov_str, conn2);
    mdl3 = fitlm(T, f3);
    [a3,b3] = getAICBIC(mdl3);

    % Step 4: early decoding only
    f4 = sprintf('%s ~ %s%s', DV, cov_str, dec_early);
    mdl4 = fitlm(T, f4);
    [a4,b4] = getAICBIC(mdl4);

    % Step 5: late decoding only
    f5 = sprintf('%s ~ %s%s', DV, cov_str, dec_late);
    mdl5 = fitlm(T, f5);
    [a5,b5] = getAICBIC(mdl5);

    % Step 6: both connectivity
    f6 = sprintf('%s ~ %s%s + %s', DV, cov_str, conn1, conn2);
    mdl6 = fitlm(T, f6);
    [a6,b6] = getAICBIC(mdl6);

    % Step 7: both connectivity + early decoding
    f7 = sprintf('%s ~ %s%s + %s + %s', DV, cov_str, conn1, conn2, dec_early);
    mdl7 = fitlm(T, f7);
    [a7,b7] = getAICBIC(mdl7);

    % Step 8: both connectivity + late decoding
    f8 = sprintf('%s ~ %s%s + %s + %s', DV, cov_str, conn1, conn2, dec_late);
    mdl8 = fitlm(T, f8);
    [a8,b8] = getAICBIC(mdl8);

    % Step 9: full model (both connectivity + both decoding)
    f9 = sprintf('%s ~ %s%s + %s + %s + %s', DV, cov_str, conn1, conn2, dec_early, dec_late);
    mdl9 = fitlm(T, f9);
    [a9,b9] = getAICBIC(mdl9);

    models = {mdl0, mdl1, mdl2, mdl3, mdl4, mdl5, mdl6, mdl7, mdl8, mdl9};
    aics   = [a0, a1, a2, a3, a4, a5, a6, a7, a8, a9];
    bics   = [b0, b1, b2, b3, b4, b5, b6, b7, b8, b9];
    step_labels = {'Null', lbl1, ...
                   sprintf('%s only', conn1), ...
                   sprintf('%s only', conn2), ...
                   sprintf('%s only', dec_early), ...
                   sprintf('%s only', dec_late), ...
                   'Both connectivity', ...
                   sprintf('Both conn + %s', dec_early), ...
                   sprintf('Both conn + %s', dec_late), ...
                   'Full model'};
end

% function [models, aics, bics, step_labels] = run_iterative_decoding(...
%         T, DV, conn1, conn2, dec_early, dec_late, perf, cov_str, getAICBIC)
function [models, aics, bics, step_labels] = run_iterative_decoding(...
    T, DV, conn1, conn2, other_dec, perf, cov_str, getAICBIC)

    % Step 0: Null
    mdl0 = fitlm(T, sprintf('%s ~ 1', DV));
    [a0,b0] = getAICBIC(mdl0);
 
    % Step 1: Covariates only
    if ~isempty(cov_str)
        f1 = sprintf('%s ~ %s1', DV, cov_str);
        lbl1 = 'Age';
    else
        f1 = sprintf('%s ~ 1', DV);
        lbl1 = 'Null';
    end
    mdl1 = fitlm(T, f1);
    [a1,b1] = getAICBIC(mdl1);
 
    % Step 2: conn1 only
    f2 = sprintf('%s ~ %s%s', DV, cov_str, conn1);
    mdl2 = fitlm(T, f2);
    [a2,b2] = getAICBIC(mdl2);
 
    % Step 3: conn2 only
    f3 = sprintf('%s ~ %s%s', DV, cov_str, conn2);
    mdl3 = fitlm(T, f3);
    [a3,b3] = getAICBIC(mdl3);
 
    % Step 4: early decoding only
    f4 = sprintf('%s ~ %s%s', DV, cov_str, other_dec);
    mdl4 = fitlm(T, f4);
    [a4,b4] = getAICBIC(mdl4);
 
    % Step 5: late decoding only
    f5 = sprintf('%s ~ %s%s', DV, cov_str, other_dec);
    mdl5 = fitlm(T, f5);
    [a5,b5] = getAICBIC(mdl5);
 
    % Step 6: performance only
    f6 = sprintf('%s ~ %s%s', DV, cov_str, perf);
    mdl6 = fitlm(T, f6);
    [a6,b6] = getAICBIC(mdl6);
 
    % Step 7: both connectivity
    f7 = sprintf('%s ~ %s%s + %s', DV, cov_str, conn1, conn2);
    mdl7 = fitlm(T, f7);
    [a7,b7] = getAICBIC(mdl7);
 
    % Step 8: full model
    f8 = sprintf('%s ~ %s%s + %s + %s + %s' , DV, cov_str, conn1, conn2, other_dec, perf);
    mdl8 = fitlm(T, f8);
    [a8,b8] = getAICBIC(mdl8);
 
    models = {mdl0, mdl1, mdl2, mdl3, mdl4, mdl5, mdl6, mdl7, mdl8};
    aics   = [a0, a1, a2, a3, a4, a5, a6, a7, a8];
    bics   = [b0, b1, b2, b3, b4, b5, b6, b7, b8];
    step_labels = {'Null', lbl1, ...
                   sprintf('%s only', conn1), ...
                   sprintf('%s only', conn2), ...
                   sprintf('%s only', other_dec), ...
                   sprintf('%s only', other_dec), ...
                   sprintf('%s only', perf), ...
                   'Both connectivity', ...
                   'Full model'};
end
%% =========================================================
%  SECTION 2: LEFT HEMISPHERE — DV = Performance Accuracy
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 2: LH — DV = Performance Accuracy\n');
fprintf('=================================================\n\n');

[mods_L1, aics_L1, bics_L1, lbls_L1] = run_iterative(...
    T, DV_perf, LH_conn1, LH_conn2, LH_dec_early, LH_dec_late, cov_str, getAICBIC);

print_and_save_comparison(mods_L1, aics_L1, bics_L1, lbls_L1, ...
    'LH — DV = Performance Accuracy', ...
    fullfile(out_dir,'model_comparison_LH_PerfAcc.txt'));

plot_aicbic(aics_L1, bics_L1, lbls_L1, 'LH: DV = PerfAcc');
save_fig('aicbic_LH_PerfAcc.png');

fprintf('\nF-test: Full model vs Connectivity-only (LH, PerfAcc)\n');
ftest_print(mods_L1{7}, mods_L1{10});

save_coefficients(mods_L1{end}, 'LH_PerfAcc_full', out_dir);

%% =========================================================
%  SECTION 3: LEFT HEMISPHERE — DV = Decoding Early
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 3: LH — DV = Decoding Early Bin\n');
fprintf('=================================================\n\n');

[mods_L2a, aics_L2a, bics_L2a, lbls_L2a] = run_iterative_decoding(...
    T, LH_dec_early, LH_conn1, LH_conn2, LH_dec_late, DV_perf, cov_str, getAICBIC);
% [mods_L2a, aics_L2a, bics_L2a, lbls_L2a] = run_iterative_decoding(...
%     T, LH_dec_early, LH_conn1, LH_conn2, cov_str, getAICBIC);

print_and_save_comparison(mods_L2a, aics_L2a, bics_L2a, lbls_L2a, ...
    'LH — DV = Decoding Early', ...
    fullfile(out_dir,'model_comparison_LH_DecEarly.txt'));

save_coefficients(mods_L2a{end}, 'LH_DecEarly_full', out_dir);

%% =========================================================
%  SECTION 4: LEFT HEMISPHERE — DV = Decoding Late
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 4: LH — DV = Decoding Late Bin\n');
fprintf('=================================================\n\n');

[mods_L2b, aics_L2b, bics_L2b, lbls_L2b] = run_iterative_decoding(...
    T, LH_dec_late, LH_conn1, LH_conn2, LH_dec_early, DV_perf, cov_str, getAICBIC);
% [mods_L2b, aics_L2b, bics_L2b, lbls_L2b] = run_iterative_decoding(...
%     T, LH_dec_late, LH_conn1, LH_conn2, cov_str, getAICBIC);

print_and_save_comparison(mods_L2b, aics_L2b, bics_L2b, lbls_L2b, ...
    'LH — DV = Decoding Late', ...
    fullfile(out_dir,'model_comparison_LH_DecLate.txt'));

save_coefficients(mods_L2b{end}, 'LH_DecLate_full', out_dir);

%% =========================================================
%  SECTION 5: RIGHT HEMISPHERE — DV = Performance Accuracy
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 5: RH — DV = Performance Accuracy\n');
fprintf('=================================================\n\n');

[mods_R1, aics_R1, bics_R1, lbls_R1] = run_iterative(...
    T, DV_perf, RH_conn1, RH_conn2, RH_dec_early, RH_dec_late, cov_str, getAICBIC);

print_and_save_comparison(mods_R1, aics_R1, bics_R1, lbls_R1, ...
    'RH — DV = Performance Accuracy', ...
    fullfile(out_dir,'model_comparison_RH_PerfAcc.txt'));

plot_aicbic(aics_R1, bics_R1, lbls_R1, 'RH: DV = PerfAcc');
save_fig('aicbic_RH_PerfAcc.png');

fprintf('\nF-test: Full model vs Connectivity-only (RH, PerfAcc)\n');
ftest_print(mods_R1{7}, mods_R1{10});

save_coefficients(mods_R1{end}, 'RH_PerfAcc_full', out_dir);

%% =========================================================
%  SECTION 6: RIGHT HEMISPHERE — DV = Decoding
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 6: RH — DV = Decoding Early & Late\n');
fprintf('=================================================\n\n');

[mods_R2a, aics_R2a, bics_R2a, lbls_R2a] = run_iterative_decoding(...
    T, RH_dec_early, RH_conn1, RH_conn2, RH_dec_late, DV_perf, cov_str, getAICBIC);
% [mods_R2a, aics_R2a, bics_R2a, lbls_R2a] = run_iterative_decoding(...
%     T, RH_dec_early, RH_conn1, RH_conn2, cov_str, getAICBIC);
print_and_save_comparison(mods_R2a, aics_R2a, bics_R2a, lbls_R2a, ...
    'RH — DV = Decoding Early', ...
    fullfile(out_dir,'model_comparison_RH_DecEarly.txt'));
save_coefficients(mods_R2a{end}, 'RH_DecEarly_full', out_dir);

[mods_R2b, aics_R2b, bics_R2b, lbls_R2b] = run_iterative_decoding(...
    T, RH_dec_late, RH_conn1, RH_conn2, RH_dec_early, DV_perf, cov_str, getAICBIC);
% [mods_R2b, aics_R2b, bics_R2b, lbls_R2b] = run_iterative_decoding(...
%     T, RH_dec_late, RH_conn1, RH_conn2, cov_str, getAICBIC);
print_and_save_comparison(mods_R2b, aics_R2b, bics_R2b, lbls_R2b, ...
    'RH — DV = Decoding Late', ...
    fullfile(out_dir,'model_comparison_RH_DecLate.txt'));
save_coefficients(mods_R2b{end}, 'RH_DecLate_full', out_dir);

%% =========================================================
%  SECTION 7: SUMMARY TABLE — ALL BEST MODELS
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 7: SUMMARY — ALL BEST MODELS\n');
fprintf('=================================================\n\n');

all_models  = {mods_L1{5},  mods_L2a{end}, mods_L2b{end}, ...
               mods_R1{5},  mods_R2a{end}, mods_R2b{end}};
all_aics    = [aics_L1(end), aics_L2a(end), aics_L2b(end), ...
               aics_R1(end), aics_R2a(end), aics_R2b(end)];
all_bics    = [bics_L1(end), bics_L2a(end), bics_L2b(end), ...
               bics_R1(end), bics_R2a(end), bics_R2b(end)];
all_names   = {'LH: PerfAcc ~ conn + decoding', ...
               'LH: DecEarly ~ conn', ...
               'LH: DecLate  ~ conn', ...
               'RH: PerfAcc ~ conn + decoding', ...
               'RH: DecEarly ~ conn', ...
               'RH: DecLate  ~ conn'};

fid = fopen(fullfile(out_dir,'summary_all_models.txt'),'w');
hdr = sprintf('%-38s  %-7s  %-9s  %-8s  %-8s  %-8s  %-8s\n', ...
    'Model','R²','Adj. R²','F','p','AIC','BIC');
sep = [repmat('-',1,90) '\n'];
fprintf(hdr); fprintf(fid, hdr);
fprintf(sep); fprintf(fid, sep);

for i = 1:length(all_models)
    m = all_models{i};
    row = sprintf('%-38s  %-7.3f  %-9.3f  %-8.2f  %-8.4f  %-8.2f  %-8.2f\n', ...
        all_names{i}, ...
        m.Rsquared.Ordinary, m.Rsquared.Adjusted, ...
        m.ModelFitVsNullModel.Fstat, m.ModelFitVsNullModel.Pvalue, ...
        all_aics(i), all_bics(i));
    fprintf(row); fprintf(fid, row);
end
fclose(fid);

fprintf('\nSummary saved to %s/summary_all_models.txt\n', out_dir);
fprintf('\n=== SCRIPT 1 COMPLETE ===\n');
fprintf('Now run Script 2 (2_assumption_checks.m) on your chosen best model.\n');

diary off;

%% =========================================================
%  LOCAL HELPER FUNCTIONS
%% =========================================================

function print_and_save_comparison(models, aics, bics, labels, title_str, filepath)
    fprintf('--- %s ---\n', title_str);
    fprintf('%-40s  %-7s  %-9s  %-8s  %-8s  %-8s  %-8s\n', ...
        'Step','R²','Adj. R²','AIC','BIC','F','p');
    fprintf('%s\n', repmat('-',1,90));

    fid = fopen(filepath, 'w');
    fprintf(fid,'MODEL COMPARISON: %s\nGenerated: %s\n\n', title_str, datestr(now));
    fprintf(fid,'%-40s  %-7s  %-9s  %-8s  %-8s  %-8s  %-8s\n', ...
        'Step','R²','Adj. R²','AIC','BIC','F','p');
    fprintf(fid,'%s\n', repmat('-',1,90));

    for i = 1:length(models)
        m = models{i};
        if m.NumCoefficients > 1
            F_val = m.ModelFitVsNullModel.Fstat;
            p_val = m.ModelFitVsNullModel.Pvalue;
            r2    = m.Rsquared.Ordinary;
            r2adj = m.Rsquared.Adjusted;
        else
            F_val = NaN; p_val = NaN; r2 = 0; r2adj = 0;
        end
        % Flag best AIC and BIC
        aic_flag = ''; bic_flag = '';
        if aics(i) == min(aics), aic_flag = ' <'; end
        if bics(i) == min(bics), bic_flag = ' <'; end
        row = sprintf('%-40s  %-7.3f  %-9.3f  %-8.2f%-3s  %-8.2f%-3s  %-8.2f  %-8.4f\n', ...
            labels{i}, r2, r2adj, aics(i), aic_flag, bics(i), bic_flag, F_val, p_val);
        fprintf(row); fprintf(fid, row);
    end
    fprintf(fid,'\n< = best (lowest) value for that criterion\n');
    fclose(fid);
    fprintf('\nSaved: %s\n\n', filepath);
end

function save_coefficients(mdl, label, out_dir)
    fid = fopen(fullfile(out_dir, sprintf('coefficients_%s.txt', label)), 'w');
    fprintf(fid,'COEFFICIENTS: %s\nGenerated: %s\n\n', label, datestr(now));
    fprintf(fid,'%-25s  %-10s  %-10s  %-10s  %-10s\n', ...
        'Predictor','Estimate','SE','t','p');
    fprintf(fid,'%s\n', repmat('-',1,70));
    coef = mdl.Coefficients;
    for i = 1:height(coef)
        sig = '';
        if coef.pValue(i) < 0.05,  sig = '*';   end
        if coef.pValue(i) < 0.01,  sig = '**';  end
        if coef.pValue(i) < 0.001, sig = '***'; end
        fprintf(fid,'%-25s  %-10.4f  %-10.4f  %-10.3f  %-10.4f %s\n', ...
            coef.Properties.RowNames{i}, coef.Estimate(i), ...
            coef.SE(i), coef.tStat(i), coef.pValue(i), sig);
    end
    fprintf(fid,'\nR²=%.3f  Adj.R²=%.3f  F=%.2f  p=%.4f\n', ...
        mdl.Rsquared.Ordinary, mdl.Rsquared.Adjusted, ...
        mdl.ModelFitVsNullModel.Fstat, mdl.ModelFitVsNullModel.Pvalue);
    fclose(fid);
    fprintf('Coefficients saved: %s/coefficients_%s.txt\n', out_dir, label);
end

function plot_aicbic(aics, bics, labels, title_str)
    figure('Position',[100 100 800 400], 'Color','w');
    x = 1:length(labels);
    subplot(1,2,1);
    bar(x, aics, 'FaceColor',[0.18 0.45 0.75], 'EdgeColor','none');
    xticks(x); xticklabels(labels); xtickangle(30);
    ylabel('AIC'); title('AIC per Step');
    [~,best] = min(aics);
    hold on; bar(best, aics(best), 'FaceColor',[0.1 0.7 0.3], 'EdgeColor','none');
    legend({'','Best model'},'Location','best'); box off;

    subplot(1,2,2);
    bar(x, bics, 'FaceColor',[0.78 0.25 0.18], 'EdgeColor','none');
    xticks(x); xticklabels(labels); xtickangle(30);
    ylabel('BIC'); title('BIC per Step');
    [~,best] = min(bics);
    hold on; bar(best, bics(best), 'FaceColor',[0.1 0.7 0.3], 'EdgeColor','none');
    legend({'','Best model'},'Location','best'); box off;

    sgtitle(title_str, 'FontSize',12, 'FontWeight','bold');
end
%%
%%-------------------------------------------------------------------------
function ftest_print(mdl_reduced, mdl_full)
    RSS1   = mdl_reduced.SSR;
    RSS2   = mdl_full.SSR;
    df1    = mdl_reduced.DFE;
    df2    = mdl_full.DFE;
    p_extra = df1 - df2;

    F_stat = ((RSS1 - RSS2) / p_extra) / (RSS2 / df2);
    p_val  = 1 - fcdf(F_stat, p_extra, df2);

    fprintf('  Reduced: %s\n', mdl_reduced.Formula.char);
    fprintf('  Full:    %s\n', mdl_full.Formula.char);
    fprintf('  F(%d,%d) = %.3f,  p = %.4f', p_extra, df2, F_stat, p_val);
    if p_val < 0.001,    fprintf('  ***\n');
    elseif p_val < 0.01, fprintf('  **\n');
    elseif p_val < 0.05, fprintf('  *\n');
    else,                fprintf('  (n.s.)\n');
    end
end