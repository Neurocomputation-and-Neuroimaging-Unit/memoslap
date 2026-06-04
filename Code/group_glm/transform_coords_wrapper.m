SPM_path = 'C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm12-main';
addpath(SPM_path);
output_dir = 'E:\memoslap\restingstate\2ndLevel\2ndLevel_FlexFact_Interaction_rPCC_roi_seed_for_DMN';
clust_directory = 'E:\memoslap\restingstate\2ndLevel\2ndLevel_FlexFact_Interaction_rPCC_roi_seed_for_DMN';
load(fullfile(clust_directory,'SPM.mat'));

% brain region name
brain_region = 'DMN' ; 

% Load template NIfTI header + build grid once
hdr_template = spm_vol([clust_directory '/mask.nii']);
[nx, ny, nz] = size(spm_read_vols(hdr_template));
[gx, gy, gz] = ndgrid(1:nx, 1:ny, 1:nz);
sphere_radius = 5;
SPM.direction = 'TALtoVOX';

% Find all NIfTI files starting with 'clust' in clust_directory
clust_files = dir(fullfile(clust_directory, 'clust*.nii'));

for i = 1:length(clust_files)

    % Get cluster name from filename
    [~, clust_name, ~] = fileparts(clust_files(i).name);
    fprintf('Processing: %s\n', clust_name);

    % Read the cluster NIfTI
    clust_hdr = spm_vol(fullfile(clust_directory, clust_files(i).name));
    clust_vol = spm_read_vols(clust_hdr);

    % Find voxel indices where cluster mask == 1
    [vx, vy, vz] = ind2sub(size(clust_vol), find(clust_vol > 0));

    if isempty(vx)
        warning('No voxels found in %s, skipping.', clust_name);
        continue;
    end

    % Compute centre of mass in voxel space of the clust file
    coords_com = [mean(vx), mean(vy), mean(vz)];

    % Convert centre of mass to MNI space using the clust file's affine
    mni_homog = clust_hdr.mat * [coords_com(1); coords_com(2); coords_com(3); 1];
    mni_coords = mni_homog(1:3);

    % Convert MNI to voxel space in template (exactly as original)
    SPM.coords = mni_coords;
    [~, vox_coords] = spmutils_transform_coords(SPM);

    % Save individual voxel coordinate file
    filename = fullfile(output_dir, sprintf('vox_%s_%s.mat', clust_name, brain_region));
    save(filename, 'vox_coords');

    % Build sphere around converted voxel coordinate
    V = zeros(nx, ny, nz);
    dist = sqrt((gx - vox_coords(1)).^2 + ...
                (gy - vox_coords(2)).^2 + ...
                (gz - vox_coords(3)).^2);
    V(dist <= sphere_radius) = 1;

    % Write NIfTI named after input file + brain region
    hdr_out = hdr_template;
    hdr_out.fname = fullfile(output_dir, sprintf('sphere_%s_%s.nii', clust_name, brain_region));
    spm_write_vol(hdr_out, V);

    fprintf('Saved: sphere_%s_%s.nii\n', clust_name, brain_region);

end