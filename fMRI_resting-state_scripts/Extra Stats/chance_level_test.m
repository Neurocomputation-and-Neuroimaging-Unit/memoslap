% chance_level_test.m
% Tests behavioral performance against chance level (0.5) per session
% Outputs table (CSV) and plot
clear all; clc;

%% SETTINGS
data_file = 'performance_subject_session_run.csv';
out_dir   = '.';
n_perm    = 10000;
chance    = 50; % percent_correct scale

subject_ids = [2202, 2205, 2206, 2207, 2210, 2211, 2212, 2214, ...
               2216, 2217, 2219, 2220, 2221, 2222, 2223, 2225, 2226, 2227, ...
               2232, 2233, 2235, 2236, 2237, 2239, 2241, ...
               2242, 2243, 2246, 2248, 2250, 2252, 2254, 2255, 2256, 2257];

%% LOAD & FILTER
T = readtable(data_file);
T = T(ismember(T.subject_id, subject_ids), :);
T = T(ismember(T.session, [3, 4]), :);

sessions    = [3, 4];
ses_labels  = {'1', '2'}; % rename 3->1, 4->2 for reporting

results = struct();

for si = 1:2
    ses = sessions(si);

    % Average across runs per subject for this session
    subj_means = NaN(length(subject_ids), 1);
    for s = 1:length(subject_ids)
        rows = T.subject_id == subject_ids(s) & T.session == ses;
        if any(rows)
            subj_means(s) = mean(T.percent_correct(rows), 'omitnan');
        end
    end
    subj_means = subj_means(~isnan(subj_means));

    % Convert to proportion for reporting
    prop = subj_means / 100;
    m    = mean(prop);
    s    = std(prop);

    % One-sample t-test against 0.5
    [~, p_t, ~, stats] = ttest(prop, 0.5);
    t_val = stats.tstat;

    % Sign-flip permutation test
    demeaned = prop - 0.5;
    null_dist = NaN(n_perm, 1);
    for p = 1:n_perm
        signs = sign(rand(length(demeaned),1) - 0.5);
        null_dist(p) = mean(signs .* demeaned);
    end
    p_perm = mean(null_dist >= mean(demeaned));

    fprintf('Session %s: mean=%.3f, sd=%.3f, t=%.2f, p=%.6f, p_perm=%.6f\n', ...
        ses_labels{si}, m, s, t_val, p_t, p_perm);

    results(si).session   = ses_labels{si};
    results(si).mean      = m;
    results(si).sd        = s;
    results(si).t         = t_val;
    results(si).p         = p_t;
    results(si).p_perm    = p_perm;
    results(si).subj_means = prop;
end

%% SAVE CSV
T_out = table(...
    {results.session}', [results.mean]', [results.sd]', ...
    [results.t]', [results.p]', [results.p_perm]', ...
    'VariableNames', {'session','mean','sd','t','p','p_perm'});
writetable(T_out, fullfile(out_dir, 'chance_level_results.csv'));
fprintf('Saved to chance_level_results.csv\n');

%% PLOT
figure('Position', [100 100 500 450]);
hold on;

colors = [0.4 0.6 0.9; 0.9 0.5 0.4];
x = [1, 2];

for si = 1:2
    prop = results(si).subj_means;
    % scatter individual subjects with jitter
    jitter = (rand(length(prop),1) - 0.5) * 0.15;
    scatter(x(si) + jitter, prop, 40, colors(si,:), 'filled', 'MarkerFaceAlpha', 0.5);
    % mean + SEM bar
    sem = results(si).sd / sqrt(length(prop));
    errorbar(x(si), results(si).mean, sem, 'k', 'LineWidth', 2, 'CapSize', 8);
    plot(x(si), results(si).mean, 'o', 'MarkerSize', 10, ...
        'MarkerFaceColor', colors(si,:), 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
end

% chance line
yline(0.5, '--k', 'Chance', 'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left');

% significance stars
for si = 1:2
    p = results(si).p;
    if p < 0.001,     sig = '***';
    elseif p < 0.01,  sig = '**';
    elseif p < 0.05,  sig = '*';
    else,             sig = 'ns';
    end
    y_star = max(results(si).subj_means) + 0.03;
    text(x(si), y_star, sig, 'HorizontalAlignment', 'center', 'FontSize', 14);
end

xlim([0.5 2.5]);
ylim([0.2 1.05]);
xticks([1 2]);
xticklabels({'Session 1', 'Session 2'});
ylabel('Proportion Correct');
title('Performance vs. Chance Level');
box off;

saveas(gcf, fullfile(out_dir, 'chance_level_plot.png'));
fprintf('Plot saved to chance_level_plot.png\n');
