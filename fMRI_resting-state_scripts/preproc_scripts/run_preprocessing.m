%% MEMOSLAP RESTING-STATE fMRI PREPROCESSING PIPELINE
% =========================================================================
% SPM12-based preprocessing pipeline for resting-state fMRI data.
%
% HOW TO USE THIS SCRIPT
%   1. Edit SECTION 1 (paths) and SECTION 2 (which subject/session to run)
%      below.
%   2. Run the script from top to bottom (F5), or run cell-by-cell.
%   3. Everything from "PIPELINE STEP DEFINITIONS" onward should normally
%      stay untouched -- it just executes whichever steps you listed in
%      analysis_steps, in the order you listed them.
%
% PIPELINE STEPS
%   #   Name                          Prefix added   Function
%   --  ----------------------------  -------------  --------------------------------
%   1   Segmentation                  (none)         B1_segmentation
%   2   Delete first X scans          x<N>           B2_delete_scans
%   3   Slice-time correction         a              B3_slice_time_correction
%   4   Realignment                   r              B4_Realignment_all_runs
%   5   Coregister (estimate)         (none)         B5_coregister_est
%   5b  Coregister (estimate+reslice) c              B5b_coregister_est_re  [alt. to 5]
%   6   Normalization                 w              B6_normalization_run
%   7   Scrubbing (motion outliers)   m<thresh>      B7_scrub_data
%   8   WM/CSF CompCor                (none)         B8_compcorr_run (+ B85, B_reslice)
%   9   Smoothing                     s<kernel>      B9_smoothing_run
%   10  Trends + global signal        (none)         B10_calculating_trends_and_gs
%   11  Nuisance regression           Rhclqg_        B11_regress_out_nuisance
%   12  Band-pass filtering           Fh<hp>l<lp>_   B12_bandpass_filter_run
%
%   Prefixes stack onto the filename left-to-right as steps run, so you can
%   always tell which steps produced a given file, e.g.
%   "Fh01l08_Rhclqg_s8m0.4ar_sub-2230_..." = filtered, nuisance-regressed,
%   smoothed(8mm), scrubbed(thr 0.4), realigned, slice-time-corrected data.
%
%   *** IMPORTANT: execution order = the order of numbers in
%   analysis_steps below, NOT numeric/case order. The default order runs
%   normalization (6) and smoothing (9) AFTER band-pass filtering (12).
%   Don't "tidy" analysis_steps into 1,2,3... without checking this. ***
%
% REQUIRED TOOLBOXES (must be on the MATLAB path -- see SECTION 1)
%   - SPM12
%   - hMRI toolbox
%   - DPABI
%   - bramila (for bramila_framewiseDisplacement, used in step 7)
%   - RESTplus  (used by some steps' underlying calls)
%
% EXPECTED DATA LAYOUT (BIDS-like)
%   <src_dir>/sub-<ID>/ses-<NN>/anat/ses-..._T1w.nii
%   <src_dir>/sub-<ID>/ses-<NN>/func/ses-..._run-01_bold.nii  (+ matching .json)
%   <src_dir>/sub-<ID>/ses-<NN>/func/ses-..._run-02_bold.nii  (+ matching .json)
%   ... (all runs for the session are picked up and processed together)
% =========================================================================


%% ======================= SECTION 1: PATHS & TOOLBOXES ==================
% Edit these once for your machine / HPC account, then you shouldn't need
% to touch this section again.

src_dir   = 'E:\memoslap\restingstate\nifti_bids';   % root folder with sub-*/ses-*/... data
SPM_path  = 'C:\path\to\spm12';                      % SPM12 install folder

addpath(fileparts(mfilename('fullpath')));           % this script's own folder
addpath(fullfile(fileparts(mfilename('fullpath')), 'steps'));  % B*_ step functions

% Not every step needs every toolbox below -- see README.md "Required
% toolboxes" table for the full step-by-step breakdown. Quick summary:
addpath(genpath('C:\path\to\hMRI-toolbox'));   % only for get_metadata_val() (TR/slice-timing from .json), used once before the step loop
addpath(genpath('C:\path\to\DPABI'));          % only for step 8 (CompCor, y_CompCor_PC)
addpath(genpath('C:\path\to\bramila-master'));  % only for step 7 (scrubbing, bramila_framewiseDisplacement)
addpath(genpath('C:\path\to\RESTplus'));       % only for steps 7, 10, 12 (rp_to4d / rp_ReadNiftiImage / rp_Write4DNIfTI / rp_IdealFilter)
addpath(SPM_path);                             % needed for almost every step (1,3,4,5/5b,6,9, + parts of 8 and 10)


%% ======================= SECTION 2: WHAT TO RUN =========================
% Which subject/session, and which steps in which order (see step table
% and the order-matters warning above).

subject_id     = 2230;
session_id     = 1;
analysis_steps = [4, 3, 1, 5, 7, 8, 10, 11, 12, 6, 9];

% Starting file prefix: leave empty '' if starting from raw data, or set
% to e.g. 's8wra' if resuming a pipeline partway through on already
% partially-preprocessed files.
prefix     = '';
corrPrefix = ''; % only needed if multiple differently-preprocessed 'mean*.nii'
                 % files exist and you must disambiguate which one to use


%% ======================= SECTION 3: PIPELINE PARAMETERS =================
% Defaults below match what was used for the memoslap resting-state
% analyses. Change only if you know you need to.

% --- Step 2: delete first N scans ---
x = 0;                    % number of leading volumes to discard (0 = skip step 2)

% --- Step 5/5b: coregistration ---
Co_er = 0;                 % 0 = estimate only (step 5, default) | 1 = estimate+reslice (step 5b)

% --- Step 6: normalization ---
vox_size = [2 2 2];        % output voxel size in mm

% --- Step 7: scrubbing ---
scrub_thresh = 0.4;        % framewise-displacement threshold (mm) for flagging outlier volumes

% --- Step 8: CompCor (WM/CSF nuisance components) ---
compcorr_sj_space   = 1;   % 1 = compute masks in subject (native) space
do_cc_reslice       = 1;   % 1 = reslice WM/CSF masks to functional space
do_cc_smooth_thresh = 1;   % 1 = smooth + threshold masks before extracting components
cc_kernel    = 4;          % smoothing kernel (mm) applied to WM/CSF masks
cc_thresh_wm = 0.95;       % probability threshold for WM mask
cc_thresh_csf = 0.95;      % probability threshold for CSF mask
numComp = 5;                % number of principal components to extract per tissue class

% --- Step 9: smoothing ---
kernel_size = [8 8 8];     % FWHM smoothing kernel (mm)

% --- Step 12: band-pass filtering ---
hpf = 0.01;   % high-pass cutoff (Hz)
lpf = 0.08;   % low-pass cutoff (Hz)


%% ======================= PIPELINE STEP DEFINITIONS ======================
% Everything below this point is the pipeline logic itself. It reads the
% settings above and runs the requested steps in the requested order.
% Normally you shouldn't need to edit anything below here.
% =========================================================================

ntask = session_id;
analysis_switch = analysis_steps;
start_prefix = prefix;

% --- Locate subject data ---
cd(src_dir)
SJ = sprintf('sub-%d', subject_id);
session = sprintf('ses-%02d', ntask);
ses_dir = fullfile(src_dir, SJ, session);

% unzip any .nii.gz files for this session
zip_files = dir(fullfile(ses_dir, '**', ['ses-', '*.gz']));
if ~isempty(zip_files)
    fprintf('Unzipping:\n')
    for z = 1:size(zip_files, 1)
        fprintf('%s\n', [zip_files(z).folder filesep zip_files(z).name])
        gunzip([zip_files(z).folder filesep zip_files(z).name]);
        delete([zip_files(z).folder filesep zip_files(z).name]);
    end
end

% locate functional runs (all runs matching this session, e.g. run-01,
% run-02, ... -- narrow the pattern below if you ever want to restrict to
% a subset of runs)
run_dir = fullfile(ses_dir, 'func');
rd = dir(fullfile(run_dir, 'ses-*run-*bold.nii'));
runs = {};
for r = 1:length(rd)
    runs{r} = rd(r).name;
end

if isempty(runs)
    all_files = dir(fullfile(run_dir, '*.nii*'));
    fprintf('\nNo run files found matching pattern "ses-*run-*bold.nii" in:\n%s\n', run_dir);
    if ~isempty(all_files)
        fprintf('Files found in directory:\n');
        for i = 1:min(10, length(all_files))
            fprintf('  %s\n', all_files(i).name);
        end
    else
        fprintf('Directory is empty or does not exist.\n');
    end
    error('Cannot continue without run files. Check that .nii files have been unzipped.');
end

fprintf('Analysing Data\n')
fprintf('Subject: %s \n', SJ)
fprintf('Session: %s \n', session)
fprintf('Runs: \n')
for r = 1:size(runs,2)
    fprintf('%s \n', runs{r})
end

% anatomical scan location
struct_dir = fullfile(ses_dir, 'anat');
nifti_files = dir(fullfile(run_dir, ['ses-', '*run-*bold*.nii']));
anat_files  = dir(fullfile(struct_dir, ['ses-', '*T1w.nii']));

fprintf('Anatomy files: \n')
for i = 1:size(anat_files,1)
    fprintf('%s \n', anat_files(i).name)
end

% --- Read TR / slice timing from the BIDS .json sidecar, cross-check vs. NIfTI header ---
json_files = dir(fullfile(src_dir, '**', ['task', '*json']));
if isequal(size(json_files), [0, 1])
    % fallback naming pattern
    json_files = dir(fullfile(src_dir, '**', ['ses-', '*bold*.json']));
end

json_file = [json_files(1).folder, filesep, json_files(1).name];
TR_json = get_metadata_val(json_file,'RepetitionTime') / 1000; % sec
slice_timing = get_metadata_val(json_file,'SliceTiming');
n_slices_json = height(slice_timing);
[~, y] = sort(slice_timing);
slice_order = y';

nifti_file_metadata = [nifti_files(1).folder, filesep, nifti_files(1).name];
info = niftiinfo(nifti_file_metadata);
TR_nifti = info.PixelDimensions(4);
n_slices_nifti = info.ImageSize(3);

if round(TR_nifti, 4) ~= round(TR_json, 4)
    warning('TR does not match between json file and nifti')
end
if n_slices_json ~= n_slices_nifti
    warning('Number of slices does not match between json file and nifti')
end

TR = TR_json;
n_slices = n_slices_json;
refslice = slice_order(round(length(slice_order)/2)); % reference slice for slice-timing correction

% NOTE: if you need to run spike removal (e.g. ArtRepair), do it as a
% separate manual step BEFORE this pipeline -- it is not automated here.

%% Run requested steps
% -------------------------------------------------------------------------
currPrefix = start_prefix;

for n = analysis_switch

    switch n

        case 1 % Segmentation
        % -----------------------------------------------------------------
        warning off
        fprintf('\n\nStep 1, segmentation: %s', session)
        B1_segmentation(struct_dir, SJ, SPM_path, '^s.*\.nii');

        case 2 % Delete first X scans
        % -----------------------------------------------------------------
        fprintf('\n\n')
        if x > 0
            for r = 1:size(runs, 2)
                fprintf('Step 2, delete first %s volumes %s %s', num2str(x), SJ, runs{r})
                B2_delete_scans(run_dir, ['^' currPrefix runs{r}], x);
            end
            currPrefix = ['x' num2str(x) currPrefix];
        end

        case 3 % Slice time correction
        % -----------------------------------------------------------------
        % For interleaved slice order: run slice-time correction, then
        % realignment. Otherwise, run realignment first, then slice-time
        % correction (put case 4 before case 3 in analysis_steps).
        fprintf('\n\n')
        for r = 1:size(runs, 2)
            fprintf('Step 3, slice time correction: %s, %s', session, runs{r})
            B3_slice_time_correction(SJ, runs{r}, run_dir, ['^' currPrefix runs{r}], n_slices, slice_order, refslice, TR);
        end
        currPrefix = ['a' currPrefix];

        case 4 % Realignment
        % -----------------------------------------------------------------
        fprintf('\n\n')
        fprintf('Step 4, realignment: %s\n', session)
        for r = 1:size(runs, 2)
            run_files{r} = spm_select('List', run_dir, ['^' currPrefix runs{r}]);
            fprintf('%s\n', run_files{r})
        end
        B4_Realignment_all_runs(run_dir, run_files);
        currPrefix = ['r' currPrefix];

        case 5 % Coregister (estimate [default], or estimate+reslice if Co_er=1)
        % -----------------------------------------------------------------
        fprintf('\n\n')
        if Co_er ~= 1
            fprintf('Step 5, coregistration (estimate): %s\n', session)
            B5_coregister_est(run_dir, struct_dir, '^s.*\.nii', runs, corrPrefix);
        else
            fprintf('Step 5, coregistration (estimate & reslice): %s\n', session)
            B5b_coregister_est_re(currPrefix, run_dir, struct_dir, '^s.*\.nii', runs);
        end

        case 6 % Normalization
        % -----------------------------------------------------------------
        fprintf('\n\n')
        fprintf('Step 6, normalization: %s\n', session)
        B6_normalization_run(run_dir, struct_dir, runs, vox_size, currPrefix);
        currPrefix = ['w' currPrefix];

        case 7 % Scrubbing: compute framewise displacement, flag + interpolate outliers
        % -----------------------------------------------------------------
        fprintf('\n\n')
        scrub_prefix = ['m' num2str(scrub_thresh)];
        for r = 1:size(runs, 2)
            fprintf('Step 7, scrubbing: %s, %s', session, runs{r})

            rp_file = spm_select('List', run_dir, ['^rp_.*' runs{r}(1:end-4) '.*\.txt$']);
            if isempty(rp_file) || size(rp_file,1) ~= 1
                error('Could not uniquely identify motion file for %s', runs{r});
            end

            cfg.motionparam = fullfile(run_dir, strtrim(rp_file));
            cfg.prepro_suite = 'spm';

            [fwd, rms] = bramila_framewiseDisplacement(cfg);
            outliers = fwd > scrub_thresh;
            percent_out = (sum(outliers) / length(outliers)) * 100;
            disp(['outliers for ' SJ ', ' runs{r} ': ' num2str(percent_out) '%']);

            save([run_dir filesep scrub_prefix currPrefix runs{r}(1:end-4) '_FWDstat.mat'], ...
                 'fwd', 'rms', 'outliers', 'percent_out', 'scrub_thresh', 'cfg')

            % scrub outliers by replacing them with the average of nearest neighbors
            B7_scrub_data(run_dir, ['^' currPrefix runs{r}], outliers, scrub_prefix);

            all_percent_out(r) = percent_out;
            all_rp{r} = load(cfg.motionparam);
        end
        currPrefix = [scrub_prefix currPrefix];
        save([src_dir filesep 'all_MOTIONstat_' currPrefix '.mat'], 'SJ', 'runs', 'scrub_thresh', 'all_percent_out', 'all_rp')

        case 8 % CompCor: WM/CSF nuisance components
        % -----------------------------------------------------------------
        fprintf('\nWM / CSF Component Correction\n')
        struct_dir = fullfile(ses_dir, 'anat');

        if compcorr_sj_space
            wm_files  = dir(fullfile(struct_dir, 'c2*T1w.nii'));
            csf_files = dir(fullfile(struct_dir, 'c3*T1w.nii'));

            if isempty(wm_files) || isempty(csf_files)
                all_anat = dir(fullfile(struct_dir, '*.nii'));
                fprintf('\nSegmentation files (c2*T1w.nii, c3*T1w.nii) not found in:\n%s\n', struct_dir);
                if ~isempty(all_anat)
                    fprintf('Files in anat directory:\n');
                    for i = 1:min(10, length(all_anat))
                        fprintf('  %s\n', all_anat(i).name);
                    end
                end
                error('Segmentation files not found. Run step 1 (Segmentation) first.');
            end

            wm_mask  = fullfile(struct_dir, wm_files(1).name);
            csf_mask = fullfile(struct_dir, csf_files(1).name);

            f2 = spm_select('List', run_dir, ['^mean' corrPrefix runs{1}]);
            if isempty(f2) || size(f2,1) == 0
                error('Could not find mean functional image for reslicing masks');
            end
            mean_img = [run_dir filesep strtrim(f2(1,:)) ',1'];

            B_reslice_masks_to_functional(mean_img, {wm_mask, csf_mask});

            cc_prefix = '';
            if do_cc_smooth_thresh
                rwm_files  = dir(fullfile(struct_dir, 'rc2*.nii'));
                rcsf_files = dir(fullfile(struct_dir, 'rc3*.nii'));
                if isempty(rwm_files) || isempty(rcsf_files)
                    error('Resliced segmentation files not found. Check that reslicing completed successfully.');
                end
                wm_mask  = fullfile(struct_dir, rwm_files(1).name);
                csf_mask = fullfile(struct_dir, rcsf_files(1).name);

                B85_smooth_thresh_masks(csf_mask, wm_mask, cc_kernel, cc_thresh_csf, cc_thresh_wm);
                cc_prefix = sprintf('tCSF%dtWM%ds%d', cc_thresh_csf*100, cc_thresh_wm*100, cc_kernel);
            end

            wm_files_final  = dir(fullfile(struct_dir, [cc_prefix 'rc2*.nii']));
            csf_files_final = dir(fullfile(struct_dir, [cc_prefix 'rc3*.nii']));
            if isempty(wm_files_final) || isempty(csf_files_final)
                error('Final processed mask files not found after smoothing/thresholding.');
            end
            wm_mask  = fullfile(struct_dir, wm_files_final(1).name);
            csf_mask = fullfile(struct_dir, csf_files_final(1).name);
        else
            wm_mask  = mni_wm_mask;   %#ok<UNRCH> % define these if compcorr_sj_space = 0
            csf_mask = mni_csf_mask;
        end

        fprintf('\n\n')
        for r = 1:size(runs, 2)
            fprintf('Step 8, CompCorr: %s, %s', session, runs{r})
            B8_compcorr_run(run_dir, SJ, ['^' currPrefix runs{r}], numComp, wm_mask, csf_mask, TR, cc_prefix);
        end

        case 9 % Smoothing
        % -----------------------------------------------------------------
        fprintf('\n\n')
        for r = 1:size(runs, 2)
            fprintf('Step 9, smoothing: %s, %s', session, runs{r})
            B9_smoothing_run(run_dir, SJ, ['^' currPrefix runs{r}], kernel_size);
        end
        currPrefix = ['s' num2str(unique(kernel_size)) currPrefix];

        case 10 % Compute trends & global signal (no data modification -- output feeds step 11)
        % -----------------------------------------------------------------
        fprintf('\n\n')
        use_gm_mask = true;   % set to false if you do NOT want GM masking

        if use_gm_mask
            gm_files = dir(fullfile(struct_dir, 'c1*.nii'));
            if isempty(gm_files)
                error('GM segmentation file (c1*.nii) not found. Run step 1 (Segmentation) first.');
            end
            gm_mask = fullfile(struct_dir, gm_files(1).name);

            ref_func_search = dir(fullfile(run_dir, [currPrefix runs{1}]));
            if isempty(ref_func_search)
                run_base = runs{1}(1:end-4);
                all_func = dir(fullfile(run_dir, ['*' run_base '*.nii']));
                if isempty(all_func)
                    error('Could not find any functional file for run: %s', runs{1});
                end
                fprintf('Warning: Expected file with prefix "%s" not found.\n', currPrefix);
                fprintf('Using file: %s\n', all_func(1).name);
                ref_func = fullfile(run_dir, all_func(1).name);
            else
                ref_func = fullfile(run_dir, ref_func_search(1).name);
            end

            B_reslice_masks_to_functional(ref_func, gm_mask);
            [p, nm, e] = fileparts(gm_mask);
            gm_mask = fullfile(p, ['r' nm e]);   % update to resliced GM mask
        end

        for r = 1:size(runs, 2)
            fprintf('Step 10, trends & GS: %s, %s\n', session, runs{r})
            B10_calculating_trends_and_gs( ...
                run_dir, ...
                ['^' currPrefix runs{r}], ...
                [currPrefix runs{r}], ...
                SPM_path, ...
                gm_mask ...
            );
        end

        case 11 % Nuisance regression (motion, CompCor, global signal, trends)
        % -----------------------------------------------------------------
        fprintf('\n\nStep 11, nuisance regression: %s\n', session)

        rgm_files = dir(fullfile(struct_dir, 'rc1*.nii'));
        if isempty(rgm_files)
            error('Resliced GM mask (rc1*.nii) not found. Run step 10 first.');
        end
        gm_mask = fullfile(struct_dir, rgm_files(1).name);

        for r = 1:size(runs,2)
            fprintf('%s\n', runs{r})
            run_id = runs{r}(1:end-4);

            % regressors included: hm=head motion (step 4), cc=CompCor (step 8),
            % tl=linear trend, tq=quadratic trend, gs=global signal (both step 10)
            B11_regress_out_nuisance(run_dir, [currPrefix runs{r}], gm_mask, 1, 1, 1, 1, 1, run_id);
        end
        currPrefix = ['Rhclqg_' currPrefix];

        case 12 % Band-pass filtering
        % -----------------------------------------------------------------
        fprintf('\n\nStep 12, band-pass filtering: %s\n', session)
        for r = 1:size(runs, 2)
            fprintf('Band-pass filter: %s\n', runs{r})
            filter_imgs = ['^' currPrefix runs{r}];
            B12_bandpass_filter_run(run_dir, TR, hpf, lpf, filter_imgs);
        end

        hpf_str = sprintf('%02d', round(hpf * 100));  % 0.01 -> '01'
        lpf_str = sprintf('%02d', round(lpf * 100));  % 0.08 -> '08'
        currPrefix = [['Fh' hpf_str 'l' lpf_str] '_' currPrefix];

        otherwise
            warning('Step %d is not a recognized pipeline step -- skipped.', n)

    end
end

fprintf('\n\nDone. Final file prefix for this run: %s\n', currPrefix)