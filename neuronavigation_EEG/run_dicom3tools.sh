INPUTFULE="/Volumes/DATI/ID11/CCNB_10673_vDMT.MR.CCNB_Projekte.12.1.2023.05.09.18.24.26.137.79166621.dcm"
OUTPUTDIRECTORY="/Volumes/DATI/ID11/unenhanced/"
OUTPUTFILE="ID11"
SEPARATOR="_"

cd $OUTPUTDIRECTORY 
dcuncat -if "$INPUTFULE" -of "$OUTPUTDIRECTORY$OUTPUTFILE$SEPARATOR" -unenhance

for file in *; do
	mv "$file" "$file.dcm"
done