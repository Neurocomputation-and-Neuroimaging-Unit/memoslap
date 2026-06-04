% =========================================================
% Normality Check — Shapiro-Wilk + Q-Q plots
% Requires: Statistics and Machine Learning Toolbox
% =========================================================

% --- Load data ---
T = readtable('E:\memoslap\restingstate\2ndLevel\Multiple Regression\all_average_conn_dec_perf.csv');

% Select numeric variables only (exclude subject_id, Sex)
numVars = {'decoding_earlybin_lSPL_spmClust', ...
           'decoding_latebin_lSPL_spmClust', ...
           'connectivity_lIFG_lSPL_spmClust', ...
           'connectivity_lSFG_lSPL_spmClust', ...
           'decoding_earlybin_rSPL_spmClust', ...
           'decoding_latebin_rSPL_spmClust', ...
           'connectivity_rIFG_rSPL_spmClust', ...
           'connectivity_rSFG_rSPL_spmClust', ...
           'perf_average', ...
           'Age', ...
           'decoding_earlybin_rS2', ...
           'connectivity_lSPL_rS2', ...
           'connectivity_rSPL_rS2'};

nVars = numel(numVars);
alpha = 0.05;

% --- Print header ---
fprintf('\n%-40s %8s %8s %8s %8s %10s\n', ...
    'Variable', 'W', 'p-value', 'Skewness', 'Kurtosis', 'Normal?');
fprintf('%s\n', repmat('-', 1, 85));

results = table('Size', [nVars, 6], ...
    'VariableTypes', {'string','double','double','double','double','string'}, ...
    'VariableNames', {'Variable','W','p_value','Skewness','Kurtosis','Normal'});

for i = 1:nVars
    x = T.(numVars{i});
    x = x(~isnan(x));

    % --- Shapiro-Wilk test ---
    % Option 1: if you have the Statistics Toolbox
    [h, p, stats_sw] = swtest(x, alpha);   % from swtest.m (File Exchange)
    % OR use lillietest as a fallback:
    % [h, p] = lillietest(x);
    % stats_sw.W = NaN;  % lillietest doesn't return W

    W = stats_sw.W;
    sk = skewness(x);
    ku = kurtosis(x) - 3;  % excess kurtosis
    normalStr = "YES";
    if h, normalStr = "NO"; end

    results.Variable(i) = numVars{i};
    results.W(i)        = W;
    results.p_value(i)  = p;
    results.Skewness(i) = sk;
    results.Kurtosis(i) = ku;
    results.Normal(i)   = normalStr;

    fprintf('%-40s %8.4f %8.4f %8.3f %8.3f %10s\n', ...
        numVars{i}, W, p, sk, ku, normalStr);
end

% --- Plot: Histograms + Q-Q plots ---
nCols = 3;
nRows = ceil(nVars / nCols);

figure('Color', 'w', 'Position', [50 50 1400 nRows * 280]);
t = tiledlayout(nRows, nCols * 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, sprintf('Normality Check — Shapiro-Wilk  (\\alpha = %.2f)', alpha), ...
    'FontSize', 14, 'FontWeight', 'bold');

for i = 1:nVars
    x = T.(numVars{i});
    x = x(~isnan(x));
    isNormal = strcmp(results.Normal(i), "YES");
    clr = [0.2 0.8 0.4];    % green
    if ~isNormal, clr = [0.9 0.3 0.3]; end  % red

    shortName = strrep(numVars{i}, '_spmClust', '');
    shortName = strrep(shortName, 'connectivity_', 'conn_');
    shortName = strrep(shortName, 'decoding_', 'dec_');

    % Histogram
    row = ceil(i / nCols);
    colIdx = mod(i-1, nCols);
    nexttile(t, (row-1)*nCols*2 + colIdx*2 + 1);
    histogram(x, 10, 'FaceColor', clr, 'EdgeColor', 'w', 'FaceAlpha', 0.85);
    if isNormal
        title(sprintf('%s\n\\checkmark Normal | W=%.3f p=%.4f', shortName, results.W(i), results.p_value(i)), ...
            'Color', clr, 'FontSize', 7);
    else
        title(sprintf('%s\n\\times Non-Normal | W=%.3f p=%.4f', shortName, results.W(i), results.p_value(i)), ...
            'Color', clr, 'FontSize', 7);
    end
    box off;

    % Q-Q plot
    nexttile(t, (row-1)*nCols*2 + colIdx*2 + 2);
    qqplot(x);
    h_lines = findobj(gca, 'Type', 'Line');
    set(h_lines(end), 'MarkerFaceColor', clr, 'MarkerEdgeColor', clr, 'MarkerSize', 5);
    title('Q-Q', 'FontSize', 7, 'Color', [0.5 0.5 0.5]);
    xlabel(''); ylabel('');
    box off;
end

% --- Save results table ---
writetable(results, 'normality_results.csv');
fprintf('\nResults saved to normality_results.csv\n');

% =========================================================
% NOTE: swtest.m is not built into MATLAB.
% Download it from MATLAB File Exchange:
%   https://www.mathworks.com/matlabcentral/fileexchange/13964
% Or use the built-in alternatives below:
%
%   lillietest(x)       — Lilliefors (Kolmogorov-Smirnov variant)
%   kstest(x)           — one-sample KS test vs standard normal
%   jbtest(x)           — Jarque-Bera test
%   chi2gof(x)          — chi-square goodness-of-fit
% =========================================================
