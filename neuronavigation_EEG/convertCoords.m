function out_coords = convertCoords(nifti_path, input_coords, modality)
    % This function will convert coordinate from scan coordinates to head
    % coordinates using the transform embedded in the uploaded nifti image.
    % 
    % Arguments to be given to the function:
    % - nifti_path      path to the nifti image from which the transform will
    %                   be extracted.
    % - input_coords    matrix of Nx3 sets of coordinates. Coordinates need
    %                   to be inserted in the following order: X Y Z
    % - modality        Which direction of the transformation? 
    %                   From ScanRAL to RAL --> 1
    %                   From RAL to ScanRAL --> 2
    % CAUTION! The script do not check for input coordinate space before
    % conversion. If coords are double transformed, probably they will
    % result in the wrong space (outside FOV) or misplaced. 

    header = niftiinfo(nifti_path);
    transform = header.Transform.T;

    out_coords = []; 

    for i = 1:size(input_coords,1)
        if modality == 1 %from ScanRAL to RAL --> using direct transform
            d = transform' * [input_coords(i,:) 1]';
            out_coords = [out_coords; d(1:3)'];

        elseif modality == 2 %from RAL to ScanRAL --> using inverse transform
            d = inv(transform') * [input_coords(i,:) 1]';
            out_coords = [out_coords; d(1:3)'];
        end
    end   
end