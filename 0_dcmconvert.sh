#!/usr/bin/env bash

## Author: Han Wang
### 04 Jun 2025: Added support for various file naming rules for the raw DWI files.
### 18 Feb 2025: Added DCM conversion for DWI data.
### 08 Jan 2025: Added support for GRIN2A project.
### 28 Nov 2024: Initial version

### This converts dicom files to nifti and mif formats for further processing. Ensure that the Directories defined below actually exist.


# Common variables:

## Config:

Anat2Nifti="1"
DWI2Nifti="1"


## Project: "kdvproj" or "grin2aproj"
### The directory structure for KdV and GRIN2A projects are different, GRIN2A has seperate anat and dwi folders under the raw folder.

Proj="grin2aproj" # unused for now
DWIFileNameVar="1" # Naming structure for the raw DWI A-P, P-A, and data folders. Variant 1 works for most files for the GRIN2A project. Variant 2 works for g-008 and g-010.

## Participants:

### KdV project list: Subjs=("113" "115" "116" "117" "126" "127" "128" "k304" "k308" "k309" "k345" "k347" "k373" "k374")
Subjs=("0437" "0903" "0922" "1050" "1098" "1117" "1266" "1527" "1572" "1690" "1726") # Put your subject ID here, and ensure the folders are in the format of "sub-ID", such as "sub-113"
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

    echo "Converting dicoms to nifti for $Subj"

    if [ $Proj == "kdvproj" ]; then
        T1_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj" -type d -name "*t1*" -exec basename {} \; | head -n 1)
        
        Dir_Subj_Tmp_T1_Raw="$Dir_Raw/$Subj/$T1_Dir_Name_Tmp"
                
        DWI_AP_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj" -type d -name "*A-P*" -exec basename {} \; | head -n 1) # Find the AP dicom folder
        DWI_PA_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj" -type d -name "*P-A*" -exec basename {} \; | head -n 1) # Find the PA dicom folder
        DWI_DAT_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj" -type d -name "*ep2d_diff*" -exec basename {} \; | head -n 1) # Find the DWI data dicom folder

        Dir_Subj_Tmp_DWI_AP_Raw="$Dir_Raw/$Subj/$DWI_AP_Dir_Name_Tmp"
        Dir_Subj_Tmp_DWI_PA_Raw="$Dir_Raw/$Subj/$DWI_PA_Dir_Name_Tmp"
        Dir_Subj_Tmp_DWI_DAT_Raw="$Dir_Raw/$Subj/$DWI_DAT_Dir_Name_Tmp"



    else
        T1_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj/anat" -type d -name "*t1*" -exec basename {} \; | head -n 1)
        
        Dir_Subj_Tmp_T1_Raw="$Dir_Raw/$Subj/anat/$T1_Dir_Name_Tmp"

        if [ $DWIFileNameVar == "1" ]; then

            DWI_AP_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj/DWI" -type d -name "*A-P*" -exec basename {} \; | head -n 1) # Find the AP dicom folder
            DWI_PA_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj/DWI" -type d -name "*P-A*" -exec basename {} \; | head -n 1) # Find the PA dicom folder
            DWI_DAT_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj/DWI" -type d -name "*MDDW_64_directions_ep2d_diff_p2" -exec basename {} \; | head -n 1) # Find the DWI data dicom folder

        else
        
            DWI_AP_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj/DWI" -type d -name "*AP*" -exec basename {} \; | head -n 1) # Find the AP dicom folder
            DWI_PA_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj/DWI" -type d -name "*PA_DIST_change_180_14" -exec basename {} \; | head -n 1) # Find the PA dicom folder
            DWI_DAT_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj/DWI" -type d -name "*ep2d_diff_mbc_p2*" -exec basename {} \; | head -n 1) # Find the DWI data dicom folder

        fi

        Dir_Subj_Tmp_DWI_AP_Raw="$Dir_Raw/$Subj/DWI/$DWI_AP_Dir_Name_Tmp"
        Dir_Subj_Tmp_DWI_PA_Raw="$Dir_Raw/$Subj/DWI/$DWI_PA_Dir_Name_Tmp"
        Dir_Subj_Tmp_DWI_DAT_Raw="$Dir_Raw/$Subj/DWI/$DWI_DAT_Dir_Name_Tmp"

    fi
    
    Dir_Subj_Tmp_T1_Proc="$Dir_PreProc/$Subj/anat"
    Dir_Subj_Tmp_DWI="$Dir_PreProc/$Subj/dwi"

    echo -e "\n"


    if [ $Anat2Nifti == "1" ]; then
        
        echo "Conversion from T1 dicom to nifti and mif started for $Subj"
        echo -e "\n"

        if [ ! -d "$Dir_Subj_Tmp_T1_Proc" ]; then
            mkdir -p "$Dir_Subj_Tmp_T1_Proc"
            echo "Folder created: $Dir_Subj_Tmp_T1_Proc"
        fi


        if find $Dir_Subj_Tmp_T1_Raw -type f -name "*.dcm" | grep -q .; then        
            mrconvert $Dir_Subj_Tmp_T1_Raw "$Dir_Subj_Tmp_T1_Proc/$(echo $Subj)_T1w.nii"
            mrconvert $Dir_Subj_Tmp_T1_Raw "$Dir_Subj_Tmp_T1_Proc/$(echo $Subj)_T1w.mif"
        else
            mrconvert "$(find $Dir_Subj_Tmp_T1_Raw/nifti_series -type f -name "*.nii" | head -n 1)" "$Dir_Subj_Tmp_T1_Proc/$(echo $Subj)_T1w.nii"
            mrconvert "$(find $Dir_Subj_Tmp_T1_Raw/nifti_series -type f -name "*.nii" | head -n 1)" "$Dir_Subj_Tmp_T1_Proc/$(echo $Subj)_T1w.mif"
        fi
    echo -e "\n"
    fi

    if [ $DWI2Nifti == "1" ]; then

        echo "Conversion from DWI dicom to nifti and mif started for $Subj"
        echo -e "\n"

        if [ ! -d "$Dir_Subj_Tmp_DWI" ]; then
            mkdir -p "$Dir_Subj_Tmp_DWI"
            echo "Folder created: $Dir_Subj_Tmp_DWI"
        fi


        if find $Dir_Subj_Tmp_DWI_DAT_Raw -type f -name "*.dcm" | grep -q .; then
            mrconvert $Dir_Subj_Tmp_DWI_AP_Raw "$Dir_Subj_Tmp_DWI/$(echo $Subj)_b0.nii.gz" -stride 1,2,3 # convert the AP file to nii.gz
            mrconvert $Dir_Subj_Tmp_DWI_PA_Raw "$Dir_Subj_Tmp_DWI/$(echo $Subj)_b0_flip.nii.gz" -stride 1,2,3 # convert the PA file to nii.gz
            mrconvert $Dir_Subj_Tmp_DWI_DAT_Raw "$Dir_Subj_Tmp_DWI/$(echo $Subj)_dwi.mif" # convert the DWI data file to mif
        else
            mrconvert "$(find $Dir_Subj_Tmp_DWI_AP_Raw/nifti_series -type f -name "*.nii" | head -n 1)" "$Dir_Subj_Tmp_DWI/$(echo $Subj)_b0.nii.gz" -stride 1,2,3 # convert the AP file to nii.gz
            mrconvert "$(find $Dir_Subj_Tmp_DWI_PA_Raw/nifti_series -type f -name "*.nii" | head -n 1)" "$Dir_Subj_Tmp_DWI/$(echo $Subj)_b0_flip.nii.gz" -stride 1,2,3 # convert the PA file to nii.gz
            mrconvert "$(find $Dir_Subj_Tmp_DWI_DAT_Raw/nifti_series -type f -name "*.nii" | head -n 1)" "$Dir_Subj_Tmp_DWI/$(echo $Subj)_dwi.mif" -fslgrad "$(find $Dir_Subj_Tmp_DWI_DAT_Raw/nifti_series -type f -name "*.bvec" | head -n 1)" "$(find $Dir_Subj_Tmp_DWI_DAT_Raw/nifti_series -type f -name "*.bval" | head -n 1)" # convert the DWI data file to mif
        fi



        echo "Conversion from DWI dicom to nifti and mif FINISHED for $Subj"
        echo -e "\n\n"
    fi

done
