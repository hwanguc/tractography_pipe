#!/usr/bin/env bash

### This script performs batch processing of the DWI files and allow for the following options:

#### Gibb's ring removal: 0 (off) or 1 (on)
#### Inhomogeneities (bias) correction: 0 (off) or 1 (on)
#### FOD normalisation (for fixel-based analysis): 0 (off) or 1 (on)
#### Package for image co-registration (dwi and anat): fsl (uing flirt) or nifreg (using niftyreg-KCL version)

### The output mif files ("sub-xxx_5tt_coreg.mif", etc) are ready for subsequent tractography based on user-defined ROI files.


# Common variables (these might move to a higher-level general script which calls specific functions at a later stage):

## Config:

GibbsRm="0"
BiasCorr="0"
FodNorm="0"
ImgCoreg="flirt"


## Project ID:

Proj="kdv" # unused for now


## Participants:

Subjs=("115" "116" "117")
mapfile -t Subjs < <(for Subj in "${Subjs[@]}"; do echo "sub-$Subj"; done) # substute the subject IDs with subj-SUBJ_ID

## Directories:

Dir_Common="/home/hanwang/Documents/gos_ich/cre_project/Data/data_proc/kdvproj"
Dir_Raw="$Dir_Common/raw"
Dir_PreProc="$Dir_Common/pre_processing"

# Preprocessing - Conversion:


for Subj in "${Subjs[@]}"; do

    ## Define the folders we're working on/in

    DWI_AP_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj" -type d -name "*A-P*" -exec basename {} \; | head -n 1) # Find the AP dicom folder
    DWI_PA_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj" -type d -name "*P-A*" -exec basename {} \; | head -n 1) # Find the PA dicom folder
    DWI_DAT_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj" -type d -name "*005*" -exec basename {} \; | head -n 1) # Find the DWI data dicom folder


    Dir_Subj_Tmp_DWI_AP_Raw="$Dir_Raw/$Subj/$DWI_AP_Dir_Name_Tmp"
    Dir_Subj_Tmp_DWI_PA_Raw="$Dir_Raw/$Subj/$DWI_PA_Dir_Name_Tmp"
    Dir_Subj_Tmp_DWI_DAT_Raw="$Dir_Raw/$Subj/$DWI_DAT_Dir_Name_Tmp"
    
    
    Dir_Subj_Tmp_DWI="$Dir_PreProc/$Subj/dwi"

    if [ ! -d "$Dir_Subj_Tmp_DWI" ]; then
        mkdir -p "$Dir_Subj_Tmp_DWI"
        echo "Folder created: $Dir_Subj_Tmp_DWI"
    fi


    ## Change the working directory to the current subject's DWI folder

    echo "Changing the working directory to the DWI folder of $Subj"
    
    cd "$Dir_Subj_Tmp_DWI" || exit
    echo -e "\n\n"

    ## Conversion from DWI dicom to Nifti and MIF for the current subject

    echo "Conversion from DWI dicom to nifti and mif started for $Subj"
    echo -e "\n"

    mrconvert $Dir_Subj_Tmp_DWI_AP_Raw "$(echo $Subj)_b0.nii.gz" -stride 1,2,3 # convert the AP file to nii.gz
    mrconvert $Dir_Subj_Tmp_DWI_PA_Raw "$(echo $Subj)_b0_flip.nii.gz" -stride 1,2,3 # convert the PA file to nii.gz
    mrconvert $Dir_Subj_Tmp_DWI_DAT_Raw "$(echo $Subj)_dwi.mif" # convert the DWI data file to mif

    echo "Conversion from DWI dicom to nifti and mif FINISHED for $Subj"
    echo -e "\n\n"








done




## Diffusion image:

### Convert dicom dwis to nifti ones:

#### AP direction
mrconvert /home/hanwang/Apps/working_directory/bash_python_proj/kdvproj/data/raw/sub-113/003_-_PRE_DWI_A-P_DIST_CORR_64_MDDW /home/hanwang/Apps/working_directory/bash_python_proj/kdvproj/data/pre_processing/sub-113/dwi/sub-113_b0.nii.gz -stride 1,2,3
#### PA direction
mrconvert /home/hanwang/Apps/working_directory/bash_python_proj/kdvproj/data/raw/sub-113/004_-_PRE_DWI_P-A_DIST_Change_180 /home/hanwang/Apps/working_directory/bash_python_proj/kdvproj/data/pre_processing/sub-113/dwi/sub-113_b0_flip.nii.gz -stride 1,2,3
#### dwi data
mrconvert /home/hanwang/Apps/working_directory/bash_python_proj/kdvproj/data/raw/sub-113/005_-_FREE_DWI_71_directions_ep2d_diff_mbc_p2 /home/hanwang/Apps/working_directory/bash_python_proj/kdvproj/data/pre_processing/sub-113/dwi/sub-113_dwi.mif

#### merge AP and PA b0s (in the pre-processing/subj folder)
fslmerge -t sub-113_b0_pair.nii.gz sub-113_b0.nii.gz sub-113_b0_flip.nii.gz
mrconvert sub-113_b0_pair.nii.gz sub-113_b0_pair.mif

