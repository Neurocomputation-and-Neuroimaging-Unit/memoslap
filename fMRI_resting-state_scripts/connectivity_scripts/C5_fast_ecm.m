function C5_fast_ecm(SJs,runs,src_dir,prefix_func,mask,ztransform,smooth,kernel_size,sessNum)
%                   SJs,runs,src_dir,prefix_func,gm_mask,ztransform,smooth,sessNum

% This is a Batch-Script to compute Eigen-Centrality-Maps for all subjects
% The pre-processed data for each run is taken individually

mask_grey=load_untouch_nii(mask);
gg=mask_grey.img;

for s = 1:length(SJs)
    subject=SJs{s};
    ECM_dir=[src_dir filesep subject filesep 'ECM_results'];
    mkdir(ECM_dir)

    if sessNum > 0 && exist([src_dir filesep SJs{s} filesep 'ses-1' filesep 'func'])
        for ses = 1:sessNum
            for r = 1:size(runs,2)
                run=runs{s,r};
                run_dir=[src_dir filesep subject filesep 'ses-' num2str(ses) filesep 'func'];

                scan_indx=[];
                %check for scrubbing
                n=1;
                f2=spm_select('List',run_dir,['^' prefix_func(n:end) run(1:end-4) '.*\_FWDstat.mat']);
                while isempty(f2) && n<length(prefix_func)
                    n=n+1;
                    f2=spm_select('List',run_dir,['^' prefix_func(n:end) run(1:end-4) '.*\_FWDstat.mat']);
                end
                if ~isempty(f2)
                    load([run_dir filesep f2],'outliers')
                end

                %find functional files
                f1 = spm_select('List',run_dir, ['^' prefix_func run(1:end-4) '.*\.nii']);

                for f=1:size(f1,1)
                    tempfile=deblank(f1(f,:));
                    display([subject ', ' run ', file ' tempfile]);
                    functional_SJdata=[run_dir filesep tempfile];

                    %check data segment
                    n=1;
                    while ~strcmp('TR',tempfile(n:n+1)) && n<length(tempfile)-1
                        n=n+1;
                    end
                    if n==length(tempfile)-1
                        inx=[1 length(spm_vol(functional_SJdata))];
                    else
                        while ~strcmp('_',tempfile(n))
                            n=n+1;
                        end

                        tmp=[];
                        n=n+1;
                        while ~strcmp('_',tempfile(n))
                            tmp=[tmp tempfile(n)];
                            n=n+1;
                        end
                        inx(1)=str2num(tmp);

                        tmp=[];
                        n=n+1;
                        while ~strcmp('.',tempfile(n))
                            tmp=[tmp tempfile(n)];
                            n=n+1;
                        end
                        inx(2)=str2num(tmp);
                    end
                    if ~isempty(f2)
                        scan_indx=find(~outliers(inx(1):inx(2)));
                    end

                    C5b_fastECM_hacked(functional_SJdata,0,1,0,24,mask,0,scan_indx);

                    %### Find ECM files for renaming
                    files2move = cellstr(spm_select('List',run_dir, [ '^*' prefix_func '.*\ECM.nii'] ));
                    for i=1:length(files2move)
                        movefile(fullfile(run_dir, files2move{i}),[run_dir filesep files2move{i}(end-10:end-4) '_' files2move{i}(1:end-12) '.nii']);
                    end

                    %###  Z-Transform and smoothing
                    file2transform=spm_select('List',run_dir,['^fastECM_.*\' prefix_func run(1:end-4)]);

                    if ztransform
                        temp=load_untouch_nii([run_dir filesep file2transform]);
                        tt=temp.img(find(gg));
                        global_mean=mean(tt);
                        global_std=std(tt);
                        temp.img=(temp.img - global_mean) / global_std;
                        temp.img(find(gg==0))=0;
                        temp.fileprefix=[run_dir filesep 'z_' file2transform];
                        save_untouch_nii(temp,temp.fileprefix);
                        file2transform=['z_' file2transform];
                    end

                    if smooth
                        % create prefix
                        aa=num2str(unique(kernel_size));
                        if length(aa)>1
                            aa=num2str(kernel_size);
                        end
                        %###  Smoothing
                        matlabbatch{1}.spm.spatial.smooth.data = {[run_dir filesep file2transform]};
                        matlabbatch{1}.spm.spatial.smooth.fwhm = kernel_size;
                        matlabbatch{1}.spm.spatial.smooth.dtype = 0;
                        matlabbatch{1}.spm.spatial.smooth.im = 0;
                        matlabbatch{1}.spm.spatial.smooth.prefix = ['s' aa(~isspace(aa))];

                        spm('defaults', 'FMRI');
                        spm_jobman('serial', matlabbatch);
                        clear matlabbatch
                    end

                    movefile([run_dir filesep '*ECM*.nii'], [ECM_dir])
                end

            end
        end
    else
        for r = 1:size(runs,2)
            run=runs{s,r};
            run_dir=[src_dir filesep subject filesep 'func'];
            
            scan_indx=[];
            %check for scrubbing
            n=1;
            f2=spm_select('List',run_dir,['^' prefix_func(n:end) run(1:end-4) '.*\_FWDstat.mat']);
            while isempty(f2) && n<length(prefix_func)
                n=n+1;
                f2=spm_select('List',run_dir,['^' prefix_func(n:end) run(1:end-4) '.*\_FWDstat.mat']);
            end
            if ~isempty(f2)
                load([run_dir filesep f2],'outliers')
            end
            
            %find functional files
            f1 = spm_select('List',run_dir, ['^' prefix_func run(1:end-4) '.*\.nii']);
            
            for f=1:size(f1,1)
                tempfile=deblank(f1(f,:));
                display([subject ', ' run ', file ' tempfile]);
                functional_SJdata=[run_dir filesep tempfile];
                
                %check data segment
                n=1;
                while ~strcmp('TR',tempfile(n:n+1)) && n<length(tempfile)-1
                    n=n+1;
                end
                if n==length(tempfile)-1
                    inx=[1 length(spm_vol(functional_SJdata))];
                else
                    while ~strcmp('_',tempfile(n))
                        n=n+1;
                    end
                    
                    tmp=[];
                    n=n+1;
                    while ~strcmp('_',tempfile(n))
                        tmp=[tmp tempfile(n)];
                        n=n+1;
                    end
                    inx(1)=str2num(tmp);
                    
                    tmp=[];
                    n=n+1;
                    while ~strcmp('.',tempfile(n))
                        tmp=[tmp tempfile(n)];
                        n=n+1;
                    end
                    inx(2)=str2num(tmp);
                end
                if ~isempty(f2)
                    scan_indx=find(~outliers(inx(1):inx(2)));
                end
                
                fastECM_hacked(functional_SJdata,0,1,0,24,mask,0,scan_indx);
                
                %### Find ECM files for renaming
                files2move = cellstr(spm_select('List',run_dir, [ '^*' prefix_func '.*\ECM.nii'] ));
                for i=1:length(files2move)
                    movefile(fullfile(run_dir, files2move{i}),[run_dir filesep files2move{i}(end-10:end-4) '_' files2move{i}(1:end-12) '.nii']);
                end
                
                %###  Z-Transform and smoothing
                file2transform=spm_select('List',run_dir,['^fastECM_.*\' prefix_func run(1:end-4)]);
                
                if ztransform
                    temp=load_untouch_nii([run_dir filesep file2transform]);
                    tt=temp.img(find(gg));
                    global_mean=mean(tt);
                    global_std=std(tt);
                    temp.img=(temp.img - global_mean) / global_std;
                    temp.img(find(gg==0))=0;
                    temp.fileprefix=[run_dir filesep 'z_' file2transform];
                    save_untouch_nii(temp,temp.fileprefix);
                    file2transform=['z_' file2transform];
                end
                
                if smooth
                    % create prefix
                    aa=num2str(unique(kernel_size));
                    if length(aa)>1
                        aa=num2str(kernel_size);
                    end
                    %###  Smoothing
                    matlabbatch{1}.spm.spatial.smooth.data = {[run_dir filesep file2transform]};
                    matlabbatch{1}.spm.spatial.smooth.fwhm = kernel_size;
                    matlabbatch{1}.spm.spatial.smooth.dtype = 0;
                    matlabbatch{1}.spm.spatial.smooth.im = 0;
                    matlabbatch{1}.spm.spatial.smooth.prefix = ['s' aa(~isspace(aa))];
                    
                    spm('defaults', 'FMRI');
                    spm_jobman('serial', matlabbatch);
                    clear matlabbatch
                end
                
                movefile([run_dir filesep '*ECM*.nii'], [ECM_dir])
            end
            
        end
    end
end
