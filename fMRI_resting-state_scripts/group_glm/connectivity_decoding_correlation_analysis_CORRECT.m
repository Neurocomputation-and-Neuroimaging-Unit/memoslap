%% ── USER-DEFINED PATHS ──────────────────────────────────────────────────────
connectivity_csv = 'E:\memoslap\restingstate\2ndLevel\2ndLevel_FlexFact_Interaction_lateWM_rSPL\final results\avg_corr_per_sphere.csv';
decoding_csv     = 'E:\memoslap\restingstate\2ndLevel\Decoding Accuracy\avg_decoding_per_sphere_rspl_latebin.csv';
output_dir       = 'E:\memoslap\restingstate\2ndLevel\Decoding Accuracy\Decoding_Connectivity';
%% ─────────────────────────────────────────────────────────────────────────────

% Suffix to select columns from each file. Columns must start with 'clust'
% and end with the suffix you specify (case-sensitive).
% Leave either empty ('') to print available columns for that file and exit.
connectivity_suffix = 'rSPL';   % e.g. 'rS2'
decoding_suffix     = 'latebin_rSPL';   % e.g. 'lSPL'
%% ─────────────────────────────────────────────────────────────────────────────
 
% ── Load tables ──────────────────────────────────────────────────────────────
conn_tbl = readtable(connectivity_csv, 'TextType', 'string', 'VariableNamingRule', 'preserve');
dec_tbl  = readtable(decoding_csv,     'TextType', 'string', 'VariableNamingRule', 'preserve');
 
conn_tbl = rename_id_col(conn_tbl);
dec_tbl  = rename_id_col(dec_tbl);

conn_tbl.subject_id = strtrim(string(conn_tbl.subject_id));
dec_tbl.subject_id  = strtrim(string(dec_tbl.subject_id));
 
% ── Identify all clust columns in each file ───────────────────────────────────
conn_avg_cols = get_avg_cols(conn_tbl);
dec_avg_cols  = get_avg_cols(dec_tbl);
 
% ── Select connectivity columns matching the suffix ───────────────────────────
if isempty(connectivity_suffix)
    fprintf('\nconnectivity_suffix is empty. Available connectivity columns:\n');
    for i = 1:numel(conn_avg_cols); fprintf('  %s\n', conn_avg_cols{i}); end
    error('Set connectivity_suffix at the top of the script and re-run.');
end
 
conn_sel = conn_avg_cols(endsWith(conn_avg_cols, connectivity_suffix));
if isempty(conn_sel)
    fprintf('\nNo connectivity columns end with "%s". Available columns:\n', connectivity_suffix);
    for i = 1:numel(conn_avg_cols); fprintf('  %s\n', conn_avg_cols{i}); end
    error('Check connectivity_suffix and re-run.');
end
fprintf('Connectivity columns selected : %s\n', strjoin(conn_sel, ', '));
 
% ── Select the single decoding column matching the suffix ─────────────────────
if isempty(decoding_suffix)
    fprintf('\ndecoding_suffix is empty. Available decoding columns:\n');
    for i = 1:numel(dec_avg_cols); fprintf('  %s\n', dec_avg_cols{i}); end
    error('Set decoding_suffix at the top of the script and re-run.');
end
 
dec_sel = dec_avg_cols(endsWith(dec_avg_cols, decoding_suffix));
if isempty(dec_sel)
    fprintf('\nNo decoding columns end with "%s". Available columns:\n', decoding_suffix);
    for i = 1:numel(dec_avg_cols); fprintf('  %s\n', dec_avg_cols{i}); end
    error('Check decoding_suffix and re-run.');
end
if numel(dec_sel) > 1
    fprintf('\nMultiple decoding columns match suffix "%s":\n', decoding_suffix);
    for i = 1:numel(dec_sel); fprintf('  %s\n', dec_sel{i}); end
    error('Use a more specific decoding_suffix so exactly one column is selected.');
end
 
dec_col = dec_sel{1};
fprintf('Decoding column selected      : %s\n', dec_col);
 
% Rename the decoding column to avoid any clash after joining
dec_tbl.Properties.VariableNames{ ...
    strcmp(dec_tbl.Properties.VariableNames, dec_col)} = 'decoding_acc';
 
% ── Inner join on subject_id ──────────────────────────────────────────────────
merged = innerjoin(conn_tbl, dec_tbl, 'Keys', 'subject_id', ...
                   'LeftVariables',  conn_tbl.Properties.VariableNames, ...
                   'RightVariables', dec_tbl.Properties.VariableNames);
 
fprintf('\nSubjects in connectivity CSV : %d\n', height(conn_tbl));
fprintf('Subjects in decoding CSV     : %d\n', height(dec_tbl));
fprintf('Subjects after inner join    : %d\n', height(merged));
 
if height(merged) == 0
    error('Inner join returned 0 subjects. Check that subject_id values match across files.');
end
 
% ── Spearman correlation: each connectivity cluster vs the decoding cluster ───
cluster_labels = {};
rho_vals       = [];
pval_vals      = [];
n_vals         = [];
 
for c = 1:numel(conn_sel)
    conn_col = conn_sel{c};
 
    x = merged.(conn_col);      % avg connectivity for this cluster
    y = merged.decoding_acc;    % decoding accuracy (single cluster)
 
    valid = isfinite(x) & isfinite(y);
    xv    = x(valid);
    yv    = y(valid);
 
    if numel(xv) < 3
        warning('Too few valid subjects for connectivity cluster "%s" — skipping.', conn_col);
        continue;
    end
 
    [rho, pval] = corr(xv, yv, 'Type', 'Spearman');
 
    cluster_labels{end+1,1} = conn_col;
    rho_vals(end+1,1)       = rho;
    pval_vals(end+1,1)      = pval;
    n_vals(end+1,1)         = sum(valid);
end
 
% ── Multiple comparison correction ───────────────────────────────────────────
m = numel(pval_vals);   % number of tests
 
% Bonferroni
bonf_vals = min(pval_vals * m, 1);
 
% FDR (Benjamini-Hochberg)
fdr_vals = fdr_bh(pval_vals);
 
% ── Build and save results table ─────────────────────────────────────────────
corr_results = table(cluster_labels, rho_vals, pval_vals, bonf_vals, fdr_vals, n_vals, ...
    'VariableNames', {'Connectivity_Cluster', 'Spearman_rho', 'p_value', 'p_bonferroni', 'p_fdr_bh', 'N'});
 
% Console summary
fprintf('\n── Spearman correlation: connectivity clusters vs decoding (%s) ──\n', dec_col);
fprintf('  Correction applied over %d tests (Bonferroni & FDR-BH)\n\n', m);
fprintf('%-35s  %8s  %10s  %12s  %10s  %4s\n', ...
        'Connectivity Cluster', 'rho', 'p_uncorr', 'p_bonferroni', 'p_fdr_bh', 'N');
fprintf('%s\n', repmat('-', 1, 85));
for i = 1:height(corr_results)
    % Significance flags based on FDR-corrected p
    sig = '';
    if     corr_results.p_fdr_bh(i) < 0.001, sig = '***';
    elseif corr_results.p_fdr_bh(i) < 0.01,  sig = '**';
    elseif corr_results.p_fdr_bh(i) < 0.05,  sig = '*';
    end
    fprintf('%-35s  %8.4f  %10.4f  %12.4f  %10.4f  %4d  %s\n', ...
            corr_results.Connectivity_Cluster{i}, ...
            corr_results.Spearman_rho(i), ...
            corr_results.p_value(i), ...
            corr_results.p_bonferroni(i), ...
            corr_results.p_fdr_bh(i), ...
            corr_results.N(i), sig);
end
fprintf('\nSignificance (* ** ***) based on FDR-BH corrected p: p<.05 / p<.01 / p<.001\n');
fprintf('Decoding cluster used: %s\n\n', dec_col);
 
output_file = fullfile(output_dir, sprintf('%s_%s.csv', decoding_suffix, connectivity_suffix));
writetable(corr_results, output_file);
fprintf('Saved to: %s\n', output_file);
 
 
%% ── Helper functions ─────────────────────────────────────────────────────────
 
function tbl = rename_id_col(tbl)
    if ~strcmp(tbl.Properties.VariableNames{1}, 'subject_id')
        tbl.Properties.VariableNames{1} = 'subject_id';
    end
end
 
function avg_cols = get_avg_cols(tbl)
    all_vars = tbl.Properties.VariableNames;
    mask     = ~contains(all_vars, 'ses-') & ...
               ~contains(all_vars, 'run-');
    avg_cols = all_vars(mask);
end
 
function p_adj = fdr_bh(p_vals)
% FDR correction using the Benjamini-Hochberg (1995) procedure.
% p_vals : column vector of uncorrected p-values
% p_adj  : BH-adjusted p-values (same order as input)
    m      = numel(p_vals);
    [p_sorted, sort_idx] = sort(p_vals(:));
    bh_crit  = (1:m)' / m;          % i/m thresholds
    p_adj_sorted = min(1, p_sorted .* m ./ (1:m)');
 
    % Enforce monotonicity (cumulative minimum from the largest rank down)
    for k = m-1 : -1 : 1
        p_adj_sorted(k) = min(p_adj_sorted(k), p_adj_sorted(k+1));
    end
 
    % Restore original order
    p_adj = zeros(size(p_vals));
    p_adj(sort_idx) = p_adj_sorted;
end