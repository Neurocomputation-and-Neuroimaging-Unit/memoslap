connmat_run1 = load("C:\Users\sreya\Documents\College\Internship_fMRI\Data\sub-2600\intraSJ_var\intraSJ_var_runs_sub-2600_ses-02.mat");
% connmat_run2 = load("C:\Users\sreya\Documents\College\Internship_fMRI\Data\sub-2202\ses-01\ROI2ROI_FC_AAL3v1\R2Rconn_s8wFh01l08_Rhclqg_m0.4arses-expRest_task-resting_run-02_dir-AP_bold_sess.mat");

y = squeeze(connmat_run1.var_runs);  %var_runs for intraSJ or CorrMat
imagesc(y)