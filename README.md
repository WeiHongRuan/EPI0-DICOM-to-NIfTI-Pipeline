# EPI0 DICOM-to-NIfTI Preprocessing Pipeline

A modular MATLAB pipeline for preparing rodent EPI data before downstream fMRI preprocessing.

The pipeline is designed to automate a dataset-specific workflow in which selected DICOM EPI files are removed, the remaining DICOM data are converted to NIfTI format, spatial metadata are adjusted, the output is renamed to `EPI0.nii`, and the resulting file is organized into predefined destination folders.

This repository serves as a **data-preparation step before the main rodent fMRI preprocessing workflow**.

> **Important:** This pipeline can delete source DICOM files and move generated NIfTI files. Always test it on a copy of your data first and keep the original dataset unchanged.

---

## Overview

Before the main fMRI preprocessing workflow can be performed, the raw EPI data require several preparation steps.

This pipeline was developed to standardize these steps and reduce repetitive manual processing. It prepares the EPI data from the original DICOM format into an organized `EPI0.nii` file that can subsequently be used in a rodent fMRI preprocessing workflow.

The overall processing sequence is:

```text
Raw DICOM EPI data
        ↓
Dataset-specific DICOM cleanup
        ↓
DICOM-to-NIfTI conversion
        ↓
Spatial metadata adjustment
        ↓
Rename output as EPI0.nii
        ↓
Organize EPI0.nii into destination folders
        ↓
Downstream rodent fMRI preprocessing
        ↓
Functional imaging analysis
```

---

## Workflow

The main pipeline performs the following steps:

1. Identify eligible EPI source folders.
2. Remove indexed DICOM files in the configured range when the dataset meets the deletion criteria.
3. Convert the remaining DICOM EPI data to NIfTI.
4. Adjust the NIfTI spatial scale by the configured factor.
5. Rename the processed output to `EPI0.nii`.
6. Create destination folders and move each `EPI0.nii` file to its assigned location.
7. Save a processing report.

Completed steps are detected where possible, allowing the pipeline to resume after an interruption without repeating finished operations.

---

## fMRI Acquisition and EPI Data Structure

For the dataset used to develop this pipeline, each fMRI EPI acquisition contains:

- **9000 DICOM images in total**
- **15 slices per time point**
- **600 time points in total**

The number of acquired time points is therefore:

```text
9000 DICOM images ÷ 15 slices per time point
= 600 time points
```

Before the DICOM-to-NIfTI conversion step, the pipeline automatically removes the first **100 fMRI time points**.

Since each time point contains 15 slices:

```text
100 time points × 15 slices per time point
= 1500 DICOM images
```

Accordingly, the pipeline removes the following files from the beginning of the EPI DICOM series:

```text
MRIm1 – MRIm1500
```

This corresponds to removing:

```text
100 / 600 time points
```

from the beginning of the acquisition.

After the initial 100 time points are removed, the remaining dataset contains:

```text
600 - 100 = 500 time points
```

and:

```text
500 time points × 15 slices
= 7500 DICOM images
```

Therefore, the data passed to the subsequent DICOM-to-NIfTI conversion step consist of:

- **7500 remaining DICOM images**
- **15 slices per time point**
- **500 remaining fMRI time points**

The data flow is:

```text
Original EPI acquisition
9000 DICOM images
600 time points
15 slices / time point
        ↓
Remove first 100 time points
        ↓
Remove MRIm1 – MRIm1500
1500 DICOM images removed
        ↓
Remaining EPI data
7500 DICOM images
500 time points
        ↓
DICOM-to-NIfTI conversion
        ↓
Spatial metadata adjustment
        ↓
EPI0.nii
        ↓
Downstream rodent fMRI preprocessing
```

> **Dataset-specific note:** The values above are based on the acquisition protocol used for the dataset for which this pipeline was developed. If another dataset contains a different number of slices per time point, acquisition length, or number of initial time points to be removed, the deletion range in `+epi0/defaultConfig.m` must be adjusted accordingly.

---

## Repository Structure

```text
EPI0-DICOM-to-NIfTI-Pipeline/
├── run_EPI0_pipeline.m        # Main entry point
├── +epi0/                     # MATLAB package containing pipeline modules
│   ├── defaultConfig.m        # Central configuration
│   ├── runStep1Delete.m
│   ├── runSteps2To4Convert.m
│   ├── runStep5CreateDestinations.m
│   ├── runStep6MoveFiles.m
│   └── ...
├── docs/
│   └── README_zh-TW.md        # Chinese usage notes
├── .gitignore
└── README.md
```

The `+epi0` directory name must be kept unchanged because the leading `+` defines a MATLAB package.

---

## Requirements

### EPI0 Preparation Pipeline

The current pipeline was developed and tested using:

- **MATLAB R2025b**
- Image Processing Toolbox functions used by the pipeline, including DICOM and NIfTI I/O
- Parallel Computing Toolbox *(optional)*

If the Parallel Computing Toolbox is unavailable, the pipeline can fall back to serial processing.

### Downstream fMRI Preprocessing

The subsequent rodent fMRI preprocessing workflow may require additional neuroimaging software and dependencies.

Please refer to the downstream preprocessing repository for its complete software requirements and installation instructions:

**Rodent Whole-Brain fMRI Data Processing Toolbox**  
GT-Emory MIND Lab

https://github.com/GT-EmoryMINDlab/rodent-whole-brain-preprocessing-recipe

---

## Usage

### 1. Download or clone this repository

The repository can be downloaded directly from GitHub or cloned using:

```bash
git clone https://github.com/WeiHongRuan/EPI0-DICOM-to-NIfTI-Pipeline.git
```

---

### 2. Open MATLAB

Open MATLAB and set the current folder to the root directory of this repository.

---

### 3. Review the configuration

Before processing a new dataset, review:

```text
+epi0/defaultConfig.m
```

The configuration file controls several dataset-specific parameters, including:

- DICOM deletion range
- spatial scaling
- destination organization
- parallel processing settings

For the current dataset, the default deletion range removes:

```text
MRIm1 – MRIm1500
```

which corresponds to the first:

```text
100 fMRI time points
```

because each time point contains 15 slices.

---

### 4. Run the pipeline

Run:

```matlab
report = run_EPI0_pipeline;
```

The program will prompt the user to select the top-level folder containing the EPI datasets.

---

### 5. Confirm the processing settings

Review the confirmation dialog carefully before starting the pipeline.

Because the workflow includes file deletion and file movement, make sure that:

- the correct dataset has been selected;
- the original data have been backed up;
- the configured deletion range is correct;
- the number of slices per time point matches the expected acquisition protocol;
- the directory structure matches the expected organization.

---

### 6. Verify the output

After the pipeline finishes, inspect the generated:

```text
EPI0.nii
```

before proceeding to downstream preprocessing.

For the acquisition protocol described above, the resulting functional dataset should contain **500 remaining time points** after removal of the first 100 time points.

---

## Downstream fMRI Preprocessing

This repository is intended as a **data-preparation step before the main rodent fMRI preprocessing workflow**.

After the DICOM EPI data have been cleaned, converted to NIfTI format, spatial metadata have been adjusted, and the resulting dataset has been renamed and organized as `EPI0.nii`, the prepared data can be used for subsequent rodent whole-brain fMRI preprocessing.

The downstream preprocessing workflow used following this preparation stage is based on:

### Rodent Whole-Brain fMRI Data Processing Toolbox

**GT-Emory MIND Lab**

https://github.com/GT-EmoryMINDlab/rodent-whole-brain-preprocessing-recipe

The relationship between the two repositories is:

```text
Raw DICOM EPI data
9000 images / 600 time points
        ↓
EPI0-DICOM-to-NIfTI-Pipeline
(this repository)
        ↓
Remove first 100 time points
        ↓
7500 images / 500 time points
        ↓
DICOM-to-NIfTI conversion
        ↓
EPI0.nii
        ↓
Rodent Whole-Brain fMRI Data Processing Toolbox
(GT-Emory MIND Lab)
        ↓
Rodent fMRI preprocessing
        ↓
Functional connectivity / downstream analysis
```

The downstream toolbox uses `EPI0.nii` or `EPI0.nii.gz` as the 4-D forward EPI timeseries.

If topup distortion correction is used, additional forward and reverse EPI reference volumes are required. Users should follow the input requirements and preprocessing instructions provided in the downstream repository.

---

## Relationship to fMRI Training at The University of Queensland

The downstream fMRI preprocessing workflow was introduced as part of my laboratory academic visit and small-animal fMRI training at **The University of Queensland (UQ), Australia**.

During the training, I learned rodent fMRI acquisition and preprocessing procedures in a Linux-based neuroimaging environment, including workflows involving tools such as:

- FSL
- AFNI
- ANTs

The workflow and processing concepts learned during this training were subsequently transferred to our home laboratory and adapted to our own rodent fMRI datasets.

This MATLAB repository was developed to automate the **data-preparation stage preceding the downstream fMRI preprocessing workflow**, particularly the organization of raw EPI DICOM data, removal of the predefined initial time points, DICOM-to-NIfTI conversion, and preparation of the final `EPI0.nii` file.

> **Note:** The linked `rodent-whole-brain-preprocessing-recipe` repository is maintained by the **GT-Emory MIND Lab**. The reference to The University of Queensland describes the context in which I received training in the preprocessing workflow; it does not indicate that the linked repository is maintained by UQ.

---

## Configuration

Most user-adjustable parameters are stored in:

```text
+epi0/defaultConfig.m
```

Current defaults include:

| Parameter | Default | Purpose |
|---|---:|---|
| `LargeFolderThreshold` | `2000` | Minimum direct-file count used by the source-folder selection logic |
| `DeleteFirstIndex` | `1` | First DICOM image removed from the EPI series |
| `DeleteLastIndex` | `1500` | Last DICOM image removed; corresponds to the first 100 fMRI time points for the current dataset (100 time points × 15 slices) |
| `ScaleFactor` | `10` | Spatial scaling factor applied to NIfTI metadata |
| `MaximumDestinationFiles` | `5` | Maximum number of destination assignments |
| `UseParallel` | `true` | Enables parallel processing when available |
| `MaxParallelWorkers` | `4` | Maximum number of parallel workers |

The default destination suffixes are:

```matlab
{'0-1X', '0-2X', '4X', '5X', '6X'}
```

For the current acquisition:

```text
DeleteFirstIndex = 1
DeleteLastIndex  = 1500
```

means that the pipeline removes:

```text
1500 DICOM images
÷ 15 slices per time point
= 100 time points
```

leaving:

```text
500 time points
7500 DICOM images
```

for subsequent conversion and preprocessing.

Review these values before using the pipeline on a new dataset.

---

## Dataset-Specific Assumptions

This code was developed for a particular EPI dataset organization and acquisition protocol.

In particular:

- Each EPI acquisition contains **9000 DICOM images**.
- Each fMRI time point contains **15 slices**.
- Each acquisition therefore contains **600 time points**.
- The first **100 time points** are removed before DICOM-to-NIfTI conversion.
- Removing 100 time points corresponds to deleting the first **1500 DICOM images**.
- The remaining dataset contains **500 time points / 7500 DICOM images**.
- DICOM source files are expected to use names beginning with `MRIm` followed by an index.

Source folders are detected using a dataset-specific naming convention implemented in:

```text
+epi0/discoverSourceFolders.m
```

Destination assignment rules are implemented in:

```text
+epi0/buildDestinationAssignments.m
```

The DICOM deletion range is defined in:

```text
+epi0/defaultConfig.m
```

For the current dataset, this range is:

```text
MRIm1 – MRIm1500
```

which corresponds specifically to the first 100 fMRI time points:

```text
100 time points × 15 slices = 1500 images
```

Spatial scaling is performed according to the configured metadata adjustment rules.

If your dataset uses a different:

- number of slices per time point;
- number of acquired time points;
- DICOM naming convention;
- directory structure;
- acquisition protocol;
- number of initial time points to remove;
- downstream preprocessing requirement;

the relevant configuration and modules must be reviewed and modified before running the pipeline.

The current default parameters should therefore **not be assumed to generalize automatically to other datasets**.

---

## Data Safety

This pipeline performs operations that may permanently modify the working dataset.

In particular, it can:

- delete selected DICOM files;
- generate new NIfTI files;
- rename processed files;
- move generated `EPI0.nii` files into destination directories.

### Before each run

It is strongly recommended to:

1. Keep an untouched backup of the original DICOM dataset.
2. Work on a separate copy of the original data.
3. Verify the deletion index range in `defaultConfig.m`.
4. Confirm the number of slices per fMRI time point.
5. Confirm that deleting 1500 images corresponds to the intended number of initial time points.
6. Confirm that the folder-naming rules match the dataset.
7. Test the pipeline on a small copied dataset first.
8. Inspect the generated `EPI0.nii` before downstream preprocessing.
9. Verify the destination folders before moving the processed files.

Do **not** use the only available copy of the experimental dataset as the working directory.

---

## GitHub Data Protection

The repository intentionally ignores common medical-imaging and generated-data formats so that raw or processed research data are not accidentally uploaded to GitHub.

The `.gitignore` file is configured to help exclude data such as:

```text
*.dcm
*.nii
*.nii.gz
```

as well as temporary and generated files.

No DICOM or NIfTI research data are included in this repository.

Research datasets, animal identifiers, raw MRI data, and other potentially sensitive experimental information should remain outside version control unless they have been appropriately prepared for public release.

---

## Main Modules

### `run_EPI0_pipeline.m`

Main entry point of the pipeline.

Coordinates the complete EPI preparation workflow and generates the final processing report.

---

### `runStep1Delete.m`

Handles the dataset-specific removal of configured indexed DICOM files.

For the current dataset, this step removes:

```text
MRIm1 – MRIm1500
```

corresponding to the first:

```text
100 fMRI time points
```

This step should be reviewed carefully before applying the pipeline to a new dataset.

---

### `runSteps2To4Convert.m`

Coordinates:

- DICOM-to-NIfTI conversion;
- spatial metadata adjustment;
- preparation of the final `EPI0.nii`.

After the first 100 time points have been removed, the remaining 7500 DICOM images are passed to this stage.

---

### `convertDicomFolder.m`

Internal DICOM-to-NIfTI conversion implementation.

Processes the remaining EPI DICOM data and generates the corresponding NIfTI dataset.

For the current acquisition protocol, the converted functional series represents:

```text
500 remaining time points
```

after removal of the initial 100 time points.

---

### `scaleNiftiSpaceByFactor.m`

Adjusts the spatial metadata of the generated NIfTI data according to the configured scale factor.

---

### `runStep5CreateDestinations.m`

Creates the destination folders required for the processed EPI datasets.

---

### `runStep6MoveFiles.m`

Moves the generated `EPI0.nii` files into their assigned destination folders.

---

### `saveReport.m`

Writes the processing report after pipeline execution.

---

## Recommended Processing Sequence

A typical workflow is:

```text
1. Preserve the original raw EPI DICOM data
        ↓
2. Create a separate working copy
        ↓
3. Confirm:
   9000 images
   15 slices / time point
   600 time points
        ↓
4. Review defaultConfig.m
        ↓
5. Run this MATLAB EPI preparation pipeline
        ↓
6. Remove first 100 time points
   = first 1500 DICOM images
        ↓
7. Retain 500 time points
   = 7500 DICOM images
        ↓
8. Convert remaining DICOM data to NIfTI
        ↓
9. Inspect the generated EPI0.nii
        ↓
10. Verify the destination folder organization
        ↓
11. Run the downstream rodent fMRI preprocessing workflow
        ↓
12. Inspect preprocessing quality
        ↓
13. Proceed with functional imaging analysis
```

The original DICOM dataset should remain unchanged throughout this process.

---

## Example Processing Concept

The role of this repository within the larger fMRI analysis workflow can be summarized as:

```text
MRI acquisition
        ↓
Raw EPI DICOM data
9000 images
600 time points
        ↓
Remove initial 100 time points
        ↓
7500 images
500 time points
        ↓
DICOM-to-NIfTI conversion
        ↓
EPI0.nii
        ↓
Preprocessing with neuroimaging tools
        ↓
Preprocessed functional data
        ↓
ROI / functional connectivity / other analyses
```

This repository primarily handles the stages from:

```text
Raw EPI DICOM data
        ↓
Initial-volume removal
        ↓
DICOM-to-NIfTI conversion
        ↓
EPI0.nii
```

while the linked downstream toolbox handles the subsequent neuroimaging preprocessing stages.

---

## Related Resources

### Downstream Rodent fMRI Preprocessing

**Rodent Whole-Brain fMRI Data Processing Toolbox**

GT-Emory MIND Lab

https://github.com/GT-EmoryMINDlab/rodent-whole-brain-preprocessing-recipe

This repository provides the subsequent rodent fMRI preprocessing workflow after the EPI data have been prepared as `EPI0.nii`.

---

## Notes

This repository contains **code only**.

No raw or processed experimental MRI data are included.

The workflow was developed around a specific rodent MRI dataset organization, acquisition protocol, and preprocessing procedure.

For the current dataset:

```text
Original acquisition:
600 time points
9000 DICOM images

Initial data removed:
100 time points
1500 DICOM images

Data retained:
500 time points
7500 DICOM images
```

Researchers using different acquisition protocols or directory structures should carefully review the configuration and relevant modules before applying the pipeline.

All generated results should be visually and quantitatively inspected before proceeding with downstream analysis.

---

## Author

**Wei-Hong Ruan**

Biomedical Engineer / Neuroscience Researcher

Research interests include:

- Functional neuroimaging
- Resting-state fMRI
- Functional connectivity analysis
- EEG and neural signal processing
- Real-time brain-state detection
- Closed-loop neuromodulation
- Focused ultrasound neuromodulation
- Multimodal neuroscience

GitHub:

https://github.com/WeiHongRuan

---

## Acknowledgment

The downstream rodent fMRI preprocessing workflow referenced in this repository is based on the:

**Rodent Whole-Brain fMRI Data Processing Toolbox**  
developed and maintained by the **GT-Emory MIND Lab**.

The author also received small-animal fMRI acquisition and preprocessing training during a laboratory academic visit to **The University of Queensland (UQ), Australia**, where related neuroimaging workflows and processing tools were introduced.

---

## License

No open-source license has been assigned yet.

Add a license only after confirming how others should be permitted to use, modify, distribute, or build upon this code.
