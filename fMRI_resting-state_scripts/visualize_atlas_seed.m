% visualize_atlas_seed.m
% Create and visualize a seed region from atlas indices

clc
clear

% Atlas file
atlas_file = 'C:\Users\sreya\Documents\College\Internship_fMRI\Toolboxes\spm12-main\AAL3\AAL3v1.nii';

% Define your seed indices (example: calcarine / V1)
seed_indices = [39, 40];  % Change to your indices

% Load atlas
V_atlas = spm_vol(atlas_file);
atlas_img = spm_read_vols(V_atlas);

% Create binary mask for seed region
seed_mask = ismember(atlas_img, seed_indices);

% Save as NIfTI
V_seed = V_atlas;
V_seed.fname = 'C:\Users\sreya\Documents\College\Internship_fMRI\Data\PCCseed_region_visualization.nii';
V_seed.descrip = sprintf('Seed region: indices %s', mat2str(seed_indices));
V_seed.dt = [2 0];  % uint8 for binary mask
spm_write_vol(V_seed, seed_mask);

fprintf('Seed region saved: %s\n', V_seed.fname);
fprintf('Open in SPM Display to visualize.\n');
fprintf('Number of voxels in seed: %d\n', sum(seed_mask(:)));