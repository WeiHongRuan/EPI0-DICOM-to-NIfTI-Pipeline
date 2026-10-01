# EPI0 DICOM-to-NIfTI Preprocessing Pipeline

A modular MATLAB pipeline for preparing EPI data before downstream preprocessing.

The pipeline is designed to automate a dataset-specific workflow in which selected DICOM EPI files are removed, the remaining DICOM data are converted to NIfTI format, spatial metadata are adjusted, the output is renamed to `EPI0.nii`, and the resulting file is organized into predefined destination folders.

> **Important:** This pipeline can delete source DICOM files and move generated NIfTI files. Always test it on a copy of your data first.

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

## Repository structure

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

## Requirements

- MATLAB
- Image Processing Toolbox functions used by the pipeline, including DICOM and NIfTI I/O
- Parallel Computing Toolbox is optional

If the Parallel Computing Toolbox is unavailable, the pipeline can fall back to serial processing.

## Usage

1. Download or clone this repository.
2. Open MATLAB.
3. Set the current folder to the repository root.
4. Run:

```matlab
report = run_EPI0_pipeline;
```

5. Select the top-level folder containing the EPI datasets.
6. Review the confirmation dialog carefully before starting the pipeline.

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

## Dataset-specific assumptions

This code was developed for a particular EPI dataset organization. In particular:

- DICOM source files are expected to use names beginning with `MRIm` followed by an index.
- Source folders are detected using a dataset-specific naming convention implemented in `+epi0/discoverSourceFolders.m`.
- Destination assignment rules are implemented in `+epi0/buildDestinationAssignments.m`.

If your dataset uses a different naming convention, modify these modules before running the pipeline.

## Data safety

The repository intentionally ignores common medical-imaging and generated-data formats so that raw or processed research data are not accidentally committed to GitHub.

Before each run:

- Keep an untouched backup of the original DICOM dataset.
- Verify the deletion index range in `defaultConfig.m`.
- Test the pipeline on a small copied dataset first.
- Confirm that the folder-naming rules match your data.

No DICOM or NIfTI data are included in this repository.

## Main modules

- `run_EPI0_pipeline.m` — coordinates the complete workflow.
- `runStep1Delete.m` — checks and removes configured indexed DICOM files.
- `runSteps2To4Convert.m` — performs DICOM conversion, scaling, and EPI0 preparation.
- `convertDicomFolder.m` — internal DICOM-to-NIfTI conversion implementation.
- `scaleNiftiSpaceByFactor.m` — adjusts NIfTI spatial metadata.
- `runStep5CreateDestinations.m` — creates output directories.
- `runStep6MoveFiles.m` — moves processed `EPI0.nii` files to assigned destinations.
- `saveReport.m` — writes the processing report.

## Notes

This repository contains code only. Research datasets, participant/animal identifiers, DICOM files, NIfTI files, and generated reports should remain outside version control unless they have been properly de-identified and are explicitly intended for public release.

## License

No open-source license has been assigned yet. Add a license only after confirming how you want others to be permitted to use, modify, and redistribute the code.
