#!/usr/bin/env bash

## Author: Han Wang
### 08 Jan 2025: Added support for GRIN2A project.
### 28 Nov 2024: Initial version

### This converts dicom files to nifti and mif formats for further processing. Ensure that the Directories defined below actually exist.


# Common variables:

## Project: "kdvproj" or "grin2aproj"
### The directory structure for KdV and GRIN2A projects are different, GRIN2A has seperate anat and dwi folders under the raw folder.

Proj="grin2aproj" # unused for now

## Participants:

Subjs=("118" "119" "120" "121" "122" "123" "130" "131" "132" "133")
mapfile -t Subjs < <(for Subj in "${Subjs[@]}"; do echo "sub-$Subj"; done) # substute the subject IDs with subj-SUBJ_ID

## Directories:

if [ $Proj == "kdvproj" ]; then
    Dir_Common="/home/hanwang/Documents/gos_ich/cre_project/Data/data_proc/kdvproj"
else
    Dir_Common="/home/hanwang/Documents/gos_ich/cre_project/Data/data_proc/grin2aproj"
fi

Dir_Raw="$Dir_Common/raw"
Dir_PreProc="$Dir_Common/pre_processing"


# Conversion:

for Subj in "${Subjs[@]}"; do

    echo "Converting T1 dicom to nifti and mif for $Subj"

    if [ $Proj == "kdvproj" ]; then
        T1_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj" -type d -name "*t1*" -exec basename {} \; | head -n 1)
        Dir_Subj_Tmp_T1_Raw="$Dir_Raw/$Subj/$T1_Dir_Name_Tmp"
    else
        T1_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj/anat" -type d -name "*t1*" -exec basename {} \; | head -n 1)
        Dir_Subj_Tmp_T1_Raw="$Dir_Raw/$Subj/anat/$T1_Dir_Name_Tmp"
    fi
    
    Dir_Subj_Tmp_T1_Proc="$Dir_PreProc/$Subj/anat"

    if [ ! -d "$Dir_Subj_Tmp_T1_Proc" ]; then
        mkdir -p "$Dir_Subj_Tmp_T1_Proc"
        echo "Folder created: $Dir_Subj_Tmp_T1_Proc"
    fi

    mrconvert $Dir_Subj_Tmp_T1_Raw "$Dir_Subj_Tmp_T1_Proc/$(echo $Subj)_T1w.nii"
    mrconvert $Dir_Subj_Tmp_T1_Raw "$Dir_Subj_Tmp_T1_Proc/$(echo $Subj)_T1w.mif"

    echo -e "\n\n"
done
