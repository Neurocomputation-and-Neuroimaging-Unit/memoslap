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


# example coordinates in MNI space:
input_pts_mni = np.array([[-21.71, -72.34, 69.42, 1.], [-67.99, -38.58, 60.13, 0.], [-0.7, -92.41, 18.02, 0.], [19.08, -44.06, 100.16, 0.]])

# same coords in nexstim space:
input_pts_nexstim = np.array([[121.68401544, 185.29985823,  22.03193067,   1.], [169.41052295, 181.32058097,  54.80731677,   0.],
                [96.98342726, 132.03856203,  15.76293791,   0.], [84.25146585, 224.29471597,  44.09401128,   0. ]])

volume_path = 'path/to/T1.nii'

#pts = input_pts_nexstim
pts = input_pts_mni
output_pts_nexstim, output_pts_ras = convert_points(pts, volume_path)

print(f'Transformation of input coordinates to NEXSTIM space:\n {output_pts_nexstim}')
print(f'Transformation of input coordinates to RAS space:\n {output_pts_ras}')