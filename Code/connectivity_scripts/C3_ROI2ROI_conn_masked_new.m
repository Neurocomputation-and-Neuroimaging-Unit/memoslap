function C3_ROI2ROI_conn_masked_new(SJ, runs, run_dir, prefix_func, atlas, ROI_values, label, out_dir)

%%%%%%%%%%%%%
% with temporal masking of outliers (scrubbing)

% load atlas
mask_atl = load_untouch_nii(atlas);
atl = mask_atl.img;
[atlas_dir, atlas_file, atlas_ext] = fileparts(atlas);

% specify ROIs
field = 'ID';
ROI = struct(field, ROI_values);

% output directory
subject = SJ;
outputdir = fullfile(out_dir, ['ROI2ROI_FC_' atlas_file label]);
mkdir(outputdir);


% LOOP over RUNS
for r = 1:length(runs)
    run = runs{r};

    % check for scrubbing file
    n = 1;
    f2 = spm_select('List', run_dir, ['^' prefix_func(n:end) run(1:end-4) '.*\_FWDstat.mat']);
    while isempty(f2) && n < length(prefix_func)
        n = n+1;
        f2 = spm_select('List', run_dir, ['^' prefix_func(n:end) run(1:end-4) '.*\_FWDstat.mat']);
    end
    if ~isempty(f2)
        load([run_dir filesep f2], 'outliers')
    end

    % list functional data files
    f1 = spm_select('List', run_dir, ['^' prefix_func run(1:end-4) '.*\.nii']);

    for f = 1:size(f1,1)
        tempfile = deblank(f1(f,:));
        display([subject ', ' run ', file ' tempfile]);

        % load preprocessed functional data
        fwdata = load_untouch_nii([run_dir filesep tempfile]);

        % check data segment
        n = 1;
        while ~strcmp('TR', tempfile(n:n+1)) && n < length(tempfile)-1
            n = n+1;
        end
        if n == length(tempfile)-1
            inx = [1 size(fwdata.img,4)];
        else
            while ~strcmp('_', tempfile(n))
                n = n+1;
            end
            tmp = [];
            n = n+1;
            while ~strcmp('_', tempfile(n))
                tmp = [tmp tempfile(n)];
                n = n+1;
            end
            inx(1) = str2num(tmp);

            tmp = [];
            n = n+1;
            while ~strcmp('.', tempfile(n))
                tmp = [tmp tempfile(n)];
                n = n+1;
            end
            inx(2) = str2num(tmp);
        end

        % apply temporal mask (scrubbing) if available
        if ~isempty(f2)
            display(['scrub data ' num2str(inx(1)) ' - ' num2str(inx(2))])
            fwdata.img(:,:,:, find(outliers(inx(1):inx(2)))) = [];
        else
            display('#####################################################')
            display('########## No FWD file found for scrubbing ##########')
            display('#####################################################')
        end

        [nDim1, nDim2, nDim3, nDimTimePoints] = size(fwdata.img);

        % convert to 2D
        AllVolume = reshape(fwdata.img, [], nDimTimePoints)';

        % extract ROI mean signals
        AvgMat = zeros(length(ROI.ID), nDimTimePoints);
        for i = 1:length(ROI.ID)
            AvgMat(i,:) = mean(AllVolume(:, find(atl == ROI(1).ID(i))), 2);
        end

        % correlate ROI mean signals
        CorrMat = zeros(length(ROI.ID), length(ROI.ID));
        for i = 1:length(ROI.ID)
            temp = repmat(AvgMat(i,:), length(ROI.ID), 1);
            CorrMat(:,i) = C3bx_calcPairCorr(AvgMat, temp);
        end

        % save connectivity matrix
        save([outputdir filesep 'R2Rconn_' tempfile(1:end-4) label '.mat'], 'CorrMat', 'ROI', 'subject', 'run', 'atlas')

        % Plot correlation matrix with labels (optional visualization)
        figure('Name', [subject ' ' run ' ' tempfile(1:end-4)]);
        imagesc(CorrMat)
        colorbar
        title(['ROI-to-ROI FC: ' subject ' ' run])
        xlabel('ROI')
        ylabel('ROI')
        
        % Add ROI labels at intervals of 10
        roi_labels = get_AAL3_labels([35, 36, 81, 82]);
        tick_positions = 10:10:length(roi_labels);  % [10, 20, 30, 40, ...]
        tick_labels = roi_labels(tick_positions);   % Only labels at those positions
        
        set(gca, 'XTick', tick_positions, 'XTickLabel', tick_labels, 'XTickLabelRotation', 90)
        set(gca, 'YTick', tick_positions, 'YTickLabel', tick_labels)
        set(gca, 'FontSize', 8)
        clim([-1 1])
        colormap('jet')
        
        % Save figure
        saveas(gcf, [outputdir filesep 'R2Rconn_plot_' tempfile(1:end-4) label '.png'])
        close(gcf)
        
        clear CorrMat i tem* AvgMat AllVolume n* fwdata
    end
    clear run
end
