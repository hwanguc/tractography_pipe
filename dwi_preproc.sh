#!/usr/bin/env bash

## Author: Han Wang
### 2 Dec 2024: Initial version

### This script performs batch processing of the DWI files and allows for the following options:

#### Gibb's ring removal: 0 (off) or 1 (on), default 0.
#### Inhomogeneities (bias) correction: 0 (off) or 1 (on), default 0.
#### Brain mask estimation: mrtrix (use the dwi2mask function from mrtrix) or bet2 (use the bet2 function from fsl, which might be preferred), default "mrtrix"
#### FOD normalisation (for fixel-based analysis): 0 (off) or 1 (on), default 0.
#### Package for image co-registration (dwi and anat): fsl (uing flirt) or nifreg (using niftyreg-KCL version), default "flirt".

### The output mif files ("sub-xxx_5tt_coreg.mif", etc) are ready for subsequent tractography based on user-defined ROI files.

### Note that this script depends on the packages MRTrix3, FSL, and ANTs (ANTs needed for bias correction).


# Common variables (these might move to a higher-level general script which calls specific functions at a later stage):

## Config:

GibbsRm="0"
BiasCorr="0"
BrainMask="mrtrix"
MaskIntThre=0.7 # Set the fractional intensity threshold for the brain mask, only for the use of bet2
FodNorm="0"
ImgCoreg="flirt"


## Project ID:

Proj="kdv" # unused for now


## Participants:

Subjs=("115" "116" "117") # Put your subject ID here, and ensure the folders are in the format of "sub-ID", such as "sub-113" 
mapfile -t Subjs < <(for Subj in "${Subjs[@]}"; do echo "sub-$Subj"; done) # substute the subject IDs with the format "sub-SUBJ_ID"

## Directories:

Dir_Common="/home/hanwang/Documents/gos_ich/cre_project/Data/data_proc/kdvproj"
Dir_Raw="$Dir_Common/raw"
Dir_PreProc="$Dir_Common/pre_processing"

# Preprocessing:

for Subj in "${Subjs[@]}"; do


    ## File Conversion and Curation:

    ### Define the folders we're working on/in

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


    ### Change the working directory to the current subject's DWI folder

    echo "Changing the working directory to the DWI folder of $Subj"
    
    cd "$Dir_Subj_Tmp_DWI" || exit
    echo -e "\n\n"

    ### Conversion from DWI dicom to Nifti and MIF for the current subject

    echo "Conversion from DWI dicom to nifti and mif started for $Subj"
    echo -e "\n"

    mrconvert $Dir_Subj_Tmp_DWI_AP_Raw "$(echo $Subj)_b0.nii.gz" -stride 1,2,3 # convert the AP file to nii.gz
    mrconvert $Dir_Subj_Tmp_DWI_PA_Raw "$(echo $Subj)_b0_flip.nii.gz" -stride 1,2,3 # convert the PA file to nii.gz
    mrconvert $Dir_Subj_Tmp_DWI_DAT_Raw "$(echo $Subj)_dwi.mif" # convert the DWI data file to mif

    echo "Conversion from DWI dicom to nifti and mif FINISHED for $Subj"
    echo -e "\n\n"

    ### merge AP and PA b0s for the current subj
    fslmerge -t "$(echo $Subj)_b0_pair.nii.gz" "$(echo $Subj)_b0.nii.gz" "$(echo $Subj)_b0_flip.nii.gz"
    mrconvert "$(echo $Subj)_b0_pair.nii.gz" "$(echo $Subj)_b0_pair.mif"


    ## Preprocessing - Data pipelines:

    ### Denoise the data using dwi_noise (note that here we also save the "noise" to a mif):
    echo "Denoising the DWI data for $Subj"
    dwidenoise "$(echo $Subj)_dwi.mif" "$(echo $Subj)_den.mif" -noise "$(echo $Subj)_noise.mif"
    echo -e "\n"

    #### calculate and save the residuals:
    echo "Calculating and saving the residual (noise) for DWI of $Subj"
    mrcalc "$(echo $Subj)_dwi.mif" "$(echo $Subj)_den.mif" -subtract "$(echo $Subj)_residual.mif"
    echo -e "\n"



    ### Remove the Gibb's ringing artifacts from the data (optional):
    if [ $GibbsRm == "1" ]; then
        echo "Removing Gibbs Ring effect for $Subj"
        mrdegibbs $(echo $Subj)_den.mif $(echo $Subj)_den_gbsrm$(echo $GibbsRm).mif
        echo -e "\n"
    else
        cp ./$(echo $Subj)_den.mif ./$(echo $Subj)_den_gbsrm$(echo $GibbsRm).mif
    fi

    ### Run preprocessing (note that the eddy options here are for single-shell data as in our case, might allow opt for multi shell in a later version):
    dwifslpreproc $(echo $Subj)_den_gbsrm$(echo $GibbsRm).mif $(echo $Subj)_den_gbsrm$(echo $GibbsRm)_preproc.mif -nocleanup -pe_dir AP -rpe_pair -se_epi $(echo $Subj)_b0_pair.mif -eddy_options " --repol"

    ### Generate a whole-brain mask
    #### remove inhomogeneities detected in the data that can lead to a better mask estimation (optional):
    
    if [ $BiasCorr == "1" ]; then
        echo "Removing inhomogeneties from DWI data for $Subj"
        dwibiascorrect ants $(echo $Subj)_den_gbsrm$(echo $GibbsRm)_preproc.mif $(echo $Subj)_den_gbsrm$(echo $GibbsRm)_preproc_biascorr$(echo $BiasCorr).mif -bias $(echo $Subj)_bias.mif
        echo -e "\n"
    else
        cp ./$(echo $Subj)_den_gbsrm$(echo $GibbsRm)_preproc.mif ./$(echo $Subj)_den_gbsrm$(echo $GibbsRm)_preproc_biascorr$(echo $BiasCorr).mif
    fi


    #### now generate a mask (options are "mrtrix" or "bet": default is mrtrix):
    
    echo "Generating a brain mask using $BrainMask for $Subj"

    if [ $BrainMask == "bet2" ]
        mrconvert $(echo $Subj)_den_gbsrm$(echo $GibbsRm)_preproc_biascorr$(echo $BiasCorr).mif $(echo $Subj)_den_gbsrm$(echo $GibbsRm)_preproc_biascorr$(echo $BiasCorr).nii
        bet2 $(echo $Subj)_den_gbsrm$(echo $GibbsRm)_preproc_biascorr$(echo $BiasCorr).nii $(echo $Subj)_brainmask_$BrainMask.nii.gz -m -f $MaskIntThre
        mrconvert $(echo $Subj)_brainmask_$BrainMask.nii.gz $(echo $Subj)_brainmask_$BrainMask.mif
    else
        dwi2mask $(echo $Subj)_den_gbsrm$(echo $GibbsRm)_preproc_biascorr$(echo $BiasCorr).mif $(echo $Subj)_brainmask_$BrainMask.mif
    fi

    echo -e "\n"



    ### Constrained Spherical Deconvolution

    #### a basis function from the diffusion data (note this is for single-shell data, might add more options for multi-shell data)
    echo "Estimating a basis function from the diffusion data for $Subj"
    dwi2response tournier $(echo $Subj)_den_gbsrm$(echo $GibbsRm)_preproc_biascorr$(echo $BiasCorr).mif $(echo $Subj)_csd.txt
    echo -e "\n"


    #### use the basis functions to estimate fibre orientation density (FOD, note that csd is only for single-shell, might need to add more options for multi-shell data later)
    echo "Estimating the fibre orientation density (FOD) for $Subj"
    dwi2fod csd $(echo $Subj)_den_gbsrm$(echo $GibbsRm)_preproc_biascorr$(echo $BiasCorr).mif $(echo $Subj)_csd.txt $(echo $Subj)_fod.mif -mask  $(echo $Subj)_brainmask_$BrainMask.mif
    echo -e "\n"


    #### now we normalise the FODs (optional - for fixel based analysis)

    if [ FodNorm == "1" ]
        echo "Normalising the FODs for $Subj"
        mtnormalise $(echo $Subj)_fod.mif $(echo $Subj)_fod_norm$(echo $FodNorm).mif -mask $(echo $Subj)_brainmask_$BrainMask.mif
        echo -e "\n"
    else
        cp ./$(echo $Subj)_fod.mif ./$(echo $Subj)_fod_norm$(echo $FodNorm).mif
    fi




# Niftyreg package, use the KCL one 
# Preprocessing - Creating tissue boundaries (copy the anat/mif file to dwi folder):

## segment the anatomical image into the five tissue types:
5ttgen fsl $(echo $Subj)_T1w.mif $(echo $Subj)_5tt_nocoreg.mif

## Coregister the diffusion and anatomical images:
### average together the b0 images:
dwiextract $(echo $Subj)_den_preproc_unbiased.mif - -bzero | mrmath - mean $(echo $Subj)_mean_b0.mif -axis 3

### convert both the segmented anatomical image and the mean b0 image we just generated:
mrconvert $(echo $Subj)_mean_b0.mif $(echo $Subj)_mean_b0.nii.gz
mrconvert $(echo $Subj)_5tt_nocoreg.mif $(echo $Subj)_5tt_nocoreg.nii.gz

### extract the first vol of the 5-tissue segmented dataset, which corresponds to the grey matter segmentation

fslroi $(echo $Subj)_5tt_nocoreg.nii.gz $(echo $Subj)_5tt_vol0.nii.gz 0 1

### Now, coregister the two datasets (mean_b0 and grey matter anatomy, anatomy as a ref, the output file is a transformation matrix):

flirt -in $(echo $Subj)_mean_b0.nii.gz -ref $(echo $Subj)_5tt_vol0.nii.gz -interp nearestneighbour -dof 6 -omat $(echo $Subj)_diff2struct_fsl.mat

### transform the matrix into a form that is readable by MRtrix

transformconvert $(echo $Subj)_diff2struct_fsl.mat $(echo $Subj)_mean_b0.nii.gz $(echo $Subj)_5tt_nocoreg.nii.gz flirt_import $(echo $Subj)_diff2struct_mrtrix.txt

### Now, we do the inverse - register the diffusion image to the anatomical image:

mrtransform $(echo $Subj)_5tt_nocoreg.mif -linear $(echo $Subj)_diff2struct_mrtrix.txt -inverse $(echo $Subj)_5tt_coreg.mif

#### we can view the coreg:
mrview $(echo $Subj)_den_preproc_unbiased.mif -overlay.load $(echo $Subj)_5tt_nocoreg.mif -overlay.colourmap 2 -overlay.load $(echo $Subj)_5tt_coreg.mif -overlay.colourmap 1

### Now, create the seed boundaries (for streamline processing later):
5tt2gmwmi $(echo $Subj)_5tt_coreg.mif $(echo $Subj)_gmwmSeed_coreg.mif








done


