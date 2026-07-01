function B2_delete_scans(run_dir, filter, nr_scans)

f=spm_select('List', run_dir, filter);

file=[run_dir filesep f];
%spm_file_split(file);

N=load_untouch_nii(file);
N.img(:,:,:,1:nr_scans)=[];
N.hdr.dime.dim(5)=N.hdr.dime.dim(5)-nr_scans;
save_untouch_nii(N,[run_dir filesep 'x' num2str(nr_scans) f]);
