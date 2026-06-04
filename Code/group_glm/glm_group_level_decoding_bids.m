clc;clear
addpath('C:\Users\nnu04\code\MATLAB\toolboxes\spm12_newest\')
ana_dir = 'H:\memoslap\decoding_bids';
% ana_dir = 'H:\memoslap\decoding_fmriprep';
% ana_dir = 'H:\memoslap_sham\decoding_bids';
% ana_dir = 'H:\memoslap_sham\decoding_fmriprep';

analysis = 'WMid'; 
% analysis = 'WMcontrol';

% dec_dir = sprintf('DEC_13Bins_%s_hm_cctCSF0tWM0s4r_hpf192_6voxRad', analysis);
% dec_dir = sprintf('DEC_13Bins_%s_hm_ccr_hpf192_6voxRad', analysis);
% dec_dir = sprintf('DEC_13Bins_WMid_hm_cccatsegtCSF0tWM0s4r_hpf192_6voxRad');
% dec_dir = sprintf('DEC_fmriprep_13Bins_WMid_nohm_hpf192_6voxRad');

% DEC_13Bins_WMid_hm_cctCSF0tWM0s4r_hpf192_6voxRad
% dec_dir = sprintf('DEC_13Bins_WMid_hm_cctCSF0tWM0s4r_hpf192_6voxRad');
% dec_dir = sprintf('DEC_13Bins_WMid_hm_cccatsegtCSF0tWM0s4r_hpf192_6voxRad');
dec_dir = sprintf('DEC_13Bins_WMid_hm_cctCSF9500tWM9500s4r_hpf192_6voxRad'); 
% dec_dir = sprintf('DEC_13Bins_WMid_hm_ccCSF_WM_MNIerodedMaskr_hpf192_6voxRad'); 

% dec_dir = sprintf('DEC_13Bins_WMid_ccfmriprep_hpf192_6voxRad');
% res_dir = fullfile(ana_dir,'testing', 'group_level_19subs_fmriprep', sprintf('Bins5-10_%s', dec_dir));

% res_dir = fullfile(ana_dir, 'group_level_19subs', sprintf('Bins3-8_%s', dec_dir));
% res_dir = fullfile(ana_dir, 'group_level_20subs_catNorm', sprintf('Bins5-10_%s', dec_dir));
% res_dir = fullfile(ana_dir, 'group_level_20subs_ccr_catNorm', sprintf('Bins5-10_%s', dec_dir));
% res_dir = fullfile(ana_dir, 'group_level_20subs_ccr', sprintf('Bins5-10_%s', dec_dir));
% res_dir = fullfile(ana_dir, 'group_level_20subs_cccatseg', sprintf('Bins5-10_%s', dec_dir));

res_dir = fullfile(ana_dir, 'group_level_50subs_ccr', sprintf('Bins5-10_%s', dec_dir));
% res_dir = fullfile(ana_dir,'testing', 'group_level_40subs_noncatseg', sprintf('Bins5-10_%s', dec_dir));
% res_dir = fullfile(ana_dir,'testing', 'group_level_40subs_noncatseg_noncatnorm', sprintf('Bins5-10_%s', dec_dir));
% res_dir = fullfile(ana_dir,'testing_for_pysvm', 'group_level_16subs', sprintf('Bins5-10_%s', dec_dir));

% res_dir = fullfile(ana_dir, 'group_level_32subs_fmriprep', sprintf('Bins4-9_%s', dec_dir));

% res_dir = fullfile(ana_dir, 'group_level_18subs_Ex7', sprintf('Bins5-10_%s', dec_dir));
% res_dir = fullfile(ana_dir, 'group_level_18subs_Ex7_fullCons', sprintf('Bins5-10_%s', dec_dir));

if ~exist(res_dir,'dir')
    mkdir(res_dir) 
end 

% note: running subject number include study drop-outs and exclusions based on
% non-performance (chance level)
% subnums = [2 4 5 7 8 9 10 11 12 13 15 16 17 18 20 21 22 23 25 28];
% subnums = [2 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 25 26 27 28 29 30 31 32 33 34 35 36 37 39 41 42 43 44 45 46];
% subnums = [2 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 25 26 27 28 29 30 31 32 33 34 35 36 37 39 41 42 43 44 45 46 47 48 52 53 56];
subnums = [2 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 25 26 27 28 29 30 31 32 33 34 35 36 37 39 41 42 43 44 45 46 47 48 50 52 53 54 55 56 57];

% w/o 27 
% subnums = [2 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 25 26 28 29 30 31 32 33 34 35 36 37 39 41 42 43 44 45 46];

% subnums = [0 2 3 5 6 7 9 10 11 12 13 15 17 18 19 20 21 23 24];

% subnums = [2 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 25 26 27 28 29 30 31 32 33 34 35 36 37 39 41 42 43 44 45 46];

% subnums = [1 2 3 7 9 10 11 12 13 15 16 17 18 19 20 21];

% subnum_base = 2000;
subnum_base = 2200;

sesnums = [3, 4];

dec_bins = [5:10];
% dec_bins = [4:9];
bin_dir_prefix = 'mean_bin_';
map_name = 's5wres_accuracy_minus_chance.nii,1';
% map_name = 's5cres_accuracy_minus_chance.nii,1';

design = [ones(1,6), 2*ones(1,6); 1:6, 1:6];

connames = {'Full WM', 'Early WM', 'Late WM'};
convecs = [1 1 1 1 1 1, 1 1 1 1 1 1, ones(1,length(subnums))*12/length(subnums);
           1 1 1 0 0 0, 1 1 1 0 0 0, ones(1,length(subnums))*6/length(subnums);
           0 0 0 1 1 1, 0 0 0 1 1 1, ones(1,length(subnums))*6/length(subnums)];

%%

matlabbatch{1}.spm.stats.factorial_design.dir = {res_dir};

matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(1).name = 'subject';
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(1).dept = 0;       
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(1).variance = 0;  
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(1).gmsca = 0;
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(1).ancova = 0;

matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(2).name = 'Session';
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(2).dept = 1;
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(2).variance = 1;
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(2).gmsca = 0;
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(2).ancova = 0;

matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(3).name = 'Bin';
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(3).dept = 1;
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(3).variance = 0;
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(3).gmsca = 0;
matlabbatch{1}.spm.stats.factorial_design.des.fblock.fac(3).ancova = 0;

scount=0;
for s = subnums
    scount = scount+1;
    imgs = cell(length(sesnums)*length(dec_bins),1);
    bcount = 0;
    for ses = sesnums
        sub_dir = fullfile(ana_dir, sprintf('sub-%04d', subnum_base+s), sprintf('ses-%02d', ses), dec_dir);
        for b = dec_bins
            bcount = bcount+1;
            map = fullfile(sub_dir, sprintf('%s%d',bin_dir_prefix,b), map_name);
            imgs{bcount} = map;
        end
    end

    matlabbatch{1}.spm.stats.factorial_design.des.fblock.fsuball.fsubject(scount).scans = imgs;
    matlabbatch{1}.spm.stats.factorial_design.des.fblock.fsuball.fsubject(scount).conds = design; 

end

matlabbatch{1}.spm.stats.factorial_design.des.fblock.maininters{1}.fmain.fnum = 1;
matlabbatch{1}.spm.stats.factorial_design.des.fblock.maininters{2}.inter.fnums = [2; 3];

matlabbatch{1}.spm.stats.factorial_design.cov = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
matlabbatch{1}.spm.stats.factorial_design.multi_cov = struct('files', {}, 'iCFI', {}, 'iCC', {});
matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1;
matlabbatch{1}.spm.stats.factorial_design.masking.im = 0;
matlabbatch{1}.spm.stats.factorial_design.masking.em = {'E:\MeMoSLAP\masks\mask.nii'}; 
matlabbatch{1}.spm.stats.factorial_design.globalc.g_omit = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%% CREATE GLM %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('Creating GLM\n')

spm_jobman('run', matlabbatch);
clear matlabbatch

%%%%%%%%%%%%%%%%%%%%%%%%%% ESTIMATE GLM %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

load(fullfile(res_dir, 'SPM.mat'));

fprintf('Estimating GLM \n');
cd(res_dir);
SPM = spm_spm(SPM);
clear SPM;

%%%%%%%%%%%%%%%%%%%%%%%%%% Contrasts %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('Contrasts \n');

matlabbatch{1}.spm.stats.con.spmmat = {fullfile(res_dir, 'SPM.mat')};
% Cycle over contrast specifications
for c = 1:numel(connames)
    % Allocate t-contrast structure
    matlabbatch{1}.spm.stats.con.consess{c}.tcon.name    = connames{c};       
    matlabbatch{1}.spm.stats.con.consess{c}.tcon.weights = convecs(c,:);         
    matlabbatch{1}.spm.stats.con.consess{c}.tcon.sessrep = 'none';             
end 
% Delete existing contrasts (1=yes)
matlabbatch{1}.spm.stats.con.delete = 1;

spm_jobman('run', matlabbatch);
clear matlabbatch