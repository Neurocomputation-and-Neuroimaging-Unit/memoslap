function C3_ROI2ROI_conn_masked(SJs,runs,src_dir,prefix_func,atlas,ROI_values,sessNum,sess_wise)

%%%%%%%%%%%%%
% with temporal masking of outliers (scrubbing)

% load atlas
mask_atl=load_untouch_nii(atlas);
atl=mask_atl.img;
[atlas_dir atlas_file atlas_ext]=fileparts(atlas);

%specify ROIs
field='ID';
ROI = struct(field, ROI_values);

% LOOP over SUBJECTS and RUNS
for s = 1:length(SJs)
    subject=SJs{s};
    sub_dir=[src_dir filesep subject];
    outputdir=[sub_dir filesep 'ROI2ROI_FC_' atlas_file];
    mkdir(outputdir);
    if sessNum > 0 && exist([src_dir filesep SJs{s} filesep 'ses-1' filesep 'func'])
        for ses = 1:sessNum
            for r = 1:size(runs,2)
                run=runs{s,r};
                run_dir = [sub_dir filesep 'ses-' num2str(ses) filesep 'func']
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

                % list functional data files
                f1 = spm_select('List', run_dir, ['^' prefix_func run(1:end-4) '.*\.nii']);

                for f=1:size(f1,1)
                    tempfile=deblank(f1(f,:));
                    display([subject ', ' run ', file ' tempfile]);
                    % Loading preprocessed functional DATA
                    fwdata=load_untouch_nii([run_dir filesep tempfile]);

                    %check data segment
                    n=1;
                    while ~strcmp('TR',tempfile(n:n+1)) && n<length(tempfile)-1
                        n=n+1;
                    end
                    if n==length(tempfile)-1
                        inx=[1 size(fwdata.img,4)];
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
                        display(['scrub data ' num2str(inx(1)) ' - ' num2str(inx(2))])
                        % apply temporal mask to the data
                        fwdata.img(:,:,:,find(outliers(inx(1):inx(2))))=[];
                    else
                        display('#####################################################')
                        display('########## No FWD file found for scrubbing ##########')
                        display('#####################################################')
                    end

                    [nDim1, nDim2, nDim3, nDimTimePoints]=size(fwdata.img);

                    % Convert into 2D
                    AllVolume=reshape(fwdata.img,[],nDimTimePoints)';
                    %extract ROI-mean signals
                    AvgMat=zeros(length(ROI.ID),nDimTimePoints);
                    for i=1:length(ROI.ID)
                        AvgMat(i,:) = mean(AllVolume(:,find(atl==ROI(1).ID(i))),2);
                    end
                    %correlate ROI-mean signals
                    CorrMat=zeros(length(ROI.ID),length(ROI.ID));
                    for i=1:length(ROI.ID)
                        temp=repmat(AvgMat(i,:),length(ROI.ID),1);
                        CorrMat(:,i)=C3bx_calcPairCorr(AvgMat,temp);
                    end
                    if sess_wise == 1
                        eval(['save ' outputdir filesep 'R2Rconn_' tempfile(1:end-4) '_sess_' num2str(ses) '.mat CorrMat ROI subject run atlas'])
                    else
                        eval(['save ' outputdir filesep 'R2Rconn_' tempfile(1:end-4) '.mat CorrMat ROI subject run atlas'])
                    end
                    clear CorrMat i tem* AvgMat AllVolume n* fwdata
                end
                clear run
            end

        end
    else
        for r = 1:size(runs,2)
            run=runs{s,r};
            run_dir = [sub_dir filesep 'func']
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
        
            % list functional data files
            f1 = spm_select('List', run_dir, ['^' prefix_func run(1:end-4) '.*\.nii']);
        
            for f=1:size(f1,1)
                tempfile=deblank(f1(f,:));
                display([subject ', ' run ', file ' tempfile]);
                % Loading preprocessed functional DATA
                fwdata=load_untouch_nii([run_dir filesep tempfile]);
            
                %check data segment
                n=1;
                while ~strcmp('TR',tempfile(n:n+1)) && n<length(tempfile)-1
                    n=n+1;
                end
                if n==length(tempfile)-1
                    inx=[1 size(fwdata.img,4)];
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
                    display(['scrub data ' num2str(inx(1)) ' - ' num2str(inx(2))])
                    % apply temporal mask to the data
                    fwdata.img(:,:,:,find(outliers(inx(1):inx(2))))=[];
                else
                    display('#####################################################')
                    display('########## No FWD file found for scrubbing ##########')
                    display('#####################################################')
                end
            
                [nDim1, nDim2, nDim3, nDimTimePoints]=size(fwdata.img);
            
                % Convert into 2D
                AllVolume=reshape(fwdata.img,[],nDimTimePoints)';
                %extract ROI-mean signals
                AvgMat=zeros(length(ROI.ID),nDimTimePoints);
                for i=1:length(ROI.ID)
                    AvgMat(i,:) = mean(AllVolume(:,find(atl==ROI(1).ID(i))),2);
                end
                %correlate ROI-mean signals
                CorrMat=zeros(length(ROI.ID),length(ROI.ID));
                for i=1:length(ROI.ID)
                    temp=repmat(AvgMat(i,:),length(ROI.ID),1);
                    CorrMat(:,i)=x_calcPairCorr(AvgMat,temp);
                end
            
                eval(['save ' outputdir filesep 'R2Rconn_' tempfile(1:end-4) '.mat CorrMat ROI subject run atlas'])
            
                clear CorrMat i tem* AvgMat AllVolume n* fwdata
            end
            clear run
        end
    end
end
