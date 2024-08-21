import sys

"""" Pipeline for optimizing the target placement with simnibs
     and creating .pdf reports according to memoslap project
     -- Miro Grundei 25/07/2023
"""

# Update paths
path_to_utils = 'C:/Users/nnu04/memoslap'
sys.path.append(path_to_utils)
import simnibs_memoslap_utils as smu

project_path = 'C:/Users/nnu04/Documents/MeMoSLAP/P2/Target_Placement/'
radius_list = 60.0 #[35.0, 50.0, 60.0, 70.0]  # test a range of radii; if only 1 the PDF is immediately created
exp_condition = 'target'  # 'target' or 'control'

# general settings
project_nr = 2
subject_path = project_path + 'test_subjects/till/m2m_till/'  # m2m-folder path
results_basepath = project_path + 'test_subjects/till/'  # results will be placed in subfolder of results_basepath


# load project settings
project = smu.projects[project_nr][exp_condition]

# update settings (optional)
project.condition = 'optimal'  # 'closest' / or select other method to get center electrode position
project.current = 0.002  # change current of center electrode
project.radius = radius_list

# run
[res_list,
 res_list_raw,
 pos_center,
 pos_surround,
 res_summary] = smu.run(subject_path, project, results_basepath,
                        add_cerebellum=True, map_to_fsavg=True, do_nnav=False)
