function C2_Cut_data_new(run_dir, runs, prefix_func, segment_size, segment_overlap, segment_start)
% cut data in segments for a single subject/session

for r = 1:length(runs)

    f = spm_select('List', run_dir, ['^' prefix_func runs{r}]);
    nr_scans = length(spm_vol([run_dir filesep f]));

    current_TR = segment_start;
    while (current_TR + segment_size-1) <= nr_scans
        display(['run ' runs{r} ', segment ' num2str(current_TR) '-' num2str(current_TR + segment_size-1)])
        M = load_untouch_nii([run_dir filesep f],[current_TR:current_TR + segment_size-1]);
        M.fileprefix = [M.fileprefix '_TR_' num2str(current_TR) '_' num2str(current_TR + segment_size-1)];
        save_untouch_nii(M,[M.fileprefix '.nii']);
        current_TR = current_TR + segment_size - segment_overlap;
    end
    if current_TR < nr_scans
        display(['run ' runs{r} ', segment ' num2str(current_TR) '-' num2str(nr_scans)])
        M = load_untouch_nii([run_dir filesep f],[current_TR:nr_scans]);
        M.fileprefix = [M.fileprefix '_TR_' num2str(current_TR) '_' num2str(nr_scans)];
        save_untouch_nii(M,[M.fileprefix '.nii']);
    end

end
