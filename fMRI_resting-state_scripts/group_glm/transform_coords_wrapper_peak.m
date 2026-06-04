SPM_path = 'C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm12-main';
addpath(SPM_path);
output_dir = 'E:\memoslap\restingstate\2ndLevel\2ndLevel_FlexFact_Interaction_lateWM_rSPL';
clust_directory = 'E:\memoslap\restingstate\2ndLevel\2ndLevel_FlexFact_Interaction_lateWM_rSPL';
load(fullfile(clust_directory,'SPM.mat'));

% brain region name
brain_region = 'rSPL';

% CHANGE: paste your table here, format: {'name', X, Y, Z}
coord_table = {
    'rIFG',     50,   16,   26;
    'rMFG',     44,   13,   30;
    'rSFG',     28,    -2,   64;
};


% Parse into labels and coords
clust_labels  = coord_table(:, 1);
coords_matrix = cell2mat(coord_table(:, 2:4));

% Load template NIfTI header + build grid once
hdr_template = spm_vol([clust_directory '/mask.nii']);
[nx, ny, nz] = size(spm_read_vols(hdr_template));
[gx, gy, gz] = ndgrid(1:nx, 1:ny, 1:nz);
sphere_radius = 5;
SPM.direction = 'TALtoVOX';

for i = 1:size(coords_matrix, 1)

    clust_name = clust_labels{i};
    fprintf('Processing: %s\n', clust_name);

    % Convert MNI to voxel space
    SPM.coords = coords_matrix(i, :)';
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

    % Write NIfTI named after cluster + brain region
    hdr_out = hdr_template;
    hdr_out.fname = fullfile(output_dir, sprintf('sphere_%s_%s.nii', clust_name, brain_region));
    spm_write_vol(hdr_out, V);

    fprintf('Saved: sphere_%s_%s.nii\n', clust_name, brain_region);

end