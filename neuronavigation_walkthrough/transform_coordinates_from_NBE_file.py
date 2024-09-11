import nibabel as nib
import numpy as np


def coordinate_transformation(img):

    # this might be the internal Nexstim coordinate system in [mm]
    # min: RIP (0,0,0)
    # max: LSA ( (nvox_RL-1)*vox_size_RL,
    #            (nvox_IS-1)*vox_size_IS,
    #            (nvox_PA-1)*vox_size_PA )
    #
    # x: Right to Left - Sagittal
    # y: Inferior to Superior - Axial
    # z: Posterior to Anterior - Coronal

    Q = img.get_qform()

    # get transformation from image voxel space to internal voxel space of nexstim
    axcodes = nib.orientations.aff2axcodes(Q)
    ornt = nib.orientations.axcodes2ornt(axcodes, (('R', 'L'), ('I', 'S'), ('P', 'A')))
    M = nib.orientations.inv_ornt_aff(ornt, img.shape)

    # scaling matrix
    voxsize = np.linalg.norm(Q[:3, :3], axis=0)
    M2 = np.zeros((4, 4))
    M2[0, 0] = voxsize[0]
    M2[1, 1] = voxsize[1]
    M2[2, 2] = voxsize[2]
    M2[3, 3] = 1.

    # trafo from "real world" space of nexstim to image voxel space
    img2vox = np.matmul(M, np.linalg.inv(M2))
    vox2img = np.linalg.inv(img2vox)

    RAS2nexstim = np.matmul(vox2img, np.linalg.inv(Q))

    # invert the previous RAS2nexstim transformation
    nexstim2RAS = np.matmul(Q, img2vox)

    return RAS2nexstim, nexstim2RAS


def convert_points(pts, volume_path):

    pts = pts[:, :3]

    img = nib.load(volume_path)
    RAS2nexstim, nexstim2RAS = coordinate_transformation(img)

    pts_nexstim = np.zeros_like(pts)
    for i in range(len(pts_nexstim)):
        pts_nexstim[i, :3] = np.matmul(RAS2nexstim,
                                       np.hstack((pts[i, :3], 1.))
                                       )[:3]

    pts_ras = np.zeros_like(pts)
    for i in range(len(pts_ras)):
        pts_ras[i, :3] = np.matmul(nexstim2RAS,
                                       np.hstack((pts[i, :3], 1.))
                                       )[:3]

    return pts_nexstim, pts_ras

import numpy as np

def parse_digitization_file(filename):
    with open(filename, 'r') as file:
        lines = file.readlines()
    
    landmarks_start_index = None
    points_start_index = None
    
    # Identify the start indices for the 'Landmarks' and 'Digitization points' sections
    for i, line in enumerate(lines):
        if line.strip() == 'Landmarks':
            landmarks_start_index = i + 3  # Skip header lines
        elif line.strip() == 'Digitization points':
            points_start_index = i + 3  # Skip header lines
            break
    
    if landmarks_start_index is None:
        raise ValueError("Could not find 'Landmarks' section.")
    if points_start_index is None:
        raise ValueError("Could not find 'Digitization points' section.")
    
    # Extract and clean landmarks data
    landmarks = []
    for line in lines[landmarks_start_index:points_start_index - 3]:  # Until the digitization points section
        if line.strip() == '':
            continue
        parts = line.strip().split('\t')
        if len(parts) >= 4:
            try:
                x = float(parts[0])
                y = float(parts[1])
                z = float(parts[2])
                # Append landmarks data
                landmarks.append([x, y, z])
            except ValueError:
                continue
    
    # Extract and clean digitization points data
    digitization_points = []
    for line in lines[points_start_index:]:
        if line.strip() == '':
            continue
        parts = line.strip().split('\t')
        if len(parts) >= 5:
            try:
                x = float(parts[0])
                y = float(parts[1])
                z = float(parts[2])
                # Optionally, you can also extract order and projection if needed
                # order = parts[3]
                # projection = parts[4]
                digitization_points.append([x, y, z])
            except ValueError:
                continue
    
    # Convert to NumPy arrays
    landmarks_array = np.array(landmarks)
    digitization_points_array = np.array(digitization_points)
    
    return landmarks_array, digitization_points_array


def export_points_with_names(points_matrix, names, output_filename):
    with open(output_filename, 'w') as file:
        for name, coords in zip(names, points_matrix):
            line = f"{name}\t{coords[0]:.2f}\t{coords[1]:.2f}\t{coords[2]:.2f}\n"
            file.write(line)


#specify electrode names
electrode_names = [
    "MRIrpa", "MRIlpa", "MRInas", "Scalprpa", "Scalpnas", "Scalplpa",
    "Fp1", "AF7", "AF3", "F1", "F3", "F5", "F7", "FT7", "FC5", "FC3",
    "FC1", "C1", "C3", "C5", "T7", "TP7", "CP5", "CP3", "CP1", "P1",
    "P3", "P5", "P7", "P9", "PO7", "PO3", "O1", "Iz", "Oz", "POz",
    "Pz", "CPz", "Fpz", "Fp2", "AF8", "AF4", "Afz", "Fz", "F2", "F4",
    "F6", "F8", "FT8", "FC6", "FC4", "FC2", "FCz", "Cz", "C2", "C4",
    "C6", "T8", "TP8", "CP6", "CP4", "CP2", "P2", "P4", "P6", "P8",
    "P10", "PO8", "PO4", "O2"
]



# Specify inputs and outputs
input_filename = 'E:/GianMiro/00Piloting/Digitization tryout/Marlon_2000/digitization_exam_mricoords.nbe'  # Replace with your digitization file
input_volume_path = 'E:/GianMiro/00Piloting/Digitization tryout\Marlon_2000/T1_ses-baseline_acq-mprage_T1w_20230914123603_10.nii' #Replace with your T1.nii scan
output_filename = 'E:/GianMiro/00Piloting/Digitization tryout/Marlon_2000/digitization_exam_rsa.sfp'  # Replace with your digitization file

# Extract digitized electrodes from .nbe file
landmarks_array, digitization_points_array = parse_digitization_file(input_filename)
pts = np.concatenate((landmarks_array, digitization_points_array))
print("Transforming the following points:", pts.shape)
print(pts)

# Transform the digitised points from Nexstim space to RSA space (same as inputted .nii file)
output_pts_nexstim, output_pts_ras = convert_points(pts, input_volume_path)

#print(f'Transformation of input coordinates to NEXSTIM space:\n {output_pts_nexstim}')
print(f'Transformation of input coordinates to RAS space:\n {output_pts_ras}')

# security check
if len(electrode_names) != output_pts_ras.shape[0]:
    raise ValueError("The number of electrode names does not match the number of points.")

# Export to .sfp file
export_points_with_names(output_pts_ras, electrode_names, output_filename)

print(f"Data exported to {output_filename}")
