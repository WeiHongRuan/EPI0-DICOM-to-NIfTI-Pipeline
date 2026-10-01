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

The current pipeline requires:

- MATLAB R2025b
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

The configuration file controls several dataset-specific parameters, including the DICOM deletion range, spatial scaling, destination organization, and parallel processing settings.

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
- the directory structure matches the expected organization.

---

### 6. Verify the output

After the pipeline finishes, inspect the generated:

```text
EPI0.nii
```

before proceeding to downstream preprocessing.

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
        ↓
EPI0-DICOM-to-NIfTI-Pipeline
(this repository)
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

## Configuration

Most user-adjustable parameters are stored in:

```text
+epi0/defaultConfig.m
```

Current defaults include:

| Parameter | Default | Purpose |
|---|---:|---|
| `LargeFolderThreshold` | `2000` | Minimum direct-file count used by the source-folder selection logic |
| `DeleteFirstIndex` | `1` | First indexed DICOM file considered for deletion |
| `DeleteLastIndex` | `1500` | Last indexed DICOM file considered for deletion |
| `ScaleFactor` | `10` | Spatial scaling factor applied to NIfTI metadata |
| `MaximumDestinationFiles` | `5` | Maximum number of destination assignments |
| `UseParallel` | `true` | Enables parallel processing when available |
| `MaxParallelWorkers` | `4` | Maximum number of parallel workers |

The default destination suffixes are:

```matlab
{'0-1X', '0-2X', '4X', '5X', '6X'}
```

Review these values before using the pipeline on a new dataset.

---

## Dataset-Specific Assumptions

This code was developed for a particular EPI dataset organization.

In particular:

- DICOM source files are expected to use names beginning with `MRIm` followed by an index.
- Source folders are detected using a dataset-specific naming convention implemented in:

```text
+epi0/discoverSourceFolders.m
```

- Destination assignment rules are implemented in:

```text
+epi0/buildDestinationAssignments.m
```

- The DICOM deletion range is defined in:

```text
+epi0/defaultConfig.m
```

- Spatial scaling is performed according to the configured metadata adjustment rules.

If your dataset uses a different naming convention, directory structure, acquisition protocol, or preprocessing requirement, these modules should be reviewed and modified before running the pipeline.

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
4. Confirm that the folder-naming rules match the dataset.
5. Test the pipeline on a small copied dataset first.
6. Inspect the generated `EPI0.nii` before downstream preprocessing.
7. Verify the destination folders before moving the processed files.

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

This step should be reviewed carefully before applying the pipeline to a new dataset.

---

### `runSteps2To4Convert.m`

Coordinates:

- DICOM-to-NIfTI conversion;
- spatial metadata adjustment;
- preparation of the final `EPI0.nii`.

---

### `convertDicomFolder.m`

Internal DICOM-to-NIfTI conversion implementation.

Processes the remaining EPI DICOM data and generates the corresponding NIfTI dataset.

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
3. Review defaultConfig.m
        ↓
4. Run this MATLAB EPI preparation pipeline
        ↓
5. Inspect the generated EPI0.nii
        ↓
6. Verify the destination folder organization
        ↓
7. Run the downstream rodent fMRI preprocessing workflow
        ↓
8. Inspect preprocessing quality
        ↓
9. Proceed with functional imaging analysis
```

The original DICOM dataset should remain unchanged throughout this process.

---

## Example Processing Concept

The role of this repository within the larger fMRI analysis workflow can be summarized as:

```text
MRI acquisition
        ↓
Raw EPI DICOM data
        ↓
DICOM data preparation
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

The workflow was developed around a specific rodent MRI dataset organization and preprocessing procedure. Researchers using different acquisition protocols or directory structures should carefully review the configuration and relevant modules before applying the pipeline.

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
