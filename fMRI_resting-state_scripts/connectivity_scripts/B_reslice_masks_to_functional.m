function B_reslice_masks_to_functional(mean_img, masks)

% allow single mask or multiple masks
if ischar(masks)
    masks = {masks};
end

% build fileset: reference first, then masks
fileset = cell(numel(masks)+1, 1);
fileset{1} = mean_img;

for i = 1:numel(masks)
    fileset{i+1} = [masks{i} ',1'];
end

matlabbatch{1}.spm.spatial.realign.write.data = fileset;
matlabbatch{1}.spm.spatial.realign.write.roptions.which = [1 0];
matlabbatch{1}.spm.spatial.realign.write.roptions.interp = 4;
matlabbatch{1}.spm.spatial.realign.write.roptions.wrap = [0 0 0];
matlabbatch{1}.spm.spatial.realign.write.roptions.mask = 1;
matlabbatch{1}.spm.spatial.realign.write.roptions.prefix = 'r';

spm('defaults', 'FMRI');
spm_jobman('run', matlabbatch);

end