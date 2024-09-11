%% SPECIFY SENSORS AND MRI PATH
mri_path = 'E:\GianMiro\00Piloting\Digitization tryout\Marlon_2000\T1_ses-baseline_acq-mprage_T1w_20230914123603_10.nii';
elec_path = 'E:\GianMiro\00Piloting\Digitization tryout\Marlon_2000\digitization_exam_rsa.sfp';


%% CREATE A NIFTI IMAGE WITH SPHERES AROUND THE ELECTRODE LOCATIONS
%load mri header for reading size and transform
header = niftiinfo(mri_path);

% Create a blank 3D image (all zeros)
image_data = zeros(header.ImageSize);

% Read in sensors and specify sphere centers
elec_ras = ft_read_sens(elec_path); 
elec_scanras = convertCoords(mri_path, elec_ras.chanpos(7:end,:), 2);
sphere_centers = elec_scanras;

sphere_radius = 5;  % Radius of the spheres (in voxels)

% Create spheres at the specified locations
for i = 1:size(sphere_centers, 1)
    center = sphere_centers(i, :);
    
    % Loop through each voxel and set value if it's inside the sphere
    for x = 1:header.ImageSize(1)
        for y = 1:header.ImageSize(2)
            for z = 1:header.ImageSize(3)
                distance = sqrt((x - center(1))^2 + (y - center(2))^2 + (z - center(3))^2);
                if distance <= sphere_radius
                    image_data(x, y, z) = 1; % Set voxel inside the sphere
                end
            end
        end
    end
end

elec_map_header = header;

% Update the header fields
elec_map_header.Filename = 'spheres_image.nii';  % Name of the new NIfTI file
elec_map_header.Datatype = 'double';             % Data type
elec_map_header.PixelDimensions = [1, 1, 1];     % Define voxel sizes (default: 1x1x1 mm)

% Write the NIfTI file
niftiwrite(image_data, elec_map_header.Filename, elec_map_header);


%% PLOT HEAD MODEL AND ELECTRODES ON TOP


elec = ft_read_sens(elec_path);
elec.coordsys = 'ras'; 
mri = ft_read_mri(mri_path);
mri.coordsys = 'ras'; 


cfg = [];
[segmentedmri] = ft_volumesegment(cfg, mri);

cfg = [];
cfg.method = 'singleshell';
headmodel = ft_prepare_headmodel(cfg, segmentedmri);

figure
ft_plot_sens(elec);
hold on
ft_plot_headmodel(headmodel);
















%% PREPARE NIFTI FILE WITH SPHERES
nifti_path = 'E:\GianMiro\00Piloting\Digitization tryout\Marlon_2000\T1_ses-baseline_acq-mprage_T1w_20230914123603_10.nii';
input_coords = [78.49	-3.16	-17.34;	-74.38	3.42	-15.40;	4.94	108.53	-15.29];
modality = 2; 





