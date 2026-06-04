function glm_2ndLevel_ttest

% data source directory
src_dir = 'E:\MeMoSLAP\analysis';

% target directory that will contain the created job.mat file 
tgt_dir      = fullfile(ana_dir, '2nd_level_ttests', '20subsSes1_noEx', 'ttest_DEC_WMid_allBins_hmotion_evenOnsetv2_hpf300_2FSubBin_MEBins_WMBins_newestSPM');
% Name of corresponding first Level Analysis
ffx_dir   = 'new_models/Intensity_low_high_separateRegs_T_rp';

% subject identifiers stub
SJs = [0, 1, 2, 3, 5, 6, 7, 9, 10, 11, 12, 13, 15, 16, 17, 18, 19, 20, 23];

% Create tgt_dir
if ~exist(tgt_dir, 'dir')
    mkdir(tgt_dir)
end            
            
contrast_names = {'WMBins6-8'}; 

concount = 0;   
% cycle over contrasts
for con = [1] %1:numel(contrast_names)
    
    concount = concount+1;
    
    % obtain the single subject contrast image filenames
    fNames = []; 
    for sj = 1:numel(SJs)
        % create SPM style file list for model specification. 
        if con < 10
            filt            = [['con_000' num2str(con)] '*\.nii$'];
        else
            filt            = [['con_00'  num2str(con)] '*\.nii$'];
        end
        sj_ffx_dir      = fullfile(src_dir, SJs{sj}, ffx_dir);
        f               = spm_select('List', sj_ffx_dir, filt);
        fs              = cellstr([repmat([sj_ffx_dir filesep], 1, 1) f repmat(',1', 1, 1)]);
        fNames          = [fNames; fs];
    end

    cur_dir = fullfile(tgt_dir, ['Con' num2str(con) '_' contrast_names{concount}]);% 
    if ~exist(cur_dir, 'dir')
        mkdir(cur_dir)
    end            
      
    
    % create one sample t-test GLM
    % -------------------------------------------------------------------------
    jobs{1}.spm.stats.factorial_design.dir                     = {cur_dir};
    jobs{1}.spm.stats.factorial_design.des.t1.scans            = cellstr(fNames);
    jobs{1}.spm.stats.factorial_design.cov                     = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
    jobs{1}.spm.stats.factorial_design.masking.tm.tm_none      = 1;
    jobs{1}.spm.stats.factorial_design.masking.im              = 1;
    jobs{1}.spm.stats.factorial_design.masking.em              = {''};
    jobs{1}.spm.stats.factorial_design.globalc.g_omit          = 1;
    jobs{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_no  = 1;
    jobs{1}.spm.stats.factorial_design.globalm.glonorm         = 1;

    spm_jobman('run', jobs)
    clear jobs
    
    
    %  Model Estimation 
    % -------------------------------------------------------------------------
    jobs{1}.stats{1}.fmri_est.spmmat = {fullfile(cur_dir, 'SPM.mat')}; 

    % Run the job
    fprintf(['Estimating GLM \n']);
    spm_jobman('run', jobs);

    clear jobs
    
    
    % T-Contrast Specification
    % -------------------------------------------------------------------------

    % one-sample t-test contrast specification
    
    connames = {'Positive Contrast' };

    convecs  = {1};
    
    % Number of contrasts
    numCons  = numel(connames);

    % Cycle over contrast specifications
    for c = 1:numCons

        % Allocate SPM.mat file
        jobs{1}.stats{1}.con.spmmat = {fullfile(cur_dir, 'SPM.mat')}; 

        % Allocate t-contrast structure
        jobs{1}.stats{1}.con.consess{c}.tcon.name    = connames{c};       
        jobs{1}.stats{1}.con.consess{c}.tcon.convec  = convecs{c};         
        jobs{1}.stats{1}.con.consess{c}.tcon.sessrep = 'none';             

        % Don't delete existing contrasts
        jobs{1}.stats{1}.con.delete = 0;   

    end 

    % Run the job
    fprintf(['Computing Contrasts\n'])
    spm_jobman('run', jobs);

    clear jobs

end

