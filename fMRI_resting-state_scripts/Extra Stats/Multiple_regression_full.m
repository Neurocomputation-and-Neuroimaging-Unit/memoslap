%% =========================================================
%  MULTIPLE REGRESSION — DV = perf_avg
%  All predictors (no hemisphere split) | All combinations
%  Age optional covariate | No sex
%  All outputs saved to results/ and figures/ folders
%% =========================================================
%
%  OUTPUT FILES SAVED:
%  - results/descriptives.txt               — means, SDs, ranges
%  - results/correlations_predictors.txt    — predictor Spearman correlations
%  - results/model_comparison_all.txt       — AIC/BIC table for all models
%  - results/coefficients_best_model.txt    — full model coefficients
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
data_file = 'E:\memoslap\restingstate\2ndLevel\Multiple Regression\all_avg_excl.csv';   % <-- update this

% --- Dependent variable ---
DV = 'perf_average';

% --- Predictors ---
pred_names = { ...
    'decoding_latebin_lSPL_spmClust', ...
    'connectivity_lSFG_lSPL_spmClust', ...
    'decoding_latebin_rSPL_spmClust', ...
    'connectivity_rIFG_rSPL_spmClust', ...
    'connectivity_rSPL_rS2' ...
};

% --- Age covariate ---
% Set to true to include Age as a covariate in all models
include_age   = true;   % <-- toggle here: true or false
covariate_age = 'Age';

% --- Output directories ---
out_dir = 'E:\memoslap\restingstate\2ndLevel\Multiple Regression\results_full_withage_excl';
fig_dir = 'E:\memoslap\restingstate\2ndLevel\Multiple Regression\figures_full_withage_excl';

%% =========================================================
%  SETUP
%% =========================================================

if ~exist(out_dir, 'dir'), mkdir(out_dir); end
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

diary(fullfile(out_dir, 'full_output_log.txt'));
diary on;

fprintf('=================================================\n');
fprintf('  MULTIPLE REGRESSION ANALYSIS — DV: %s\n', DV);
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
    row = sprintf('%-275s  %-5d  %-9.3f  %-9.3f  %-8.2f%-2s  %-8.2f%-2s  %-12.6f\n', ...
        all_vars{i}, mean(v,'omitnan'), std(v,'omitnan'), min(v), max(v), n);
    fprintf(row); fprintf(fid, row);
end
fclose(fid);
fprintf('Descriptives saved to %s/descriptives.txt\n', out_dir);

% --- Age correlations with DV (only if included) ---
if include_age
    fprintf('\n--- Age correlation with DV ---\n');
    [r,p] = corr(T.(covariate_age), T.(DV), 'type','Spearman','rows','complete');
    sig = '';
    if p < 0.05, sig = ' *'; end
    if p < 0.01, sig = ' **'; end
    fprintf('Age vs %s:  rho = %.3f,  p = %.4f%s\n', DV, r, p, sig);
end

% --- Distributions ---
n_vars = length(all_vars);
n_cols = min(n_vars, 6);
n_rows = ceil(n_vars / n_cols);
figure('Name','Distributions', 'Position',[50 50 min(230*n_cols,1400) 280*n_rows], 'Color','w');
for i = 1:n_vars
    subplot(n_rows, n_cols, i);
    histogram(T.(all_vars{i}), 10, 'FaceColor',[0.25 0.55 0.80], ...
              'EdgeColor','w', 'FaceAlpha',0.85);
    title(strrep(all_vars{i},'_','\_'), 'FontSize',8, 'Interpreter','tex');
    xlabel('Value','FontSize',7); ylabel('Count','FontSize',7);
    box off;
end
sgtitle(sprintf('Variable Distributions (DV: %s)', strrep(DV,'_','\_')), ...
    'FontSize',12, 'FontWeight','bold', 'Interpreter','tex');
save_fig('distributions.png');
fprintf('Figure saved: %s/distributions.png\n', fig_dir);

% --- Scatterplots: each predictor vs DV ---
% --- Scatterplots: each predictor vs DV ---
% Build extended predictor list including Age and Sex
if include_age
    scatter_preds = [pred_names, {covariate_age}];
else
    scatter_preds = pred_names;
end
% Add Sex if it exists in the table
if ismember('Sex', T.Properties.VariableNames)
    scatter_preds = [scatter_preds, {'Sex'}];
end

n_scatter = length(scatter_preds);
n_cols_s = min(n_scatter, 5);
n_rows_s = ceil(n_scatter / n_cols_s);

figure('Name','Scatterplots vs DV', ...
       'Position',[50 50 min(260*n_cols_s,1300) 260*n_rows_s], ...
       'Color','w');  % <-- white figure background

for i = 1:n_scatter
    subplot(n_rows_s, n_cols_s, i);
    
    scatter(T.(scatter_preds{i}), T.(DV), 45, [0.18 0.45 0.75], 'filled', ...
            'MarkerFaceAlpha', 0.7);
    ls = lsline;
    ls.Color = [0.3 0.3 0.3];  % dark grey fit line
    
    box off;
    
    % White axes background, black text/axes
    set(gca, 'Color', 'w', ...
             'XColor', 'k', ...
             'YColor', 'k', ...
             'FontSize', 7);
    
    % --- Format x-axis label ---
    raw = scatter_preds{i};
    formatted = format_pred_label(raw);
    
    xlabel(formatted, 'FontSize', 7, 'Color', 'k', 'Interpreter', 'none');
    ylabel(strrep(DV, '_', ' '), 'FontSize', 7, 'Color', 'k', 'Interpreter', 'none');
    
    % Spearman correlation
    [r, p] = corr(T.(scatter_preds{i}), T.(DV), 'type', 'Spearman', 'rows', 'complete');
    title(sprintf('\\rho=%.2f, p=%.3f', r, p), 'FontSize', 8, 'Color', 'k');
end

sgtitle(sprintf('Predictors vs %s', strrep(DV, '_', ' ')), ...
    'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k', 'Interpreter', 'none');

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
fprintf(fid, '%-40s', '');
for j = 1:n_preds, fprintf(fid,'%-42s', pred_names{j}); end
fprintf(fid,'\n');
for i = 1:n_preds
    fprintf(fid,'%-40s', pred_names{i});
    for j = 1:n_preds
        fprintf(fid,'%-42s', sprintf('r=%.3f (p=%.3f)', R_mat(i,j), P_mat(i,j)));
    end
    fprintf(fid,'\n');
end
fprintf(fid,'\nNOTE: |r| > 0.7 between predictors may indicate multicollinearity.\n');
fclose(fid);
fprintf('Predictor correlations saved to %s/correlations_predictors.txt\n', out_dir);

% Heatmap figure
figure('Position',[100 100 680 580], 'Color','w');
imagesc(R_mat); clim([-1 1]);
n_colors = 256;
cmap_r = [linspace(0,1,n_colors/2), ones(1,n_colors/2)]';
cmap_g = [linspace(0,1,n_colors/2), linspace(1,0,n_colors/2)]';
cmap_b = [ones(1,n_colors/2),       linspace(1,0,n_colors/2)]';
colormap([cmap_r, cmap_g, cmap_b]);
cb = colorbar; cb.Label.String = 'Spearman \rho'; cb.Label.FontSize=10;
tick_labels = strrep(pred_names,'_','\_');
xticks(1:n_preds); xticklabels(tick_labels); xtickangle(30);
yticks(1:n_preds); yticklabels(tick_labels);
ax = gca; ax.FontSize = 8;
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
             'FontSize',7, 'FontWeight','bold', 'Color',tc);
    end
end
title('Predictor Correlation Matrix','FontSize',12,'FontWeight','bold');
subtitle('* p<.05   ** p<.01   *** p<.001','FontSize',8);
axis square;
save_fig('corrmatrix_predictors.png');
fprintf('Figure saved: %s/corrmatrix_predictors.png\n', fig_dir);

%% =========================================================
%  SECTION 2: ALL INDIVIDUAL + COMBINATION MODELS
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 2: ITERATIVE MODEL BUILDING\n');
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

% --- Build all 2^n_preds - 1 non-empty subsets ---
% This covers all individual models and all combinations.
n_combos = 2^n_preds - 1;  % exclude the empty set (null)

fprintf('Building %d models (all non-empty subsets of %d predictors)...\n', n_combos, n_preds);
fprintf('Including null model');
if include_age, fprintf(' and age-only model'); end
fprintf('.\n\n');

combo_models = cell(1, n_combos);
combo_aics   = zeros(1, n_combos);
combo_bics   = zeros(1, n_combos);
combo_labels = cell(1, n_combos);

for k = 1:n_combos
    % Determine which predictors are in this subset (binary mask from k)
    bits   = dec2bin(k, n_preds) == '1';
    subset = pred_names(bits);

    % Build formula
    pred_str = strjoin(subset, ' + ');
    formula  = sprintf('%s ~ %s%s', DV, cov_str, pred_str);

    % Fit model
    mdl = fitlm(T, formula);
    [a, b] = getAICBIC(mdl);

    combo_models{k} = mdl;
    combo_aics(k)   = a;
    combo_bics(k)   = b;
    combo_labels{k} = pred_str;
end

fprintf('All models fitted.\n');

%% =========================================================
%  SECTION 3: PRINT AND SAVE RESULTS
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 3: MODEL COMPARISON\n');
fprintf('=================================================\n\n');

% Prepend null (and age if applicable) to the arrays for display
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

% Sort by AIC for display
[sorted_aics, sort_idx] = sort(all_aics);
sorted_bics   = all_bics(sort_idx);
sorted_labels = all_labels(sort_idx);
sorted_mods   = all_mods(sort_idx);

% Identify best AIC and BIC overall
[~, best_aic_idx] = min(all_aics);
[~, best_bic_idx] = min(all_bics);

% --- Print to console and save ---
fid = fopen(fullfile(out_dir, 'model_comparison_all.txt'), 'w');
hdr = sprintf('%-70s  %-5s  %-9s  %-9s  %-9s  %-9s  %-9s\n', ...
    'Model (predictors)', 'k', 'R²', 'Adj. R²', 'AIC', 'BIC', 'p');
sep_line = [repmat('-',1,125) '\n'];

fprintf('\n--- Model Comparison (sorted by AIC) ---\n\n');
fprintf(hdr); fprintf(fid, sprintf('MODEL COMPARISON: DV = %s\nDate: %s\n\n', DV, datestr(now)));
fprintf(fid, hdr);
fprintf(sep_line); fprintf(fid, sep_line);

for i = 1:n_total
    m = sorted_mods{i};
    lbl = sorted_labels{i};

    if m.NumCoefficients > 1
        r2    = m.Rsquared.Ordinary;
        r2adj = m.Rsquared.Adjusted;
        F_val = m.ModelFitVsNullModel.Fstat;
        p_val = m.ModelFitVsNullModel.Pvalue;
    else
        r2 = 0; r2adj = 0; F_val = NaN; p_val = NaN;
    end

    aic_flag = ''; bic_flag = '';
    if sorted_aics(i) == min(all_aics), aic_flag = '<'; end
    if sorted_bics(i) == min(all_bics), bic_flag = '<'; end


    row = sprintf('%-275s  %-5d  %-9.3f  %-9.3f  %-8.2f%-2s  %-8.2f%-2s  %-12.6f\n', ...
        lbl, m.NumCoefficients - 1 + include_age, ...
        r2, r2adj, sorted_aics(i), aic_flag, sorted_bics(i), bic_flag, p_val);
    fprintf(row); fprintf(fid, row);
end

fprintf(fid, '\n< = best (lowest) value for that criterion\n');
fprintf(fid, 'k = number of brain predictors (excluding intercept');
if include_age, fprintf(fid, ' and age'); end
fprintf(fid, ')\n');
fclose(fid);
fprintf('\nSaved: %s/model_comparison_all.txt\n', out_dir);

%% =========================================================
%  SECTION 4: BEST MODEL SUMMARY
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 4: BEST MODELS\n');
fprintf('=================================================\n\n');

fprintf('Best model by AIC: %s\n', all_labels{best_aic_idx});
fprintf('Best model by BIC: %s\n', all_labels{best_bic_idx});

best_mdl_aic = all_mods{best_aic_idx};
best_mdl_bic = all_mods{best_bic_idx};

fprintf('\n--- Best AIC model coefficients ---\n');
disp(best_mdl_aic.Coefficients);

fprintf('\n--- Best BIC model coefficients ---\n');
disp(best_mdl_bic.Coefficients);

% Save coefficients for best AIC model
save_coefficients(best_mdl_aic, 'best_AIC_model', out_dir);
save_coefficients(best_mdl_bic, 'best_BIC_model', out_dir);

%% =========================================================
%  SECTION 5: FULL MODEL (ALL PREDICTORS)
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 5: FULL MODEL (ALL PREDICTORS)\n');
fprintf('=================================================\n\n');

full_formula = sprintf('%s ~ %s%s', DV, cov_str, strjoin(pred_names, ' + '));
fprintf('Formula: %s\n\n', full_formula);
mdl_full = fitlm(T, full_formula);
disp(mdl_full);
save_coefficients(mdl_full, 'full_model', out_dir);

%% =========================================================
%  SECTION 6: SUMMARY TABLE
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 6: SUMMARY TABLE\n');
fprintf('=================================================\n\n');

summary_models  = {best_mdl_aic, best_mdl_bic, mdl_full};
summary_names   = { ...
    sprintf('Best AIC: %s', all_labels{best_aic_idx}), ...
    sprintf('Best BIC: %s', all_labels{best_bic_idx}), ...
    'Full model (all predictors)' ...
};
summary_aics    = [all_aics(best_aic_idx), all_aics(best_bic_idx), ...
                   all_aics(strcmp(all_labels, strjoin(pred_names,' + ')))];
summary_bics    = [all_bics(best_aic_idx), all_bics(best_bic_idx), ...
                   all_bics(strcmp(all_labels, strjoin(pred_names,' + ')))];

fid = fopen(fullfile(out_dir,'summary_all_models.txt'),'w');
hdr2 = sprintf('%-60s  %-7s  %-9s  %-8s  %-8s  %-8s  %-8s\n', ...
    'Model','R²','Adj. R²','F','p','AIC','BIC');
sep2 = [repmat('-',1,115) '\n'];
fprintf(hdr2); fprintf(fid, hdr2);
fprintf(sep2);  fprintf(fid, sep2);

for i = 1:length(summary_models)
    m = summary_models{i};
    % Truncate label
    lbl_s = summary_names{i};
    if length(lbl_s) > 58, lbl_s = [lbl_s(1:55) '...']; end
    row = sprintf('%-60s  %-7.3f  %-9.3f  %-8.2f  %-12.6f  %-8.2f  %-8.2f\n', ...
        lbl_s, ...
        m.Rsquared.Ordinary, m.Rsquared.Adjusted, ...
        m.ModelFitVsNullModel.Fstat, m.ModelFitVsNullModel.Pvalue, ...
        summary_aics(i), summary_bics(i));
    fprintf(row); fprintf(fid, row);
end
fclose(fid);
fprintf('\nSummary saved to %s/summary_all_models.txt\n', out_dir);

%% =========================================================
%  SECTION 7: AIC/BIC FIGURES
%% =========================================================

fprintf('\n=================================================\n');
fprintf('  SECTION 7: FIGURES\n');
fprintf('=================================================\n\n');

% Plot top 20 models sorted by AIC (plotting all 2^9=511 models is too dense)
n_plot = min(20, n_total);
top_labels_plot = sorted_labels(1:n_plot);
top_aics_plot   = sorted_aics(1:n_plot);
top_bics_plot   = sorted_bics(1:n_plot);

% Shorten labels for the plot
short_labels = cell(1, n_plot);
for i = 1:n_plot
    sl = sorted_labels{i};
    % Replace known predictor names with compact codes
    sl = strrep(sl, 'connectivity_lIFG_lSPL_spmClust',  'cLIFG');
    sl = strrep(sl, 'connectivity_lSFG_lSPL_spmClust',  'cLSFG');
    sl = strrep(sl, 'connectivity_rIFG_rSPL_spmClust',  'cRIFG');
    sl = strrep(sl, 'connectivity_rSFG_rSPL_spmClust',  'cRSFG');
    sl = strrep(sl, 'connectivity_lSPL_rS2',            'cLSPL');
    sl = strrep(sl, 'connectivity_rSPL_rS2',            'cRSPL');
    sl = strrep(sl, 'decoding_latebin_lSPL_spmClust',   'dLlate');
    sl = strrep(sl, 'decoding_latebin_rSPL_spmClust',   'dRlate');
    sl = strrep(sl, 'decoding_earlybin_rS2',            'dRearly');
    sl = strrep(sl, ' + ', '+');
    short_labels{i} = sl;
end

figure('Position',[100 100 1000 420], 'Color','w');
x = 1:n_plot;

subplot(1,2,1);
bar(x, top_aics_plot, 'FaceColor',[0.18 0.45 0.75], 'EdgeColor','none');
xticks(x); xticklabels(short_labels); xtickangle(40);
ylabel('AIC','FontSize',11); title(sprintf('Top %d Models by AIC', n_plot),'FontSize',11);
hold on; bar(1, top_aics_plot(1), 'FaceColor',[0.1 0.7 0.3], 'EdgeColor','none');
legend({'Other','Best AIC'},'Location','best'); box off;

subplot(1,2,2);
[sorted_bics_plot, bic_plot_idx] = sort(top_bics_plot);
bar(x, sorted_bics_plot, 'FaceColor',[0.78 0.25 0.18], 'EdgeColor','none');
xticks(x); xticklabels(short_labels(bic_plot_idx)); xtickangle(40);
ylabel('BIC','FontSize',11); title(sprintf('Top %d Models by BIC', n_plot),'FontSize',11);
hold on; bar(1, sorted_bics_plot(1), 'FaceColor',[0.1 0.7 0.3], 'EdgeColor','none');
legend({'Other','Best BIC'},'Location','best'); box off;

sgtitle(sprintf('Model Comparison — DV: %s  (Age: %s)', ...
    strrep(DV,'_','\_'), mat2str(include_age)), ...
    'FontSize',12,'FontWeight','bold','Interpreter','tex');
save_fig('aicbic_all_models.png');
fprintf('Figure saved: %s/aicbic_all_models.png\n', fig_dir);

fprintf('\n=== SCRIPT COMPLETE ===\n');
fprintf('Total models evaluated: %d\n', n_total);
fprintf('Best AIC model: %s\n', all_labels{best_aic_idx});
fprintf('Best BIC model: %s\n', all_labels{best_bic_idx});
fprintf('\nNow run assumption checks (2_assumption_checks.m) on your chosen model.\n');

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

function label = format_pred_label(raw)

% Converts raw variable names to clean figure labels.

    % --- Connectivity renaming ---
    % Pattern: connectivity_X_Y_spmClust  -->  Y-X RS-FC
    % (spmClust is dropped; hemisphere prefix kept)
    conn_pattern = '^connectivity_([a-zA-Z0-9]+)_([a-zA-Z0-9]+)(_spmClust)?$';
    tok = regexp(raw, conn_pattern, 'tokens');
    if ~isempty(tok)
        roi1 = tok{1}{1};  % e.g. lIFG
        roi2 = tok{1}{2};  % e.g. lSPL
        label = sprintf('%s-%s RS-FC', roi2, roi1);
        return;
    end

    % --- Decoding renaming ---
    % decoding_latebin_XSPL_spmClust  -->  Late-delay XSPL decoding accuracy
    % decoding_earlybin_XS2           -->  Early-delay XS2 decoding accuracy
    dec_pattern = '^decoding_(early|late)bin_([a-zA-Z0-9]+?)(_spmClust)?$';
    tok = regexp(raw, dec_pattern, 'tokens');
    if ~isempty(tok)
        timing = tok{1}{1};  % early / late
        roi    = tok{1}{2};  % e.g. rSPL, rS2
        timing_str = [upper(timing(1)) timing(2:end)];  % Early / Late
        label = sprintf('%s-delay %s decoding accuracy', timing_str, roi);
        return;
    end

    % --- Age / Sex / anything else: just clean underscores ---
    label = strrep(raw, '_', ' ');
end