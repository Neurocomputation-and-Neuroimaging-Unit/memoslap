# -*- coding: utf-8 -*-
"""
Created on Mon Sep  4 16:11:37 2023

@author: axthi
"""
import numpy as np
from copy import deepcopy
from scipy.spatial.distance import cdist
from simnibs import mesh_io, file_finder

from .preparation import create_cereb_surface, get_central_gm_with_mask, get_center_pos
from .write_nnav import _make_matsimnibs
from .project_settings import projects

# NOTE: Replace this by import of SimNIBS ElementTags once available
from .mesh_element_properties import ElementTags


def _get_surface_cylinder(m, label, matrix, radius=20):
    ''' extracts surface cylinder underneath electrode '''
    # extract surface
    m_surf = m.crop_mesh(tags = label)
    
    # tranform into electrode coordinate space
    node_pos = m_surf.nodes.node_coord
    node_pos = np.matmul(np.linalg.inv(matrix),
                         np.hstack((node_pos, np.ones((node_pos.shape[0],1)))).T
                         )
    m_surf.nodes.node_coord = node_pos[:3,:].T
        
    # crop cylinder
    idx = np.argwhere(np.linalg.norm(m_surf.nodes.node_coord[:,:2],
                                     axis=1)<=radius
                      )+1
    m_surf = m_surf.crop_mesh(nodes=idx)
    
    # keep surface component closest to electrode
    components = m_surf.elm.connected_components() # returns 1-based elm indices 
    baricenters = m_surf.elements_baricenters().value
    meddist = [np.median(baricenters[c-1][:,2]) for c in components]
    m_surf = m_surf.crop_mesh(elements=components[np.argmin(meddist)])
    
    # transform back to original space
    node_pos = m_surf.nodes.node_coord
    node_pos = np.matmul(matrix,
                         np.hstack((node_pos, np.ones((node_pos.shape[0],1)))).T
                         )
    m_surf.nodes.node_coord = node_pos[:3,:].T
    return m_surf


def _return_min_distance_mean_median(coords1, coords2):
    dist_mat = cdist(coords1, coords2)
    min_per_column = dist_mat.min(axis=0)
    min_per_row = dist_mat.min(axis=1)
    all_mins = np.hstack((min_per_column, min_per_row))

    Q1 = np.percentile(all_mins, 25)
    med = np.median(all_mins)
    Q3 = np.percentile(all_mins, 75)
    
    return Q1, med, Q3





def get_matsimnibs(subject_path, pos_centers):
    """
    return the matsimnibs matrices for the given center positions

    Parameters
    ----------
    subject_path : string
        path to m2m-folder.
    pos_centers : np.array
        array of shape (N_positions, 3).

    Returns
    -------
    matsimnibs : np.array
        array of shape (N_positions, 4, 4).

    """
    # load mesh and get skin nodes and normals
    # (required for creating the normal direction under the electrode)
    ff = file_finder.SubjectFiles(subpath = subject_path)
    m=mesh_io.read_msh(ff.fnamehead)
    
    m = m.crop_mesh(elm_type = 2)
    m = m.crop_mesh(tags = ElementTags.SCALP_TH_SURFACE)
    skin_nodes = m.nodes.node_coord
    skin_normals = m.nodes_normals().value
    
    matsimnibs = np.zeros((pos_centers.shape[0],4,4))
    for i, pos in enumerate(pos_centers):
        matsimnibs[i] = _make_matsimnibs(pos, skin_nodes, skin_normals)
    return matsimnibs


def get_scalp_skull_thickness(subject_path, matsimnibs, radius=20.):
    """
    return scalp and skull thicknesses for the positions defined by the 
    matsimnibs

    Parameters
    ----------
    subject_path : string
        path to m2m-folder.
    matsimnibs : np.array
        array of shape (N_positions, 4, 4).
    radius: float, optional
        radius of the cylinders used to cut out the surfaces. The default is 20.
        
    Returns
    -------
    Q1_scalp, med_scalp, Q3_scalp, Q1_bone, med_bone, Q3_bone : np.arrays of shape (N_positions,)
        first quartiles, median and third quartiles of the scalp and skull 
        thicknesses in the cylinders defined by the matsimnibs and the radius

    """
    DEBUG = False
    
    # load mesh, recreate surfaces to ensure surfaces of interest are closed
    ff = file_finder.SubjectFiles(subpath = subject_path)
    m = mesh_io.read_msh(ff.fnamehead)
    m = m.crop_mesh(elm_type=4)
    
    idx = (m.elm.tag1 == ElementTags.WM) + (m.elm.tag1 == ElementTags.GM) + (m.elm.tag1 == ElementTags.BLOOD)
    m.elm.tag1[idx] = ElementTags.CSF # everything inside skull becomes CSF
    
    idx = (m.elm.tag1 == ElementTags.COMPACT_BONE) + (m.elm.tag1 == ElementTags.SPONGY_BONE)
    m.elm.tag1[idx] = ElementTags.BONE # combine bone types
    
    idx = (m.elm.tag1 == ElementTags.EYE_BALLS) + (m.elm.tag1 == ElementTags.MUSCLE)
    m.elm.tag1[idx] = ElementTags.SCALP # everything outside skull becomes scalp
    
    m.elm.tag2[:] = m.elm.tag1
    m.reconstruct_unique_surface(add_outer_as = ElementTags.SCALP)
    
    if DEBUG:
        m_dbg = deepcopy(m)
    
    # loop over matsimnibs to get bone and scalp thicknesses
    Q1_scalp = np.zeros(matsimnibs.shape[0])
    med_scalp = np.zeros(matsimnibs.shape[0])
    Q3_scalp = np.zeros(matsimnibs.shape[0])
    
    Q1_bone = np.zeros(matsimnibs.shape[0])
    med_bone = np.zeros(matsimnibs.shape[0])
    Q3_bone = np.zeros(matsimnibs.shape[0])
    
    for i, mat in enumerate(matsimnibs):
        # cut out surface cylinders underneath the electrode
        m_surf_SCALP = _get_surface_cylinder(m, ElementTags.SCALP_TH_SURFACE, mat, radius=radius)
        m_surf_BONE  = _get_surface_cylinder(m, ElementTags.BONE_TH_SURFACE, mat, radius=radius)
        m_surf_CSF   = _get_surface_cylinder(m, ElementTags.CSF_TH_SURFACE, mat, radius=radius)
        
        # measure distances between surface cylinders
        r = _return_min_distance_mean_median(m_surf_BONE.nodes.node_coord, 
                                              m_surf_SCALP.nodes.node_coord)
        Q1_scalp[i] = r[0]
        med_scalp[i] = r[1]
        Q3_scalp[i] = r[2]
        
        r = _return_min_distance_mean_median(m_surf_BONE.nodes.node_coord, 
                                              m_surf_CSF.nodes.node_coord)      
        Q1_bone[i] = r[0]
        med_bone[i] = r[1]
        Q3_bone[i] = r[2]
        
        if DEBUG:
            for k, m_hlp in enumerate([m_surf_SCALP,m_surf_BONE,m_surf_CSF]):
                m_hlp.elm.tag1[:] = 101+i*10+k
                m_hlp.elm.tag2 = m_hlp.elm.tag1
                m_dbg = m_dbg.join_mesh(m_hlp)
                
    if DEBUG:
        mesh_io.write_msh(m_dbg,'debug.msh')
    
    return Q1_scalp, med_scalp, Q3_scalp, Q1_bone, med_bone, Q3_bone
    
    
def get_pos_centers_for_subject(subject_path, add_cerebellum=True):
    """
    returns the center positions for all projects (target and control)
    for a subject

    Parameters
    ----------
    subject_path : string
        path to m2m-folder.
    add_cerebellum : boolean, optional
        whether to add cerebellum to the surface (needed for P6). 
        The default is True.

    Returns
    -------
    pos_centers : dict of np.array
        The dict contains two arrays of length eight with the center positions
        of the projects, one for target and one for control.

    """
    pos_centers = dict()
    
    if add_cerebellum:
        create_cereb_surface(subject_path, add_cerebellum)
    
    for exp_condition in ['target', 'control']:
        pos_hlp = np.zeros((len(projects),3))
        
        for project_nr in range(1,len(projects)+1):
            project = projects[project_nr][exp_condition]
            
            # get position of center electrode
            m_surf = get_central_gm_with_mask(subject_path,
                                              project.hemi,
                                              project.fname_roi,
                                              project.mask_type,
                                              add_cerebellum
                                                  )
            pos_hlp[project_nr-1] = get_center_pos(m_surf,
                                                   subject_path,
                                                   project.condition,
                                                   project.el_name
                                                   )   
        pos_centers.update({exp_condition: pos_hlp})
        
    return pos_centers


def get_scalp_skull_thickness_for_subject(subject_path, add_cerebellum=True, radius=20.):
    """
    return scalp and skull thicknesses for the target and control positions

    Parameters
    ----------
    subject_path : string
        path to m2m-folder.
    add_cerebellum : boolean, optional
        whether to add cerebellum to the surface (needed for P6). 
        The default is True.
    radius : float, optional
        radius of the cylinders used to cut out the surfaces. 

    Returns
    -------
    Q1_scalp, med_scalp, Q3_scalp, Q1_bone, med_bone, Q3_bone : dict
        dict containing first quartiles, median and third quartiles of the scalp
        and skull thicknesses in the cylinders defined by the radius, 
        separately for the target and control positions

    """
    # get center positions for all projects
    print('getting center positions')
    pos_centers = get_pos_centers_for_subject(subject_path, add_cerebellum)
    pos_centers_stacked = np.vstack((pos_centers['target'], 
                                     pos_centers['control']))
    
    # get matsimnibs for the center positions
    print('getting matsimnibs for the center positions')
    matsimnibs = get_matsimnibs(subject_path, pos_centers_stacked)
    
    # extract surfaces in cylinders below center positions and calculate thickness
    print('getting scalp and skull thickness underneath center positions')
    [Q1_sc, med_sc, Q3_sc,
     Q1_bo, med_bo, Q3_bo] = get_scalp_skull_thickness(subject_path, 
                                                       matsimnibs, 
                                                       radius=radius
                                                       )                                                
    len_target  = pos_centers['target'].shape[0]
    Q1_scalp  = {'target' : Q1_sc[:len_target],  'control' : Q1_sc[len_target:]}
    med_scalp = {'target' : med_sc[:len_target], 'control' : med_sc[len_target:]}
    Q3_scalp  = {'target' : Q3_sc[:len_target],  'control' : Q3_sc[len_target:]}
    
    Q1_bone   = {'target' : Q1_bo[:len_target],  'control' : Q1_bo[len_target:]}
    med_bone  = {'target' : med_bo[:len_target], 'control' : med_bo[len_target:]}
    Q3_bone   = {'target' : Q3_bo[:len_target],  'control' : Q3_bo[len_target:]}
    
    return Q1_scalp, med_scalp, Q3_scalp, Q1_bone, med_bone, Q3_bone


def get_areas_for_subject(subject_path, add_cerebellum=True):
    """
    calculates the roi areas for all projects (target and control)
    for a subject

    Parameters
    ----------
    subject_path : string
        path to m2m-folder.
    add_cerebellum : boolean, optional
        whether to add cerebellum to the surface (needed for P6). 
        The default is True.

    Returns
    -------
    roi_areas : dict of np.array
        The dict contains two arrays of length eight with the roi
        areas of the projects, one for target and one for control.

    """
    roi_areas = dict()
    
    if add_cerebellum:
        create_cereb_surface(subject_path, add_cerebellum)
    
    for exp_condition in ['target', 'control']:
        areas_hlp = np.zeros(len(projects))
        
        for project_nr in range(1,len(projects)+1):
            project = projects[project_nr][exp_condition]
            
            # get surface with mask as nodedata field
            m_surf = get_central_gm_with_mask(subject_path,
                                              project.hemi,
                                              project.fname_roi,
                                              project.mask_type,
                                              add_cerebellum
                                              )
            mask_idx = m_surf.field['mask'].value
            
            # get node areas
            areas = m_surf.nodes_areas().value
            assert len(areas) == len(mask_idx)
            
            # calculate area of mask
            areas_hlp[project_nr-1] = np.sum(areas[mask_idx])
            
            print('P'+str(project_nr)+' '
                  +exp_condition+': '+
                  "{:.1f}".format(areas_hlp[project_nr-1]))
        roi_areas.update({exp_condition: areas_hlp})
        
    return roi_areas
