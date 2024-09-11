"""
    Run with:
        simnibs_python tDCS_Nx1_get_best.py

    within the interpreter:
        exec(open("tDCS_Nx1_get_best.py").read())
    Copyright (C) 2021 Axel Thielscher
"""

import numpy as np
import os

from simnibs import __version__, sim_struct, mesh_io
from simnibs.utils.file_finder import SubjectFiles
import Nx1_stuff


###     SETUP
###################
subjectpaths = [
#  '/mnt/projects/PRACTISE/mri_pilot/X27881/m2m_psm'
    'm2m_ernie3'
    ]

# option 1: use mask on fsaverage surface template
# !! set to '' if not used !!
fn_mask_fsspace = 'P5_lM1-LH'
#fn_mask_fsspace = 'lh.BA4a_4p_6crown_large.label'
hemi = 'lh'
#fn_mask_fsspace = ''


# or use a binary mask as nifti file (nifti has to be in subject space)
# (one mask per subject)
# !! set to [] if not used !!
#ROI_fns = [
#  '/mnt/projects/PRACTISE/freesurfer_safecopy/X27881/mri/J7024/SCANS/X27881_HK_LH.nii.gz'
#    ]
ROI_fns = []

# or use spherical mask (center as MNI coord)
# (used when fn_mask_fsspace = '' and ROI_fns = [])
#ROI_centerMNI = [0, -30, -10]
#ROI_radius = 30

ROI_shift = 1.0 # in [mm]

condition = 'closest' # 'closest' or 'optimal'
var_name = 'E_magn'

target_strength = 0.2 # in [V/m]

N = 4 # number of surround electrodes
radius_surround = 60.
phi_offset = 0.
multichannel = True # set to True if current in each surround electrode is separately controlled
current_center = 0.001  # Current flow through center channel (A)

# required current flow through the center will be determined by the script:
target_strength = 0.2 # target field strength in the ROI in [V/m]

# properties of centre electrode
EL_center = sim_struct.ELECTRODE()
EL_center.shape = 'ellipse'  # round shape
EL_center.dimensions = [20, 20]  # 30 mm diameter
EL_center.thickness = [2, 1]  # 2 mm rubber electrodes on top of 1 mm gel layer

# properties of surround electrodes
EL_surround = sim_struct.ELECTRODE()
EL_surround.shape = 'ellipse'  # round shape
EL_surround.dimensions = [20, 20]  # 30 mm diameter
EL_surround.thickness = [2, 1]  # 2 mm rubber electrodes on top of 1 mm gel layer


###  PREPARE SIMULATIONS
############################
assert condition == 'closest' or condition == 'optimal'

for i, subpath in enumerate(subjectpaths):
    subject_files = SubjectFiles(subpath=subpath)
    if len(fn_mask_fsspace) > 0:
        pathfem = fn_mask_fsspace+'__'+subject_files.subid+'__'+condition
    elif len(ROI_fns) > 0:
        pathfem = 'niftiROI__'+subject_files.subid+'__'+condition
    else:
        pathfem = str(ROI_centerMNI)+'__'+subject_files.subid+'__'+condition
    print(pathfem)

    # load head mesh
    m = mesh_io.read_msh(subject_files.fnamehead)
    if int(__version__[0])>3:
        #m = Nx1_stuff.relabel_internal_air(m, subpath)
        m = Nx1_stuff.relabel_internal_air(m)

    if len(fn_mask_fsspace) > 0:
        # convert mask to individual space (on central surface)
        _, mask_pos = Nx1_stuff.convert_mask(fn_mask_fsspace, hemi, subpath)
    elif len(ROI_fns) > 0:
        m_GMsurf, mask_pos = Nx1_stuff.ROI_from_nifti(m, ROI_fns[i], ROI_shift)
    else:
        # get GM surface in spherical ROI
        m_GMsurf, mask_pos = Nx1_stuff.sphericalROI(m, ROI_centerMNI, ROI_radius, ROI_shift, subpath)

    if condition == 'closest':
        # use skin position closest to CoG of mask
        pos_center = Nx1_stuff.get_closest_skin_pos(mask_pos, m)
    else:
        # project mask positions to pial surface of tet mesh
        # and relabel corresponding GM triangles
        m = Nx1_stuff.project_to_pial(mask_pos, m)
        # solve FEM to get optimal position on skin
        # with lowest ohmic ressitance to mask
        m, pos_center = Nx1_stuff.get_optimal_center_pos(m)
    EL_center.centre = pos_center


    ### write out mesh with ROI and position of central electrode
    ############################################################
    pathfem = os.path.abspath(os.path.expanduser(pathfem))
    if not os.path.isdir(pathfem):
        os.mkdir(pathfem)

    fn_cap = os.path.join(subject_files.eeg_cap_folder,'easycap_BC_TMS64_X21.csv')
    _, coordinates, _, name, _, _ = read_csv_positions(fn_cap)

    dist = np.linalg.norm(coordinates - pos_center,axis=1)
    idx_sort = np.argsort(dist)
    dist_sorted = dist[idx_sort]
    name_sorted = [name[i] for i in idx_sort]

    print('closest electrodes: ')
    for i in range(3):
        print('# {}  distance: {:.1f} mm'.format(name_sorted[i],dist_sorted[i]))

    mesh_io.write_geo_spheres(np.vstack((pos_center,coordinates[idx_sort])),
                              os.path.join(pathfem,'mesh_with_ROI.geo'),
                              np.hstack(([0,1,1,1],2*np.ones(len(name_sorted)-3,dtype='int'))),
                              name=('center and EEG positions'))

    txt_pos = np.vstack((pos_center,coordinates[idx_sort[:3]]))
    txt_pos[:,2] += 10
    txt_list = ['center']
    for i in range(3):
        txt_list.append('#{} - {:.1f} mm'.format(name_sorted[i],dist_sorted[i]))
    mesh_io.write_geo_text(txt_pos,txt_list,
                           os.path.join(pathfem,'mesh_with_ROI.geo'),
                           name=('EEG electrode names'), mode='ba')

    mesh_io.write_msh(m, os.path.join(pathfem,'mesh_with_ROI.msh'))


    ###  RUN SIMULATION
    #######################################
    Nx1_stuff.run_simus(subpath, pathfem,
                        current_center, N, [radius_surround], [phi_offset],
                        EL_center, EL_surround)
    if len(fn_mask_fsspace) > 0:
        m_surf, roi_median_f, focality_f, _ = Nx1_stuff.analyse_simus(subpath,
                                                pathfem,
                                                hemi, fn_mask_fsspace,
                                                [radius_surround], [phi_offset],
                                                var_name, 0.)
    else:
        m_surf, roi_median_f, focality_f, _ = Nx1_stuff.analyse_simus2(subpath,
                                                pathfem, m_GMsurf,
                                                [radius_surround], [phi_offset],
                                                var_name, 0.)
    print(roi_median_f)
    mesh_io.write_msh(m_surf,os.path.join(pathfem,'results_final.msh'))

    # get stimulation intensity
    stim_int = 1000*current_center*target_strength/roi_median_f[0][0]
    txt_list = ['stimulation intensity for {:.2f} V/m in ROI: {:.1f} mA'.format(target_strength,stim_int)]
    txt_pos = pos_center + [0., 0., 20.]
    txt_list = ['stimulation intensity for {:.2f} V/m in ROI: {:.1f} mA'.format(target_strength,stim_int)]
    mesh_io.write_geo_text([txt_pos],txt_list,
                           os.path.join(pathfem,'mesh_with_ROI.geo'),
                           name=('stimulation intensity'), mode='ba')
    print(txt_list[0])
