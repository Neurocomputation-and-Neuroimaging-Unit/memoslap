function B5b_coregister_est_re(currPrefix, func_dir, struct_dir, filter_struct, runs)

warning off

f1 = spm_select('List', struct_dir, filter_struct);
numVols = size(f1,1);
structural = cellstr([repmat([struct_dir filesep], numVols, 1) f1 repmat(',1', numVols, 1)]);

f2 = spm_select('List', func_dir, ['^mean' runs{1}]); 
numVols = size(f2,1);
mean_img   = cellstr([repmat([func_dir filesep], numVols, 1) f2 repmat(',1', numVols, 1)]);

for r = 1:size(runs,2)
    f3 = spm_select('ExtFPList', func_dir, ['^' currPrefix runs{r}],Inf);
    numVols = size(f3,1);
    Images{r,:}=cellstr(spm_select('ExtFPList', func_dir,['^' currPrefix runs{r}],Inf));
end
%--------------------------------------------------------------------------
%---------------------- Coregister (Estimate & Reslice) -------------------
%--------------------------------------------------------------------------
for i = 1:size(Images,1)
    matlabbatch{1}.spm.spatial.coreg.estimate.ref = structural;
    matlabbatch{1}.spm.spatial.coreg.estimate.source = mean_img;
    matlabbatch{1}.spm.spatial.coreg.estimate.other = Images{i,:};
    matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';
    matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
    matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
    matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.interp = 4;
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.wrap = [0 0 0];
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.mask = 0;
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.prefix = 'c';

    % run job
    spm_jobman('run', matlabbatch)
    clear jobs
end
