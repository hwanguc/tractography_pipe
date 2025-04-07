#!/usr/bin/env bash

## Author: Han Wang
### 13 Jan 2025: Initial version

### This script performs batch-processing of diffusion-weighted imaging (DWI) data for multiple subjects and extracts tensor-derived metrics (i.e., ADC, FA, AD, RD, eigenvector) from multiple ROIs.

#### Gibb's ring removal: 0 (off) or 1 (on), default 0.
#### Inhomogeneities (bias) correction: 0 (off) or 1 (on), default 0.
#### Brain mask estimation: mrtrix (use the dwi2mask function from mrtrix) or bet2 (use the bet2 function from fsl, which might be preferred), default "mrtrix"
#### Mask Intensity Threshold (only for bet2): default 0.7.
#### FOD normalisation (for fixel-based analysis): 0 (off) or 1 (on), default 0.
#### Package for image co-registration (dwi and anat): flirt (uing flirt in fsl) or niftyreg (using niftyreg-KCL version), default "flirt".
#### SIFT2 (for streamline filtering): 0 (off) or 1 (on), default 0.

#### Project ID: "kdvproj" or "grin2aproj".
#### Supported ROIs names: "cc" (corpus callosum), "leftaf" (left arcuate fasciculus), and "rightaf" (right arcuate fasciculus).
#### Filenames of the ROIs should be in the format of "sub-113_roi_roiname_seed.mif" (seed region), "sub-113_roi_roiname_incl.mif" (include region), and "sub-113_roi_roiname_excl.mif" (exclude region). 
#### Alternatively, "sub-113_roiname.mif" if only one ROI is used.
#### Supported metrics: "fa" (fractional anisotropy), "adc" (apparent diffusion coefficient), "ad" (axial diffusivity), "rd" (radial diffusivity).

### Note that this script depends on package MRTrix3.
### This script will overwrite existing files from the previous runs WITHOUT any warning, so use carefully!


# Common variables (these might move to a higher-level general script which calls specific functions at a later stage):

## Config (These need to match with the configs in dwi_preproc.sh, due to add a seperate config file for cross usage of the variables across scripts):

GibbsRm="0"
BiasCorr="0"
BrainMask="mrtrix"
MaskIntThre=0.7 # Set the fractional intensity threshold for the brain mask, only for the use of bet2
FodNorm="0"
ImgCoreg="niftyreg"
Sift="1"


## Project ID:

Proj="grin2aproj"

## ROIs:

ROIs=("cc" "leftaf" "rightaf") # Put your ROI names here

## Metrics:

Metrics=("fa" "adc" "ad" "rd") # Put your metrics here

## Participants:

Subjs=("114") # Put your subject ID here, and ensure the folders are in the format of "sub-ID", such as "sub-113" 
mapfile -t Subjs < <(for Subj in "${Subjs[@]}"; do echo "sub-$Subj"; done) # substute the subject IDs with the format "sub-SUBJ_ID"

## Directories:

if [ $Proj == "kdvproj" ]; then
    Dir_Common="/home/hanwang/Documents/gos_ich/cre_project/Data/data_proc/kdvproj"
else
    Dir_Common="/home/hanwang/Documents/gos_ich/cre_project/Data/data_proc/grin2aproj"
fi

Dir_PreProc="$Dir_Common/pre_processing"
Dir_Output="$Dir_Common/output"

### Create an output folder to save the results if it doesn't exist

if [ ! -d "$Dir_Output" ]; then
    mkdir -p "$Dir_Output"
    echo "Folder created: $Dir_Output"
fi

Output_Filename="250331_output_tract_metrics_sift$(echo $Sift).txt"

if [ -f "$Dir_Output/$Output_Filename" ]; then
    echo -e "\n\n"
    echo "Metrics output from the previous run exists. Overwriting the file."
    rm "$Dir_Output/$Output_Filename"
fi

## A counter to keep track of the output tables generated:

i=0

# Tractography:

for Subj in "${Subjs[@]}"; do


    echo -e "\n"
    echo "Started running the tractography pipeline for $Subj"
    echo -e "\n"

    ## 1. Define the folders we're working on/in and change the working directory
    
    
    Dir_Subj_Tmp_DWI="$Dir_PreProc/$Subj/dwi"

    if [ ! -d "$Dir_Subj_Tmp_DWI" ]; then
        echo "Error! DWI working folder not found: $Dir_Subj_Tmp_DWI"
        echo -e "\n\n"
        exit 1
    fi

    
    echo "Changing the working directory to the DWI folder of $Subj"
    
    cd "$Dir_Subj_Tmp_DWI" || exit
    echo -e "\n\n"

    ## 2. Perform tractography

    ### Generate the tracks

    echo "Generating tracks for $Subj"
    echo -e "\n"

    #### Generate CC tracks:

    echo "Generating the corpus callosum (CC) tracks for $Subj"
    tckgen -act $(echo $Subj)_5tt_coreg_$(echo $ImgCoreg).mif -seed_image $(echo $Subj)_roi_cc.mif -seed_direction 1,0,0 -nthreads 8 -maxlength 250 -cutoff 0.06 -select 2500 $(echo $Subj)_fod_norm$(echo $FodNorm).mif $(echo $Subj)_tracks_cc.tck -force
    echo -e "\n"

    #### Generate left arcuate fasciculus (AF) tracks:

    echo "Generating the left arcuate fasciculus (AF) tracks for $Subj"
    tckgen -act $(echo $Subj)_5tt_coreg_$(echo $ImgCoreg).mif -seed_image $(echo $Subj)_roi_leftaf_seed.mif -include $(echo $Subj)_roi_leftaf_incl.mif -exclude $(echo $Subj)_roi_cc.mif -nthreads 8 -maxlength 250 -cutoff 0.06 -select 500 $(echo $Subj)_fod_norm$(echo $FodNorm).mif $(echo $Subj)_tracks_leftaf.tck -force
    #tckgen -act $(echo $Subj)_5tt_coreg_$(echo $ImgCoreg).mif -seed_image $(echo $Subj)_roi_leftaf_seed.mif -include $(echo $Subj)_roi_leftaf_incl4_hw.mif -exclude sub-114_roi_leftaf_excl3.mif -exclude $(echo $Subj)_roi_cc.mif -nthreads 8 -maxlength 250 -cutoff 0.06 -select 500 $(echo $Subj)_fod_norm$(echo $FodNorm).mif $(echo $Subj)_tracks_leftaf.tck -force
    #tckgen -act $(echo $Subj)_5tt_coreg_$(echo $ImgCoreg).mif -seed_image $(echo $Subj)_roi_leftaf_seed.mif -include $(echo $Subj)_roi_leftaf_incl.mif -exclude $(echo $Subj)_roi_cc.mif -nthreads 8 -maxlength 250 -cutoff 0.06 -select 500 $(echo $Subj)_fod_norm$(echo $FodNorm).mif $(echo $Subj)_tracks_leftaf.tck -force
    echo -e "\n"


    #### Generate right arcuate fasciculus (AF) tracks:

    echo "Generating the right arcuate fasciculus (AF) tracks for $Subj"
    tckgen -act $(echo $Subj)_5tt_coreg_$(echo $ImgCoreg).mif -seed_image $(echo $Subj)_roi_rightaf_seed.mif -include $(echo $Subj)_roi_rightaf_incl.mif -exclude $(echo $Subj)_roi_cc.mif -nthreads 8 -maxlength 250 -cutoff 0.06 -select 500 $(echo $Subj)_fod_norm$(echo $FodNorm).mif $(echo $Subj)_tracks_rightaf.tck -force
    echo -e "\n"

    
    ## 3. Perform streamline filtering (SIFT2)

    for ROI in "${ROIs[@]}"; do

        if [ $Sift == "1" ]; then

            echo "Performing SIFT2 for $ROI tracks for $Subj"

            tcksift2 -act $(echo $Subj)_5tt_coreg_$(echo $ImgCoreg).mif -out_mu $(echo $Subj)_sift_$(echo $ROI)_mu.txt -out_coeffs $(echo $Subj)_sift_$(echo $ROI)_coeffs.txt -nthreads 8 $(echo $Subj)_tracks_$(echo $ROI).tck $(echo $Subj)_fod_norm$(echo $FodNorm).mif $(echo $Subj)_sift_$(echo $ROI).txt -force
            tckedit $(echo $Subj)_tracks_$(echo $ROI).tck -tck_weights_in $(echo $Subj)_sift_$(echo $ROI).txt $(echo $Subj)_tracks_$(echo $ROI)_sift$(echo $Sift).tck -force

        else

            cp ./$(echo $Subj)_tracks_$(echo $ROI).tck ./$(echo $Subj)_tracks_$(echo $ROI)_sift$(echo $Sift).tck

        fi

        echo -e "\n"


        ## 4. Extract metrics:


        ### Generate a density map based on the ROI tracks (assuming we've generated the ROI's tck file) with a template from a whole-brain we want to look at

        echo "Generating the density map for $ROI tracks for $Subj"
        tckmap $(echo $Subj)_tracks_$(echo $ROI)_sift$(echo $Sift).tck $(echo $Subj)_tracks_$(echo $ROI)_density.mif -template $(echo $Subj)_fa.mif -force
        echo -e "\n"

        ### keep a note of the max density from the print below as the threshold for the number of streamlines per voxel.
        echo "Thresholding the number of streamlines per voxel based on 10% of the max density for $ROI tracks for $Subj"
        mrstats $(echo $Subj)_tracks_$(echo $ROI)_density.mif > $(echo $Subj)_tracks_$(echo $ROI)_density.txt -force
        Thr=$(($(awk 'NR==2{print $8}' $(echo $Subj)_tracks_$(echo $ROI)_density.txt)/10))

        ### threshold the desity map with the min desity extracted above
        mrthreshold -abs $Thr $(echo $Subj)_tracks_$(echo $ROI)_density.mif $(echo $Subj)_tracks_$(echo $ROI)_density_thr$(echo $Thr).mif -force
        echo -e "\n"


        ## Now extract the metrics and store in a table (which will be updated for each metric, roi, and subject processed):

        for Metric in "${Metrics[@]}"; do

            i=$((i + 1))

            echo "Extracting $Metric for $ROI tracks for $Subj"

            table=$(echo $Subj)_tracks_$(echo $ROI)_$(echo $Metric)_measures.txt
            
            mrstats -mask $(echo $Subj)_tracks_$(echo $ROI)_density_thr$(echo $Thr).mif $(echo $Subj)_$(echo $Metric).mif > "$table" -force

            {
                read -r header  # Read the header
                echo -e "Subj\tROI\tMetric\tDensity_Thr\t$header"  # Add new headers
                while IFS= read -r line; do
                    echo -e "$Subj\t$ROI\t$Metric\t$Thr\t$line"  # Prepend Subj and ROI
                done
            } < "$table" > "processed_$table"

            # Combine processed tables
            if [[ $i -eq 1 ]]; then
                # For the first table, copy header + body
                cat "processed_$table" > $Dir_Output/$Output_Filename
            else
                # For subsequent tables, append only the body (skip header)
                tail -n +2 "processed_$table" >> $Dir_Output/$Output_Filename
            fi

            echo -e "\n"

        done

    done

    echo "Metrics extraction completed for $Subj"

done