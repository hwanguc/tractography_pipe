#!/usr/bin/env bash

## Author: Han Wang
### 2 Dec 2024: Initial version
### 11 Dec 2024: Added an option to support co-registration by Niftyreg (KCL)
### 8 Jan 2025: Added support for GRIN2A project.
### 10 Jan 2025: Added tensor-derived metrics extraction (i.e., ADC, FA, AD, RD, eigenvector).

### This script performs batch processing of the DWI files and allows for the following options:

#### Gibb's ring removal: 0 (off) or 1 (on), default 0.
#### Inhomogeneities (bias) correction: 0 (off) or 1 (on), default 0.
#### Brain mask estimation: mrtrix (use the dwi2mask function from mrtrix) or bet2 (use the bet2 function from fsl, which might be preferred), default "mrtrix"
#### Mask Intensity Threshold (only for bet2): default 0.7.
#### FOD normalisation (for fixel-based analysis): 0 (off) or 1 (on), default 0.
#### Package for image co-registration (dwi and anat): flirt (uing flirt in fsl) or niftyreg (using niftyreg-KCL version), default "flirt".

#### Project ID: "kdvproj" or "grin2aproj". The directory structure for KdV and GRIN2A projects are different, GRIN2A has seperate anat and dwi folders under the raw folder.

### The output mif files ("sub-xxx_5tt_coreg.mif", etc) are ready for subsequent tractography based on user-defined ROI files.

### Note that this script depends on the packages MRTrix3, FSL, Niftyreg, and ANTs (ANTs needed for bias correction).

# Common variables (these might move to a higher-level general script which calls specific functions at a later stage):

## Config:

GibbsRm="0"
BiasCorr="0"
BrainMask="mrtrix"
MaskIntThre=0.7 # Set the fractional intensity threshold for the brain mask, only for the use of bet2
FodNorm="0"
ImgCoreg="niftyreg"


## Project ID:

Proj="grin2aproj"

## Participants:

Subjs=("g004" "g005") # Put your subject ID here, and ensure the folders are in the format of "sub-ID", such as "sub-113" 
mapfile -t Subjs < <(for Subj in "${Subjs[@]}"; do echo "sub-$Subj"; done) # substute the subject IDs with the format "sub-SUBJ_ID"

## Directories:

if [ $Proj == "kdvproj" ]; then
    Dir_Common="/home/hanwang/Documents/gos_ich/cre_project/Data/data_proc/kdvproj"
else
    Dir_Common="/home/hanwang/Documents/gos_ich/cre_project/Data/data_proc/grin2aproj"
fi

Dir_Raw="$Dir_Common/raw"
Dir_PreProc="$Dir_Common/pre_processing"

# Preprocessing:

for Subj in "${Subjs[@]}"; do

    echo -e "\n"
    echo "Pre-processing started for $Subj"
    echo -e "\n"

    ## 1. File Conversion and Curation:

    ### Define the folders we're working on/in


    if [ $Proj == "kdvproj" ]; then
        DWI_AP_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj" -type d -name "*A-P*" -exec basename {} \; | head -n 1) # Find the AP dicom folder
        DWI_PA_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj" -type d -name "*P-A*" -exec basename {} \; | head -n 1) # Find the PA dicom folder
        DWI_DAT_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj" -type d -name "*005*" -exec basename {} \; | head -n 1) # Find the DWI data dicom folder


        Dir_Subj_Tmp_DWI_AP_Raw="$Dir_Raw/$Subj/$DWI_AP_Dir_Name_Tmp"
        Dir_Subj_Tmp_DWI_PA_Raw="$Dir_Raw/$Subj/$DWI_PA_Dir_Name_Tmp"
        Dir_Subj_Tmp_DWI_DAT_Raw="$Dir_Raw/$Subj/$DWI_DAT_Dir_Name_Tmp"
    
    else

        DWI_AP_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj/DWI" -type d -name "*A-P*" -exec basename {} \; | head -n 1) # Find the AP dicom folder
        DWI_PA_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj/DWI" -type d -name "*P-A*" -exec basename {} \; | head -n 1) # Find the PA dicom folder
        DWI_DAT_Dir_Name_Tmp=$(find "$Dir_Raw/$Subj/DWI" -type d -name "*MDDW_64_directions_ep2d_diff_p2" -exec basename {} \; | head -n 1) # Find the DWI data dicom folder


        Dir_Subj_Tmp_DWI_AP_Raw="$Dir_Raw/$Subj/DWI/$DWI_AP_Dir_Name_Tmp"
        Dir_Subj_Tmp_DWI_PA_Raw="$Dir_Raw/$Subj/DWI/$DWI_PA_Dir_Name_Tmp"
        Dir_Subj_Tmp_DWI_DAT_Raw="$Dir_Raw/$Subj/DWI/$DWI_DAT_Dir_Name_Tmp"

    fi
    
    
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
    echo -e "\n"

    echo "Merging AP and PA b0s into b0_pair.mif for $Subj"
    ### merge AP and PA b0s for the current subj
    fslmerge -t "$(echo $Subj)_b0_pair.nii.gz" "$(echo $Subj)_b0.nii.gz" "$(echo $Subj)_b0_flip.nii.gz"
    mrconvert "$(echo $Subj)_b0_pair.nii.gz" "$(echo $Subj)_b0_pair.mif"
    echo -e "\n\n"

    ## 2. Data pipelines:

    ### Denoise the data using dwi_noise (note that here we also save the "noise" to a mif):
    echo -e "\n"
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
    echo "Runnning the DWIFSL preprocessing pipeline for $Subj"
    dwifslpreproc $(echo $Subj)_den_gbsrm$(echo $GibbsRm).mif $(echo $Subj)_den_gbsrm$(echo $GibbsRm)_preproc.mif -nocleanup -pe_dir AP -rpe_pair -se_epi $(echo $Subj)_b0_pair.mif -eddy_options " --repol"
    echo -e "\n"

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

    if [ $BrainMask == "bet2" ]; then
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

    if [ FodNorm == "1" ]; then
        echo "Normalising the FODs for $Subj"
        mtnormalise $(echo $Subj)_fod.mif $(echo $Subj)_fod_norm$(echo $FodNorm).mif -mask $(echo $Subj)_brainmask_$BrainMask.mif
        echo -e "\n\n"
    else
        cp ./$(echo $Subj)_fod.mif ./$(echo $Subj)_fod_norm$(echo $FodNorm).mif
        echo -e "\n"
    fi


    ## 3. Creating tissue boundaries (copy the anat/mif file to dwi folder):
    ### Will give an option below to use the "niftyreg" package (use the KCL one)

    ### copy the T1 mif file to the dwi folder
    cp $Dir_PreProc/$Subj/anat/$(echo $Subj)_T1w.mif ./$(echo $Subj)_T1w.mif

    ### segment the anatomical image into the five tissue types:
    echo "Creating tissue boundaries for the five tissues for $Subj"
    5ttgen fsl $(echo $Subj)_T1w.mif $(echo $Subj)_5tt_nocoreg.mif
    echo -e "\n\n"


    ## 4. Coregister the diffusion and anatomical images:

    echo "Coregistering the diffusion and anatomical images for $Subj"
    ### average together the b0 images:
    dwiextract $(echo $Subj)_den_gbsrm$(echo $GibbsRm)_preproc_biascorr$(echo $BiasCorr).mif - -bzero | mrmath - mean $(echo $Subj)_mean_b0.mif -axis 3

    ### convert both the segmented anatomical image and the mean b0 image we just generated:
    mrconvert $(echo $Subj)_mean_b0.mif $(echo $Subj)_mean_b0.nii.gz
    mrconvert $(echo $Subj)_5tt_nocoreg.mif $(echo $Subj)_5tt_nocoreg.nii.gz

    ### extract the first vol of the 5-tissue segmented dataset, which corresponds to the grey matter segmentation
    fslroi $(echo $Subj)_5tt_nocoreg.nii.gz $(echo $Subj)_5tt_vol0.nii.gz 0 1

    echo -e "\n"

    echo "Registering 5-tissue boundaries onto DWI image (using the inverse DWI to 5tt transformation matrix) for $Subj using $ImgCoreg"

    if [ ImgCoreg == "flirt" ]; then
        ### Now, coregister the two datasets (mean_b0 and grey matter anatomy, anatomy as a ref, the output file is a transformation matrix):
        flirt -in $(echo $Subj)_mean_b0.nii.gz -ref $(echo $Subj)_5tt_vol0.nii.gz -interp nearestneighbour -dof 6 -omat $(echo $Subj)_diff2struct_$(echo $ImgCoreg).mat

        ### transform the matrix into a form that is readable by MRtrix
        transformconvert $(echo $Subj)_diff2struct_$(echo $ImgCoreg).mat $(echo $Subj)_mean_b0.nii.gz $(echo $Subj)_5tt_nocoreg.nii.gz flirt_import $(echo $Subj)_diff2struct_$(echo $ImgCoreg)_mrtrix.txt

        ### Now, we do the inverse - register the diffusion image to the anatomical image:
        mrtransform $(echo $Subj)_5tt_nocoreg.mif -linear $(echo $Subj)_diff2struct_$(echo $ImgCoreg)_mrtrix.txt -inverse $(echo $Subj)_5tt_coreg_$(echo $ImgCoreg).mif

    else
        ### Generate the transformation matrix with Niftyreg, ref image T1, floating image mean b0
        reg_aladin -ref $(echo $Subj)_5tt_vol0.nii.gz -flo $(echo $Subj)_mean_b0.nii.gz -interp 0 -aff $(echo $Subj)_diff2struct_$(echo $ImgCoreg).txt

        ### Calculate the inverse matrix from the transformation matrix for using T1 as floating image
        reg_transform -invAff $(echo $Subj)_diff2struct_$(echo $ImgCoreg).txt $(echo $Subj)_diff2struct_$(echo $ImgCoreg)_inverse.txt

        ### regrid the mean b0 image to T1 resolution (1*1*1) so we can use b0 as a ref image for resampling
        mrgrid $(echo $Subj)_mean_b0.nii.gz regrid -voxel 1 $(echo $Subj)_mean_b0_1mm-iso.nii.gz

        ### Register T1 onto the DWI image using the inverse matrix calculated above
        reg_resample -ref $(echo $Subj)_mean_b0_1mm-iso.nii.gz -flo $(echo $Subj)_5tt_nocoreg.nii.gz -trans $(echo $Subj)_diff2struct_$(echo $ImgCoreg)_inverse.txt -inter 0 -res $(echo $Subj)_5tt_coreg_$(echo $ImgCoreg).nii.gz

        mrconvert $(echo $Subj)_5tt_coreg_$(echo $ImgCoreg).nii.gz $(echo $Subj)_5tt_coreg_$(echo $ImgCoreg).mif
    fi

    #### we can view the coreg:
    #mrview $(echo $Subj)_den_preproc_unbiased.mif -overlay.load $(echo $Subj)_5tt_nocoreg.mif -overlay.colourmap 2 -overlay.load $(echo $Subj)_5tt_coreg.mif -overlay.colourmap 1
    echo -e "\n"

    echo "Creating the seed boundaries for streamline estimation for $Subj"

    ### Now create the seed boundaries for streamline processing later
    5tt2gmwmi $(echo $Subj)_5tt_coreg_$(echo $ImgCoreg).mif $(echo $Subj)_gmwmSeed_coreg.mif
    echo -e "\n"

    ## 5. Extract whole-brain tensor-derived metrics:
    ### Estimate diffusion tensor based on diffusion-wighted image:

    echo "Estimating the diffusion tensor and generating tensor-derived measures for $Subj"

    dwi2tensor $(echo $Subj)_den_gbsrm$(echo $GibbsRm)_preproc_biascorr$(echo $BiasCorr).mif -mask $(echo $Subj)_brainmask_$BrainMask.mif $(echo $Subj)_dt.mif

    ### Generate tensor-derived measures (ADC, FA, AD, RD, eigenvector):
    tensor2metric $(echo $Subj)_dt.mif -fa $(echo $Subj)_fa.mif -adc $(echo $Subj)_adc.mif -vector $(echo $Subj)_ev.mif -ad $(echo $Subj)_ad.mif -rd $(echo $Subj)_rd.mif

    echo -e "\n"
    echo "Pre-processing completed for $Subj"
    echo -e "\n\n"

done