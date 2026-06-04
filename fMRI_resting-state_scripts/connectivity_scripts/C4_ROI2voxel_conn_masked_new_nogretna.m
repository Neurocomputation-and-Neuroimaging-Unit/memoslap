function C4_ROI2voxel_conn_masked_new_nogretna(SJ, runs, run_dir, prefix_func, atlas, seed_ROI, mask_file, label, out_dir)

%%%%%%%%%%%%%
% with temporal masking of outliers (scrubbing)

% load GM mask once — used for both seed definition and timeseries extraction
Vm = spm_vol(mask_file);
gm_img = spm_read_vols(Vm);
gm_img = (gm_img > 0);   % binary mask

if ischar(seed_ROI)
    % load ROI file and read voxel values restricted to GM mask
    Vr = spm_vol(seed_ROI);
    roi_img = spm_read_vols(Vr);
    roi_img_masked = roi_img .* gm_img;        % restrict to GM
    indsroi = find(roi_img_masked > 0);        % indices of GM voxels inside ROI
    [roi_path, roi_name] = fileparts(seed_ROI);
else
    % load atlas and read voxel values restricted to GM mask
    Vr = spm_vol(atlas);
    atlas_img = spm_read_vols(Vr);
    atlas_img_masked = atlas_img .* gm_img;    % restrict atlas to GM voxels only
    indsroi = find(ismember(atlas_img_masked, seed_ROI));  % seed voxels within GM
    [atlas_dir, atlas_file, atlas_ext] = fileparts(atlas);
    roi_name = atlas_file;
    for i = 1:length(seed_ROI)
        roi_name = [roi_name '_' num2str(seed_ROI(i))];
    end
end

% get brain mask coordinates for output map generation
dim = size(gm_img);
[x, y, z] = ind2sub(dim, find(gm_img));

Vs = Vm;            % struct for save
Vs.dt(1) = 64;      % 64=float32, see spm_type
Vs.pinfo = [1;0;0];
Vs.descrip = 'Result';

clear Vm Vr atlas_img atlas_img_masked roi_img roi_img_masked

% output directory
subject = SJ;
outputdir = fullfile(out_dir, ['ROI2voxel_FC_' roi_name label]);
mkdir(outputdir);

% LOOP over RUNS
for r = 1:length(runs)
    run = runs{r};

    % check for scrubbing
    n = 1;
    f2 = spm_select('List', run_dir, ['^' prefix_func(n:end) run(1:end-4) '.*\_FWDstat.mat']);
    while isempty(f2) && n < length(prefix_func)
        n = n+1;
        f2 = spm_select('List', run_dir, ['^' prefix_func(n:end) run(1:end-4) '.*\_FWDstat.mat']);
    end
    if ~isempty(f2)
        load([run_dir filesep f2], 'outliers')
    end

    % list functional data files
    f1 = spm_select('List', run_dir, ['^' prefix_func run(1:end-4) '.*\.nii']);

    for f = 1:size(f1,1)
        tempfile = deblank(f1(f,:));
        display([subject ', ' run ', file ' tempfile]);

        % read functional data and restrict to GM voxels
        V = spm_vol([run_dir filesep tempfile]);
        data_4d = spm_read_vols(V);                            % load 4D data [x,y,z,t]
        data_2d = reshape(data_4d, [], size(data_4d, 4))';     % reshape to [t x voxels]
        data_voxel = data_2d(:, find(gm_img));                 % restrict to GM voxels only [t x GM voxels]

        roi_data = mean(data_voxel(:, ismember(find(gm_img), indsroi)), 2);  % mean seed timeseries

        % correlation analysis
        [corrval, pval] = corr(roi_data, data_voxel);
        tval = spm_invTcdf(pval, length(roi_data)-1);

        % generate 3D maps
        corrMap = single(zeros(dim));
        pMap    = single(zeros(dim));
        tMap    = single(zeros(dim));
        for i = 1:length(x)
            corrMap(x(i), y(i), z(i)) = corrval(i);
            pMap(x(i),    y(i), z(i)) = pval(i);
            tMap(x(i),    y(i), z(i)) = tval(i);
        end

        % save MATLAB data
        save([outputdir filesep 'R2Vconn_' tempfile(1:end-4) label '.mat'], ...
            'corrval', 'pval', 'tval', 'dim', 'x', 'y', 'z', ...
            'subject', 'run', 'atlas', 'seed_ROI', 'tempfile', 'roi_name');

        % save NIfTI 3D maps
        Vs.fname = [outputdir filesep 'corrMap_' tempfile(1:end-4) label '.nii'];
        Vs = spm_write_vol(Vs, corrMap);
        Vs.fname = [outputdir filesep 'pMap_' tempfile(1:end-4) label '.nii'];
        Vs = spm_write_vol(Vs, pMap);
        Vs.fname = [outputdir filesep 'tMap_' tempfile(1:end-4) label '.nii'];
        Vs = spm_write_vol(Vs, tMap);

        clear cor* data_* i V roi_da* pv* tv* pM* tM* temp*
    end
end
