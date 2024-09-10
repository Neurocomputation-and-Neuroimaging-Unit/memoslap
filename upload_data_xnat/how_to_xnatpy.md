# How To use XNAT python package
https://xnat.readthedocs.io/en/latest/

(not to be confused with pyxnat)

### Preparatory steps (by Robert Malinowski):
You need to modify __init__.py from XNAT Package to to use your client-cert for the connectiont to the xnat server!

1) modify __init__.py
   - stored: ~\AppData\Roaming\Python\Python39\site-packages\xnat
   - modify:
     `def connect(server=None, user=None, password=None, verify=True, crt=None, netrc_file=None, debug=False,
            extension_types=True, loglevel=None, logger=None, detect_redirect=True,
            no_parse_model=False, default_timeout=300, auth_provider=None, jsession=None,
            cli=False)`
     
   Here I included a new Parameter "crt=None"  
   - add in Line 533 (addition by Miro: for me it was later around line 560):
          ` if crt is not None:
               requests_session.cert = crt `

    This is for https request can handle the client cert session

3) Convert your *.p12 file + Passwort to a *.pem file   -> see provided function `pfx2pem.py` (Miro edit)
4) put the pem file a cert param into the xnat.connect() function
