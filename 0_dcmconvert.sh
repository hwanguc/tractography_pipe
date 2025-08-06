#!/usr/bin/env bash

## Author: Han Wang
### 06 Aug 2025: Added support for GOSH fullterm controls (multi-shell)
### 25 July 2025: Added support for GOSH preterm participants (multi-shell).
### 22 July 2025: Added support for FOXP2 project.
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

Proj="pretermproj" # unused for now
GOSHPorjVariant="2" # Variant 1 works for the GOSH preterm multi-shell patients, Variant 2 works for GOSH multi-shell controls.
DWIFileNameVar="1" # Naming structure for the raw DWI A-P, P-A, and data folders. Variant 1 works for most files for the GRIN2A project. Variant 2 works for g-008 and g-010.

## Participants:

### KdV project list: Subjs=("113" "115" "116" "117" "126" "127" "128" "k304" "k308" "k309" "k345" "k347" "k373" "k374")
### Subjs=("12225111" "12225211" "12225311" "MEL.04_1" "MEL.04_2" "MEL.04_3") # Put your subject ID here, and ensure the folders are in the format of "sub-ID", such as "sub-113"
Subjs=("27" "28" "29" "30" "31" "32" "34" "35" "37" "38") # GOSH preterm multi-shell patient
mapfile -t Subjs < <(for Subj in "${Subjs[@]}"; do echo "sub-$Subj"; done) # substute the subject IDs with subj-SUBJ_ID

## Directories:

if [ $Proj == "kdvproj" ]; then
    Dir_Common="/home/hanwang/Documents/gos_ich/cre_project/Data/data_proc/kdvproj"
elif [ $Proj == "foxp2proj" ]; then
    Dir_Common="/home/hanwang/Documents/gos_ich/cre_project/Data/data_proc/foxp2proj"
elif [ $Proj == "grin2aproj" ]; then
    Dir_Common="/home/hanwang/Documents/gos_ich/cre_project/Data/data_proc/grin2aproj"
else
    Dir_Common="/home/hanwang/Documents/gos_ich/cre_project/Data/data_proc/pretermproj"
fi

Dir_Raw="$Dir_Common/raw"
Dir_PreProc="$Dir_Common/pre_processing"


# Conversion:

for Subj in "${Subjs[@]}"; do

    ### Define the directories for the current subject:

    if [ $Proj == "kdvproj" ] || [ $Proj == "grin2aproj" ] || [ $Proj == "foxp2proj" ]; then

        echo "Converting dicoms to nifti for $Subj"

        if [ $Proj == "kdvproj" ] || [ $Proj == "foxp2proj" ]; then
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

    else # for now this is only for the preterm project

        if [ $GOSHPorjVariant == "1" ]; then # for GOSH preterm multi-shell patients, all measures are in a single nii of mif file.

            Dir_Subj_Tmp_T1_Raw=$(find "$Dir_Raw/$Subj" -type f -name "*t1_mprage*.nii.gz" ! -name "*defaced*" | head -n 1)

            Dir_Subj_Tmp_DWI_AP_Raw=$(find "$Dir_Raw/$Subj" -type f -name "*ADC*.mif" | head -n 1)
            Dir_Subj_Tmp_DWI_PA_Raw=$(find "$Dir_Raw/$Subj" -type f -name "*NEGPE*.mif" | head -n 1)
            Dir_Subj_Tmp_DWI_DAT_Raw=$(find "$Dir_Raw/$Subj" -type f -name "*MULTISHELL_20CH*.mif" ! -name "*ADC*" ! -name "*NEGPE*" | head -n 1)
            
        else # for GOSH fullterm controls, there's distinction for defaced T1.
            Dir_Subj_Tmp_T1_Raw=$(find "$Dir_Raw/$Subj" -type f -name "*T1_MPRAGE*.nii.gz" | head -n 1)

            Dir_Subj_Tmp_DWI_PA_Raw=$(find "$Dir_Raw/$Subj" -type f -name "*NEGPE*.nii.gz" | head -n 1)
            Dir_Subj_Tmp_DWI_DAT_Raw=$(find "$Dir_Raw/$Subj" -type f -name "*MULTISHELL*.nii.gz" ! -name "*SBREF*" | head -n 1)

            #### the AP file is not always available, so we need to create from DWI file.

            echo "Creating AP file from DWI data for $Subj as the AP file is not available..."

            fslroi $Dir_Subj_Tmp_DWI_DAT_Raw "$Dir_Raw/$Subj/$(echo $Subj)_b0.nii.gz" 0 1
            Dir_Subj_Tmp_DWI_AP_Raw="$Dir_Raw/$Subj/$(echo $Subj)_b0.nii.gz"
                    
        fi
            
    fi
    
    Dir_Subj_Tmp_T1_Proc="$Dir_PreProc/$Subj/anat"
    Dir_Subj_Tmp_DWI="$Dir_PreProc/$Subj/dwi"

    echo -e "\n"


    if [ $Anat2Nifti == "1" ]; then

        if [ ! -d "$Dir_Subj_Tmp_T1_Proc" ]; then
            mkdir -p "$Dir_Subj_Tmp_T1_Proc"
            echo "Folder created: $Dir_Subj_Tmp_T1_Proc"
        fi


        echo "Conversion from T1 dicom to nifti and mif started for $Subj"
        echo -e "\n"

        if find "$Dir_Subj_Tmp_T1_Raw" -type f -name "*.dcm" | grep -q . || [ "$Proj" == "pretermproj" ]; then        
            mrconvert $Dir_Subj_Tmp_T1_Raw "$Dir_Subj_Tmp_T1_Proc/$(echo $Subj)_T1w.nii"
            mrconvert $Dir_Subj_Tmp_T1_Raw "$Dir_Subj_Tmp_T1_Proc/$(echo $Subj)_T1w.mif"
        else
            mrconvert "$(find $Dir_Subj_Tmp_T1_Raw/nifti_series -type f -name "*.nii" | head -n 1)" "$Dir_Subj_Tmp_T1_Proc/$(echo $Subj)_T1w.nii"
            mrconvert "$(find $Dir_Subj_Tmp_T1_Raw/nifti_series -type f -name "*.nii" | head -n 1)" "$Dir_Subj_Tmp_T1_Proc/$(echo $Subj)_T1w.mif"


        echo "Conversion from T1 dicom to nifti and mif finished for $Subj"
        fi

        echo -e "\n"
    fi

    if [ $DWI2Nifti == "1" ]; then


        if [ ! -d "$Dir_Subj_Tmp_DWI" ]; then
            mkdir -p "$Dir_Subj_Tmp_DWI"
            echo "Folder created: $Dir_Subj_Tmp_DWI"
        fi

        echo "Conversion from DWI dicom to nifti and mif started for $Subj"
        echo -e "\n"


        if [ $Proj == "pretermproj" ]; then

            if [ $GOSHPorjVariant == "1" ]; then # GOSH preterm patients

                mrconvert $Dir_Subj_Tmp_DWI_AP_Raw "$Dir_Subj_Tmp_DWI/$(echo $Subj)_b0.nii.gz" # convert the AP file to nii.gz
                mrconvert $Dir_Subj_Tmp_DWI_PA_Raw "$Dir_Subj_Tmp_DWI/$(echo $Subj)_b0_flip.nii.gz" # convert the PA file to nii.gz
                cp $Dir_Subj_Tmp_DWI_DAT_Raw "$Dir_Subj_Tmp_DWI/$(echo $Subj)_dwi.mif" # convert the DWI data file to mif

            else # GOSH fullterm controls
                cp $Dir_Subj_Tmp_DWI_AP_Raw "$Dir_Subj_Tmp_DWI/$(echo $Subj)_b0.nii.gz" # copy the AP file to the pre-proc folder
                cp $Dir_Subj_Tmp_DWI_PA_Raw "$Dir_Subj_Tmp_DWI/$(echo $Subj)_b0_flip.nii.gz" # copy the PA file to the pre-proc folder
                mrconvert $Dir_Subj_Tmp_DWI_DAT_Raw "$Dir_Subj_Tmp_DWI/$(echo $Subj)_dwi.mif" -fslgrad "$(find $Dir_Raw/$Subj -type f -name "*.bvec" | head -n 1)" "$(find $Dir_Raw/$Subj -type f -name "*.bval" | head -n 1)" # convert the DWI data file to mif

            fi

        else

            if find $Dir_Subj_Tmp_DWI_DAT_Raw -type f -name "*.dcm" | grep -q .; then
                mrconvert $Dir_Subj_Tmp_DWI_AP_Raw "$Dir_Subj_Tmp_DWI/$(echo $Subj)_b0.nii.gz" -stride 1,2,3 # convert the AP file to nii.gz
                mrconvert $Dir_Subj_Tmp_DWI_PA_Raw "$Dir_Subj_Tmp_DWI/$(echo $Subj)_b0_flip.nii.gz" -stride 1,2,3 # convert the PA file to nii.gz
                mrconvert $Dir_Subj_Tmp_DWI_DAT_Raw "$Dir_Subj_Tmp_DWI/$(echo $Subj)_dwi.mif" # convert the DWI data file to mif
            else
                mrconvert "$(find $Dir_Subj_Tmp_DWI_AP_Raw/nifti_series -type f -name "*.nii" | head -n 1)" "$Dir_Subj_Tmp_DWI/$(echo $Subj)_b0.nii.gz" -stride 1,2,3 # convert the AP file to nii.gz
                mrconvert "$(find $Dir_Subj_Tmp_DWI_PA_Raw/nifti_series -type f -name "*.nii" | head -n 1)" "$Dir_Subj_Tmp_DWI/$(echo $Subj)_b0_flip.nii.gz" -stride 1,2,3 # convert the PA file to nii.gz
                mrconvert "$(find $Dir_Subj_Tmp_DWI_DAT_Raw/nifti_series -type f -name "*.nii" | head -n 1)" "$Dir_Subj_Tmp_DWI/$(echo $Subj)_dwi.mif" -fslgrad "$(find $Dir_Subj_Tmp_DWI_DAT_Raw/nifti_series -type f -name "*.bvec" | head -n 1)" "$(find $Dir_Subj_Tmp_DWI_DAT_Raw/nifti_series -type f -name "*.bval" | head -n 1)" # convert the DWI data file to mif
            fi
        
        fi
        echo "Conversion from DWI dicom to nifti and mif FINISHED for $Subj"
        echo -e "\n\n"
    fi

done
