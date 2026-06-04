function C2_Cut_data(src_dir,SJs,runs,prefix_func,segment_size,segment_overlap,segment_start,sessNum)
% cut data in segments for each subject/run

for s=1:length(SJs)
    
    if sessNum > 0 && exist([src_dir filesep SJs{s} filesep 'ses-1' filesep 'func'])
    
        for ses = 1:sessNum
    
            for r=1:size(runs,2)
                tempdir=[src_dir filesep SJs{s} filesep 'ses-' num2str(ses) filesep 'func'];
                f = spm_select('List',tempdir, ['^' prefix_func runs{s,r}]);
                nr_scans=length(spm_vol([tempdir filesep f]));
        
                current_TR=segment_start;
                while (current_TR + segment_size-1) <= nr_scans
                    display(['subject ' SJs{s} ', ' runs{s,r} ', segment ' num2str(current_TR) '-' num2str(current_TR + segment_size-1)])
                    M = load_untouch_nii([tempdir filesep f],[current_TR:current_TR + segment_size-1]);
                    M.fileprefix = [M.fileprefix '_TR_' num2str(current_TR) '_' num2str(current_TR + segment_size-1)];
                    save_untouch_nii(M,[M.fileprefix '.nii']);
                    current_TR = current_TR + segment_size - segment_overlap;
                end
                if current_TR < nr_scans
                    display(['subject ' SJs{s} ', ' runs{s,r} ', segment ' num2str(current_TR) '-' num2str(nr_scans)])
                    M = load_untouch_nii([tempdir filesep f],[current_TR:nr_scans]);
                    M.fileprefix = [M.fileprefix '_TR_' num2str(current_TR) '_' num2str(nr_scans)];
                    save_untouch_nii(M,[M.fileprefix '.nii']);
                end
        
            end
        end
    else
    
        for r=1:size(runs,2)
            tempdir=[src_dir filesep SJs{s} filesep 'func'];
            f = spm_select('List',tempdir, ['^' prefix_func runs{s,r}]);
            nr_scans=length(spm_vol([tempdir filesep f]));
        
            current_TR=segment_start;
            while (current_TR + segment_size-1) <= nr_scans
                display(['subject ' SJs{s} ', ' runs{s,r} ', segment ' num2str(current_TR) '-' num2str(current_TR + segment_size-1)])
                M = load_untouch_nii([tempdir filesep f],[current_TR:current_TR + segment_size-1]);
                M.fileprefix = [M.fileprefix '_TR_' num2str(current_TR) '_' num2str(current_TR + segment_size-1)];
                save_untouch_nii(M,[M.fileprefix '.nii']);
                current_TR = current_TR + segment_size - segment_overlap;
            end
            if current_TR < nr_scans
                display(['subject ' SJs{s} ', ' runs{s,r} ', segment ' num2str(current_TR) '-' num2str(nr_scans)])
                M = load_untouch_nii([tempdir filesep f],[current_TR:nr_scans]);
                M.fileprefix = [M.fileprefix '_TR_' num2str(current_TR) '_' num2str(nr_scans)];
                save_untouch_nii(M,[M.fileprefix '.nii']);
            end
        
        end
    end
    
end
