function prefix = B11_regress_out_nuisance(data_dir, filter, fbm, hm, cc, tl, tq, gs, run_id)

% make NIFTIs with regressed out nuisance variables
% data_dir: directory containing the data
% filter: file pattern to match (includes prefix and run name)
% fbm: full brain/GM mask
% hm: include head motion (1/0)
% cc: include CompCorr (1/0)
% tl: include linear trend (1/0)
% tq: include quadratic trend (1/0)
% gs: include global signal (1/0)
% run_id: run identifier (e.g., 'sub-2000_ses-rest1_task-resting_dir-AP_run-01_bold' without .nii)

%% load covariates
%head motion
if hm
    dinfo='> head motion ';
    prefix='Rh';
    % Find realignment parameter file from step 4 (rp_*.txt)
    % Use run_id to find the specific file for this run
    f=spm_select('List',data_dir,['^rp_.*' run_id '.*\.txt$']);
    if isempty(f)
        % Try without the strict ending
        f=spm_select('List',data_dir,['^rp_.*' run_id '.*\.txt']);
    end
    if ~isempty(f)
        % If multiple files match, take the first one
        if size(f,1) > 1
            f = f(1,:);
        end
        nCOV=load([data_dir filesep strtrim(f)]);
    else
        error('Could not find head motion file for run: %s', run_id);
    end
else
    nCOV=[];    %nuisance Covariates
    dinfo='';
    prefix='R';
end

%CompCorr
if cc
    % CompCorr PCs from step 8 - look for files with CompCorPCs
    % Use run_id to find the specific file for this run
    f=spm_select('List',data_dir,['.*' run_id '_CompCorPCs.txt']);
    if isempty(f)
        % Try with prefix pattern
        f=spm_select('List',data_dir,[run_id '_CompCorPCs.txt']);
    end
    if ~isempty(f)
        % If multiple files match, take the first one
        if size(f,1) > 1
            f = f(1,:);
        end
        temp = load([data_dir filesep strtrim(f)]);
        nCOV=[nCOV temp];
        clear temp
    else
        error('Could not find CompCorr file for run: %s', run_id);
    end
    dinfo=[dinfo ' > CompCorr PCs '];
    prefix=[prefix 'c'];
end

%linear trend
if tl
    % Linear trend from step 10
    % Use run_id to find the specific file for this run
    f=spm_select('List',data_dir,['.*' run_id '_trend_linear.txt']);
    if isempty(f)
        f=spm_select('List',data_dir,[run_id '_trend_linear.txt']);
    end
    if ~isempty(f)
        % If multiple files match, take the first one
        if size(f,1) > 1
            f = f(1,:);
        end
        temp = load([data_dir filesep strtrim(f)]);
        nCOV=[nCOV temp];
        clear temp
    else
        error('Could not find linear trend file for run: %s', run_id);
    end
    dinfo=[dinfo ' > linear trend '];
    prefix=[prefix 'l'];
end

%quadratic trend
if tq
    % Quadratic trend from step 10
    % Use run_id to find the specific file for this run
    f=spm_select('List',data_dir,['.*' run_id '_trend_quadratic.txt']);
    if isempty(f)
        f=spm_select('List',data_dir,[run_id '_trend_quadratic.txt']);
    end
    if ~isempty(f)
        % If multiple files match, take the first one
        if size(f,1) > 1
            f = f(1,:);
        end
        temp = load([data_dir filesep strtrim(f)]);
        nCOV=[nCOV temp];
        clear temp
    else
        error('Could not find quadratic trend file for run: %s', run_id);
    end
    dinfo=[dinfo ' > quadratic trend '];
    prefix=[prefix 'q'];
end

%global signal
if gs
    % Global signal from step 10
    % Use run_id to find the specific file for this run
    f=spm_select('List',data_dir,['.*' run_id '_global_signal.txt']);
    if isempty(f)
        f=spm_select('List',data_dir,[run_id '_global_signal.txt']);
    end
    if ~isempty(f)
        % If multiple files match, take the first one
        if size(f,1) > 1
            f = f(1,:);
        end
        temp = load([data_dir filesep strtrim(f)]);
        nCOV=[nCOV temp];
        clear temp
    else
        error('Could not find global signal file for run: %s', run_id);
    end
    dinfo=[dinfo ' > global signal '];
    prefix=[prefix 'g'];
end

prefix=[prefix '_'];
%% load data

% Remove .nii extension from filter if present for pattern matching
filter_pattern = filter;
if endsWith(filter_pattern, '.nii')
    filter_pattern = filter_pattern(1:end-4);
end

f=spm_select('List',data_dir,['^' filter_pattern '\.nii$']);
% If multiple files match, take the first one
if size(f,1) > 1
    f = f(1,:);
end

if isempty(f)
    error('Could not find functional data file matching pattern: %s in %s', filter_pattern, data_dir);
end

rest_file=[data_dir filesep strtrim(f)];

% Use SPM's spm_vol and spm_read_vols which handle varying orientations
V = spm_vol(rest_file);
numVols = length(V);

% Get dimensions from first volume
[nDim1, nDim2, nDim3] = size(spm_read_vols(V(1)));

% Read all volumes
AllVolume = zeros(nDim1, nDim2, nDim3, numVols);
for v = 1:numVols
    AllVolume(:,:,:,v) = spm_read_vols(V(v));
end

% Store header info
Header = V(1);
vsize = sqrt(sum(V(1).mat(1:3,1:3).^2));

%load full brain mask
V_mask = spm_vol(fbm);
gm_mask = spm_read_vols(V_mask);
[nDim1, nDim2, nDim3]=size(gm_mask);

%% check for scrubbing
% Look for scrubbing files from step 7 (FWDstat.mat files)
% Use run_id to find the specific file for this run
f3=spm_select('List',data_dir,['.*' run_id '_FWDstat.mat']);
if isempty(f3)
    % Try simpler pattern
    f3=spm_select('List',data_dir,[run_id '_FWDstat.mat']);
end
if ~isempty(f3)
    % If multiple files match, take the first one
    if size(f3,1) > 1
        f3 = f3(1,:);
    end
    load([data_dir filesep strtrim(f3)])
    %mask 'bad' time points (outliers)
    nCOV_masked = nCOV(find(~outliers),:);
    AllVolume_masked = AllVolume(:,:,:,find(~outliers));
    numVols_masked=size(AllVolume_masked,4);
    fprintf('Found scrubbing data: %d outliers masked\n', sum(outliers));
else
    fprintf('No scrubbing data found for this run\n');
    nCOV_masked = nCOV;
    AllVolume_masked = AllVolume;
    numVols_masked=size(AllVolume_masked,4);
end


%% regress out nuisance covariates
fprintf('\n');
display(['regress out nuisance covariates: ' dinfo]);

AllVolume=reshape(AllVolume,[],numVols)';    % Convert into 2D
AllVolume_masked=reshape(AllVolume_masked,[],numVols_masked)';    % Convert into 2D


Residual_data=[];
for i = 1:size(AllVolume_masked,2)
    resp = AllVolume_masked(:,i);
    % Replace regstats with basic linear regression: Y = X*beta + intercept
    % Add intercept column to nCOV_masked
    X = [ones(size(nCOV_masked,1),1) nCOV_masked];
    % Solve for beta using least squares: beta = (X'*X)\(X'*Y)
    all_betas = X\resp;
    % Extract betas (exclude intercept, keep only nuisance regressors)
    Betas = all_betas(2:(size(nCOV,2)+1));
    nuisance = nCOV*Betas;
    Residual_data(:,i) = AllVolume(:,i) - nuisance;
end

%mask out non-brain regions
Residual_data(isnan(gm_mask) | gm_mask==0)=0;
% Convert into 4D
AllVolumeBrain=reshape(Residual_data',[nDim1, nDim2, nDim3, numVols]);
% Save all images to disk
fprintf('\n\t Saving data.\tWait...');

% Create new header for output
Vo = V(1);  % Use first volume as template
Vo.fname = [data_dir filesep prefix strtrim(f)];
Vo.pinfo = [1;0;0];
Vo.dt = [16 0];  % float32

% Write 4D volume
for v = 1:numVols
    Vo.n = [v 1];
    spm_write_vol(Vo, AllVolumeBrain(:,:,:,v));
end
%clear All* temp_path

fprintf('...done\n\n');
