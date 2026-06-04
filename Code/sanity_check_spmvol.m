% quick_compare_gretna.m
% Quick sanity check: compare GRETNA vs no-GRETNA tMaps

clc
clear

% GRETNA file
gretna_file = 'C:\Users\sreya\Documents\College\Internship_fMRI\Data\brain_mask.nii';

% No-GRETNA file
nogretna_file = 'C:\Users\sreya\Documents\College\Internship_fMRI\Data\PCCseed_region_visualization.nii';

% Load volumes
hdr_A = spm_vol(gretna_file);
A_vol = spm_read_vols(hdr_A);

hdr_B = spm_vol(nogretna_file);
B_vol = spm_read_vols(hdr_B);

% Subtract
diff = A_vol - B_vol;

% Check
max_diff = max(abs(diff(:)));
fprintf('Max difference: %.10e\n', max_diff);

if max_diff == 0
    fprintf('✓ IDENTICAL - Functions are the same!\n');
else
    fprintf('✗ DIFFERENT - Max difference: %.10e\n', max_diff);
end

% Save difference map as NIfTI for visualization
hdr_diff = hdr_A;
hdr_diff.fname = 'C:\Users\sreya\Documents\College\Internship_fMRI\DIFF_atlasPCC_vs_wholebrain.nii';
hdr_diff.descrip = 'Difference: whole brain - atlasPCC';
spm_write_vol(hdr_diff, diff);

fprintf('Difference map saved: %s\n', hdr_diff.fname);
fprintf('Open in SPM to visualize where differences are located.\n');

% Also show some stats about where differences occur
num_nonzero = sum(diff(:) ~= 0);
total_voxels = numel(diff);
fprintf('Non-zero differences in %d / %d voxels (%.2f%%)\n', ...
    num_nonzero, total_voxels, 100*num_nonzero/total_voxels);