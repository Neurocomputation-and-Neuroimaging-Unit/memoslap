%% =========================================================
%  MULTIPLE REGRESSION — DV = perf
%  Predictors: decoding_earlybin_rS2, connectivity_rSPL_rS2,
%              connectivity_lSPL_rS2
%  Age optional covariate | No sex
%  All individual + combination models
%  All outputs saved to results/ and figures/ folders
%% =========================================================
%
%  OUTPUT FILES SAVED:
%  - results/descriptives.txt               — means, SDs, ranges
%  - results/correlations_predictors.txt    — predictor Spearman correlations
%  - results/model_comparison_all.txt       — AIC/BIC table for all models
%  - results/coefficients_best_AIC_model.txt
%  - results/coefficients_best_BIC_model.txt
%  - results/coefficients_full_model.txt
%  - results/summary_all_models.txt         — one-page summary table
%  - figures/distributions.png
%  - figures/scatterplots.png
%  - figures/corrmatrix_predictors.png
%  - figures/aicbic_all_models.png
%
%% =========================================================

clear; clc; close all;

%% =========================================================
%  CONFIG — UPDATE THESE TO MATCH YOUR FILE AND PATHS
%% =========================================================

% --- File path ---
data_file = 'E:\memoslap\restingstate\2ndLevel\Multiple Regression\all_average_conn_dec_perf.csv';   % <-- update this

% --- Dependent variable ---
DV = 'perf_average';

% --- Predictors ---
pred_names = { ...
    'decoding_earlybin_rS2', ...
    'connectivity_rSPL_rS2', ...
    'connectivity_lSPL_rS2'  ...
};

% --- Age covariate ---
% Set to true to include Age as a covariate in all models
include_age   = false;   % <-- toggle here: true or false
covariate_age = 'Age';

% --- Output directories ---
out_dir = 'E:\memoslap\restingstate\2ndLevel\Multiple Regression\results_rs2_noage';
fig_dir = 'E:\memoslap\restingstate\2ndLevel\Multiple Regression\figures_rs2_noage';

%% =========================================================
%  SETUP
%% =========================================================

if ~exist(out_dir, 'dir'), mkdir(out_dir); end
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

diary(fullfile(out_dir, 'full_output_log.txt'));
diary on;

fprintf('=================================================\n');
fprintf('  MULTIPLE REGRESSION ANALYSIS — DV: %s\n', DV);
fprintf('  Predictors: %s\n', strjoin(pred_names, ', '));
fprintf('  Include age: %s\n', mat2str(include_age));
fprintf('  Run date: %s\n', datestr(now));
fprintf('=================================================\n\n');

%% =========================================================
%  LOAD DATA
%% =========================================================

T = readtable(data_file);

fprintf('Data loaded: %d subjects, %d variables\n', height(T), width(T));
fprintf('Columns: %s\n\n', strjoin(T.Properties.VariableNames, ', '));

%% =========================================================
%  HELPER FUNCTIONS
%% =========================================================

% AIC and BIC from fitlm object
getAICBIC = @(m) deal( ...
    -2 * m.LogLikelihood + 2 * m.NumCoefficients, ...
    -2 * m.LogLikelihood + m.NumCoefficients * log(m.NumObservations));

% Covariate prefix string for formulas
if include_age
    cov_str = sprintf('%s + ', covariate_age);
else
    cov_str = '';
end

% Save figure helper
save_fig = @(fname) exportgraphics(gcf, fullfile(fig_dir, fname), 'Resolution', 200);

n_preds = length(pred_names);

%% =========================================================
%  SECTION 1: PRELIMINARY CHECKS
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 1: PRELIMINARY CHECKS\n');
fprintf('=================================================\n\n');

% --- Descriptive statistics ---
if include_age
    all_vars = [{DV}, {covariate_age}, pred_names];
else
    all_vars = [{DV}, pred_names];
end

fid = fopen(fullfile(out_dir, 'descriptives.txt'), 'w');
fprintf(fid, 'DESCRIPTIVE STATISTICS\nGenerated: %s\n\n', datestr(now));
header = sprintf('%-40s  %-8s  %-8s  %-8s  %-8s  %-6s\n', ...
    'Variable','Mean','SD','Min','Max','N');
fprintf(header); fprintf(fid, header);
sep = [repmat('-',1,78) '\n'];
fprintf(sep); fprintf(fid, sep);

for i = 1:length(all_vars)
    v = T.(all_vars{i});
    n = sum(~isnan(v));
    row = sprintf('%-40s  %-8.3f  %-8.3f  %-8.3f  %-8.3f  %-6d\n', ...
        all_vars{i}, mean(v,'omitnan'), std(v,'omitnan'), min(v), max(v), n);
    fprintf(row); fprintf(fid, row);
end
fclose(fid);
fprintf('Descriptives saved to %s/descriptives.txt\n', out_dir);

% --- Age correlation with DV (only if included) ---
if include_age
    fprintf('\n--- Age correlation with DV ---\n');
    [r,p] = corr(T.(covariate_age), T.(DV), 'type','Spearman','rows','complete');
    sig = '';
    if p < 0.05, sig = ' *'; end
    if p < 0.01, sig = ' **'; end
    fprintf('Age vs %s:  rho = %.3f,  p = %.4f%s\n', DV, r, p, sig);
end

% --- Distributions ---
n_vars  = length(all_vars);
figure('Name','Distributions', 'Position',[50 50 280*n_vars 280], 'Color','w');
for i = 1:n_vars
    subplot(1, n_vars, i);
    histogram(T.(all_vars{i}), 10, 'FaceColor',[0.25 0.55 0.80], ...
              'EdgeColor','w', 'FaceAlpha',0.85);
    title(strrep(all_vars{i},'_','\_'), 'FontSize',9, 'Interpreter','tex');
    xlabel('Value','FontSize',8); ylabel('Count','FontSize',8);
    box off;
end
sgtitle(sprintf('Variable Distributions (DV: %s)', strrep(DV,'_','\_')), ...
    'FontSize',12,'FontWeight','bold','Interpreter','tex');
save_fig('distributions.png');
fprintf('Figure saved: %s/distributions.png\n', fig_dir);

% --- Scatterplots: each predictor vs DV ---
figure('Name','Scatterplots vs DV', ...
       'Position',[50 50 300*n_preds 300], 'Color','w');
for i = 1:n_preds
    subplot(1, n_preds, i);
    scatter(T.(pred_names{i}), T.(DV), 50, [0.18 0.45 0.75], 'filled', ...
            'MarkerFaceAlpha',0.7);
    lsline; box off;
    xlabel(strrep(pred_names{i},'_','\_'),'FontSize',8,'Interpreter','tex');
    ylabel(strrep(DV,'_','\_'),'FontSize',8,'Interpreter','tex');
    [r,p] = corr(T.(pred_names{i}), T.(DV), 'type','Spearman','rows','complete');
    sig = '';
    if p < 0.05, sig = '*'; end
    if p < 0.01, sig = '**'; end
    if p < 0.001, sig = '***'; end
    title(sprintf('\\rho=%.2f, p=%.3f %s', r, p, sig), 'FontSize',9);
end
sgtitle(sprintf('Predictors vs %s', strrep(DV,'_','\_')), ...
    'FontSize',12,'FontWeight','bold','Interpreter','tex');
save_fig('scatterplots.png');
fprintf('Figure saved: %s/scatterplots.png\n', fig_dir);

% --- Predictor correlation matrix ---
pred_mat = zeros(height(T), n_preds);
for i = 1:n_preds
    pred_mat(:,i) = T.(pred_names{i});
end
[R_mat, P_mat] = corr(pred_mat, 'type','Spearman','rows','complete');

fid = fopen(fullfile(out_dir, 'correlations_predictors.txt'), 'w');
fprintf(fid, 'PREDICTOR CORRELATIONS (Spearman rho, p-value)\nGenerated: %s\n\n', datestr(now));
fprintf(fid, '%-35s', '');
for j = 1:n_preds, fprintf(fid,'%-35s', pred_names{j}); end
fprintf(fid,'\n');
for i = 1:n_preds
    fprintf(fid,'%-35s', pred_names{i});
    for j = 1:n_preds
        fprintf(fid,'%-35s', sprintf('r=%.3f (p=%.3f)', R_mat(i,j), P_mat(i,j)));
    end
    fprintf(fid,'\n');
end
fprintf(fid,'\nNOTE: |r| > 0.7 may indicate multicollinearity.\n');
fclose(fid);
fprintf('Predictor correlations saved to %s/correlations_predictors.txt\n', out_dir);

% Heatmap figure
figure('Position',[100 100 480 420], 'Color','w');
imagesc(R_mat); clim([-1 1]);
n_colors = 256;
cmap_r = [linspace(0,1,n_colors/2), ones(1,n_colors/2)]';
cmap_g = [linspace(0,1,n_colors/2), linspace(1,0,n_colors/2)]';
cmap_b = [ones(1,n_colors/2),       linspace(1,0,n_colors/2)]';
colormap([cmap_r, cmap_g, cmap_b]);
cb = colorbar; cb.Label.String = 'Spearman \rho'; cb.Label.FontSize = 10;
tick_labels = strrep(pred_names,'_','\_');
xticks(1:n_preds); xticklabels(tick_labels); xtickangle(25);
yticks(1:n_preds); yticklabels(tick_labels);
ax = gca; ax.FontSize = 9;
for i = 1:n_preds
    for j = 1:n_preds
        if i == j
            txt = '—';
        else
            stars = '';
            if P_mat(i,j) < 0.001, stars = '***';
            elseif P_mat(i,j) < 0.01, stars = '**';
            elseif P_mat(i,j) < 0.05, stars = '*'; end
            txt = sprintf('%.2f%s', R_mat(i,j), stars);
        end
        tc = 'k';
        if abs(R_mat(i,j)) > 0.6, tc = 'w'; end
        text(j, i, txt, 'HorizontalAlignment','center', ...
             'FontSize',9, 'FontWeight','bold', 'Color',tc);
    end
end
title('Predictor Correlation Matrix','FontSize',12,'FontWeight','bold');
subtitle('* p<.05   ** p<.01   *** p<.001','FontSize',8);
axis square;
save_fig('corrmatrix_predictors.png');
fprintf('Figure saved: %s/corrmatrix_predictors.png\n', fig_dir);

%% =========================================================
%  SECTION 2: ALL INDIVIDUAL + COMBINATION MODELS
%  With 3 predictors: 2^3 - 1 = 7 non-empty subsets
%    Individual (k=1): dec_early | conn_rSPL | conn_lSPL
%    Pairs     (k=2): dec+conn_rSPL | dec+conn_lSPL | conn_rSPL+conn_lSPL
%    Full      (k=3): dec + conn_rSPL + conn_lSPL
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 2: ALL MODELS (individual + combinations)\n');
fprintf('  DV = %s  |  %d predictors  |  Age: %s\n', DV, n_preds, mat2str(include_age));
fprintf('=================================================\n\n');

% --- Null model ---
mdl_null = fitlm(T, sprintf('%s ~ 1', DV));
[a_null, b_null] = getAICBIC(mdl_null);

% --- Age-only model (if applicable) ---
if include_age
    mdl_age = fitlm(T, sprintf('%s ~ %s', DV, covariate_age));
    [a_age, b_age] = getAICBIC(mdl_age);
end

% --- All 2^3 - 1 = 7 non-empty subsets ---
n_combos     = 2^n_preds - 1;
combo_models = cell(1, n_combos);
combo_aics   = zeros(1, n_combos);
combo_bics   = zeros(1, n_combos);
combo_labels = cell(1, n_combos);

fprintf('Building %d models (all non-empty subsets of %d predictors):\n\n', n_combos, n_preds);

for k = 1:n_combos
    bits   = dec2bin(k, n_preds) == '1';
    subset = pred_names(bits);
    pred_str = strjoin(subset, ' + ');
    formula  = sprintf('%s ~ %s%s', DV, cov_str, pred_str);

    mdl = fitlm(T, formula);
    [a, b] = getAICBIC(mdl);

    combo_models{k} = mdl;
    combo_aics(k)   = a;
    combo_bics(k)   = b;
    combo_labels{k} = pred_str;

    fprintf('  Model %2d: %s\n', k, formula);
end

fprintf('\nAll models fitted.\n');

%% =========================================================
%  SECTION 3: PRINT AND SAVE MODEL COMPARISON
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 3: MODEL COMPARISON\n');
fprintf('=================================================\n\n');

% Assemble full list: null, (age), all combos
if include_age
    all_mods   = [{mdl_null}, {mdl_age}, combo_models];
    all_aics   = [a_null, a_age, combo_aics];
    all_bics   = [b_null, b_age, combo_bics];
    all_labels = [{'Null'}, {'Age only'}, combo_labels];
else
    all_mods   = [{mdl_null}, combo_models];
    all_aics   = [a_null, combo_aics];
    all_bics   = [b_null, combo_bics];
    all_labels = [{'Null'}, combo_labels];
end

n_total = length(all_mods);

% Sort by AIC
[~, sort_idx]   = sort(all_aics);
sorted_mods     = all_mods(sort_idx);
sorted_aics     = all_aics(sort_idx);
sorted_bics     = all_bics(sort_idx);
sorted_labels   = all_labels(sort_idx);

[~, best_aic_idx] = min(all_aics);
[~, best_bic_idx] = min(all_bics);

fid = fopen(fullfile(out_dir, 'model_comparison_all.txt'), 'w');
hdr = sprintf('%-65s  %-5s  %-7s  %-9s  %-10s  %-10s  %-9s\n', ...
    'Model (predictors)', 'k', 'R²', 'Adj. R²', 'AIC', 'BIC', 'p');
sep_line = [repmat('-',1,120) '\n'];

fprintf('--- Model Comparison (sorted by AIC) ---\n\n');
fprintf(fid, 'MODEL COMPARISON: DV = %s\nDate: %s\n', DV, datestr(now));
fprintf(fid, 'Include age: %s\n\n', mat2str(include_age));
fprintf(hdr); fprintf(fid, hdr);
fprintf(sep_line); fprintf(fid, sep_line);

for i = 1:n_total
    m   = sorted_mods{i};
    lbl = sorted_labels{i};

    if m.NumCoefficients > 1
        r2    = m.Rsquared.Ordinary;
        r2adj = m.Rsquared.Adjusted;
        p_val = m.ModelFitVsNullModel.Pvalue;
    else
        r2 = 0; r2adj = 0; p_val = NaN;
    end

    aic_flag = ''; bic_flag = '';
    if sorted_aics(i) == min(all_aics), aic_flag = '<'; end
    if sorted_bics(i) == min(all_bics), bic_flag = '<'; end

    % Count brain predictors (excluding intercept and age)
    k_preds = sum(dec2bin(find(strcmp(all_labels, sorted_labels{i})) - 1 - include_age, n_preds) == '1');
    if strcmp(sorted_labels{i}, 'Null') || strcmp(sorted_labels{i}, 'Age only')
        k_preds = 0;
    end

    row = sprintf('%-65s  %-5d  %-7.3f  %-9.3f  %-8.2f%-3s  %-8.2f%-3s  %-9.4f\n', ...
        lbl, k_preds, r2, r2adj, ...
        sorted_aics(i), aic_flag, sorted_bics(i), bic_flag, p_val);
    fprintf(row); fprintf(fid, row);
end

fprintf(fid, '\n< = best (lowest) value for that criterion\n');
fprintf(fid, 'k = number of brain predictors\n');
fclose(fid);
fprintf('\nSaved: %s/model_comparison_all.txt\n', out_dir);

%% =========================================================
%  SECTION 4: F-TESTS (nested model comparisons)
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 4: F-TESTS (nested comparisons)\n');
fprintf('=================================================\n\n');

% Individual models
dec_idx   = find(strcmp(all_labels, pred_names{1}));
rSPL_idx  = find(strcmp(all_labels, pred_names{2}));
lSPL_idx  = find(strcmp(all_labels, pred_names{3}));
full_idx  = find(strcmp(all_labels, strjoin(pred_names, ' + ')));

% Connectivity-only pair
conn_pair_label = sprintf('%s + %s', pred_names{2}, pred_names{3});
conn_pair_idx   = find(strcmp(all_labels, conn_pair_label));

fprintf('F-test: Full model vs decoding only\n');
ftest_print(all_mods{dec_idx}, all_mods{full_idx});

fprintf('\nF-test: Full model vs connectivity pair only\n');
ftest_print(all_mods{conn_pair_idx}, all_mods{full_idx});

%% =========================================================
%  SECTION 5: BEST MODEL & FULL MODEL COEFFICIENTS
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 5: BEST MODELS\n');
fprintf('=================================================\n\n');

fprintf('Best model by AIC: %s\n', all_labels{best_aic_idx});
fprintf('Best model by BIC: %s\n\n', all_labels{best_bic_idx});

fprintf('--- Best AIC model ---\n');
disp(all_mods{best_aic_idx}.Coefficients);

fprintf('--- Best BIC model ---\n');
disp(all_mods{best_bic_idx}.Coefficients);

fprintf('--- Full model (all 3 predictors) ---\n');
disp(all_mods{full_idx}.Coefficients);

save_coefficients(all_mods{best_aic_idx}, 'best_AIC_model', out_dir);
save_coefficients(all_mods{best_bic_idx}, 'best_BIC_model', out_dir);
save_coefficients(all_mods{full_idx},     'full_model',     out_dir);

%% =========================================================
%  SECTION 6: SUMMARY TABLE
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 6: SUMMARY TABLE\n');
fprintf('=================================================\n\n');

summary_mods  = {all_mods{best_aic_idx}, all_mods{best_bic_idx}, all_mods{full_idx}};
summary_names = { ...
    sprintf('Best AIC: %s', all_labels{best_aic_idx}), ...
    sprintf('Best BIC: %s', all_labels{best_bic_idx}), ...
    'Full model (all 3 predictors)' ...
};

fid = fopen(fullfile(out_dir,'summary_all_models.txt'),'w');
hdr2 = sprintf('%-55s  %-7s  %-9s  %-8s  %-8s  %-8s  %-8s\n', ...
    'Model','R²','Adj. R²','F','p','AIC','BIC');
sep2 = [repmat('-',1,105) '\n'];
fprintf(hdr2); fprintf(fid, hdr2);
fprintf(sep2);  fprintf(fid, sep2);

for i = 1:length(summary_mods)
    m    = summary_mods{i};
    lbl_s = summary_names{i};
    if length(lbl_s) > 53, lbl_s = [lbl_s(1:50) '...']; end
    [a_s, b_s] = getAICBIC(m);
    row = sprintf('%-55s  %-7.3f  %-9.3f  %-8.2f  %-8.4f  %-8.2f  %-8.2f\n', ...
        lbl_s, ...
        m.Rsquared.Ordinary, m.Rsquared.Adjusted, ...
        m.ModelFitVsNullModel.Fstat, m.ModelFitVsNullModel.Pvalue, ...
        a_s, b_s);
    fprintf(row); fprintf(fid, row);
end
fclose(fid);
fprintf('\nSummary saved to %s/summary_all_models.txt\n', out_dir);

%% =========================================================
%  SECTION 7: AIC/BIC FIGURE (all 7 models)
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 7: FIGURES\n');
fprintf('=================================================\n\n');

% Compact labels for plot
short_labels = cell(1, n_total);
for i = 1:n_total
    sl = all_labels{i};
    sl = strrep(sl, 'decoding_earlybin_rS2',  'dec_early');
    sl = strrep(sl, 'connectivity_rSPL_rS2',  'conn_rSPL');
    sl = strrep(sl, 'connectivity_lSPL_rS2',  'conn_lSPL');
    sl = strrep(sl, ' + ', '+');
    short_labels{i} = sl;
end

% Sort for AIC plot
[sorted_aics_plot, idx_a] = sort(all_aics);
[sorted_bics_plot, idx_b] = sort(all_bics);

figure('Position',[100 100 1000 400], 'Color','w');

subplot(1,2,1);
bar(1:n_total, sorted_aics_plot, 'FaceColor',[0.18 0.45 0.75], 'EdgeColor','none');
hold on; bar(1, sorted_aics_plot(1), 'FaceColor',[0.1 0.7 0.3], 'EdgeColor','none');
xticks(1:n_total); xticklabels(short_labels(idx_a)); xtickangle(35);
ylabel('AIC','FontSize',11); title('Models ranked by AIC','FontSize',11);
legend({'Other','Best AIC'},'Location','best'); box off;

subplot(1,2,2);
bar(1:n_total, sorted_bics_plot, 'FaceColor',[0.78 0.25 0.18], 'EdgeColor','none');
hold on; bar(1, sorted_bics_plot(1), 'FaceColor',[0.1 0.7 0.3], 'EdgeColor','none');
xticks(1:n_total); xticklabels(short_labels(idx_b)); xtickangle(35);
ylabel('BIC','FontSize',11); title('Models ranked by BIC','FontSize',11);
legend({'Other','Best BIC'},'Location','best'); box off;

sgtitle(sprintf('Model Comparison — DV: %s  (Age: %s)', ...
    strrep(DV,'_','\_'), mat2str(include_age)), ...
    'FontSize',12,'FontWeight','bold','Interpreter','tex');
save_fig('aicbic_all_models.png');
fprintf('Figure saved: %s/aicbic_all_models.png\n', fig_dir);

fprintf('\n=== SCRIPT COMPLETE ===\n');
fprintf('Total models evaluated: %d (null');
if include_age, fprintf(' + age-only'); end
fprintf(' + %d predictor subsets)\n', n_combos);
fprintf('Best AIC model: %s\n', all_labels{best_aic_idx});
fprintf('Best BIC model: %s\n', all_labels{best_bic_idx});
fprintf('\nNow run assumption checks on your chosen best model.\n');

diary off;

%% =========================================================
%  LOCAL HELPER FUNCTIONS
%% =========================================================

function save_coefficients(mdl, label, out_dir)
    fid = fopen(fullfile(out_dir, sprintf('coefficients_%s.txt', label)), 'w');
    fprintf(fid,'COEFFICIENTS: %s\nGenerated: %s\n\n', label, datestr(now));
    fprintf(fid,'Formula: %s\n\n', mdl.Formula.char);
    fprintf(fid,'%-30s  %-10s  %-10s  %-10s  %-10s\n', ...
        'Predictor','Estimate','SE','t','p');
    fprintf(fid,'%s\n', repmat('-',1,75));
    coef = mdl.Coefficients;
    for i = 1:height(coef)
        sig = '';
        if coef.pValue(i) < 0.05,  sig = '*';   end
        if coef.pValue(i) < 0.01,  sig = '**';  end
        if coef.pValue(i) < 0.001, sig = '***'; end
        fprintf(fid,'%-30s  %-10.4f  %-10.4f  %-10.3f  %-10.4f %s\n', ...
            coef.Properties.RowNames{i}, coef.Estimate(i), ...
            coef.SE(i), coef.tStat(i), coef.pValue(i), sig);
    end
    fprintf(fid,'\nR²=%.3f  Adj.R²=%.3f  F=%.2f  p=%.4f\n', ...
        mdl.Rsquared.Ordinary, mdl.Rsquared.Adjusted, ...
        mdl.ModelFitVsNullModel.Fstat, mdl.ModelFitVsNullModel.Pvalue);
    fclose(fid);
    fprintf('Coefficients saved: %s/coefficients_%s.txt\n', out_dir, label);
end

function ftest_print(mdl_reduced, mdl_full)
    RSS1    = mdl_reduced.SSR;
    RSS2    = mdl_full.SSR;
    df1     = mdl_reduced.DFE;
    df2     = mdl_full.DFE;
    p_extra = df1 - df2;
    F_stat  = ((RSS1 - RSS2) / p_extra) / (RSS2 / df2);
    p_val   = 1 - fcdf(F_stat, p_extra, df2);
    fprintf('  Reduced: %s\n', mdl_reduced.Formula.char);
    fprintf('  Full:    %s\n', mdl_full.Formula.char);
    fprintf('  F(%d,%d) = %.3f,  p = %.4f', p_extra, df2, F_stat, p_val);
    if p_val < 0.001,    fprintf('  ***\n');
    elseif p_val < 0.01, fprintf('  **\n');
    elseif p_val < 0.05, fprintf('  *\n');
    else,                fprintf('  (n.s.)\n');
    end
end
