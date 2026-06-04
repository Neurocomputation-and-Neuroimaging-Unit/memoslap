function [tal_coords, vox_coords] = spmutils_transform_coords(SPM)
% Get index voxel coordinates at specified Talairach location and v.v.

% Input: SPM structure with regular and custom fields
% SPM.direction     'TALtoVOX' or 'VOXtoTAL'
% SPM.coords        coordinates

direction = SPM.direction;
coords = SPM.coords;

% get index voxel coordinates and conversion matrix M provided by SPM
xyz_vox = SPM.xVol.XYZ;
conv_M = SPM.xVol.M;
% transform all Talairach coorniates to voxel indices or v.v
xyz_tal = conv_M * [xyz_vox; ones(1,size(xyz_vox,2))];

if strcmp(direction, 'TALtoVOX')
    % find the corresponding voxel coordinate index for Talairach coords of interest
    [tal_coords,i_xyz_tal,temp] = spm_XYZreg('NearestXYZ',coords,xyz_tal);
    % look up the corresponding voxel coordinates
    vox_coords = xyz_vox(:,i_xyz_tal);
    tal_coords(4) = [];
elseif strcmp(direction, 'VOXtoTAL')
    [temp,i_xyz_vox,temp] = spm_XYZreg('NearestXYZ',coords,xyz_vox);
    tal_coords = xyz_tal(:,i_xyz_vox);
    tal_coords(4) = [];
    vox_coords = coords;
end    
    
end