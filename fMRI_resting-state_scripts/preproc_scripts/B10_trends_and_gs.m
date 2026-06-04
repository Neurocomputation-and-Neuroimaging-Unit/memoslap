function B10_trends_and_gs(fileset, nuisance_file)
% function B10_trends_and_gs(data_dir, filter, filtered_file, SPM_path, fbm)

% Function does not modify the functional data
% File selection handled by the calling pipeline

fprintf('    Computing trends and global signal...\n');
%% Load data using SPM (4D)
V = spm_vol(fileset);
AllVolume = spm_read_vols(V);

% Dimensions
[nDim1, nDim2, nDim3, nTimePoints] = size(AllVolume);

%apply GM mask
[gm_mask, vsize, AllFileList ,Header, nVolumn] =rp_to4d(fbm);
data=[];
for i=1:nDimTimePoints
    temp=AllVolume(:,:,:,i);
    data(:,i)=temp(find(gm_mask)); % 2d, voxel x time
end


%check for scrubbing
n=1;
f3=spm_select('List',data_dir, ['^' filtered_file(n:end) '.*\_FWDstat.mat']);
while isempty(f3) && n<length(filtered_file)
    n=n+1;
    f3=spm_select('List',data_dir,['^' filtered_file(n:end) '.*\_FWDstat.mat']);
end
if ~isempty(f3)
    load([data_dir filesep f3],'outliers')
    %mask outliers
    data_masked=data(:,find(~outliers));
else
    data_masked=data;
end


%f=spm_select('List',data_dir, filter);
%rest_file=[run_dir filesep f];
%[AllVolume, vsize, AllFileList ,Header, nVolumn] =rp_to4d(rest_file);

%% Compute Global Signal (mean over all voxels)
GS = zeros(nTimePoints,1);
for t = 1:nTimePoints
    vol = AllVolume(:,:,:,t);
    GS(t) = mean(vol(~isnan(vol)));
end

%% Compute temporal trends
time = (1:nTimePoints)';

% Linear + quadratic trends (matches typical B0 behavior)
trend_linear    = detrend(time, 0);
trend_quadratic = detrend(time.^2, 0);

trends = [trend_linear, trend_quadratic];

%% Save nuisance regressors
save(nuisance_file, ...
    'GS', ...
    'trends', ...
    'time', ...
    '-v7');

fprintf('    Saved nuisance regressors to:\n    %s\n', nuisance_file);

end
 
