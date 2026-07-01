# memoslap resting-state fMRI preprocessing pipeline

SPM12-based preprocessing pipeline for resting-state fMRI data (subject-level).

## Folder contents

```
run_preprocessing.m      <- main script: EDIT PATHS AT THE TOP, THEN RUN
B*.m                     <- step functions the pipeline calls. Either directly in this
                             folder, or in a steps/ subfolder -- match this to whichever
                             addpath line is active near the top of run_preprocessing.m
```

## Quick start

1. Open `run_preprocessing.m`.
2. **Section 1**: set `src_dir`, `SPM_path`, and the toolbox `addpath` lines.
3. **Section 2**: set `subject_id`, `session_id`, `analysis_steps` (order matters — see below).
4. Run the whole script (F5).
5. Section 3 has tunable parameters (smoothing kernel, filter cutoffs, etc.) — defaults match what was used for the original analyses.

## Required toolboxes

| Toolbox | Used in | Function(s) |
|---|---|---|
| **SPM12** | Steps 1, 3, 4, 5/5b, 6, 9, + parts of 8 & 10 — the backbone | `spm_select`, `spm_vol`, `matlabbatch{...}.spm.*` |
| **hMRI toolbox** | Once, before the step loop, to read the `.json` sidecar | `get_metadata_val()` |
| **DPABI** | Step 8 only (CompCor) | `y_CompCor_PC()` |
| **RESTplus** | Steps 7, 10, 12 | `rp_to4d`, `rp_ReadNiftiImage`, `rp_Write4DNIfTI`, `rp_IdealFilter` |
| **bramila** | Step 7 only (scrubbing) | `bramila_framewiseDisplacement()` |
| **NIfTI toolbox** (Jimmy Shen) | Step 2 only — dormant by default (`x=0`) | `load_untouch_nii()`, `save_untouch_nii()` |

## Data layout & naming

```
<src_dir>/sub-<ID>/ses-<NN>/anat/ses-..._T1w.nii
<src_dir>/sub-<ID>/ses-<NN>/func/ses-..._run-01_bold.nii  (+ .json)
<src_dir>/sub-<ID>/ses-<NN>/func/ses-..._run-02_bold.nii  (+ .json)
... (all runs picked up and processed together)
```

- `subject_id` → `sub-<id>`, **not** zero-padded. `session_id` → `ses-<NN>`, zero-padded to 2 digits.
- `.nii.gz` files are auto-unzipped (originals deleted after).
- Functional runs matched via `ses-*run-*bold.nii` — narrow this pattern if you only want specific runs.
- TR/slice-timing read from the first matching `.json` sidecar found; assumes all runs share the same values.
- Tissue masks found by pattern: GM `c1*.nii`→`rc1*.nii`, WM `c2*T1w.nii`→`rc2*.nii`, CSF `c3*T1w.nii`→`rc3*.nii` (steps 8/10 reslice these; `cc_prefix` like `tCSF95tWM95s4` gets added if step 8 smooths/thresholds them). If multiple matches exist, the first alphabetically is used.
- Nothing is overwritten — each step prepends a prefix and writes a new file. Rerunning a step can leave stale duplicates; clear `func/` before reprocessing a subject from scratch.

## Pipeline steps

| # | Step | Prefix added | Function |
|---|------|---------------|----------|
| 1 | Segmentation | (none) | `B1_segmentation` |
| 2 | Delete first X scans | `x<N>` | `B2_delete_scans` |
| 3 | Slice-time correction | `a` | `B3_slice_time_correction` |
| 4 | Realignment | `r` | `B4_Realignment_all_runs` |
| 5 | Coregister (estimate) | (none) | `B5_coregister_est` |
| 5b | Coregister (estimate+reslice) — alt. to 5 | `c` | `B5b_coregister_est_re` |
| 6 | Normalization | `w` | `B6_normalization_run` |
| 7 | Scrubbing (motion outliers) | `m<thresh>` | `B7_scrub_data` |
| 8 | WM/CSF CompCor | (none) | `B8_compcorr_run` (+ `B85_smooth_thresh_masks`, `B_reslice_masks_to_functional`) |
| 9 | Smoothing | `s<kernel>` | `B9_smoothing_run` |
| 10 | Trends + global signal | (none, feeds 11) | `B10_calculating_trends_and_gs` |
| 11 | Nuisance regression | `Rhclqg_` | `B11_regress_out_nuisance` |
| 12 | Band-pass filtering | `Fh<hp>l<lp>_` | `B12_bandpass_filter_run` |

Each step **prepends** its prefix (`currPrefix = ['<new>' currPrefix]`), so the filename reads **right-to-left in chronological order** — leftmost = most recent step. With the default order below, the final file looks like:

```
s8wFh01l08_Rhclqg_m0.4ar_sub-2230_ses-01_run-02_bold.nii
```
(smoothed → normalized → band-pass filtered → nuisance-regressed → scrubbed → realigned → slice-time corrected → original)

## ⚠️ Execution order ≠ case-number order

`analysis_steps` runs **in the order you list it**, not numeric order:

```matlab
analysis_steps = [4, 3, 1, 5, 7, 8, 10, 11, 12, 6, 9];
```

→ Realign → Slice-time → Segment → Coregister → Scrub → CompCor → Trends/GS → Nuisance regression → **Band-pass → THEN Normalize → THEN Smooth**. Don't "tidy" this into ascending order without checking with whoever supervises the analysis — it changes what the pipeline does.

## Notes

- Step logic is preserved exactly as used in the original research; only file layout, comments, and config location changed.
- `B13_cut_data.m` isn't called anywhere in the pipeline (kept for potential future use — add a `case` for it if needed).
- `denoising_pipeline.m` (same folder) is a **separate, unrelated pipeline** — CONN toolbox, takes fMRIPrep output, not this pipeline's output.
