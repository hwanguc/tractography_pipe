#!/usr/bin/env bash

### This script performs batch processing of the DWI files and allow for the following options:

#### Gibb's ring removal: 0 (off) or 1 (on)
#### Inhomogeneities (bias) correction: 0 (off) or 1 (on)
#### FOD normalisation (for fixel-based analysis): 0 (off) or 1 (on)
#### Package for image co-registration (dwi and anat): fsl (uing flirt) or nifreg (using )

### The output mif files ("sub-xxx_5tt_coreg.mif", etc) are ready for subsequent tractography based on user-defined ROI files.

