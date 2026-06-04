% rmANOVA_performance.m
% Repeated measures ANOVA: Session (3,4) x Run (1,2,3,4) on percent_correct
clear all; clc;

%% LOAD DATA
T = readtable('performance_subject_session_run.csv');

% Keep only sessions 3 and 4
T = T(ismember(T.session, [3, 4]), :);

% Keep only specified subjects
subject_ids = [2202, 2205, 2206, 2207, 2210, 2211, 2212, 2214, ...
               2216, 2217, 2219, 2220, 2221, 2222, 2223, 2225, 2226, 2227, ...
               2232, 2233, 2235, 2236, 2237, 2239, 2241, ...
               2242, 2243, 2246, 2248, 2250, 2252, 2254, 2255, 2256, 2257];
T = T(ismember(T.subject_id, subject_ids), :);

% Keep only sessions 3 and 4
T = T(ismember(T.session, [3, 4]), :);

%% RESHAPE: one row per subject, columns = ses3_run1 ... ses4_run4
subject_ids = unique(T.subject_id);
n = length(subject_ids);

data = NaN(n, 8); % 2 sessions x 4 runs = 8 columns

for s = 1:n
    subj = subject_ids(s);
    for ss = 1:2
        ses = ss + 2; % session 3 or 4
        for r = 1:4
            idx = T.subject_id == subj & T.session == ses & T.run == r;
            if any(idx)
                col = (ss-1)*4 + r;
                data(s, col) = T.percent_correct(idx);
            end
        end
    end
end

% Remove subjects with any missing data
ok = ~any(isnan(data), 2);
data = data(ok, :);
fprintf('Subjects with complete data: %d / %d\n', sum(ok), n);

%% BUILD TABLE FOR fitrm
varnames = {'s3r1','s3r2','s3r3','s3r4','s4r1','s4r2','s4r3','s4r4'};
D = array2table(data, 'VariableNames', varnames);

%% DEFINE WITHIN-SUBJECT FACTORS
within = table(...
    categorical([3;3;3;3;4;4;4;4]), ...
    categorical([1;2;3;4;1;2;3;4]), ...
    'VariableNames', {'Session','Run'});

%% FIT REPEATED MEASURES MODEL
rm = fitrm(D, 's3r1-s4r4 ~ 1', 'WithinDesign', within);

%% RUN ANOVA
ranova_tbl = ranova(rm, 'WithinModel', 'Session + Run + Session:Run');
disp(ranova_tbl)

%% PRINT SUMMARY
fprintf('\n=== Repeated Measures ANOVA: Session x Run ===\n')

% Extract rows by name
row_names = ranova_tbl.Properties.RowNames;

for i = 1:height(ranova_tbl)
    name = row_names{i};
    if contains(name, 'Error'), continue; end
    F  = ranova_tbl.F(i);
    df1 = ranova_tbl.DF(i);
    % find corresponding error row
    err_row = find(strcmp(row_names, ['(Intercept):' strrep(name,'(Intercept):','') 'Error']) | ...
                   strcmp(row_names, [name '(Error)']));
    p  = ranova_tbl.pValue(i);
    fprintf('%s: F(%d) = %.3f, p = %.3f\n', name, df1, F, p);
end

%% SAVE ANOVA TABLE TO CSV
writetable(ranova_tbl, 'rmANOVA_results.csv', 'WriteRowNames', true);
fprintf('\nANOVA table saved to rmANOVA_results.csv\n');
