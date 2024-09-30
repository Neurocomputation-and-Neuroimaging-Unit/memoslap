# Digitization of EEG cap using Nexstim neuronavigation system
This is a walkthrough of the necessary steps, data and scripts one needs to digitize an EEG cap with the Nexstim neuronagivation system.

## Preparing the T1 image 
In the current version of the eXimia software (INSERT SOFTWARE VERSION HERE), only the old 2D dicom are accepted. The old 2D dicom is part of a MR SOP class that was the common standard until a few years ago. The SOP class determines how the information in the file are stored and read: pixel size, patient position, institute name and so on. 
In recent years, scanners only allow users to export DICOM images in "enhanced" formats. This is a different SOP class: not only data is stored in a unique 3D file, but also the information contained in the file are stored differently. For this reason, eXimia will give an error when trying to import scans that are not in the old 2D dicom format. 

The solution to this problem comes from a toolbox called dicom3tools (https://www.dclunie.com/dicom3tools.html) by David Clunie. The function dcuncat allow also to "unenhance" a dicom image. It not only changes the header information to match the MR SOP class of an old 2D dicom, but also gives back one .dcm file for each slice (as the image was exported from the beginning in the old dicom format). 
NOTE: some information in the enhanced format is actually missing. dcuncat simply replaces this info with standard values in order to match the right SOP class. The missing information is not a problem when importing in eXimia. 

###Guide for MacOS users
After installing dicom3tools, simply run through your bash the following [command](https://github.com/Neurocomputation-and-Neuroimaging-Unit/memoslap/blob/main/neuronavigation_EEG/run_dicom3tools.sh).
To run the `run_dicom3tools` bash function (located on your desktop) on your MacOS, open the terminal and type: 
```
sh /Users/USERNAME/Dekstop/run_dicom3tools
```

###Guide for Windows users
In progress ...

###Quality check
This is an image exported from the scanner as an old DICOM:
![Old 2D dicom](https://github.com/Neurocomputation-and-Neuroimaging-Unit/memoslap/blob/main/neuronavigation_EEG/imgs/2Ddicom_sub-2012_OG.JPG)
This is the same image exported from the scanner as an enhanced DICOM and then unenhanced following the instructions reported before: 
![Unenhanced 3D dicom](https://github.com/Neurocomputation-and-Neuroimaging-Unit/memoslap/blob/main/neuronavigation_EEG/imgs/2Ddicom_sub-2012_unenhanced.JPG)
As you'll be able to tell, there's no difference between the two!


## Acquiring the digitized cap (electrode positions)
In the eXimia software, make sure that the T1w image of your participant is correctly loaded (only old dicom are accepted on software version 3). 
Once the registration is done, click on the "Digitization" panel and "New exam". 
At this point, you'll be able to take the position of each electrode on the scalp. 

Please digitize each electrode in the following order: "Fp1", "AF7", "AF3", "F1", "F3", "F5", "F7", "FT7", "FC5", "FC3", "FC1", "C1", "C3", "C5", "T7", "TP7", "CP5", "CP3", "CP1", "P1", "P3", "P5", "P7", "P9", "PO7", "PO3", "O1", "Iz", "Oz", "POz", "Pz", "CPz", "Fpz", "Fp2", "AF8", "AF4", "Afz", "Fz", "F2", "F4", "F6", "F8", "FT8", "FC6", "FC4", "FC2", "FCz", "Cz", "C2", "C4", "C6", "T8", "TP8", "CP6", "CP4", "CP2", "P2", "P4", "P6", "P8", "P10", "PO8", "PO4", "O2". The script is not optimized yet for auto-labelling electrodes based on their position but only based on their order. 
IMPORTANT NOTE: make sure to insert the point of the digitizing pen inside the electrode and not only on top. This will ensure that the digitized points are adhering to the scalp.

For more information on how eXimia (Nexstim) works, please consult the [manual](https://github.com/Neurocomputation-and-Neuroimaging-Unit/memoslap/blob/main/neuronavigation/NX81491%20NBS%20System%20User%20Manual%204.3_USA.pdf), conveniently updated into our github.

Once all 64 electrodes have been digitized, in the eXimia session tree (left panel) right-click on the digitization exam and select "export" (do not select export EMSE as the scripts have not been optimized to deal with that format). 
IMPORTANT NOTE: please also make sure that in the settings panel, the System coordinates is set to "MRI-coordinate system" (standard configuration) before exporting. 

The exported file will look like this: 

![Example of the digitzation file](https://github.com/Neurocomputation-and-Neuroimaging-Unit/memoslap/blob/main/neuronavigation_EEG/imgs/Digization_example.png)


## Importing the data
As a first step, convert your old dicom files into a nifti image (in this example, I used dcm2niix as contained in MRIcron v.1.0.20190902). 
Then run the [transform_coordinates_from_NBE_file.py](https://github.com/Neurocomputation-and-Neuroimaging-Unit/memoslap/blob/main/neuronavigation_EEG/transform_coordinates_from_NBE_file.py) script by first making sure that the following fields are correct: 
- input_filename --> path to the digitized electrode file as exported from nexstim
- input_volume_path --> path to the nifti image
- output_filename --> path to the to-be-converted file containing the digitized electrode positions

The script will convert the electrode positions that are saved into the Nexstim space into the space of the nifti image. This will make sure that the electrode position and the T1 are in the same space. 
The converted digitized electrode positions are stored into an .sfp file that will look like this:

![Example of the converted digitzation file](https://github.com/Neurocomputation-and-Neuroimaging-Unit/memoslap/blob/main/neuronavigation_EEG/imgs/Digitization_example_converted.png)


## Checking that electrodes have been digitized correctly
Now simply make sure that the converted digitized electrodes and the T1 nifti image are matching and especially that the electrodes are adjecent to the participant's scalp. To do this, simply create a nifti file containing spheres centered at the electrode positions using the [plot_digitization_exam.m](https://github.com/Neurocomputation-and-Neuroimaging-Unit/memoslap/blob/main/neuronavigation_EEG/plot_digitization_exam.m) script. Make sure to change the following fields: 
- mri_path --> path to the converted T1w nifti image
- elec_path --> path to the converted electrodes

To display the electrode positions on top of the T1 image, download [MRIcroGL](https://www.nitrc.org/projects/mricrogl). First open the T1 and then add the electrode positions nifti image as an overlay. 
![Example of how an image is displayed on MRIcroGL](https://github.com/Neurocomputation-and-Neuroimaging-Unit/memoslap/blob/main/neuronavigation_EEG/imgs/screenshot_MRIcroGL.png)
