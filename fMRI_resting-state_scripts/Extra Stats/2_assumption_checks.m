%% =========================================================
%  SCRIPT 2: ASSUMPTION CHECKS
%  Run this AFTER Script 1 (1_multiple_regression.m)
%  Pick whichever model had the best AIC/BIC from Script 1
%  All figures and results saved automatically
%% =========================================================
%
%  ASSUMPTIONS TESTED:
%  1. Linearity          — Residuals vs Fitted plot
%  2. Normality          — QQ plot + Shapiro-Wilk test
%  3. Homoscedasticity   — Scale-Location plot + Breusch-Pagan test
%  4. Outliers/Influence — Cook's Distance + Studentized residuals
%  5. Multicollinearity  — Variance Inflation Factor (VIF)
%
%  OUTPUT FILES SAVED:
%  - figures/assumptions_[MODEL_LABEL].png
%  - results/assumption_checks_[MODEL_LABEL].txt
%
%% =========================================================

clear; clc; close all;

%% =========================================================
%  STEP 1: MAKE SURE SCRIPT 1 HAS BEEN RUN
%% =========================================================

% Check that the models from Script 1 exist in the workspace
required_vars = {'mods_L1','mods_L2a','mods_L2b','mods_R1','mods_R2a','mods_R2b'};
missing = {};
for i = 1:length(required_vars)
    if ~evalin('base', sprintf('exist(''%s'',''var'')', required_vars{i}))
        missing{end+1} = required_vars{i};
    end
end

if ~isempty(missing)
    error(['Script 1 must be run first (or its workspace saved and loaded).\n' ...
           'Missing variables: %s\n' ...
           'Run 1_multiple_regression.m first, then come back here.'], ...
           strjoin(missing, ', '));
end

% Load models from base workspace
mods_L1  = evalin('base','mods_L1');
mods_L2a = evalin('base','mods_L2a');
mods_L2b = evalin('base','mods_L2b');
mods_R1  = evalin('base','mods_R1');
mods_R2a = evalin('base','mods_R2a');
mods_R2b = evalin('base','mods_R2b');

%% =========================================================
%  STEP 2: CHOOSE YOUR MODEL
%% =========================================================
%
%  Look at the AIC/BIC table printed by Script 1
%  (also in results/summary_all_models.txt)
%  and pick the best-fitting model below.
%
%  OPTIONS:
%    'LH_PerfAcc'    — LH full model, DV = Performance Accuracy
%    'LH_DecEarly'   — LH model, DV = Decoding Early bin
%    'LH_DecLate'    — LH model, DV = Decoding Late bin
%    'RH_PerfAcc'    — RH full model, DV = Performance Accuracy
%    'RH_DecEarly'   — RH model, DV = Decoding Early bin
%    'RH_DecLate'    — RH model, DV = Decoding Late bin
%
%  ---> SET THIS TO YOUR CHOSEN MODEL <---
chosen_model = 'LH_PerfAcc';

% Output folders
out_dir = 'results';
fig_dir = 'figures';
if ~exist(out_dir,'dir'), mkdir(out_dir); end
if ~exist(fig_dir,'dir'), mkdir(fig_dir); end

%% =========================================================
%  STEP 3: LOAD CHOSEN MODEL
%% =========================================================

switch chosen_model
    case 'LH_PerfAcc'
        mdl = mods_L1{end};     % full model = last in cell array
    case 'LH_DecEarly'
        mdl = mods_L2a{end};
    case 'LH_DecLate'
        mdl = mods_L2b{end};
    case 'RH_PerfAcc'
        mdl = mods_R1{end};
    case 'RH_DecEarly'
        mdl = mods_R2a{end};
    case 'RH_DecLate'
        mdl = mods_R2b{end};
    otherwise
        error('Unknown model: %s. Check spelling against the options listed above.', chosen_model);
end

fprintf('=================================================\n');
fprintf('  ASSUMPTION CHECKS: %s\n', chosen_model);
fprintf('  Model formula: %s\n', mdl.Formula.char);
fprintf('  N = %d observations\n', mdl.NumObservations);
fprintf('=================================================\n\n');

% Extract key quantities
residuals    = mdl.Residuals.Raw;
res_stud     = mdl.Residuals.Studentized;
fitted       = mdl.Fitted;
n            = mdl.NumObservations;
k            = mdl.NumCoefficients - 1;   % excluding intercept

% Open results log
log_file = fullfile(out_dir, sprintf('assumption_checks_%s.txt', chosen_model));
fid = fopen(log_file, 'w');
fprintf(fid, 'ASSUMPTION CHECKS: %s\n', chosen_model);
fprintf(fid, 'Model formula: %s\n', mdl.Formula.char);
fprintf(fid, 'Generated: %s\n\n', datestr(now));

%% =========================================================
%  ASSUMPTION 1: LINEARITY
%  Residuals vs Fitted — should show no pattern
%% =========================================================

fprintf('--- ASSUMPTION 1: Linearity (Residuals vs Fitted) ---\n');
fprintf(fid, '--- ASSUMPTION 1: Linearity ---\n');
fprintf('Look for: random scatter around y=0, no curve or funnel shape\n\n');
fprintf(fid, 'Visual check: see figures/assumptions_%s.png (top-left panel)\n', chosen_model);
fprintf(fid, 'Look for: random scatter around y=0, no systematic pattern\n\n');

%% =========================================================
%  ASSUMPTION 2: NORMALITY OF RESIDUALS
%  Shapiro-Wilk test + QQ plot
%% =========================================================

fprintf('--- ASSUMPTION 2: Normality of Residuals ---\n');
fprintf(fid, '--- ASSUMPTION 2: Normality ---\n');

% Shapiro-Wilk test
% Note: requires swtest.m (available on MATLAB File Exchange)
% If not available, we fall back to a Lilliefors test
try
    [h_sw, p_sw, W_sw] = swtest(residuals);
    sw_name = 'Shapiro-Wilk';
    sw_stat = W_sw;
catch
    fprintf('NOTE: swtest not found — using Lilliefors test instead.\n');
    fprintf(fid, 'NOTE: swtest not found — using Lilliefors test.\n');
    [h_sw, p_sw] = lillietest(residuals);
    sw_name = 'Lilliefors';
    sw_stat = NaN;
end

result_str = 'PASS (residuals approximately normal)';
if h_sw == 1
    result_str = 'FAIL (residuals may not be normal — consider transformation)';
end

fprintf('%s test: stat=%.4f, p=%.4f → %s\n', sw_name, sw_stat, p_sw, result_str);
fprintf(fid, '%s test: stat=%.4f, p=%.4f\nResult: %s\n\n', ...
    sw_name, sw_stat, p_sw, result_str);

%% =========================================================
%  ASSUMPTION 3: HOMOSCEDASTICITY
%  Breusch-Pagan test + Scale-Location plot
%% =========================================================

fprintf('\n--- ASSUMPTION 3: Homoscedasticity ---\n');
fprintf(fid, '--- ASSUMPTION 3: Homoscedasticity ---\n');

% Breusch-Pagan test (manual implementation)
res_sq = residuals.^2;
X_mat  = [ones(n,1), fitted];
bp_mdl = fitlm(array2table([fitted, res_sq], 'VariableNames',{'fitted','res_sq'}), ...
               'res_sq ~ fitted');
bp_stat = n * bp_mdl.Rsquared.Ordinary;   % n * R² ~ Chi²(1)
bp_p    = 1 - chi2cdf(bp_stat, 1);

bp_result = 'PASS (homoscedasticity assumption met)';
if bp_p < 0.05
    bp_result = 'FAIL (heteroscedasticity present — consider robust SEs or transformation)';
end

fprintf('Breusch-Pagan test: BP=%.3f, p=%.4f → %s\n', bp_stat, bp_p, bp_result);
fprintf(fid, 'Breusch-Pagan test: BP=%.3f, p=%.4f\nResult: %s\n\n', ...
    bp_stat, bp_p, bp_result);

%% =========================================================
%  ASSUMPTION 4: OUTLIERS & INFLUENTIAL CASES
%  Cook's Distance + Studentized residuals
%% =========================================================

fprintf('\n--- ASSUMPTION 4: Outliers and Influential Cases ---\n');
fprintf(fid, '--- ASSUMPTION 4: Outliers and Influential Cases ---\n');

% Cook's distance
[~, cooks] = mdl.plotDiagnostics('cookd');
close;   % close the auto-generated plot, we'll make our own

% Threshold: common rule is 4/n
cook_thresh  = 4 / n;
outlier_cook = find(cooks > cook_thresh);

% Studentized residuals threshold: |> 2| flagged, |> 3| serious
outlier_res2 = find(abs(res_stud) > 2);
outlier_res3 = find(abs(res_stud) > 3);

fprintf('Cook''s D threshold (4/n = %.3f): %d observations flagged\n', ...
    cook_thresh, length(outlier_cook));
fprintf('Studentized residuals |>2|: %d flagged\n', length(outlier_res2));
fprintf('Studentized residuals |>3|: %d flagged (serious)\n\n', length(outlier_res3));

fprintf(fid, 'Cook''s D threshold (4/n = %.3f): %d flagged\n', cook_thresh, length(outlier_cook));
if ~isempty(outlier_cook)
    fprintf(fid, 'Flagged observations (Cook''s D): %s\n', num2str(outlier_cook'));
end
fprintf(fid, 'Studentized |>2|: %d  |>3|: %d\n', ...
    length(outlier_res2), length(outlier_res3));
if ~isempty(outlier_res3)
    fprintf(fid, 'Serious outliers (|res_stud|>3): observation(s) %s\n', ...
        num2str(outlier_res3'));
    fprintf('WARNING: Observation(s) %s have |studentized residual| > 3.\n', ...
        num2str(outlier_res3'));
    fprintf('Consider inspecting these subjects.\n');
end
fprintf(fid, '\n');

%% =========================================================
%  ASSUMPTION 5: MULTICOLLINEARITY (VIF)
%% =========================================================

fprintf('--- ASSUMPTION 5: Multicollinearity (VIF) ---\n');
fprintf(fid, '--- ASSUMPTION 5: Multicollinearity (VIF) ---\n');

% Compute VIF manually for each predictor
pred_names = mdl.CoefficientNames(2:end);   % skip intercept
X_full     = [ones(n,1), mdl.Variables{:,1:end-1}];   % design matrix
vif_vals   = zeros(1, length(pred_names));

for j = 1:length(pred_names)
    % Regress predictor j on all other predictors
    other_cols = setdiff(2:size(X_full,2), j+1);
    X_others   = X_full(:, other_cols);
    y_j        = X_full(:, j+1);
    aux_mdl    = fitlm(X_others, y_j);
    vif_vals(j)= 1 / (1 - aux_mdl.Rsquared.Ordinary);
end

fprintf('%-25s  %-8s  %-s\n', 'Predictor', 'VIF', 'Status');
fprintf('%s\n', repmat('-',1,50));
fprintf(fid, '%-25s  %-8s  %-s\n', 'Predictor', 'VIF', 'Status');
fprintf(fid, '%s\n', repmat('-',1,50));

for j = 1:length(pred_names)
    if vif_vals(j) < 5
        vif_status = 'OK';
    elseif vif_vals(j) < 10
        vif_status = 'MODERATE — monitor';
    else
        vif_status = 'HIGH — multicollinearity problem';
    end
    row = sprintf('%-25s  %-8.3f  %s\n', pred_names{j}, vif_vals(j), vif_status);
    fprintf(row); fprintf(fid, row);
end
fprintf(fid, '\nVIF < 5: acceptable | 5-10: moderate | >10: problematic\n\n');

%% =========================================================
%  COMBINED FIGURE — ALL ASSUMPTION PLOTS
%% =========================================================

figure('Name', sprintf('Assumption Checks: %s', chosen_model), ...
       'Position', [50 50 1200 900], 'Color','w');

% --- Plot 1: Residuals vs Fitted ---
subplot(2,3,1);
scatter(fitted, residuals, 45, [0.18 0.45 0.75], 'filled', 'MarkerFaceAlpha',0.7);
yline(0, 'r--', 'LineWidth',1.5);
xlabel('Fitted Values','FontSize',10);
ylabel('Residuals','FontSize',10);
title('1. Residuals vs Fitted','FontSize',11,'FontWeight','bold');
subtitle('Look for: random scatter, no pattern','FontSize',8);
box off; grid on;

% Smooth trend line to help spot patterns
hold on;
[sorted_fit, sort_idx] = sort(fitted);
smoothed = smooth(residuals(sort_idx), 0.4, 'loess');
plot(sorted_fit, smoothed, 'r-', 'LineWidth',1.5);
hold off;

% --- Plot 2: QQ Plot ---
subplot(2,3,2);
qqplot(residuals);
title('2. Normal Q-Q Plot','FontSize',11,'FontWeight','bold');
subtitle(sprintf('S-W p=%.4f — %s', p_sw, ternary(h_sw==0,'PASS','FAIL')), 'FontSize',8);
box off;

% --- Plot 3: Scale-Location (sqrt standardized residuals vs fitted) ---
subplot(2,3,3);
scatter(fitted, sqrt(abs(res_stud)), 45, [0.78 0.25 0.18], 'filled', 'MarkerFaceAlpha',0.7);
hold on;
[sf2, si2] = sort(fitted);
plot(sf2, smooth(sqrt(abs(res_stud(si2))), 0.4,'loess'), 'r-','LineWidth',1.5);
hold off;
xlabel('Fitted Values','FontSize',10);
ylabel('\surd|Studentized Residuals|','FontSize',10);
title('3. Scale-Location','FontSize',11,'FontWeight','bold');
subtitle(sprintf('BP test p=%.4f — %s', bp_p, ternary(bp_p>0.05,'PASS','FAIL')),'FontSize',8);
box off; grid on;

% --- Plot 4: Histogram of residuals ---
subplot(2,3,4);
histogram(residuals, 12, 'FaceColor',[0.2 0.6 0.4], 'EdgeColor','w', 'FaceAlpha',0.85);
xline(0,'r--','LineWidth',1.5);
xlabel('Residuals','FontSize',10); ylabel('Count','FontSize',10);
title('4. Residual Distribution','FontSize',11,'FontWeight','bold');
subtitle('Should be approximately bell-shaped','FontSize',8);
box off;

% --- Plot 5: Cook's Distance ---
subplot(2,3,5);
stem(1:n, cooks, 'filled', 'Color',[0.18 0.45 0.75], 'MarkerSize',4);
yline(cook_thresh, 'r--', 'LineWidth',1.5, 'Label', sprintf('Threshold=%.3f', cook_thresh));
xlabel('Observation','FontSize',10); ylabel('Cook''s Distance','FontSize',10);
title('5. Cook''s Distance','FontSize',11,'FontWeight','bold');
subtitle(sprintf('%d observations above threshold', length(outlier_cook)),'FontSize',8);
if ~isempty(outlier_cook)
    hold on;
    stem(outlier_cook, cooks(outlier_cook), 'filled', ...
         'Color',[0.9 0.3 0.1], 'MarkerSize',6);
    hold off;
end
box off;

% --- Plot 6: Studentized Residuals ---
subplot(2,3,6);
scatter(1:n, res_stud, 45, [0.5 0.3 0.7], 'filled', 'MarkerFaceAlpha',0.7);
yline(0,  'k-',  'LineWidth',1);
yline( 2, 'b--', 'LineWidth',1.5, 'Label', '+2');
yline(-2, 'b--', 'LineWidth',1.5, 'Label', '-2');
yline( 3, 'r--', 'LineWidth',1.5, 'Label', '+3');
yline(-3, 'r--', 'LineWidth',1.5, 'Label', '-3');
xlabel('Observation','FontSize',10);
ylabel('Studentized Residuals','FontSize',10);
title('6. Studentized Residuals','FontSize',11,'FontWeight','bold');
subtitle(sprintf('%d obs |>2|,  %d obs |>3|', ...
    length(outlier_res2), length(outlier_res3)),'FontSize',8);
% Label the serious outliers
if ~isempty(outlier_res3)
    hold on;
    scatter(outlier_res3, res_stud(outlier_res3), 70, [0.9 0.1 0.1], 'filled');
    text(outlier_res3+0.3, res_stud(outlier_res3), ...
         arrayfun(@(x) sprintf('S%d',x), outlier_res3,'UniformOutput',false), ...
         'FontSize',8, 'Color',[0.9 0.1 0.1]);
    hold off;
end
box off;

% Overall title
sgtitle(sprintf('Assumption Checks — %s\n%s', ...
    chosen_model, strrep(mdl.Formula.char,'_','\_')), ...
    'FontSize',13,'FontWeight','bold');

% Save figure
fig_path = fullfile(fig_dir, sprintf('assumptions_%s.png', chosen_model));
exportgraphics(gcf, fig_path, 'Resolution',200);
fprintf('\nFigure saved: %s\n', fig_path);

%% =========================================================
%  FINAL SUMMARY PRINTED AND SAVED
%% =========================================================

summary_str = sprintf([...
    '\n=== ASSUMPTION CHECK SUMMARY: %s ===\n' ...
    'Linearity:          Visual check — see panel 1\n' ...
    'Normality:          %s test p=%.4f → %s\n' ...
    'Homoscedasticity:   Breusch-Pagan p=%.4f → %s\n' ...
    'Outliers (Cook''s D): %d flagged (threshold=%.3f)\n' ...
    'Serious outliers:   %d observations with |stud. res.| > 3\n' ...
    'VIF range:          %.2f – %.2f\n' ...
    '=====================================\n'], ...
    chosen_model, ...
    sw_name, p_sw, ternary(h_sw==0,'PASS','FAIL'), ...
    bp_p, ternary(bp_p>0.05,'PASS','FAIL'), ...
    length(outlier_cook), cook_thresh, ...
    length(outlier_res3), ...
    min(vif_vals), max(vif_vals));

fprintf(summary_str);
fprintf(fid, summary_str);
fclose(fid);

fprintf('\nFull results saved to: %s\n', log_file);
fprintf('\n=== SCRIPT 2 COMPLETE ===\n');

%% =========================================================
%  UTILITY FUNCTION
%% =========================================================

function out = ternary(condition, val_true, val_false)
    if condition
        out = val_true;
    else
        out = val_false;
    end
end
