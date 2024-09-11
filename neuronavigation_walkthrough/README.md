# Digitization of EEG cap using Nexstim neuronavigation system
This is a walkthrough of the necessary steps, data and scripts one needs to digitize an EEG cap with the Nexstim neuronagivation system.

## Acquiring the digitized cap (electrode positions)
In the eXimia software, make sure that the T1w image of your participant is correctly loaded (only old dicom are accepted on software version 3). 
Once the registration is done, click on the "Digitization" panel and "New exam". 
At this point, you'll be able to take the position of each electrode on the scalp. 

Please digitize each electrode in the following order: "Fp1", "AF7", "AF3", "F1", "F3", "F5", "F7", "FT7", "FC5", "FC3", "FC1", "C1", "C3", "C5", "T7", "TP7", "CP5", "CP3", "CP1", "P1", "P3", "P5", "P7", "P9", "PO7", "PO3", "O1", "Iz", "Oz", "POz", "Pz", "CPz", "Fpz", "Fp2", "AF8", "AF4", "Afz", "Fz", "F2", "F4", "F6", "F8", "FT8", "FC6", "FC4", "FC2", "FCz", "Cz", "C2", "C4", "C6", "T8", "TP8", "CP6", "CP4", "CP2", "P2", "P4", "P6", "P8", "P10", "PO8", "PO4", "O2". The script is not optimized yet for auto-labelling electrodes based on their position but only based on their order. 
IMPORTANT NOTE: make sure to insert the point of the digitizing pen inside the electrode and not only on top. This will ensure that the digitized points are adhering to the scalp.

Once all 64 electrodes have been digitized, in the eXimia session tree (left panel) right-click on the digitization exam and select "export" (do not select export EMSE as the scripts have not been optimized to deal with that format). 
IMPORTANT NOTE: please also make sure that in the settings panel, the System coordinates is set to "MRI-coordinate system" (standard configuration) before exporting. 

The exported file will look like this: 
![Example of the digitzation file](https://github.com/Neurocomputation-and-Neuroimaging-Unit/memoslap/blob/main/neuronavigation_walkthrough/Digization_example.png)


## Importing the data


## Checking that electrodes have been digitized correctly
