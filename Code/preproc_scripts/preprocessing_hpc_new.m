subject_id     = 2230;
session_id     = 1;
analysis_steps = [4, 3, 1, 5, 7, 8, 10, 11, 12, 6, 9];
prefix         = '';

% Preprocessing HPC
% -------------------------------------------------------------------------
% subject_id: double

% Change details here:
ntask = session_id;  
analysis_switch = analysis_steps; % [4, 5, 1, 6, 9]; 
start_prefix=prefix; %''; % if totally raw data, then keep empty, otherwise add prefix, e.g. 's8wra'
corrPrefix = ''; %prefix; %''; % so if you perform differnt kinds of preprocessing, there will be 
% multiple 'mean...nii' files -> check which one you want and if theres anything 
% in between the 'mean' and 'sub-00...' then put that there (probably nothing or an a?)

compcorr_sj_space = 1;
do_cc_reslice = 1;
do_cc_smooth_thresh = 1;
cc_kernel = 4;
cc_thresh_wm = 0.95;
cc_thresh_csf = 0.95;


% Set paths
% -------------------------------------------------------------------------
src_dir      = 'E:\memoslap\restingstate\nifti_bids';
addpath(('C:\Users\sreya\Documents\College\Internship_fMRI\Code\preproc_scripts')); 
addpath(genpath('C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\hMRI-toolbox-0.6.1'));
addpath(genpath('C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\DPABI_V9.0_250415\DPABI_V9.0_250415'));
addpath(genpath('C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\bramila-master'));
addpath(genpath('C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\250123_1003_RESTplus_v1.31'));
% SPM_path = 'C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm_25.01.02';          
SPM_path = 'C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm12-main';          
addpath(SPM_path);

% Get data
% -------------------------------------------------------------------------
cd(src_dir) 
SJ = sprintf('sub-%d', subject_id);

% session & run identifiers
session = sprintf('ses-%02d', ntask);
ses_dir = fullfile(src_dir, SJ, session);

% unzip
zip_files = dir(fullfile(ses_dir, '**', ['ses-', '*.gz']));
if ~isempty(zip_files) 
    fprintf('Unzipping:\n')
	for z = 1:size(zip_files, 1)
        fprintf('%s\n', [zip_files(z).folder filesep zip_files(z).name])
		gunzip([zip_files(z).folder filesep zip_files(z).name]);
        delete([zip_files(z).folder filesep zip_files(z).name]);
	end
end

% get runs
run_dir = fullfile(ses_dir, 'func');
rd = dir(fullfile(run_dir, 'ses-*run-02*bold.nii'));
%rd = dir(fullfile(run_dir, 'ses-*bold.nii'));
runs = {};  % Initialize runs as empty cell array
for r = 1:length(rd)
    runs{r} = rd(r).name;
end

if isempty(runs)
    % Try to show what files exist to help debug
    all_files = dir(fullfile(run_dir, '*.nii*'));
    fprintf('\nNo run files found matching pattern "ses-*bold.nii" in:\n%s\n', run_dir);
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
fprintf('Sesssion: %s \n', session)
fprintf('Runs: \n')
for r = 1:size(runs,2)
    fprintf('%s \n', runs{r})
end

% anatomy identifier
ana = ['anat'];
struct_dir = fullfile(ses_dir, ana);

%nifti_files = dir(fullfile(run_dir, ['ses-', '*run-02*boldb.nii']));
nifti_files = dir(fullfile(run_dir, ['ses-', '*run-02*bold*.nii']));
%nifti_files = dir(fullfile(run_dir, ['ses-', '*bold*.nii'])); %look for all functional nifti files
anat_files = dir(fullfile(struct_dir, ['ses-', '*T1w.nii'])); %look for all anat nifti files

fprintf('Anatomy files: \n')
for i = 1:size(anat_files,1)
    fprintf('%s \n', anat_files(i).name)
end

% anatomical masks (for comp corr)
% mni_wm_mask=['C:\Users\...\wm_mask_eroded.nii']; %white matter mask file
% mni_csf_mask=['C:\Users\...\csf_mask_eroded.nii']; %csf mask file
% full_brain_mask=['C:\Users\...\full_brain_mask.nii']; %full brain mask file

% get the data from the json file 
%json_files = (dir(fullfile(src_dir, '**', '*run-02*boldb*.json')));
json_files = (dir(fullfile(src_dir, '**', ['task', '*json']))); %extract all json files, althoguh they should have the same info 
%to check if the first command returns an empty structure. If yes, it means the json files
%have a different naming, starting with subject 
if isequal(size(json_files), [0, 1]) 
    json_files = (dir(fullfile(src_dir, '**', ['ses-', '*bold*.json'])));
    % json_files = (dir(fullfile(src_dir, '**', ['sub-', '*.json'])));
end

json_file = [json_files(1).folder, filesep, json_files(1).name]; %we select the first json file to extract metadata from 
TR_json = get_metadata_val(json_file,'RepetitionTime') / 1000; % repetition time in sec
slice_timing = get_metadata_val(json_file,'SliceTiming'); %extract slice timing
n_slices_json = height(slice_timing); %compute number of slices from slice timing
[~,y]= sort(slice_timing); %compute slice order 
slice_order = y';

% get the same info from nifti header  
nifti_file_metadata = [nifti_files(1).folder, filesep, nifti_files(1).name] ;
info = niftiinfo(nifti_file_metadata);
TR_nifti = info.PixelDimensions(4); 
n_slices_nifti = info.ImageSize(3);

% compare json and nifti header 
if round(TR_nifti, 4) ~= round(TR_json, 4)
    warning ("TR does not match between json file and nifti") 
end 
if n_slices_json ~= n_slices_nifti
    warning ("Number of slices does not match between json file and nifti") 
end 

TR = TR_json;
n_slices = n_slices_json; 

% Additional input
% -------------------------------------------------------------------------
% ------ NOTE: spike removal (e.g. "artrepair") should be performed as first step
% 1)  Segmentation
% ------ Create nuisance masks on your own or take the provided ones
% 2) --> remove first x scans                       --> prefix: x(number of cut volumes)
x=0;
% 3) --> slice time correction                      --> prefix: a
%  for interleaved slice order: do slice time correction, then realignment
%  otherwise do first realignment, then slice time correction (in analysis_switch 4 before 3)
% n_slices = 37; % number of slices
% slice_order=[1:n_slices];
refslice = slice_order(round(length(slice_order)/2)); % reference slice
% TR=2; % repetition time in sec.
%# step 4  Realignment                                --> prefix: r
% realign over all runs
%# step 5  Coregister (estimate) mean-epi 2 anatomy (DEFAULT)
%# step 5b  Coregister (estimate & resclice) mean-epi 2 anatomy --> prefix c
Co_er = 0; %default: 0, if 1, then estimate & reslice
%# step 6  Normalization                              --> prefix: w
vox_size=[2 2 2]; % preferred voxel size after Normailzation (in mm)
%vox_size=repmat(info.PixelDimensions(1),1,3); % Voxel size from JSON-file (not changed)
%# step 7  Scrubbing: calculate, interpolate outliers --> prefix: m(scrub_thresh)
scrub_thresh=0.4; % threshhold FD for scrubbing
%# step 8 Calculate WM and CSF Nuisance Signal
numComp = 5; % number of principle components
%# step 9 Smoothing                                   --> prefix: s
kernel_size=[8 8 8]; %FWHM kernel size
%# # step 10 Compute trends & global signal (no data modification)
%# step 11 Nuisance regression (motion, CompCor, GS, trends) --> prefix: n
%# step 12 Band-pass filtering                       --> prefix: hp()_lp()
hpf = 0.01;   % high-pass cutoff (Hz)
lpf = 0.08;   % low-pass cutoff (Hz)


%% Analyses
% -------------------------------------------------------------------------
currPrefix=start_prefix;

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
        if x>0
            for r = 1:size(runs, 2)
                fprintf('Step 2, delete first %s volumes %s %s', num2str(x), SJ, runs{r})
                B2_delete_scans(run_dir, ['^' currPrefix runs{r}], x);
            end
            currPrefix = ['x' num2str(x) currPrefix];
        end   

        case 3 % Slice time correction
        % -----------------------------------------------------------------
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
            run_files{r} = spm_select('List',run_dir,['^' currPrefix runs{r}]);
            fprintf('%s\n', run_files{r})
        end
        B4_Realignment_all_runs(run_dir, run_files);
        currPrefix = ['r' currPrefix]; %%%%%%%%%%%%%% fix
            
        case 5 % Coregister (estimate)
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

        currPrefix=['w' currPrefix];
            
        case 7 % Scrubbing: calculate outliers
        % -----------------------------------------------------------------
        fprintf('\n\n')
        scrub_prefix=['m' num2str(scrub_thresh)];
        for r = 1:size(runs, 2)
            fprintf('Step 7, scrubbing: %s, %s', session, runs{r})
            %estimate and save motion statistics
            rp_file = spm_select('List', run_dir, ['^rp_.*' runs{r}(1:end-4) '.*\.txt$']);

            if isempty(rp_file) || size(rp_file,1) ~= 1
                error('Could not uniquely identify motion file for %s', runs{r});
            end

            cfg.motionparam = fullfile(run_dir, strtrim(rp_file));
            cfg.prepro_suite = 'spm';

            %compute FD and outliers
            [fwd,rms]=bramila_framewiseDisplacement(cfg);
            outliers=fwd>scrub_thresh;

            percent_out=(sum(outliers)/length(outliers))*100;
            disp(['outliers for ' SJ ', ' runs{r} ': ' num2str(percent_out) '%']); 

            save([run_dir filesep scrub_prefix currPrefix runs{r}(1:end-4) '_FWDstat.mat'],'fwd','rms','outliers','percent_out','scrub_thresh','cfg')
            %scrub outliers by replacing them with average of nearest neighbors
            % Use currPrefix instead of hardcoded '^r' to scrub the correct files
            B7_scrub_data(run_dir, ['^' currPrefix runs{r}], outliers, scrub_prefix);
            all_percent_out(r)=percent_out;
            all_rp{r}=load(cfg.motionparam);            
        end

        currPrefix=[scrub_prefix currPrefix];
        save([src_dir filesep 'all_MOTIONstat_' currPrefix '.mat'],'SJ','runs','scrub_thresh','all_percent_out','all_rp')
            
        case 8 % CompCorr
        % -----------------------------------------------------------------
	    fprintf('\nWM / CSF Component Correction\n')
        struct_dir = fullfile(ses_dir, ana);
	    if compcorr_sj_space
            % Find the actual segmentation files (they use original anat filename)
            wm_files = dir(fullfile(struct_dir, 'c2*T1w.nii'));
            csf_files = dir(fullfile(struct_dir, 'c3*T1w.nii'));
            
            if isempty(wm_files) || isempty(csf_files)
                % Try to show what's actually in the directory
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
            
            % Use the first match (should only be one T1w file)
            wm_mask = fullfile(struct_dir, wm_files(1).name);
            csf_mask = fullfile(struct_dir, csf_files(1).name);

            f2 = spm_select('List', run_dir, ['^mean' corrPrefix runs{1}]);
            if isempty(f2) || size(f2,1) == 0
                error('Could not find mean functional image for reslicing masks');
            end
            % Use only the first mean image as reference, make it a single string with ',1'
            mean_img = [run_dir filesep strtrim(f2(1,:)) ',1'];

            B_reslice_masks_to_functional(mean_img, {wm_mask, csf_mask});

		cc_prefix = '';
	    if do_cc_smooth_thresh
            % Find the actual resliced segmentation files
            rwm_files = dir(fullfile(struct_dir, 'rc2*.nii'));
            rcsf_files = dir(fullfile(struct_dir, 'rc3*.nii'));
            
            if isempty(rwm_files) || isempty(rcsf_files)
                error('Resliced segmentation files not found. Check that reslicing completed successfully.');
            end
            
            wm_mask = fullfile(struct_dir, rwm_files(1).name);
            csf_mask = fullfile(struct_dir, rcsf_files(1).name);

		B85_smooth_thresh_masks(csf_mask, wm_mask, cc_kernel, cc_thresh_csf, cc_thresh_wm);
		cc_prefix = sprintf('tCSF%dtWM%ds%d', cc_thresh_csf*100, cc_thresh_wm*100, cc_kernel);
	    end 

	    % Find the final processed mask files
        wm_files_final = dir(fullfile(struct_dir, [cc_prefix 'rc2*.nii']));
        csf_files_final = dir(fullfile(struct_dir, [cc_prefix 'rc3*.nii']));
        
        if isempty(wm_files_final) || isempty(csf_files_final)
            error('Final processed mask files not found after smoothing/thresholding.');
        end
        
        wm_mask = fullfile(struct_dir, wm_files_final(1).name);
        csf_mask = fullfile(struct_dir, csf_files_final(1).name);

        else
            wm_mask = mni_wm_mask;
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
            B9_smoothing_run(run_dir, SJ, ['^' currPrefix runs{r}],kernel_size);
        end
        currPrefix=['s' num2str(unique(kernel_size)) currPrefix];
            
        case 10 % Calculate trends and global signal
        % -----------------------------------------------------------------   
        fprintf('\n\n')
        
        use_gm_mask = true;   % set to false if you do NOT want GM masking
        
        % --- GM mask reslicing
        if use_gm_mask
            % Find the actual GM segmentation file
            gm_files = dir(fullfile(struct_dir, 'c1*.nii'));
            if isempty(gm_files)
                error('GM segmentation file (c1*.nii) not found. Run step 1 (Segmentation) first.');
            end
            gm_mask = fullfile(struct_dir, gm_files(1).name);
            
            % Find the actual functional file to use as reference
            % Try to find with current prefix first
            ref_func_search = dir(fullfile(run_dir, [currPrefix runs{1}]));
            if isempty(ref_func_search)
                % If not found, try to find ANY functional file for this run
                run_base = runs{1}(1:end-4); % Remove .nii extension
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
        
            [p, n, e] = fileparts(gm_mask);
            gm_mask = fullfile(p, ['r' n e]);   % update to resliced GM mask
        end
        
        for r = 1:size(runs, 2)
        
            fprintf('Step 10, trends & GS: %s, %s\n', session, runs{r})
        
            f = spm_select('List', run_dir, ['^' currPrefix runs{r}]);
            V = spm_vol([run_dir filesep f(1,:)]);
        
            files = cell(size(V,1),1);
            for i = 1:size(V,1)
                files{i} = [run_dir filesep strtrim(f(1,:)) ',' num2str(i)];
            end
        
            fileset{r} = char(files);
        
            % output filename for nuisance regressors
            nuisance_file = fullfile(run_dir, ...
                ['nuisance_' currPrefix runs{r}(1:end-4) '.mat']);
        
            % compute trends + GS 
            B10_calculating_trends_and_gs( ...
                run_dir, ...
                ['^' currPrefix runs{r}], ...
                [currPrefix runs{r}], ...
                SPM_path, ...
                gm_mask ...
            );
        
        end

        case 11 % Nuisance regression
        % -----------------------------------------------------------------
        fprintf('\n\nStep 11, nuisance regression: %s\n', session)
        
        % Get GM mask (resliced in step 10)
        % Search for the actual resliced GM mask file
        rgm_files = dir(fullfile(struct_dir, 'rc1*.nii'));
        if isempty(rgm_files)
            error('Resliced GM mask (rc1*.nii) not found. Run step 10 first.');
        end
        gm_mask = fullfile(struct_dir, rgm_files(1).name);
        
        % Use currPrefix which should be 'm0.4ar' after steps 4,3,7
        
        for r = 1:size(runs,2)
            fprintf('%s\n', runs{r})
            
            % Extract run identifier (remove .nii extension)
            run_id = runs{r}(1:end-4);
        
            % Call B11 with current prefix
            % hm=1 (head motion from step 4), cc=1 (compcorr from step 8)
            % tl=1 (linear trend from step 10), tq=1 (quadratic trend from step 10)
            % gs=1 (global signal from step 10)
            prefix_out = B11_regress_out_nuisance(run_dir, [currPrefix runs{r}], gm_mask, 1, 1, 1, 1, 1, run_id);
        end
        
        currPrefix = ['Rhclqg_' currPrefix];



        case 12 % Band-pass filtering
        % -----------------------------------------------------------------
        fprintf('\n\nStep 12, band-pass filtering: %s\n', session)

        for r = 1:size(runs, 2)
            fprintf('Band-pass filter: %s\n', runs{r})

            % run_dir already points to ses/.../func
            % filter_imgs must be a pattern for spm_select
            filter_imgs = ['^' currPrefix runs{r}];

            B12_bandpass_filter_run(run_dir, TR, hpf, lpf, filter_imgs);
        end

        % build band-pass prefix from filter parameters
        hpf_str = sprintf('%02d', round(hpf * 100));  % 0.01 -> '01'
        lpf_str = sprintf('%02d', round(lpf * 100));  % 0.08 -> '08'
        
        pref = ['Fh' hpf_str 'l' lpf_str];
        
        % update current prefix (same logic as previous steps)
        currPrefix = [pref '_' currPrefix];
       

            %files={};
            %for i=1:(size(V,1))
             %   files{i} = [run_dir filesep strtrim(f(1,:)) ',' int2str(i)];
            %end
            %fileset{r}=char(files);
        %end

        %if exist('fileset')
            %B10_detrending_lmgs(fileset);
            %clear fileset files
        %end

        
        % -----------------------------------------------------------------   

        % fprintf('######################################################################################')
        % fprintf('############################## Case %d does not exsist ##############################', n)
        % fprintf('######################################################################################')

    end
end