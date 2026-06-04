%% ASSUMPTION CHECKS — standalone, no Script 1 needed
clear; clc; close all;

%% --- SETTINGS --- change these ---
data_path  = 'E:\memoslap\restingstate\2ndLevel\Multiple Regression\all_avg_excl.csv';   % path to your data file
out_dir    = 'assumption_check_results';         % output folder (created if missing)

%predictors = {'Age',}
predictors = {'Age', 'connectivity_lSFG_lSPL_spmClust', 'decoding_latebin_rSPL_spmClust', 'connectivity_rIFG_rSPL_spmClust','connectivity_rSPL_rS2'}
% predictors = {'Age', ...
% %     'decoding_latebin_lSPL_spmClust', ...
% %     'connectivity_lIFG_lSPL_spmClust', ...
%       'connectivity_lSFG_lSPL_spmClust', ...
%       'decoding_latebin_rSPL_spmClust', ...
%       'connectivity_rIFG_rSPL_spmClust', ...
% %     'connectivity_rSFG_rSPL_spmClust', ...
% %     'decoding_earlybin_rS2', ...
% %     'connectivity_lSPL_rS2', ...
%       'connectivity_rSPL_rS2' ...
%   };
DV = 'perf_average';
% --------------------------------

%% --- Setup output folder ---
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
model_label = strjoin(predictors, '_AND_');
model_label = model_label(1:min(60,end));   % truncate for filename safety

diary(fullfile(out_dir, sprintf('results_%s.txt', model_label)));
fprintf('Output directory: %s\n', out_dir);
fprintf('Generated: %s\n\n', datestr(now));

%% --- Load data & fit model ---
T = readtable(data_path);
formula = [DV ' ~ ' strjoin(predictors, ' + ')];
mdl = fitlm(T, formula);
disp(mdl);

%% --- Extract quantities ---
residuals   = mdl.Residuals.Raw;
res_stud    = mdl.Residuals.Studentized;
fitted      = mdl.Fitted;
n           = mdl.NumObservations;
cook_thresh = 4/n;

%% --- ASSUMPTION 2: Normality ---
fprintf('--- ASSUMPTION 2: Normality of Residuals ---\n');
[h_sw, p_sw, W_sw] = swtest(residuals);
fprintf('Shapiro-Wilk: W=%.4f, p=%.4f → %s\n\n', W_sw, p_sw, ...
    ternary(h_sw==0, 'PASS (normal)', 'FAIL (non-normal)'));

%% --- ASSUMPTION 3: Homoscedasticity (Breusch-Pagan) ---
fprintf('--- ASSUMPTION 3: Homoscedasticity ---\n');
bp_tbl  = array2table([fitted, residuals.^2], 'VariableNames',{'fitted','res_sq'});
bp_mdl  = fitlm(bp_tbl, 'res_sq ~ fitted');
bp_stat = n * bp_mdl.Rsquared.Ordinary;
bp_p    = 1 - chi2cdf(bp_stat, 1);
fprintf('Breusch-Pagan: BP=%.3f, p=%.4f → %s\n\n', bp_stat, bp_p, ...
    ternary(bp_p>0.05, 'PASS (homoscedastic)', 'FAIL (heteroscedastic)'));

%% --- ASSUMPTION 4: Outliers ---
fprintf('--- ASSUMPTION 4: Outliers & Influential Cases ---\n');

% Compute Cook's Distance manually
% Compute leverage (hat values) manually
X     = [ones(n,1), table2array(T(:, predictors))];
H     = X * ((X'*X) \ X');
h     = diag(H);
mse   = mdl.MSE;
p     = mdl.NumCoefficients;
cooks = (residuals.^2 .* h) ./ (p * mse * (1 - h).^2);

outlier_cook = find(cooks > cook_thresh);
outlier_res2 = find(abs(res_stud) > 2);
outlier_res3 = find(abs(res_stud) > 3);
fprintf('Cook''s D threshold (4/n = %.3f): %d observations flagged\n', cook_thresh, length(outlier_cook));
if ~isempty(outlier_cook)
    fprintf('  Flagged observations: %s\n', num2str(outlier_cook'));
end
fprintf('Studentized residuals |>2|: %d flagged\n', length(outlier_res2));
fprintf('Studentized residuals |>3|: %d flagged (serious)\n', length(outlier_res3));
if ~isempty(outlier_res3)
    fprintf('  Serious outlier observations: %s\n', num2str(outlier_res3'));
end
fprintf('\n');

%% --- ASSUMPTION 5: VIF ---
fprintf('--- ASSUMPTION 5: Multicollinearity (VIF) ---\n');
pred_names = predictors;
X_full     = table2array(T(:, predictors));
vif_vals   = zeros(1, length(pred_names));

for j = 1:length(pred_names)
    y_j      = X_full(:, j);
    X_others = X_full(:, setdiff(1:size(X_full,2), j));
    if size(X_others, 2) == 0
        vif_vals(j) = 1;   % only one predictor, no multicollinearity possible
    else
        aux        = fitlm(X_others, y_j);
        r2         = aux.Rsquared.Ordinary;
        if r2 >= 1
            vif_vals(j) = Inf;
        else
            vif_vals(j) = 1 / (1 - r2);
        end
    end
end

fprintf('%-42s  %-8s  %s\n', 'Predictor', 'VIF', 'Status');
fprintf('%s\n', repmat('-',1,65));
for j = 1:length(pred_names)
    if vif_vals(j) < 5
        status = 'OK';
    elseif vif_vals(j) < 10
        status = 'MODERATE';
    else
        status = 'HIGH — problem';
    end
    fprintf('%-42s  %-8.3f  %s\n', pred_names{j}, vif_vals(j), status);
end
fprintf('\n');

%% --- SUMMARY ---
fprintf('=== SUMMARY ===\n');
fprintf('Model:              %s\n', formula);
fprintf('N:                  %d\n', n);
fprintf('R²:                 %.3f\n', mdl.Rsquared.Ordinary);
fprintf('Adj. R²:            %.3f\n', mdl.Rsquared.Adjusted);
fprintf('Normality:          SW W=%.4f, p=%.4f → %s\n', W_sw, p_sw, ternary(h_sw==0,'PASS','FAIL'));
fprintf('Homoscedasticity:   BP=%.3f, p=%.4f → %s\n', bp_stat, bp_p, ternary(bp_p>0.05,'PASS','FAIL'));
fprintf('Cook''s D flagged:   %d (threshold=%.3f)\n', length(outlier_cook), cook_thresh);
fprintf('Serious outliers:   %d (|stud. res.| > 3)\n', length(outlier_res3));
fprintf('VIF range:          %.2f – %.2f\n', min(vif_vals), max(vif_vals));
fprintf('===============\n\n');

%% --- FIGURE ---
figure('Position',[50 50 1200 900],'Color','w');
[sf, si] = sort(fitted);

subplot(2,3,1);
scatter(fitted, residuals, 45,[0.18 0.45 0.75],'filled','MarkerFaceAlpha',0.7);
yline(0,'r--','LineWidth',1.5); hold on;
plot(sf, smooth(residuals(si),0.4,'loess'),'r-','LineWidth',1.5); hold off;
xlabel('Fitted Values'); ylabel('Residuals');
title('1. Residuals vs Fitted'); box off; grid on;

subplot(2,3,2);
qqplot(residuals);
title(sprintf('2. Normal Q-Q  (SW p=%.4f)', p_sw)); box off;

subplot(2,3,3);
scatter(fitted, sqrt(abs(res_stud)),45,[0.78 0.25 0.18],'filled','MarkerFaceAlpha',0.7);
hold on;
plot(sf, smooth(sqrt(abs(res_stud(si))),0.4,'loess'),'r-','LineWidth',1.5); hold off;
xlabel('Fitted Values'); ylabel('\surd|Stud. Resid.|');
title(sprintf('3. Scale-Location  (BP p=%.4f)', bp_p)); box off; grid on;

subplot(2,3,4);
histogram(residuals,12,'FaceColor',[0.2 0.6 0.4],'EdgeColor','w');
xline(0,'r--','LineWidth',1.5);
xlabel('Residuals'); ylabel('Count');
title('4. Residual Distribution'); box off;

subplot(2,3,5);
stem(1:n, cooks,'filled','Color',[0.18 0.45 0.75],'MarkerSize',4);
yline(cook_thresh,'r--','LineWidth',1.5);
if ~isempty(outlier_cook)
    hold on;
    stem(outlier_cook, cooks(outlier_cook),'filled','Color',[0.9 0.3 0.1],'MarkerSize',6);
    text(outlier_cook+0.3, cooks(outlier_cook), ...
         arrayfun(@(x) sprintf('S%d',x), outlier_cook,'UniformOutput',false),...
         'FontSize',8,'Color',[0.9 0.3 0.1]);
    hold off;
end
xlabel('Observation'); ylabel('Cook''s Distance');
title(sprintf('5. Cook''s Distance  (%d flagged)', length(outlier_cook))); box off;

subplot(2,3,6);
scatter(1:n, res_stud,45,[0.5 0.3 0.7],'filled','MarkerFaceAlpha',0.7);
yline(0,'k-'); yline(2,'b--'); yline(-2,'b--'); yline(3,'r--'); yline(-3,'r--');
if ~isempty(outlier_res3)
    hold on;
    scatter(outlier_res3, res_stud(outlier_res3),70,[0.9 0.1 0.1],'filled');
    text(outlier_res3+0.3, res_stud(outlier_res3), ...
         arrayfun(@(x) sprintf('S%d',x), outlier_res3,'UniformOutput',false),...
         'FontSize',8,'Color',[0.9 0.1 0.1]);
    hold off;
end
xlabel('Observation'); ylabel('Studentized Residuals');
title(sprintf('6. Studentized Residuals  (%d |>3|)', length(outlier_res3))); box off;

sgtitle(strrep(formula,'_','\_'),'FontSize',11,'FontWeight','bold');

%% --- Save figure ---
fig_path = fullfile(out_dir, sprintf('figure_%s.png', model_label));
exportgraphics(gcf, fig_path, 'Resolution', 200);
fprintf('Figure saved:  %s\n', fig_path);

diary off;
fprintf('Results saved: %s\n', fullfile(out_dir, sprintf('results_%s.txt', model_label)));

%% --- Utility ---
function out = ternary(cond, a, b)
    if cond; out = a; else; out = b; end
end