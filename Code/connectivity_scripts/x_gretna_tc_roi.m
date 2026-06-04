function [tc] = gretna_tc_roi(V, Template)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function is used to read the original time courses in
% the mask
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Mask = Template;
Info_mask = spm_vol(Mask);
[Ymask xyz] = spm_read_vols(Info_mask);
Ymask = ceil(Ymask);
    ind = find(Ymask(:)>0);
    [I,J,K] = ind2sub(size(Ymask),ind);
    XYZ = [I J K]';
    XYZ(4,:) = 1;
    VY = spm_get_data(V,XYZ);
    tc= VY;
return                