%% Age & Gender Linear Model Analysis
% =========================================================
% Tests whether age and gender predict each numeric DV column
% in a target file (e.g. avg_performance, cluster connectivity).
%
% MODEL (per DV):
%   DV ~ 1 + age + gender
%
% Since each subject contributes one row, a standard OLS linear
% model (fitlm) is used. FDR correction (Benjamini-Hochberg,
% q = 0.05) is applied across all DVs separately for each
% predictor (age, gender).
%
% OUTPUTS:
%   One CSV per predictor (age, gender) with beta, SE, t, p,
%   p_FDR, and significance flags for every DV column.
%
% CONFIGURE THE PATHS BELOW BEFORE RUNNING
% =========================================================

clc
close all
clear

%% ── USER CONFIGURATION ──────────────────────────────────
DEMOGRAPHICS_FILE = 'E:\memoslap\restingstate\2ndLevel\Linear Mixed Effects Model\combined_ID_Alter_Geschlecht.csv';
% CSV must contain: subject_id column + age column + gender column

TARGET_FILE       = 'E:\memoslap\restingstate\2ndLevel\Linear Mixed Effects Model\All_average_connectivity.csv';
% CSV must contain: subject_id column + one or more numeric DV columns
% Examples: avg_performance file, avg_corr_per_sphere file, Table 1 output, etc.

OUTPUT_DIR        = 'E:\memoslap\restingstate\2ndLevel\Linear Mixed Effects Model';
% Directory where result CSVs will be saved

OUTPUT_SUFFIX     = 'connectivity';
% Short label appended to output filenames, e.g. 'connectivity', 'performance'

EXCLUDE_COLS      = {};
% Column names in the target file to skip even if numeric
% e.g. {'avg_performance'} or {} to skip nothing extra
%% ── END CONFIGURATION ───────────────────────────────────


%% 1. Load files
demo   = readtable(DEMOGRAPHICS_FILE,  'TextType', 'string', 'VariableNamingRule', 'preserve');
target = readtable(TARGET_FILE,        'TextType', 'string', 'VariableNamingRule', 'preserve');

fprintf('Demographics file: %d rows, columns: %s\n\n', ...
    height(demo), strjoin(demo.Properties.VariableNames, ' | '));
fprintf('Target file:       %d rows, columns: %s\n\n', ...
    height(target), strjoin(target.Properties.VariableNames, ' | '));


%% 2. Detect subject ID column in each file
demo_cols   = demo.Properties.VariableNames;
target_cols = target.Properties.VariableNames;

demo_subj_idx   = find(contains(lower(demo_cols),   'subject'), 1);
target_subj_idx = find(contains(lower(target_cols), 'subject'), 1);

if isempty(demo_subj_idx)
    error('Could not find subject column in demographics file. Columns: %s', strjoin(demo_cols, ', '));
end
if isempty(target_subj_idx)
    error('Could not find subject column in target file. Columns: %s', strjoin(target_cols, ', '));
end

demo_subj_col   = demo_cols{demo_subj_idx};
target_subj_col = target_cols{target_subj_idx};
fprintf('Subject column — demographics: "%s" | target: "%s"\n\n', demo_subj_col, target_subj_col);


%% 3. Detect age and gender columns in demographics file
age_idx    = find(contains(lower(demo_cols), 'age'),    1);
gender_idx = find(contains(lower(demo_cols), 'sex'), 1);

if isempty(age_idx)
    error('Could not find age column in demographics file. Columns: %s', strjoin(demo_cols, ', '));
end
if isempty(gender_idx)
    error('Could not find gender/sex column in demographics file. Columns: %s', strjoin(demo_cols, ', '));
end

age_col    = demo_cols{age_idx};
gender_col = demo_cols{gender_idx};
fprintf('Demographics columns — age: "%s" | gender: "%s"\n\n', age_col, gender_col);


%% 4. Normalise subject IDs: strip "sub-" prefix, force string
demo.(demo_subj_col)     = regexprep(string(demo.(demo_subj_col)),     '^sub-', '');
target.(target_subj_col) = regexprep(string(target.(target_subj_col)), '^sub-', '');


%% 5. Match subjects across files
[common_subjs, i_demo, i_target] = intersect( ...
    demo.(demo_subj_col), target.(target_subj_col), 'stable');

n_common = numel(common_subjs);
fprintf('Subjects matched across files: %d\n\n', n_common);

if n_common < 5
    error('Too few matched subjects (%d). Check subject ID formatting.', n_common);
end

% Aligned rows
demo_matched   = demo(i_demo, :);
target_matched = target(i_target, :);


%% 6. Extract and prepare predictors
% Age → numeric
age_raw = demo_matched.(age_col);
if isnumeric(age_raw)
    age_vec = age_raw;
else
    age_vec = str2double(strrep(string(age_raw), ',', '.'));
end

% Gender → categorical (keeps whatever labels are in the file, e.g. M/F, 0/1, male/female)
gender_raw = demo_matched.(gender_col);
if isnumeric(gender_raw)
    gender_vec = categorical(gender_raw);
else
    gender_vec = categorical(string(gender_raw));
end

fprintf('Age   — mean: %.2f, SD: %.2f, range: %.0f–%.0f\n', ...
    mean(age_vec,'omitnan'), std(age_vec,'omitnan'), min(age_vec), max(age_vec));
fprintf('Gender distribution:\n');
disp(tabulate(cellstr(gender_vec)));


%% 7. Identify numeric DV columns in target file
% Skip: subject ID column, any non-numeric column, user-excluded columns
non_dv = [target_subj_col, EXCLUDE_COLS];
dv_cols = {};
for c = 1:numel(target_cols)
    col_name = target_cols{c};
    if ismember(col_name, non_dv), continue; end
    col_data = target_matched.(col_name);
    % Convert to numeric if stored as string
    if iscell(col_data) || isstring(col_data)
        col_data = str2double(col_data);
    end
    if isnumeric(col_data)
        dv_cols{end+1} = col_name; %#ok<AGROW>
    end
end

n_dv = numel(dv_cols);
fprintf('\nDV columns identified (%d):\n', n_dv);
fprintf('  %s\n', dv_cols{:});
fprintf('\n');

if n_dv == 0
    error('No numeric DV columns found in target file after exclusions.');
end


%% 8. Fit linear model: DV ~ 1 + age + gender, for each DV
% Pre-allocate result arrays
dv_names   = dv_cols(:);
n_obs_all  = zeros(n_dv, 1);

beta_age   = zeros(n_dv, 1);   se_age   = zeros(n_dv, 1);
t_age      = zeros(n_dv, 1);   p_age    = zeros(n_dv, 1);

beta_gen   = zeros(n_dv, 1);   se_gen   = zeros(n_dv, 1);
t_gen      = zeros(n_dv, 1);   p_gen    = zeros(n_dv, 1);

r2_vals    = zeros(n_dv, 1);
r2adj_vals = zeros(n_dv, 1);

for d = 1:n_dv
    col_name = dv_cols{d};
    y = target_matched.(col_name);
    if iscell(y) || isstring(y)
        y = str2double(y);
    end
    y = double(y);

    % Build predictor table for this DV (drop rows with any NaN)
    tbl = table(age_vec, gender_vec, y, 'VariableNames', {'age','gender','DV'});
    valid = ~any(ismissing(tbl), 2);
    tbl   = tbl(valid, :);
    n_obs_all(d) = height(tbl);

    if n_obs_all(d) < 5
        fprintf('  Skipping "%s": only %d valid rows.\n', col_name, n_obs_all(d));
        beta_age(d) = NaN; se_age(d) = NaN; t_age(d) = NaN; p_age(d) = NaN;
        beta_gen(d) = NaN; se_gen(d) = NaN; t_gen(d) = NaN; p_gen(d) = NaN;
        r2_vals(d) = NaN; r2adj_vals(d) = NaN;
        continue
    end

    mdl = fitlm(tbl, 'DV ~ age + gender');

    coef_names = mdl.Coefficients.Properties.RowNames;

    % Age coefficient (always named 'age')
    age_row = find(strcmpi(coef_names, 'age'), 1);
    if ~isempty(age_row)
        beta_age(d) = mdl.Coefficients.Estimate(age_row);
        se_age(d)   = mdl.Coefficients.SE(age_row);
        t_age(d)    = mdl.Coefficients.tStat(age_row);
        p_age(d)    = mdl.Coefficients.pValue(age_row);
    else
        beta_age(d) = NaN; se_age(d) = NaN; t_age(d) = NaN; p_age(d) = NaN;
    end

    % Gender coefficient (fitlm names it gender_<level> for categorical)
    gen_row = find(contains(lower(coef_names), 'gender'), 1);
    if ~isempty(gen_row)
        beta_gen(d) = mdl.Coefficients.Estimate(gen_row);
        se_gen(d)   = mdl.Coefficients.SE(gen_row);
        t_gen(d)    = mdl.Coefficients.tStat(gen_row);
        p_gen(d)    = mdl.Coefficients.pValue(gen_row);
    else
        beta_gen(d) = NaN; se_gen(d) = NaN; t_gen(d) = NaN; p_gen(d) = NaN;
    end

    r2_vals(d)    = mdl.Rsquared.Ordinary;
    r2adj_vals(d) = mdl.Rsquared.Adjusted;
end


%% 9. FDR correction (Benjamini-Hochberg, q = 0.05) per predictor
p_fdr_age = bh_fdr(p_age);
p_fdr_gen = bh_fdr(p_gen);

sig_age_uncorr = p_age    < 0.05;
sig_age_fdr    = p_fdr_age < 0.05;
sig_gen_uncorr = p_gen    < 0.05;
sig_gen_fdr    = p_fdr_gen < 0.05;


%% 10. Build and save output tables

if ~exist(OUTPUT_DIR, 'dir'), mkdir(OUTPUT_DIR); end

% ── Table: Age results ──
T_age = table(dv_names, n_obs_all, beta_age, se_age, t_age, p_age, p_fdr_age, ...
              sig_age_uncorr, sig_age_fdr, ...
    'VariableNames', {'DV','n','beta','SE','t_stat', ...
                      'p_uncorrected','p_FDR','sig_p05_uncorrected','sig_FDR05'});

fprintf('\nAge results:\n');
disp(T_age);
out_age = fullfile(OUTPUT_DIR, sprintf('lm_age_effect_%s.csv', OUTPUT_SUFFIX));
writetable(T_age, out_age);
fprintf('Saved: %s\n', out_age);

% ── Table: Gender results ──
T_gen = table(dv_names, n_obs_all, beta_gen, se_gen, t_gen, p_gen, p_fdr_gen, ...
              sig_gen_uncorr, sig_gen_fdr, ...
    'VariableNames', {'DV','n','beta','SE','t_stat', ...
                      'p_uncorrected','p_FDR','sig_p05_uncorrected','sig_FDR05'});

fprintf('\nGender results:\n');
disp(T_gen);
out_gen = fullfile(OUTPUT_DIR, sprintf('lm_gender_effect_%s.csv', OUTPUT_SUFFIX));
writetable(T_gen, out_gen);
fprintf('Saved: %s\n', out_gen);


%% ── Helper: Benjamini-Hochberg FDR ──────────────────────
function p_adj = bh_fdr(p_vals)
% Returns BH-adjusted p-values (same length as input, NaNs preserved).
    n      = numel(p_vals);
    p_adj  = nan(n, 1);
    valid  = find(~isnan(p_vals));
    nv     = numel(valid);
    if nv == 0, return; end

    [p_sorted, sort_idx] = sort(p_vals(valid));
    ranks   = (1:nv)';
    adj     = min(1, p_sorted .* nv ./ ranks);
    % Enforce monotonicity
    for k = nv-1:-1:1
        adj(k) = min(adj(k), adj(k+1));
    end
    orig_idx = valid(sort_idx);
    p_adj(orig_idx) = adj;
end