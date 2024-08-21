# Target placement - MeMoSLAP pipeline

Miro Grundei - 25/07/2023

### Overview: Steps for each single subject
1) Use charm to create a head model 
    * requires T1 nifti, additional T2 image recommended
    * see https://simnibs.github.io/simnibs/build/html/tutorial/head_meshing.html
    * after head model creation one should check coregistration (m2m_subID folder: charm_report.html)
    * for coregistration issues check https://simnibs.github.io/simnibs/build/html/tutorial/advanced/fix_affine_registration.html#fix-affine-registration-tutorial
``` 
charm --forcerun --forceqform 'till' 'C:\Users\nnu04\Documents\MeMoSLAP\P2\Target_Placement\test_subjects\till\t1\t1.nii' 'C:\Users\nnu04\Documents\MeMoSLAP\P2\Target
_Placement\test_subjects\till\t2\t2.nii'
```
``` 
charm --forcerun --forceqform 'till' 'C:\Users\nnu04\Documents\MeMoSLAP\P2\Target_Placement\test_subjects\till\t1\t1.nii' 'C:\Users\nnu04\Documents\MeMoSLAP\P2\Target
_Placement\test_subjects\till\t2\t2.nii' --usesettings m2m_settings_files/settings_scaling.ini
```
2) Run simnibs for memoslap \
   Change paths and details about the project in "target_optimization.py"
      * essentially runs itself a simnibs wrapper function around the following steps
        * create a coarse cerebellum central gm surface and add it to the m2m-folder content (only for charm results)
        * map mask to middle GM surfaces
        * get positions of center electrode
        * get the surround electrode positions and run FEM
        * map e-field onto the middle GM surfaces
        * map e-field of lh and rh to fsaverage (optional)
        * export electrode positions for use with neuronavigation (only simnibs4)
``` 
python target_optimization.py
```
3) Create Report PDF if not already created in previous step (in case multiple radii were iterated) 
   *  requires m2m folder, project number and information on which radius should be used for the report
``` 
python prepare_reports.py --report 'placement' --subj_path 'C:\Users\nnu04\Documents\MeMoSLAP\P2\Target_Placement\test_subjects\till\m2m_till\' --proj 2 --subj 'till'
 --radius 60
```   


