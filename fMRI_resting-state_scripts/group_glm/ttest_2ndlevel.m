clear all
clc

matlabbatch{1}.spm.stats.factorial_design.dir = {'E:\memoslap\restingstate\rs2_lateWM_sphere_2nd'};
matlabbatch{1}.spm.stats.factorial_design.des.t1.scans = {
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2202\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2204\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2205\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2206\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2207\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2210\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2211\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2212\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2214\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2215\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2216\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2217\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2218\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2219\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2220\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2221\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2223\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2225\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2226\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2227\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2228\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2229\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          'E:\memoslap\restingstate\nifti_bids\sub-2230\ses-01\connectivity\ROI2voxel_FC_earlyWM_rS2\corrMap_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-01_dir-AP_bold.nii,1'
                                                          };
matlabbatch{1}.spm.stats.factorial_design.cov = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
matlabbatch{1}.spm.stats.factorial_design.multi_cov = struct('files', {}, 'iCFI', {}, 'iCC', {});
matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1;
matlabbatch{1}.spm.stats.factorial_design.masking.im = 1;
matlabbatch{1}.spm.stats.factorial_design.masking.em = {''};
matlabbatch{1}.spm.stats.factorial_design.globalc.g_omit = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm = 1;

    % Run the job
    fprintf(['Specifying GLM \n']);
    spm_jobman('run', matlabbatch);

    clear matlabbatch

%%
    
    %  Model Estimation 
    % -------------------------------------------------------------------------
    matlabbatch{1}.stats{1}.fmri_est.spmmat = {fullfile('E:\memoslap\restingstate\rs2_lateWM_sphere_2nd', 'SPM.mat')}; 

    % Run the job
    fprintf(['Estimating GLM \n']);
    spm_jobman('run', matlabbatch);


    
