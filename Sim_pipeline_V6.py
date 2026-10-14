"""
SimNIBS ROI + harmonization pipeline V6.
Christian Curiel 

V6:
- This script runs, or reuses, one SimNIBS tDCS simulation per subject,
anatomical session, and condition, then writes one consolidated result table (.csv)

"""

import argparse
import csv
from pathlib import Path

import numpy as np
import simnibs
from simnibs import run_simnibs, sim_struct


BASE_DIR = Path("/Volumes/ChrisSSD/FUBerlin")
DATA_DIR = BASE_DIR / "MeMoSLAP_data"
COORDINATE_CSV = BASE_DIR / "Berlin_subjects_NEW.csv"

# Baseline anatomical session
BASELINE_ANAT_SESSION = "ses-base"

# Exact model folder conventions shown by the dataset:
MODEL_FOLDER_TEMPLATES = {
    "T1-2": "m2m_subject{subject_number}",
}
MODELS = ("T1-2",)

SOURCE_SESSIONS = ("ses-1", "ses-2", "ses-3", "ses-4")

CONDITION = "auto"
CONDITION_ORDER = ["target", "control"]

RESULTS_DIR_NAME = "results_sim-harm_V5"
COMPLETED_OUTPUT_CSV = DATA_DIR / "sim_results_V6.csv"

NIFTI_ROIS = {
    "lSPL_late": DATA_DIR / "resimnibs" / "lSPL_late.nii",
    "rSPL_late": DATA_DIR / "resimnibs" / "rSPL_late.nii",
    "rS2_early": DATA_DIR / "resimnibs" / "rS2_early.nii",
}

FSAVERAGE_ROIS = {
    "lPPC": {"path": DATA_DIR / "resimnibs" / "lPPC", "hemi": "lh"},
    "rOTC": {"path": DATA_DIR / "resimnibs" / "rOTC", "hemi": "rh"},
}

INTENDED_ROI_BY_CONDITION = {
    "target": "lPPC",
    "control": "rOTC",
}

ELECTRODE_ORDER = ["anode", "cathode1", "cathode2", "cathode3"]
CURRENTS = [2e-3, -0.666e-3, -0.667e-3, -0.667e-3]
ELECTRODE_DIMENSIONS_MM = [20, 20]
ELECTRODE_THICKNESS_MM = 2
ANODE_REFERENCE_RADIUS_MM = 10.0
DEFAULT_THRESHOLDS = [0.10, 0.15, 0.20]

RESULT_FIELDNAMES = [
    "subject",
    "model",
    "anat_session",
    "session",
    "run",
    "condition",
    "roi_name",
    "roi_type",
    "roi_space",
    "roi_path",
    "roi_mni_x",
    "roi_mni_y",
    "roi_mni_z",
    "roi_subject_x",
    "roi_subject_y",
    "roi_subject_z",
    "n_gray_matter_elements",
    "electric_field_name",
    "mean_MagE",
    "median_MagE",
    "current_density_field_name",
    "mean_J",
    "median_J",
    "error",
]

HARMONIZATION_BASE_FIELDNAMES = [
    "subject",
    "model",
    "anat_session",
    "session",
    "run",
    "condition",
    "roi_name",
    "is_intended_roi",
    "median_MagE",
    "mean_MagE",
    "area_weighted_mean_MagE",
    "roi_area_mm2",
    "integrated_MagE_mm2",
]

HARMONIZATION_METRIC_FIELDNAMES = [
    "is_intended_roi",
    "median_MagE",
    "mean_MagE",
    "area_weighted_mean_MagE",
    "roi_area_mm2",
    "integrated_MagE_mm2",
]

HARMONIZATION_JOIN_KEYS = [
    "subject",
    "model",
    "anat_session",
    "session",
    "run",
    "condition",
    "roi_name",
]
HARMONIZATION_OUTPUT_PREFIX = "harmonization_"

# ==============================================================================
# SECTION: ELECTRODE COORDINATE PARSING
# Reads the subject electrode coordinate CSV file, validates required channels
# (anode and three cathodes), and retrieves subject-space (X, Y, Z) coordinates
# for the selected subject, session, run, and condition.
# ==============================================================================

def normalized_coordinate_rows(coordinate_csv):
    with coordinate_csv.open(newline="") as f:
        sample = f.read(4096)
        f.seek(0)
        dialect = csv.Sniffer().sniff(sample, delimiters=",;")
        reader = csv.DictReader(f, dialect=dialect)
        for row in reader:
            yield {
                key.strip().lstrip("\ufeff"): value.strip()
                for key, value in row.items()
                if key is not None
            }


def available_conditions_for_subject(subject, session_for_csv, run_for_csv, coordinate_csv):
    electrodes_by_condition = {}
    for row in normalized_coordinate_rows(coordinate_csv):
        if row["subject"] != subject:
            continue
        if row["session"] != session_for_csv:
            continue
        if row["run"] != run_for_csv:
            continue
        electrodes_by_condition.setdefault(row["condition"], set()).add(row["electrode"])

    available_conditions = [
        condition
        for condition, electrodes in electrodes_by_condition.items()
        if all(electrode in electrodes for electrode in ELECTRODE_ORDER)
    ]
    return sorted(
        available_conditions,
        key=lambda condition: (
            CONDITION_ORDER.index(condition)
            if condition in CONDITION_ORDER
            else len(CONDITION_ORDER),
            condition,
        ),
    )


def load_electrode_subject_coordinates(
    subject,
    session_for_csv,
    run_for_csv,
    condition,
    coordinate_csv,
):
    rows_by_electrode = {}
    for row in normalized_coordinate_rows(coordinate_csv):
        if row["subject"] != subject:
            continue
        if row["session"] != session_for_csv:
            continue
        if row["run"] != run_for_csv:
            continue
        if row["condition"] != condition:
            continue
        if row["electrode"] in ELECTRODE_ORDER:
            rows_by_electrode[row["electrode"]] = row

    missing = [name for name in ELECTRODE_ORDER if name not in rows_by_electrode]
    if missing:
        raise RuntimeError(
            "Missing electrode rows in coordinate CSV: " + ", ".join(missing)
        )

    coordinates = {}
    for electrode in ELECTRODE_ORDER:
        row = rows_by_electrode[electrode]
        coordinates[electrode] = np.array(
            [float(row["X"]), float(row["Y"]), float(row["Z"])],
            dtype=float,
        )
    return coordinates

# ==============================================================================
# SECTION: SIMNIBS SIMULATION RUNNER
# Configures the SimNIBS FEM session (electric fields, surface/fsaverage mappings)
# and checks whether completed simulation meshes already exist on disk.
# If valid outputs are detected, the simulation step is skipped and the pipeline
# proceeds directly to post-processing (smart auto-resume).
# ==============================================================================

def run_tdcs_simulation(electrode_subject_coordinates, subject_m2m, results_dir):
    results_dir.mkdir(parents=True, exist_ok=True)

    session = sim_struct.SESSION()
    session.subpath = str(subject_m2m)
    session.pathfem = str(results_dir)
    session.fields = "eEjJ"
    session.map_to_surf = True
    session.map_to_fsavg = True

    tdcs = session.add_tdcslist()
    tdcs.currents = CURRENTS

    for channel_number, electrode_name in enumerate(ELECTRODE_ORDER, start=1):
        electrode = tdcs.add_electrode()
        electrode.channelnr = channel_number
        electrode.centre = electrode_subject_coordinates[electrode_name].tolist()
        electrode.dimensions = ELECTRODE_DIMENSIONS_MM
        electrode.shape = "ellipse"
        electrode.thickness = ELECTRODE_THICKNESS_MM

    run_simnibs(session)
    return session


def find_result_mesh(results_dir):
    matches = [
        path
        for path in sorted(results_dir.glob("*TDCS*scalar*.msh"))
        if not path.name.startswith("._")
        and "_central" not in path.stem
        and path.stat().st_size > 1_000_000
    ]
    if not matches:
        raise FileNotFoundError(
            f"No readable volume '*TDCS*scalar*.msh' result was found in {results_dir}"
        )
    return matches[0]


def has_complete_simulation(results_dir):
    """Checks if both subject volume mesh and fsaverage overlays are complete."""
    has_vol = any(
        path
        for path in results_dir.glob("*TDCS*scalar*.msh")
        if not path.name.startswith("._")
        and "_central" not in path.stem
        and path.stat().st_size > 1_000_000
    )
    fsavg_dir = results_dir / "fsavg_overlays"
    has_fsavg = (
        fsavg_dir.is_dir()
        and any(
            path
            for path in fsavg_dir.glob("*TDCS*scalar*fsavg.msh")
            if not path.name.startswith("._") and path.stat().st_size > 1_000_000
        )
    )
    return has_vol and has_fsavg


def find_fsaverage_mesh(results_dir):
    fsavg_dir = results_dir / "fsavg_overlays"
    matches = [
        path
        for path in sorted(fsavg_dir.glob("*TDCS*scalar*fsavg.msh"))
        if not path.name.startswith("._") and path.stat().st_size > 1_000_000
    ]
    if not matches:
        raise FileNotFoundError(
            "No readable fsaverage '*TDCS*scalar*fsavg.msh' result was found in "
            f"{fsavg_dir}. Re-run with fsaverage mapping enabled."
        )
    return matches[0]

# ==============================================================================
# SECTION: FIELD EXTRACTION & ROI SAMPLING
# Extracts electric field (|E|) and current density (|J|) arrays from:
#   1) Subject gray matter tetrahedral elements (transformed to MNI space for
#      NIfTI volumetric mask sampling).
#   2) FreeSurfer fsaverage surface nodes (for cortical surface overlays and
#      cross-subject centroid mapping).
# ==============================================================================

def get_field_data(mesh, possible_names):
    for name in possible_names:
        if name in mesh.field:
            field = mesh.field[name][:]
            field = np.asarray(field).squeeze()
            if field.ndim == 2:
                field = np.linalg.norm(field, axis=1)
            return name, field
    return None, None


def get_node_field_data(mesh, possible_names):
    for name in possible_names:
        if name in mesh.field:
            field = mesh.field[name]
            if hasattr(field, "value"):
                field = field.value
            else:
                field = field[:]
            field = np.asarray(field).squeeze()
            if field.ndim == 2:
                field = np.linalg.norm(field, axis=1)
            return name, field
    return None, None


def get_gray_matter_fields(subject_m2m, results_dir):
    result_mesh = find_result_mesh(results_dir)
    head_mesh = simnibs.read_msh(str(result_mesh))
    gray_matter = head_mesh.crop_mesh(simnibs.ElementTags.GM)

    electric_name, electric_field = get_field_data(gray_matter, ["magnE", "E_magn", "E"])
    if electric_name is None:
        raise KeyError(
            "Could not find an electric field. Available fields: "
            f"{list(gray_matter.field.keys())}"
        )

    current_name, current_field = get_field_data(gray_matter, ["magnJ", "J_magn", "J"])
    element_centers_subject = gray_matter.elements_baricenters()[:]
    element_centers_mni = np.asarray(
        simnibs.subject2mni_coords(element_centers_subject, str(subject_m2m)),
        dtype=float,
    )
    element_volumes = gray_matter.elements_volumes_and_areas()[:]

    return {
        "result_mesh": result_mesh,
        "element_centers_subject": element_centers_subject,
        "element_centers_mni": element_centers_mni,
        "element_volumes": element_volumes,
        "electric_name": electric_name,
        "electric_field": electric_field,
        "current_name": current_name or "",
        "current_field": current_field,
    }


def get_fsaverage_fields(results_dir):
    fsavg_mesh_path = find_fsaverage_mesh(results_dir)
    fsavg_mesh = simnibs.read_msh(str(fsavg_mesh_path))

    electric_name, electric_field = get_node_field_data(
        fsavg_mesh,
        ["E_magn", "magnE", "E"],
    )
    if electric_name is None:
        raise KeyError(
            "Could not find an electric fsaverage field. Available fields: "
            f"{list(fsavg_mesh.field.keys())}"
        )

    current_name, current_field = get_node_field_data(
        fsavg_mesh,
        ["J_magn", "magnJ", "J"],
    )
    node_areas = np.asarray(fsavg_mesh.nodes_areas()[:]).squeeze()
    if len(electric_field) != len(node_areas):
        raise ValueError(
            "Electric-field and vertex-area arrays do not match: "
            f"{len(electric_field)} E values vs {len(node_areas)} node areas."
        )

    return {
        "result_mesh": fsavg_mesh_path,
        "node_areas": node_areas,
        "electric_name": electric_name,
        "electric_field": electric_field,
        "current_name": current_name or "",
        "current_field": current_field,
    }


def load_nifti_mask(roi_path):
    try:
        import nibabel as nib
    except ImportError as exc:
        raise ImportError(
            "nibabel is required for NIfTI ROI masks in this SimNIBS environment."
        ) from exc

    image = nib.load(str(roi_path))
    return image.get_fdata(), image.affine


def sample_mask_at_mni_coordinates(mask_data, mask_affine, mni_coordinates):
    try:
        import nibabel as nib
    except ImportError as exc:
        raise ImportError(
            "nibabel is required for NIfTI ROI coordinate sampling."
        ) from exc

    voxel_coordinates = nib.affines.apply_affine(
        np.linalg.inv(mask_affine),
        mni_coordinates,
    )
    voxel_indices = np.rint(voxel_coordinates).astype(int)

    inside = np.all(voxel_indices >= 0, axis=1)
    inside &= np.all(voxel_indices < np.array(mask_data.shape), axis=1)

    roi = np.zeros(len(mni_coordinates), dtype=bool)
    if np.any(inside):
        valid_idx = voxel_indices[inside]
        roi[inside] = mask_data[
            valid_idx[:, 0],
            valid_idx[:, 1],
            valid_idx[:, 2],
        ] > 0
    return roi


def load_fsaverage_overlay_mask(roi_path):
    try:
        from nibabel.freesurfer.io import read_morph_data
    except ImportError as exc:
        raise ImportError(
            "nibabel is required for FreeSurfer/fsaverage ROI overlays."
        ) from exc

    overlay = np.asarray(read_morph_data(str(roi_path))).squeeze()
    return overlay > 0

# ==============================================================================
# SECTION: REGION SUMMARIZATION & HARMONIZATION CALCULATIONS
# Computes volume-weighted and area-weighted statistics (mean, median) across
# target ROIs. For surface harmonization, calculates total surface area,
# integrated field magnitude, and the area/fraction exposed above defined
# electric field thresholds (e.g., 0.10, 0.15, 0.20 V/m).
# ==============================================================================

def summarize_field_region(field_data, region):
    weights = field_data["element_volumes"][region]
    current_field = field_data["current_field"]

    result = {
        "roi_mni_x": "",
        "roi_mni_y": "",
        "roi_mni_z": "",
        "roi_subject_x": "",
        "roi_subject_y": "",
        "roi_subject_z": "",
        "n_gray_matter_elements": int(np.count_nonzero(region)),
        "electric_field_name": field_data["electric_name"],
        "mean_MagE": np.nan,
        "median_MagE": np.nan,
        "current_density_field_name": field_data["current_name"],
        "mean_J": np.nan,
        "median_J": np.nan,
    }

    if result["n_gray_matter_elements"] == 0:
        return result

    roi_subject = np.average(
        field_data["element_centers_subject"][region],
        axis=0,
        weights=weights,
    )
    roi_mni = np.average(
        field_data["element_centers_mni"][region],
        axis=0,
        weights=weights,
    )

    result.update(
        {
            "roi_subject_x": roi_subject[0],
            "roi_subject_y": roi_subject[1],
            "roi_subject_z": roi_subject[2],
            "roi_mni_x": roi_mni[0],
            "roi_mni_y": roi_mni[1],
            "roi_mni_z": roi_mni[2],
            "mean_MagE": np.average(
                field_data["electric_field"][region],
                weights=weights,
            ),
            "median_MagE": np.median(field_data["electric_field"][region]),
        }
    )
    if current_field is not None:
        result["mean_J"] = np.average(current_field[region], weights=weights)
        result["median_J"] = np.median(current_field[region])

    return result


def fsaverage_mask_center_in_subject(roi_mask, hemi, subject_m2m):
    from simnibs.mesh_tools import mesh_io
    from simnibs.utils.file_finder import SubjectFiles
    from simnibs.utils.transformations import cross_subject_map

    morph = cross_subject_map(
        "fsaverage",
        str(subject_m2m),
        hemi=hemi,
        project_kwargs={"method": "nearest"},
    )
    subject_mask = morph[hemi].resample(roi_mask.astype(float)) > 0.5
    if not np.any(subject_mask):
        raise ValueError(
            f"fsaverage ROI did not project to any {hemi} subject vertices."
        )

    subject_files = SubjectFiles(subpath=str(subject_m2m))
    subject_surface = mesh_io.load_subject_surfaces(subject_files, "central")[hemi]
    subject_coordinates = np.asarray(subject_surface.nodes.node_coord[:])
    subject_areas = np.asarray(subject_surface.nodes_areas()[:]).squeeze()

    return np.average(
        subject_coordinates[subject_mask],
        axis=0,
        weights=subject_areas[subject_mask],
    )


def fsaverage_region(roi_mask, hemi, total_vertices):
    n_vertices = len(roi_mask)
    if total_vertices != n_vertices * 2:
        raise ValueError(
            "ROI mask, fsaverage field, and node-area array do not have identical "
            "hemisphere vertex numbers/order. Expected the combined fsaverage mesh "
            f"to have {n_vertices * 2} vertices, but found {total_vertices}."
        )

    hemi_offset = 0 if hemi == "lh" else n_vertices
    region = np.zeros(total_vertices, dtype=bool)
    region[hemi_offset : hemi_offset + n_vertices] = roi_mask
    return region


def summarize_fsaverage_region(field_data, roi_mask, hemi, subject_m2m):
    region = fsaverage_region(roi_mask, hemi, len(field_data["electric_field"]))
    weights = field_data["node_areas"][region]
    current_field = field_data["current_field"]

    result = {
        "roi_mni_x": "",
        "roi_mni_y": "",
        "roi_mni_z": "",
        "roi_subject_x": "",
        "roi_subject_y": "",
        "roi_subject_z": "",
        "n_gray_matter_elements": int(np.count_nonzero(region)),
        "electric_field_name": field_data["electric_name"],
        "mean_MagE": np.nan,
        "median_MagE": np.nan,
        "current_density_field_name": field_data["current_name"],
        "mean_J": np.nan,
        "median_J": np.nan,
    }

    if result["n_gray_matter_elements"] == 0:
        return result

    subject_roi_center = fsaverage_mask_center_in_subject(
        roi_mask,
        hemi,
        subject_m2m,
    )
    mni_roi_center = np.asarray(
        simnibs.subject2mni_coords(
            np.atleast_2d(subject_roi_center),
            str(subject_m2m),
        ),
        dtype=float,
    )[0]

    result.update(
        {
            "roi_subject_x": subject_roi_center[0],
            "roi_subject_y": subject_roi_center[1],
            "roi_subject_z": subject_roi_center[2],
            "roi_mni_x": mni_roi_center[0],
            "roi_mni_y": mni_roi_center[1],
            "roi_mni_z": mni_roi_center[2],
            "mean_MagE": np.average(
                field_data["electric_field"][region],
                weights=weights,
            ),
            "median_MagE": np.median(field_data["electric_field"][region]),
        }
    )
    if current_field is not None:
        result["mean_J"] = np.average(current_field[region], weights=weights)
        result["median_J"] = np.median(current_field[region])

    return result


def empty_result_row(
    subject,
    anat_session,
    session_for_csv,
    run_for_csv,
    condition,
    roi_name,
    roi_type,
    roi_path="",
    error="",
):
    return {
        "subject": subject,
        "anat_session": anat_session,
        "session": session_for_csv,
        "run": run_for_csv,
        "condition": condition,
        "roi_name": roi_name,
        "roi_type": roi_type,
        "roi_space": "",
        "roi_path": str(roi_path),
        "roi_mni_x": "",
        "roi_mni_y": "",
        "roi_mni_z": "",
        "roi_subject_x": "",
        "roi_subject_y": "",
        "roi_subject_z": "",
        "n_gray_matter_elements": 0,
        "electric_field_name": "",
        "mean_MagE": np.nan,
        "median_MagE": np.nan,
        "current_density_field_name": "",
        "mean_J": np.nan,
        "median_J": np.nan,
        "error": error,
    }


def threshold_fieldnames(thresholds):
    names = []
    for threshold in thresholds:
        label = f"{threshold:.2f}"
        names.append(f"area_above_{label}_mm2")
        names.append(f"fraction_above_{label}")
    return names


def empty_harmonization_row(
    subject,
    anat_session,
    condition,
    roi_name,
    thresholds,
    error="",
):
    row = {
        "subject": subject,
        "anat_session": anat_session,
        "condition": condition,
        "roi_name": roi_name,
        "is_intended_roi": roi_name == INTENDED_ROI_BY_CONDITION.get(condition, ""),
        "median_MagE": np.nan,
        "mean_MagE": np.nan,
        "area_weighted_mean_MagE": np.nan,
        "roi_area_mm2": np.nan,
        "integrated_MagE_mm2": np.nan,
        "error": error,
    }
    for threshold in thresholds:
        label = f"{threshold:.2f}"
        row[f"area_above_{label}_mm2"] = np.nan
        row[f"fraction_above_{label}"] = np.nan
    return row


def summarize_harmonization_roi(
    subject,
    anat_session,
    condition,
    roi_name,
    roi_mask,
    hemi,
    fsaverage_data,
    thresholds,
):
    region = fsaverage_region(roi_mask, hemi, len(fsaverage_data["electric_field"]))
    e_values = fsaverage_data["electric_field"][region]
    area_values = fsaverage_data["node_areas"][region]
    if len(e_values) == 0:
        raise ValueError("ROI mask did not select any fsaverage vertices.")

    roi_area = np.sum(area_values)
    integrated = np.sum(area_values * e_values)

    row = empty_harmonization_row(
        subject,
        anat_session,
        condition,
        roi_name,
        thresholds,
    )
    row.update(
        {
            "median_MagE": np.median(e_values),
            "mean_MagE": np.mean(e_values),
            "area_weighted_mean_MagE": integrated / roi_area,
            "roi_area_mm2": roi_area,
            "integrated_MagE_mm2": integrated,
        }
    )

    for threshold in thresholds:
        label = f"{threshold:.2f}"
        above = e_values >= threshold
        area_above = np.sum(area_values[above])
        row[f"area_above_{label}_mm2"] = area_above
        row[f"fraction_above_{label}"] = area_above / roi_area

    return row

# ==============================================================================
# SECTION: REGION SUMMARIZATION & HARMONIZATION CALCULATIONS
# Computes volume-weighted and area-weighted statistics (mean, median) across
# target ROIs. For surface harmonization, calculates total surface area,
# integrated field magnitude, and the area/fraction exposed above defined
# electric field thresholds (e.g., 0.10, 0.15, 0.20 V/m).
# ==============================================================================

def analyze_result_rows(
    subject,
    anat_session,
    session_for_csv,
    run_for_csv,
    condition,
    electrode_subject_coordinates,
    subject_m2m,
    gray_matter_data,
    fsaverage_data,
    fsaverage_error="",
):
    results = []

    for roi_name, roi_path in NIFTI_ROIS.items():
        result = empty_result_row(
            subject,
            anat_session,
            session_for_csv,
            run_for_csv,
            condition,
            roi_name,
            "nifti_mask",
            roi_path,
        )
        result["roi_space"] = "mni_volume"

        try:
            mask_data, mask_affine = load_nifti_mask(roi_path)
            roi = sample_mask_at_mni_coordinates(
                mask_data,
                mask_affine,
                gray_matter_data["element_centers_mni"],
            )
            summary = summarize_field_region(gray_matter_data, roi)
        except Exception as exc:
            result["error"] = str(exc)
            results.append(result)
            continue

        result.update(summary)
        if result["n_gray_matter_elements"] == 0:
            result["error"] = "No gray matter elements found in ROI."
        results.append(result)

    for roi_name, roi_info in FSAVERAGE_ROIS.items():
        result = empty_result_row(
            subject,
            anat_session,
            session_for_csv,
            run_for_csv,
            condition,
            roi_name,
            "fsaverage_overlay",
            roi_info["path"],
            fsaverage_error,
        )
        result["roi_space"] = f"fsaverage_{roi_info['hemi']}"

        if fsaverage_data is not None:
            try:
                roi_mask = load_fsaverage_overlay_mask(roi_info["path"])
                summary = summarize_fsaverage_region(
                    fsaverage_data,
                    roi_mask,
                    roi_info["hemi"],
                    subject_m2m,
                )
            except Exception as exc:
                result["error"] = str(exc)
                results.append(result)
                continue

            result.update(summary)
            if result["n_gray_matter_elements"] == 0:
                result["error"] = "No fsaverage vertices found in ROI."
        results.append(result)

    anode_subject = electrode_subject_coordinates["anode"]
    distances_to_anode = np.linalg.norm(
        gray_matter_data["element_centers_subject"] - anode_subject,
        axis=1,
    )
    nearest_anode_index = int(np.argmin(distances_to_anode))
    anode_center = gray_matter_data["element_centers_subject"][nearest_anode_index]
    anode_region = (
        np.linalg.norm(
            gray_matter_data["element_centers_subject"] - anode_center,
            axis=1,
        )
        < ANODE_REFERENCE_RADIUS_MM
    )

    anode_result = empty_result_row(
        subject,
        anat_session,
        session_for_csv,
        run_for_csv,
        condition,
        "anode",
        "nearest_gm_subject_sphere",
    )
    anode_result["roi_space"] = "subject_volume"
    anode_result.update(summarize_field_region(gray_matter_data, anode_region))
    if anode_result["n_gray_matter_elements"] == 0:
        anode_result["error"] = "No gray matter elements found under the anode."
    results.append(anode_result)

    return results


def analyze_harmonization_rows(
    subject,
    anat_session,
    condition,
    fsaverage_data,
    thresholds,
    fsaverage_error="",
):
    rows = []
    for roi_name, roi_info in FSAVERAGE_ROIS.items():
        if fsaverage_data is None:
            row = empty_harmonization_row(
                subject,
                anat_session,
                condition,
                roi_name,
                thresholds,
                fsaverage_error,
            )
        else:
            try:
                roi_mask = load_fsaverage_overlay_mask(roi_info["path"])
                row = summarize_harmonization_roi(
                    subject,
                    anat_session,
                    condition,
                    roi_name,
                    roi_mask,
                    roi_info["hemi"],
                    fsaverage_data,
                    thresholds,
                )
            except Exception as exc:
                row = empty_harmonization_row(
                    subject,
                    anat_session,
                    condition,
                    roi_name,
                    thresholds,
                    str(exc),
                )
        rows.append(row)
    return rows


def subject_result_error_rows(
    subject,
    anat_session,
    session_for_csv,
    run_for_csv,
    condition,
    error,
):
    return [
        empty_result_row(
            subject,
            anat_session,
            session_for_csv,
            run_for_csv,
            condition,
            "subject_processing",
            "error",
            error=str(error),
        )
    ]


def subject_harmonization_error_rows(
    subject,
    anat_session,
    condition,
    thresholds,
    error,
):
    return [
        empty_harmonization_row(
            subject,
            anat_session,
            condition,
            roi_name,
            thresholds,
            str(error),
        )
        for roi_name in FSAVERAGE_ROIS
    ]


def write_csv(rows, output_csv, fieldnames):
    output_csv.parent.mkdir(parents=True, exist_ok=True)
    with output_csv.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    return output_csv


def harmonization_fieldnames(thresholds):
    names = []
    for name in HARMONIZATION_METRIC_FIELDNAMES:
        names.append(f"{HARMONIZATION_OUTPUT_PREFIX}{name}")
    for name in threshold_fieldnames(thresholds):
        names.append(f"{HARMONIZATION_OUTPUT_PREFIX}{name}")
    names.append(f"{HARMONIZATION_OUTPUT_PREFIX}error")
    return names


def empty_harmonization_output_values(thresholds):
    return {name: "" for name in harmonization_fieldnames(thresholds)}


def harmonization_lookup_key(row):
    return tuple(row[key] for key in HARMONIZATION_JOIN_KEYS)


def prefixed_harmonization_values(row, thresholds):
    values = empty_harmonization_output_values(thresholds)
    source_fieldnames = HARMONIZATION_METRIC_FIELDNAMES + threshold_fieldnames(thresholds)
    for name in source_fieldnames:
        values[f"{HARMONIZATION_OUTPUT_PREFIX}{name}"] = row.get(name, "")
    values[f"{HARMONIZATION_OUTPUT_PREFIX}error"] = row.get("error", "")
    return values


def consolidate_result_rows(result_rows, harmonization_rows, thresholds):
    harmonization_by_key = {
        harmonization_lookup_key(row): row
        for row in harmonization_rows
    }

    consolidated_rows = []
    for result_row in result_rows:
        row = dict(result_row)
        row.update(empty_harmonization_output_values(thresholds))

        if result_row.get("roi_name") in FSAVERAGE_ROIS:
            harmonization_row = harmonization_by_key.get(
                harmonization_lookup_key(result_row)
            )
            if harmonization_row is not None:
                row.update(prefixed_harmonization_values(harmonization_row, thresholds))

        consolidated_rows.append(row)
    return consolidated_rows


def model_m2m_path(data_dir, subject, model):
    if model not in MODEL_FOLDER_TEMPLATES:
        raise ValueError(
            f"Unknown model {model!r}. Expected one of {', '.join(MODELS)}."
        )

    subject_number = subject[4:] if subject.startswith("sub-") else subject
    subject_dir = data_dir / subject
    model_name = MODEL_FOLDER_TEMPLATES[model].format(subject_number=subject_number)
    return subject_dir, subject_dir / BASELINE_ANAT_SESSION / "anat" / model_name


def source_result_dir(data_dir, subject, source_session, run, condition, model,
                      results_dir_name):
    subject_dir = data_dir / subject
    return (
        subject_dir
        / results_dir_name
        / source_session
        / run
        / condition
        / model
    )


def add_run_metadata(rows, subject, model, source_session, run):
    for row in rows:
        row["subject"] = subject
        row["model"] = model
        row["anat_session"] = BASELINE_ANAT_SESSION
        row["session"] = source_session
        row["run"] = run
    return rows


def analyze_subject_model_condition(
    subject,
    source_session,
    run_for_csv,
    condition,
    model,
    args,
    thresholds,
):
    subject_dir, subject_m2m = model_m2m_path(args.data_dir, subject, model)
    results_dir = source_result_dir(
        args.data_dir,
        subject,
        source_session,
        run_for_csv,
        condition,
        model,
        args.results_dir_name,
    )

    if not subject_dir.exists():
        raise FileNotFoundError(f"Subject folder was not found: {subject_dir}")
    if not subject_m2m.exists():
        raise FileNotFoundError(
            f"{model} baseline m2m folder was not found: {subject_m2m}"
        )

    electrode_subject_coordinates = load_electrode_subject_coordinates(
        subject,
        source_session,
        run_for_csv,
        condition,
        args.coordinate_csv,
    )

    results_dir.mkdir(parents=True, exist_ok=True)

    # --- LÓGICA V6: AUTO-RESUME ---
    # Comprueba si ya existen los cálculos completos para esta combinación
    already_computed = has_complete_simulation(results_dir)

    if args.force_rerun:
        simulate_now = True
    elif args.skip_simulation:
        if not already_computed:
            raise FileNotFoundError(
                f"--skip-simulation was requested, but no existing complete mesh "
                f"was found in {results_dir}"
            )
        simulate_now = False
    else:
        simulate_now = not already_computed

    if simulate_now:
        print(
            f"--> [SIMULATING] {subject} | {source_session} | "
            f"run={run_for_csv} | cond={condition} | model={model}"
        )
        run_tdcs_simulation(
            electrode_subject_coordinates,
            subject_m2m,
            results_dir,
        )
    else:
        print(
            f"--> [REUSING EXISTING SIMULATION] {subject} | {source_session} | "
            f"run={run_for_csv} | cond={condition} | model={model}"
        )

    gray_matter_data = get_gray_matter_fields(subject_m2m, results_dir)

    fsaverage_data = None
    fsaverage_error = ""
    try:
        fsaverage_data = get_fsaverage_fields(results_dir)
    except Exception as exc:
        fsaverage_error = str(exc)
        print(
            f"ERROR loading fsaverage fields for "
            f"{subject} {source_session} {run_for_csv} {condition} {model}: {exc}"
        )

    result_rows = analyze_result_rows(
        subject,
        BASELINE_ANAT_SESSION,
        source_session,
        run_for_csv,
        condition,
        electrode_subject_coordinates,
        subject_m2m,
        gray_matter_data,
        fsaverage_data,
        fsaverage_error,
    )

    harmonization_rows = analyze_harmonization_rows(
        subject,
        BASELINE_ANAT_SESSION,
        condition,
        fsaverage_data,
        thresholds,
        fsaverage_error,
    )

    add_run_metadata(
        result_rows, subject, model, source_session, run_for_csv
    )
    add_run_metadata(
        harmonization_rows, subject, model, source_session, run_for_csv
    )

    return result_rows, harmonization_rows


def is_missing_model_error(error):
    return (
        isinstance(error, FileNotFoundError)
        and "baseline m2m folder was not found" in str(error)
    )


def available_source_runs(
    subject,
    source_session,
    coordinate_csv,
    requested_runs=None,
):
    runs = set()
    for row in normalized_coordinate_rows(coordinate_csv):
        if row["subject"] != subject or row["session"] != source_session:
            continue
        run = row["run"]
        if requested_runs and run not in requested_runs:
            continue
        runs.add(run)

    complete_runs = []
    for run in sorted(runs):
        conditions = available_conditions_for_subject(
            subject,
            source_session,
            run,
            coordinate_csv,
        )
        if conditions:
            complete_runs.append(run)
    return complete_runs


# ==============================================================================
# SECTION: SUBJECT DISCOVERY & COMMAND-LINE INTERFACE (CLI)
# Automatically scans the dataset directory for subject folders, determines
# valid sessions/runs from coordinate records, and exposes execution flags
# (--force-rerun, --skip-simulation, --continue-on-error, custom thresholds).
# ==============================================================================

def discover_subjects(data_dir, requested_subjects=None):
    if requested_subjects:
        subjects = []
        for subject in requested_subjects:
            subject = str(subject)
            if not subject.startswith("sub-"):
                subject = f"sub-{subject}"
            
            subject_dir = data_dir / subject
            if not subject_dir.is_dir():
                raise FileNotFoundError(
                    f"Subject folder was not found: {subject_dir}"
                )
            subjects.append(subject)
        return sorted(subjects)

    return sorted(
        path.name
        for path in data_dir.glob("sub-*")
        if path.is_dir()
    )


def parse_args():
    parser = argparse.ArgumentParser(
        description="SimNIBS V6: Auto-resuming pipeline for completed and pending simulations."
    )
    parser.add_argument("--data-dir", type=Path, default=DATA_DIR)
    parser.add_argument("--coordinate-csv", type=Path, default=COORDINATE_CSV)
    parser.add_argument("--results-dir-name", default=RESULTS_DIR_NAME)
    parser.add_argument(
        "--output-csv",
        type=Path,
        default=COMPLETED_OUTPUT_CSV,
        help="Consolidated output CSV. Default: sim_results_V6.csv.",
    )
    parser.add_argument(
        "--subjects",
        nargs="+",
        help="Optional list such as sub-2202 sub-2264 or 2202 2264.",
    )
    parser.add_argument(
        "--source-sessions",
        nargs="+",
        default=list(SOURCE_SESSIONS),
        choices=list(SOURCE_SESSIONS),
        help="Non-baseline coordinate sessions to process.",
    )
    parser.add_argument(
        "--runs",
        nargs="+",
        default=["run-01"],
        help="CSV runs to process. Default: run-01.",
    )
    parser.add_argument(
        "--models",
        nargs="+",
        default=list(MODELS),
        choices=list(MODELS),
        help="Baseline models to process.",
    )
    parser.add_argument(
        "--condition",
        default=CONDITION,
        help="Use 'auto' for every complete condition, or pass target/control.",
    )
    parser.add_argument(
        "--thresholds",
        nargs="+",
        type=float,
        default=DEFAULT_THRESHOLDS,
        help="Harmonization field thresholds in V/m.",
    )
    parser.add_argument(
        "--skip-simulation",
        action="store_true",
        help="Fail if any simulation is missing rather than running it.",
    )
    parser.add_argument(
        "--force-rerun",
        action="store_true",
        help="Force SimNIBS to re-simulate even if output meshes already exist.",
    )
    parser.add_argument(
        "--continue-on-error",
        action="store_true",
        help="Write error rows and continue if one subject/model/run/condition fails.",
    )
    return parser.parse_args()

# ==============================================================================
# SECTION: MAIN EXECUTION CONTROLLER
# Parses arguments, validates coordinate CSV headers, and executes the nested
# processing loop (Subject -> Session -> Run -> Condition -> Model) while
# handling error recovery and exporting the final consolidated CSV file.
# ==============================================================================

def main():
    args = parse_args()
    thresholds = sorted(args.thresholds)
    subjects = discover_subjects(args.data_dir, args.subjects)

    required_columns = {
        "subject", "session", "run", "electrode", "condition", "X", "Y", "Z"
    }
    first_row = next(iter(normalized_coordinate_rows(args.coordinate_csv)), None)
    if first_row is None:
        raise RuntimeError(f"No coordinate rows found in {args.coordinate_csv}")
    missing_columns = required_columns - set(first_row.keys())
    if missing_columns:
        raise RuntimeError(
            "Coordinate CSV is missing required columns: "
            + ", ".join(sorted(missing_columns))
        )

    all_result_rows = []
    all_harmonization_rows = []

    print(f"Found {len(subjects)} subject(s): {', '.join(subjects)}")
    print(f"Coordinate sessions: {', '.join(args.source_sessions)}")
    print(f"Baseline models: {', '.join(args.models)}")
    print(f"Target runs: {', '.join(args.runs) if args.runs else 'all'}")

    for subject in subjects:
        print(f"\n=== Processing {subject} ===")
        subject_has_source_data = False

        for source_session in args.source_sessions:
            runs = available_source_runs(
                subject,
                source_session,
                args.coordinate_csv,
                args.runs,
            )

            if not runs:
                continue

            subject_has_source_data = True
            for run_for_csv in runs:
                conditions = (
                    available_conditions_for_subject(
                        subject, source_session, run_for_csv, args.coordinate_csv
                    )
                    if args.condition == "auto"
                    else [args.condition]
                )

                for condition in conditions:
                    for model in args.models:
                        try:
                            result_rows, harmonization_rows = (
                                analyze_subject_model_condition(
                                    subject,
                                    source_session,
                                    run_for_csv,
                                    condition,
                                    model,
                                    args,
                                    thresholds,
                                )
                            )
                        except Exception as exc:
                            if not args.continue_on_error and not is_missing_model_error(exc):
                                raise

                            print(
                                f"ERROR processing {subject} {source_session} "
                                f"{run_for_csv} {condition} {model}: {exc}"
                            )

                            result_rows = subject_result_error_rows(
                                subject,
                                BASELINE_ANAT_SESSION,
                                source_session,
                                run_for_csv,
                                condition,
                                exc,
                            )
                            harmonization_rows = subject_harmonization_error_rows(
                                subject,
                                BASELINE_ANAT_SESSION,
                                condition,
                                thresholds,
                                exc,
                            )

                            add_run_metadata(
                                result_rows,
                                subject,
                                model,
                                source_session,
                                run_for_csv,
                            )
                            add_run_metadata(
                                harmonization_rows,
                                subject,
                                model,
                                source_session,
                                run_for_csv,
                            )

                        all_result_rows.extend(result_rows)
                        all_harmonization_rows.extend(harmonization_rows)

        if not subject_has_source_data:
            print(f"No valid coordinate data found for {subject}; skipped.")

    completed_rows = consolidate_result_rows(
        all_result_rows,
        all_harmonization_rows,
        thresholds,
    )
    completed_fieldnames = RESULT_FIELDNAMES + harmonization_fieldnames(thresholds)

    completed_csv = write_csv(
        completed_rows,
        args.output_csv,
        completed_fieldnames,
    )

    print(f"\nPipeline finished successfully!")
    print(f"Consolidated CSV generated at: {completed_csv}")
    print(f"Total entries processed: {len(completed_rows)}")


if __name__ == "__main__":
    main()
