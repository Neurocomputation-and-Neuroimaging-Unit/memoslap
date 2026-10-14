#!/usr/bin/env python3
"""
Batch charm runner:
Ejecuta: charm subjectXXXX <T1.nii.gz> <T2.nii.gz>
en cada carpeta ROOT/sub-XXXX/ses-base/anat/
"""

import subprocess
import sys
from pathlib import Path

# Configuración básica
ROOT_DIR = Path("/Volumes/ChrisSSD/FUBerlin/MeMoSLAP_data")
ANAT_SESSION = "ses-base"


def main():
    if not ROOT_DIR.is_dir():
        print(f"Error: No existe el directorio {ROOT_DIR}")
        sys.exit(1)

    subjects = sorted(p for p in ROOT_DIR.glob("sub-*") if p.is_dir())

    for sub_dir in subjects:
        sub_name = sub_dir.name  
        charm_id = "subject" + sub_name.removeprefix("sub-")
        anat_dir = sub_dir / ANAT_SESSION / "anat"

        if not anat_dir.is_dir():
            print(f"[{sub_name}] Carpeta no encontrada: {anat_dir}")
            continue

        # Saltar si ya existe la reconstrucción m2m
        if any(anat_dir.glob("m2m*")):
            print(f"[{sub_name}] Ya tiene m2m procesado. Saltando.")
            continue

        # Buscar T1 y T2 (.nii.gz)
        t1_files = sorted(f for f in anat_dir.glob("*T1w*.nii.gz") if not f.name.startswith("._"))
        t2_files = sorted(f for f in anat_dir.glob("*T2w*.nii.gz") if not f.name.startswith("._"))
        #t2_files = sorted(anat_dir.glob("*T2w*.nii.gz"))

        if not t1_files:
            print(f"[{sub_name}] Falta T1w en {anat_dir}")
            continue
        if not t2_files:
            print(f"[{sub_name}] Falta T2w en {anat_dir}")
            continue

        t1 = t1_files[0].name
        t2 = t2_files[0].name

        # Comando directo: charm <ID> <T1> <T2>
        cmd = ["charm", charm_id, t1, t2, "--forceqform"]

        print(f"\n[{sub_name}] Ejecutando: {' '.join(cmd)}")
        subprocess.run(cmd, cwd=anat_dir, check=False)


if __name__ == "__main__":
    main()
