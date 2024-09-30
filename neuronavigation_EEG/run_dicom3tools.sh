#This script will run the function dcuncat in order to "unenhance" the 3D dicom images located in the INPUTFILE folder
#into a slice series of 2D images located in the OUTPUTDIRECTORY folder. 
#Because dcuncat do not automatically assign the ".dcm" extension to the exported files, this is done afterwards by the function. 
#Before running, make sure that the variables match your system and that dicom3tools is installed. 
#For any problem, do not hesitate to contact me: gianluigi.giannini@fu-berlin.de

INPUTFULE="/Users/YOURUSERNAME/Desktop/imgs_inpu/enhanced.dcm"
OUTPUTDIRECTORY="/Users/YOURUSERNAME/Desktop/imgs_output/"
OUTPUTFILE="ID11"
SEPARATOR="_"

cd $OUTPUTDIRECTORY 
dcuncat -if "$INPUTFULE" -of "$OUTPUTDIRECTORY$OUTPUTFILE$SEPARATOR" -unenhance

for file in *; do
	mv "$file" "$file.dcm"
done
