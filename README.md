# EPI0 DICOM-to-NIfTI Preparation Pipeline

A modular MATLAB pipeline for preparing rodent EPI data before downstream fMRI preprocessing.

This workflow was developed to organize and standardize EPI data before applying the main rodent fMRI preprocessing pipeline. It performs dataset-specific DICOM cleanup, converts the remaining EPI DICOM images into NIfTI format, prepares the output as `EPI0.nii`, and organizes the resulting file for subsequent preprocessing.

---

## Overview

Before running the main fMRI preprocessing workflow, the raw EPI data require several preparation steps.

The general workflow implemented in this repository is:

```text
Raw DICOM EPI data
        ↓
Remove dataset-specific DICOM images
        ↓
DICOM-to-NIfTI conversion
        ↓
Prepare / adjust NIfTI metadata
        ↓
Rename output as EPI0.nii
        ↓
Organize EPI0.nii into the required directory
        ↓
Downstream rodent fMRI preprocessing
