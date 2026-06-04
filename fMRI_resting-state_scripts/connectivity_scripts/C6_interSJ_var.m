function C6_interSJ_var(src_dir,SJs,corr_matrix_folder,corr_matrix_include,sessNum,rois)
% cut data in segments for each subject/run

for s=1:length(SJs)

    corr_data = zeros(sessNum,rois,rois);
    sj_path = [src_dir filesep SJs{s} filesep corr_matrix_folder];
       
    for ses = 1:sessNum

        cd(sj_path)
        c=dir(['*' corr_matrix_include '_' num2str(ses) '*']);
        corr = load([c.folder filesep c.name]);
        this_data = corr.CorrMat;
        corr_data(ses, :, :) = this_data;

    end

    var_data = std(corr_data, 0, 1);
%     eval(['save ' sj_path filesep 'intraSJ_var_SJ_' SJs{s} '.mat var_data'])
    save([sj_path filesep 'intraSJ_var_SJ_' SJs{s}], 'var_data', '-mat');

    imagesc(reshape(var_data, [rois,rois]))

end