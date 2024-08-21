# XNAT Upload based on scripts by Robert Malinowski
# Preparatory steps:
#-> You need to modify __init__.py from XNAT Package to to use your client-cert for the connectiont to the xnat server!

#1) modify __init__.py
#   -stored: ~\AppData\Roaming\Python\Python39\site-packages\xnat
#   -modify: def connect(server=None, user=None, password=None, verify=True, crt=None, netrc_file=None, debug=False,
#            extension_types=True, loglevel=None, logger=None, detect_redirect=True,
#            no_parse_model=False, default_timeout=300, auth_provider=None, jsession=None,
#            cli=False):     
#                       Here I included a new Parameter "crt=None"   
#   -add in Line 533 (addition by Miro: for me it was later around 560):
#           if crt is not None:
#               requests_session.cert = crt
#                       This is for https request can handle the client cert session
#2) Convert your *.p12 file + Passwort to a *.pem file   -> Internet research!  
#3) put the pem file a cert param into the xnat.connect() function

import xnat
import os
import time
import shutil
import requests


def upload_to_prearchive(prj, subID, subIDses, data):

    print(f'Upload file: {data}')

    rtn = session.prearchive.find(prj, subID, subIDses)
    print(f'Feedback from pre-archive: {rtn}')

    if rtn:
        print('Session already uploaded!')
    else:
        print(f'Starting upload as {subIDses}')
        try:
            response = session.services.import_(data, project=prj, subject=subID, experiment=subIDses)
        except Exception as e:
            error_message = str(e)
            if "504 Gateway Time-out" in error_message:
                print('Gateway time-out (expected)')
                pass
            else:
                print(f'An unexpected error occurred: {e}')


# Start XNAT session
# ------------------------------------
usr = 'grundeim'    # XNAT user
pw = ''             # XNAT password
pemcrt = 'C:/Users/nnu04/Documents/MeMoSLAP/XNAT/GRUNDEI.pem'   # Certificate in .pem format

session = xnat.connect('https://neuro.med.uni-greifswald.de/xnat', user=usr, password=pw, cert=pemcrt)

# Upload data
# ------------------------------------
xnat_prj = '002'  # project ID, 3digits e.g. 002, 008 ...
data_base_path = '//campus.fu-berlin.de/daten/ERZWISS/CCNB-MRT/DICOM/MeMoSLAP_P2'  # path to data storage at CCNB

subjects = [15, 16, 17, 18, 19, 20, 23, 24]     # subject number (in the 2000 range for Sham Arm)
sessions = [0, 1, 2, 3, 4]      # session ID for XNAT ['base', 1, 2, 3, 4]
data_sessions = ['base', 'rest1', 'rest2', 'task1', 'task2']    # session ID as stored at CCNB

for sub in subjects:
    xnat_subID = f'20{sub:02d}'             # only subject number e.g. 2000

    for ses in sessions:
        # MRI Session (Note: sub-2001_ses-base = 2001_base, sub-2001_ses-task2 = 2001_4)
        if ses == 0:
            xnat_sesID = f'{xnat_subID}_base'
        else:
            xnat_sesID = f'{xnat_subID}_{ses}'
        # subject ID as stored at CCNB, e.g. sub-2011, sub-2000, ...
        data_subID = f'sub-{xnat_subID}'
        # session ID as stored at CCNB, e.g. rest1, rest2, task1, task2
        data_sesID = data_sessions[ses]
        # Full data path to DICOM Session
        data = f'{data_base_path}/{data_subID}/{data_subID}_ses-{data_sesID}.zip'

        # make zipfile if not zipped (which it is on the CCNB Dicom server
        # shutil.make_archive(subIDses, 'zip', data)

        # upload to prearchive
        upload_to_prearchive(xnat_prj, xnat_subID, xnat_sesID, data)


print('Script ended.')
print(f'Uploaded subjects {subjects} with Sessions {sessions}.')
print("Sleep.....")
time.sleep(100)
print("Disconnect.....")
session.disconnect()
