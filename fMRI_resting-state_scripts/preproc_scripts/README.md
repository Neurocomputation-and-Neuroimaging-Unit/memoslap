# memoslap resting-state fMRI preprocessing pipeline

SPM12-based preprocessing pipeline for resting-state fMRI data (subject-level).

## Folder contents

```
run_preprocessing.m      <- main script: EDIT PATHS AT THE TOP, THEN RUN
steps/                   <- all the B*_ functions the pipeline calls (leave alone)
```

## Quick start

1. Open `run_preprocessing.m`.
2. In **Section 1 (Paths & Toolboxes)**, set:
   - `src_dir` — folder containing your `sub-*/ses-*/...` data
   - `SPM_path` — your local SPM12 install
   - the four `addpath(genpath(...))` lines for hMRI, DPABI, bramila, RESTplus
3. In **Section 2 (What to run)**, set `subject_id`, `session_id`, and `analysis_steps`
   (which steps to run, in which order — see warning below).
4. Run the whole script (F5). Nothing else in the file needs editing for a normal run.
5. Section 3 holds all the tunable parameters (smoothing kernel, filter cutoffs,
   scrubbing threshold, etc.) if you ever need to deviate from the defaults.

## Required toolboxes on the MATLAB path

Not every step needs every toolbox — here's exactly which step uses what,
traced from the actual function calls (not just "what's on the addpath"):

| Toolbox | Used in | Function(s) |
|---|---|---|
| **SPM12** | Steps 1, 3, 4, 5/5b, 6, 9, plus mask reslicing/smoothing inside 8 & 10 — the backbone of almost the whole pipeline | `spm_select`, `spm_vol`, `matlabbatch{...}.spm.*` |
| **hMRI toolbox** | Once, before the step loop even starts, to read the BIDS `.json` sidecar | `get_metadata_val()` (RepetitionTime, SliceTiming) |
| **DPABI** | Step 8 only (CompCor) | `y_CompCor_PC()` |
| **RESTplus** | Steps 7, 10, 12 | `rp_to4d`, `rp_ReadNiftiImage`, `rp_Write4DNIfTI`, `rp_IdealFilter` |
| **bramila** | Step 7 only (scrubbing) | `bramila_framewiseDisplacement()` |


## Expected data layout (BIDS-like)

```
<src_dir>/sub-<ID>/ses-<NN>/anat/ses-..._T1w.nii
<src_dir>/sub-<ID>/ses-<NN>/func/ses-..._run-02_bold.nii  (+ matching .json sidecar)
```

## File & folder naming conventions

The pipeline finds files by pattern-matching, not by asking you for exact
paths — so your data has to follow these naming rules or it won't find
anything (and will error out with "no run files found" etc.).

### Folder structure

```
<src_dir>/
  sub-<subject_id>/                e.g. sub-2230        (subject_id is set in Section 2, no zero-padding)
    ses-<NN>/                      e.g. ses-01           (session_id zero-padded to 2 digits, via sprintf('ses-%02d', ...))
      anat/
        ses-..._T1w.nii             <- structural scan
      func/
        ses-..._run-01_bold.nii     <- functional run 1
        ses-..._run-01_bold.json    <- BIDS sidecar (TR, slice timing)
        ses-..._run-02_bold.nii     <- functional run 2
        ses-..._run-02_bold.json    <- BIDS sidecar
        ...                          <- all runs matching the pattern are processed together
```

- `subject_id` is a plain number (e.g. `2230`) → folder becomes `sub-2230`.
  It is **not** zero-padded — if your subjects are named `sub-002230` or
  similar you'll need to adjust `SJ = sprintf('sub-%d', subject_id)` near
  the top of the pipeline logic.
- `session_id` **is** zero-padded to 2 digits (`1` → `ses-01`).
- If your data arrives as `.nii.gz`, the script auto-unzips everything
  under `ses-*` in that session folder before doing anything else — no
  action needed, but the `.gz` originals get deleted after unzipping.

### Functional run files

The pipeline picks up **all** runs for the session matching:
```
ses-*run-*bold.nii
```
in the `func/` folder — so if a session has `run-01`, `run-02`, `run-03`,
etc., all of them are found and looped over together at every step. If you
ever want to restrict processing to a subset of runs, narrow the pattern
(search for `'ses-*run-*bold.nii'` near the top of the pipeline logic),
e.g. `'ses-*run-02*bold.nii'` to go back to a single run.

Note: a few steps (8 and 10) pick one run as a reference image for mask
reslicing (`runs{1}`) — this is intentional, not a limitation. Steps 1–4
realign/coregister all runs together into one shared space per session,
so any single run works as the reference at that point.

### JSON sidecar (TR / slice timing)

The script looks for `task*.json` anywhere under `src_dir` first; if none
are found it falls back to `ses-*bold*.json`. It only reads the **first**
match it finds and assumes all runs share the same TR/slice-timing — fine
if your acquisition parameters are identical across runs/subjects, not
fine otherwise.

### Anatomical / tissue mask files

These are produced by SPM's segmentation (step 1) and are found by
pattern, not hardcoded names:

| Tissue | Native-space (before reslice) | Resliced-to-functional (after `B_reslice_masks_to_functional`) |
|---|---|---|
| Grey matter  | `c1*.nii`  (anat folder) | `rc1*.nii` |
| White matter | `c2*T1w.nii` | `rc2*.nii` (or `<cc_prefix>rc2*.nii` if smoothed/thresholded in step 8) |
| CSF          | `c3*T1w.nii` | `rc3*.nii` (or `<cc_prefix>rc3*.nii`) |

`cc_prefix` (from step 8) looks like `tCSF95tWM95s4` — encoding the CSF
threshold, WM threshold, and smoothing kernel used. If step 8 finds more
than one matching file, it silently uses the first one alphabetically —
worth checking manually if a subject has stray leftover files from a
previous run.

### Output / intermediate files

The pipeline never renames the original file — each step writes a **new**
file with a prefix stuck on the front (see prefix table below), and reads
whatever file currently has all the prefixes applied so far
(`currPrefix` in the code, rebuilt at each step). This means:

- Nothing is overwritten — you'll accumulate one file per step per run in
  `func/`, e.g. `sub-2230_..._bold.nii` → `rsub-2230_..._bold.nii` →
  `arsub-2230_..._bold.nii` → `m0.4arsub-2230_..._bold.nii` → ...
  (with the default step order, realignment runs before slice-timing, so
  `r` gets prepended before `a` — see the prefix-stacking example above)
- If you rerun a step, it'll create a duplicate with the same prefix
  (SPM/DPABI functions typically won't error, but you can end up with
  stale duplicate files — worth clearing a subject's `func/` folder before
  reprocessing from scratch).
- The **final** filename (after all requested steps) tells you exactly
  what was done, in the exact order it was done — see the worked example
  below the step table.

## Pipeline steps

| # | Step | Prefix added | Function |
|---|------|---------------|----------|
| 1 | Segmentation | (none) | `B1_segmentation` |
| 2 | Delete first X scans | `x<N>` | `B2_delete_scans` |
| 3 | Slice-time correction | `a` | `B3_slice_time_correction` |
| 4 | Realignment | `r` | `B4_Realignment_all_runs` |
| 5 | Coregister (estimate) | (none) | `B5_coregister_est` |
| 5b | Coregister (estimate+reslice) — alternative to 5 | `c` | `B5b_coregister_est_re` |
| 6 | Normalization | `w` | `B6_normalization_run` |
| 7 | Scrubbing (motion outliers) | `m<thresh>` | `B7_scrub_data` |
| 8 | WM/CSF CompCor | (none) | `B8_compcorr_run` (+ `B85_smooth_thresh_masks`, `B_reslice_masks_to_functional`) |
| 9 | Smoothing | `s<kernel>` | `B9_smoothing_run` |
| 10 | Trends + global signal | (none, feeds step 11) | `B10_calculating_trends_and_gs` |
| 11 | Nuisance regression | `Rhclqg_` | `B11_regress_out_nuisance` |
| 12 | Band-pass filtering | `Fh<hp>l<lp>_` | `B12_bandpass_filter_run` |

Each step **prepends** its own prefix to the front of whatever prefix
string already exists (`currPrefix = ['<new>' currPrefix]`). That means
the filename reads **right-to-left in chronological order** — the prefix
closest to the original filename was added first, and the leftmost prefix
was added most recently. With the default step order
(`[4,3,1,5,7,8,10,11,12,6,9]`), the final filename looks like:

```
s8wFh01l08_Rhclqg_m0.4ar_sub-2230_ses-01_run-02_bold.nii
```

Reading left to right (most recent → oldest): smoothed (8mm) → normalized
→ band-pass filtered → nuisance-regressed → scrubbed (thr 0.4) →
realigned → slice-time corrected → original file.

## ⚠️ Execution order is NOT the case-number order

`analysis_steps` is a list of step numbers, and the pipeline runs them **in the
order you list them**, not in numeric order. The current default,

```matlab
analysis_steps = [4, 3, 1, 5, 7, 8, 10, 11, 12, 6, 9];
```

runs Realignment → Slice-timing → Segmentation → Coregister → Scrubbing →
CompCor → Trends/GS → Nuisance regression → **Band-pass filtering → THEN
Normalization → THEN Smoothing**.

Normalization and smoothing intentionally run last here. Don't "clean up"
this array into ascending order without checking with whoever is
supervising the analysis — it will change what the pipeline actually does.

## Notes 

- The step logic in `run_preprocessing.m` is preserved exactly as used in
  the original research; only the file layout, comments, and config
  location changed. If a step looks confusing, check the inline comment
  above that `case` block first — most known gotchas are documented there.
- Post-processing scripts (`C5_fast_ecm_new.m`, `C6_interSJ_var_new.m`) are
  separate, later-stage analyses and are not part of this preprocessing
  pipeline — they live one level up in the original repo.
