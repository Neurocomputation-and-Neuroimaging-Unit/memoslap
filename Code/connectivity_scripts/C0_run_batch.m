% C0_run_batch
% Batch runner script to run C0_connectivity_batch_new_complete
% for multiple subjects and sessions automatically.
% Edit the subject and session lists below, then run this script.

clc
close all
clear all

%#####################################################
%#################### INPUT ##########################
%#####################################################

% List all subject IDs to process
subject_ids = [2202, 2204, 2205, 2206, 2207, 2210, 2211, 2212, 2214, 2215, ...
                2216, 2217, 2219, 2220, 2221, 2222, 2223, 2225, 2226, 2227, ...
                2228, 2231, 2232, 2233, 2234, 2235, 2236, 2237, 2239, 2241, ...
                2242, 2243, 2246, 2247, 2248, 2250, 2252, 2254, 2255, 2256, 2257];
%subject_ids = [2215]
%subject_ids = [2231, 2232, 2233, 2234, 2235, 2236, 2237, 2239, 2241, 2242, 2243, 2244, 2245, 2246, 2247, 2248, 2250, 2252, 2253, 2254, 2255, 2256, 2257];  % add as many as needed
%subject_ids = [2205, 2206, 2207, 2210, 2211, 2212, 2214, 2215, 2216, 2217, 2218, 2219, 2220, 2221, 2222, 2223, 2225, 2226, 2227, 2228, 2229, 2230, 2231, 2232, 2233, 2234, 2235, 2236, 2237, 2239, 2241, 2242, 2243, 2244, 2245, 2246, 2247, 2248, 2250, 2252, 2253, 2254, 2255, 2256, 2257];  % add as many as needed
% subject_ids = [2218]

% List all session IDs to process for each subject
session_ids = [1, 2];  % add as many as needed

% Analysis steps to run
analysis_switch = [1, 4];

% Label for output folders (set to '' for no label)
label = '';

% Seed ROI for step 4 (seed-based analysis)
seed_ROI = 'C:\Users\sreya\Documents\College\Internship_fMRI\Data\rois_sreya\earlyWM_rS2_spmClust.nii';
% seed_ROI = [39, 40];

% Prefix for finding final preprocessed functional data
prefix_func = 's8wFh01l08_Rhclqg_m0.4ar';

% Atlas file path  
atlas = 'C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm12-main\AAL3\AAL3v1.nii';

% Skip already processed subjects (1 = skip, 0 = always run)
skip_existing = 0;

%#####################################################
%#################### INPUT end ######################
%#####################################################

% Track progress
total = length(subject_ids) * length(session_ids);
count = 0;
failed = {};

for s = 1:length(subject_ids)
    for sess = 1:length(session_ids)
        
        subject_id = subject_ids(s);
        session_id = session_ids(sess);
        count = count + 1;
        
        fprintf('\n========================================================\n')
        fprintf('Running %d/%d: sub-%d, ses-%02d\n', count, total, subject_id, session_id)
        fprintf('========================================================\n')
        
        % Check if already processed (optional skip)
        if skip_existing
            SJ_check = sprintf('sub-%d', subject_id);
            session_check = sprintf('ses-%02d', session_id);
            connectivity_folder = sprintf('connectivity%s', label);
            check_path = fullfile('E:\memoslap\restingstate\nifti_bids', ...
                SJ_check, session_check, connectivity_folder);
            if exist(check_path, 'dir')
                fprintf('Output already exists, skipping: %s\n', check_path)
                continue
            end
        end
        
        % Run C0 for this subject/session, catch errors so loop continues
        try
            C0_connectivity_batch_new_complete(subject_id, session_id, analysis_switch, label, seed_ROI, prefix_func, atlas);
            fprintf('✓ Finished: sub-%d, ses-%02d\n', subject_id, session_id)
        catch ME
            warning('✗ Failed: sub-%d, ses-%02d\n', subject_id, session_id)
            disp(ME.message)
            disp('Stack trace:')
            for i = 1:length(ME.stack)
                fprintf('  File: %s, Line: %d, Function: %s\n', ...
                    ME.stack(i).file, ME.stack(i).line, ME.stack(i).name);
            end
            failed{end+1} = sprintf('sub-%d ses-%02d: %s', subject_id, session_id, ME.message);
        end
        
    end
end

% Summary
fprintf('\n========================================================\n')
fprintf('Batch complete. %d/%d processed.\n', count - length(failed), total)
if ~isempty(failed)
    fprintf('Failed runs:\n')
    for i = 1:length(failed)
        fprintf('  %s\n', failed{i})
    end
end
fprintf('========================================================\n')