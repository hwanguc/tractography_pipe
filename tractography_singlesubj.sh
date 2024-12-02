#!/usr/bin/env bash

### This script processes a single participant to estimate their whole-brain tractography and extracts some diffusion-based measures like MD/FA/AD/RD, etc.
### The script also performs a ROI analysis based on pre-defined fibre tract and extracts measures within those regions.


# Preprocessing - Conversion:

## Anatomical image: convert from dicom folder to nifti and mif (we will use mif for analysis)

mrconvert /home/hanwang/Apps/working_directory/bash_python_proj/kdvproj/data/raw/sub-113/012_-_t1_mpr_0.9_iso_hres /home/hanwang/Apps/working_directory/bash_python_proj/kdvproj/data/pre_processing/sub-113/anat/sub-113_T1w.nii
mrconvert /home/hanwang/Apps/working_directory/bash_python_proj/kdvproj/data/raw/sub-113/012_-_t1_mpr_0.9_iso_hres /home/hanwang/Apps/working_directory/bash_python_proj/kdvproj/data/pre_processing/sub-113/anat/sub-113_T1w.mif

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


# Preprocessing - Data pipelines:

## Denoise the data using dwi_noise (in the pre-processing/subj folder):

dwidenoise sub-113_dwi.mif sub-113_den.mif -noise sub-113_noise.mif
### calculate and save the residuals:
mrcalc sub-113_dwi.mif sub-113_den.mif -subtract sub-113_residual.mif


## Remove the Gibb's ringing artifacts from the data (optional):
mrdegibbs sub-113_den.mif sub-113_den_unr.mif


## Run preprocessing (note that the eddy options here are for single-shell data as in our case):
dwifslpreproc sub-113_den.mif sub-113_den_preproc.mif -nocleanup -pe_dir AP -rpe_pair -se_epi sub-113_b0_pair.mif -eddy_options " --repol"


## Generate a whole-brain mask
### remove inhomogeneities detected in the data that can lead to a better mask estimation (optional):
dwibiascorrect ants sub-113_den_preproc.mif sub-113_den_preproc_unbiased.mif -bias sub-113_bias.mif
### now generate a mask (might alternatively try with FSL's bet2 func?):
dwi2mask sub-113_den_preproc_unbiased.mif sub-113_mask.mif


## Constrained Spherical Deconvolution
### a basis function from the diffusion data (note this is for single-shell data)

dwi2response tournier sub-113_den_preproc_unbiased.mif sub-113_csd.txt

### use the basis functions to estimate fibre orientation density (FOD)
dwi2fod csd sub-113_den_preproc_unbiased.mif sub-113_csd.txt sub-113_fod.mif -mask  sub-113_mask.mif

### now we normalise the FODs (optional - for fixel based analysis)
mtnormalise sub-113_fod.mif sub-113_fod_norm.mif -mask sub-113_mask.mif





# Niftyreg package, use the KCL one 
# Preprocessing - Creating tissue boundaries (copy the anat/mif file to dwi folder):

## segment the anatomical image into the five tissue types:
5ttgen fsl sub-113_T1w.mif sub-113_5tt_nocoreg.mif

## Coregister the diffusion and anatomical images:
### average together the b0 images:
dwiextract sub-113_den_preproc_unbiased.mif - -bzero | mrmath - mean sub-113_mean_b0.mif -axis 3

### convert both the segmented anatomical image and the mean b0 image we just generated:
mrconvert sub-113_mean_b0.mif sub-113_mean_b0.nii.gz
mrconvert sub-113_5tt_nocoreg.mif sub-113_5tt_nocoreg.nii.gz

### extract the first vol of the 5-tissue segmented dataset, which corresponds to the grey matter segmentation

fslroi sub-113_5tt_nocoreg.nii.gz sub-113_5tt_vol0.nii.gz 0 1

### Now, coregister the two datasets (mean_b0 and grey matter anatomy, anatomy as a ref, the output file is a transformation matrix):

flirt -in sub-113_mean_b0.nii.gz -ref sub-113_5tt_vol0.nii.gz -interp nearestneighbour -dof 6 -omat sub-113_diff2struct_fsl.mat

### transform the matrix into a form that is readable by MRtrix

transformconvert sub-113_diff2struct_fsl.mat sub-113_mean_b0.nii.gz sub-113_5tt_nocoreg.nii.gz flirt_import sub-113_diff2struct_mrtrix.txt

### Now, we do the inverse - register the diffusion image to the anatomical image:

mrtransform sub-113_5tt_nocoreg.mif -linear sub-113_diff2struct_mrtrix.txt -inverse sub-113_5tt_coreg.mif

#### we can view the coreg:
mrview sub-113_den_preproc_unbiased.mif -overlay.load sub-113_5tt_nocoreg.mif -overlay.colourmap 2 -overlay.load sub-113_5tt_coreg.mif -overlay.colourmap 1

### Now, create the seed boundaries (for streamline processing later):
5tt2gmwmi sub-113_5tt_coreg.mif sub-113_gmwmSeed_coreg.mif



# Tractography:

## Generate and edit streamlines:

### Generate a whole-brain tractography based on constrained spherical deconvolution (CSD).

tckgen -act sub-113_5tt_coreg.mif -backtrack -seed_gmwmi sub-113_gmwmSeed_coreg.mif -nthreads 8 -maxlength 250 -cutoff 0.06 -select 10000000 sub-113_fod_norm.mif sub-113_tracks_10M.tck

### Optimise per-streamline cross-section multipliers to match a whole-brain tractogram to fixel-wise fibre densities (we will need the sift_1M.txt file for any downstream analysis with the )tck_weights_in option, for example, for the connectome analysis.

tcksift2 -act sub-113_5tt_coreg.mif -out_mu sub-113_sift_mu.txt -out_coeffs sub-113_sift_coeffs.txt -nthreads 8 sub-113_tracks_10M.tck sub-113_fod_norm.mif sub-113_sift_1M.txt


### Reduce the number of tracts (based on ORIGINAL tracks).

tckedit sub-113_tracks_10M.tck -number 200k sub-113_smallerTracks_200k.tck

### Reduce the number of tracts (Or base on SIFT2 filtered tracks).

tckedit sub-113_tracks_10M.tck -number 200k -tck_weights_in sub-113_sift_1M.txt sub-113_smallerTracks_200k_sift2.tck

#### We can view the reduced tracts now:

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_smallerTracks_200k_sift2.tck



# Diffusion-based measures (Whole Brain):

## Estimate diffusion tensor based on diffusion-wighted image:
dwi2tensor sub-113_den_preproc_unbiased.mif -mask sub-113_mask.mif sub-113_dt.mif

## Generate tensor-derived measures (ADC, FA, AD, RD, eigenvector):
tensor2metric sub-113_dt.mif -fa sub-113_fa.mif -adc sub-113_md.mif -vector sub-113_ev.mif -ad sub-113_ad.mif -rd sub-113_rd

## Edit tracks based on ROIs (assuming ROIs manually generated in the subject's folder):


### CC:

### include the CC ROI:

#### track number unthresholded
tckedit sub-113_tracks_10M.tck -tck_weights_in sub-113_sift_1M.txt -include sub-113_cctest.mif sub-113_tracks_cc_10M_sift2_1.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_cc_10M_sift2_1.tck

#### track number 10000
tckedit sub-113_tracks_10M.tck -tck_weights_in sub-113_sift_1M.txt -number 10000 -include sub-113_cctest.mif sub-113_tracks_cc_10M_sift2_2.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_cc_10M_sift2_2.tck

#### track number 10000, cc conservative

tckedit sub-113_tracks_10M.tck -tck_weights_in sub-113_sift_1M.txt -number 10000 -include sub-113_cctest2.mif sub-113_tracks_cc_10M_sift2_3.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_cc_10M_sift2_3.tck

#### track number 3000, cc conservative

tckedit sub-113_tracks_10M.tck -tck_weights_in sub-113_sift_1M.txt -number 3000 -include sub-113_cctest2.mif sub-113_tracks_cc_10M_sift2_4.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_cc_10M_sift2_4.tck

#### track number 10000, cc conservative (less inferior)

tckedit -force sub-113_tracks_10M.tck -tck_weights_in sub-113_sift_1M.txt -number 10000 -include sub-113_cctest6.mif sub-113_tracks_cc_10M_sift2_5.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_cc_10M_sift2_5.tck




#### track number 10000, cc conservative, tckgen seed_image with cc

tckgen -act sub-113_5tt_coreg.mif -backtrack -seed_gmwmi sub-113_gmwmSeed_coreg.mif -seed_image sub-113_cctest2.mif -nthreads 8 -maxlength 250 -cutoff 0.06 -select 10000 sub-113_fod_norm.mif sub-113_tracks_cc_10k.tck

tcksift2 -act sub-113_5tt_coreg.mif -out_mu sub-113_sift_cc_mu_1.txt -out_coeffs sub-113_sift_cc_coeffs_1.txt -nthreads 8 sub-113_tracks_cc_10k.tck sub-113_fod_norm.mif sub-113_sift_cc_10k.txt

tckedit sub-113_tracks_cc_10k.tck -tck_weights_in sub-113_sift_cc_10k.txt sub-113_tracks_cc_10k_sift2_1.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_cc_10k_sift2_1.tck


#### track number 3000, cc conservative, tckgen seed_image with cc

tckgen -act sub-113_5tt_coreg.mif -backtrack -seed_gmwmi sub-113_gmwmSeed_coreg.mif -seed_image sub-113_cctest2.mif -nthreads 8 -maxlength 250 -cutoff 0.06 -select 3000 sub-113_fod_norm.mif sub-113_tracks_cc_3k.tck

tcksift2 -act sub-113_5tt_coreg.mif -out_mu sub-113_sift_cc_mu_2.txt -out_coeffs sub-113_sift_cc_coeffs_2.txt -nthreads 8 sub-113_tracks_cc_3k.tck sub-113_fod_norm.mif sub-113_sift_cc_3k.txt

tckedit sub-113_tracks_cc_3k.tck -tck_weights_in sub-113_sift_cc_3k.txt sub-113_tracks_cc_3k_sift2_1.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_cc_3k_sift2_1.tck



#### track number 10000, cc conservative, tckgen seed_image with cc, no act seed option.

tckgen -force -act sub-113_5tt_coreg.mif -backtrack -seed_image sub-113_cctest2.mif -nthreads 8 -maxlength 250 -cutoff 0.06 -select 10000 sub-113_fod_norm.mif sub-113_tracks_cc_noactseed_10k.tck

tcksift2 -force -act sub-113_5tt_coreg.mif -out_mu sub-113_sift_cc_mu_3.txt -out_coeffs sub-113_sift_cc_coeffs_3.txt -nthreads 8 sub-113_tracks_cc_noactseed_10k.tck sub-113_fod_norm.mif sub-113_sift_cc_noactseed_10k.txt

tckedit -force sub-113_tracks_cc_noactseed_10k.tck -tck_weights_in sub-113_sift_cc_noactseed_10k.txt sub-113_tracks_cc_10k_sift2_2.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_cc_10k_sift2_2.tck


#### track number 10000, cc conservative, tckgen seed_image with cc, no act seed option, no backtrack.

tckgen -act sub-113_5tt_coreg.mif -seed_image sub-113_cctest2.mif -nthreads 8 -maxlength 250 -cutoff 0.06 -select 10000 sub-113_fod_norm.mif sub-113_tracks_cc_noactseed_nobacktrack_10k.tck

tcksift2 -act sub-113_5tt_coreg.mif -out_mu sub-113_sift_cc_mu_4.txt -out_coeffs sub-113_sift_cc_coeffs_4.txt -nthreads 8 sub-113_tracks_cc_noactseed_nobacktrack_10k.tck sub-113_fod_norm.mif sub-113_sift_cc_noactseed_nobacktrack_10k.txt

tckedit sub-113_tracks_cc_noactseed_nobacktrack_10k.tck -tck_weights_in sub-113_sift_cc_noactseed_nobacktrack_10k.txt sub-113_tracks_cc_10k_sift2_3.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_cc_10k_sift2_3.tck


#### track number 10000, cc conservative, tckgen seed_image with cc, no act seed option, no backtrack, seed_direction added.

tckgen -act sub-113_5tt_coreg.mif -seed_image sub-113_cctest2.mif -seed_direction 1,0,0 -nthreads 8 -maxlength 250 -cutoff 0.06 -select 10000 sub-113_fod_norm.mif sub-113_tracks_cc_noactseed_nobacktrack_leftright_10k.tck

tcksift2 -act sub-113_5tt_coreg.mif -out_mu sub-113_sift_cc_mu_5.txt -out_coeffs sub-113_sift_cc_coeffs_5.txt -nthreads 8 sub-113_tracks_cc_noactseed_nobacktrack_leftright_10k.tck sub-113_fod_norm.mif sub-113_sift_cc_noactseed_nobacktrack_leftright_10k.txt

tckedit sub-113_tracks_cc_noactseed_nobacktrack_leftright_10k.tck -tck_weights_in sub-113_sift_cc_noactseed_nobacktrack_leftright_10k.txt sub-113_tracks_cc_10k_sift2_4.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_cc_10k_sift2_4.tck


#### track number 10000, cc conservative, tckgen seed_image with cc, no act seed option, no backtrack, seed_direction added, seed_number 5m

tckgen -force -act sub-113_5tt_coreg.mif -seed_image sub-113_cctest2.mif -seed_direction 1,0,0 -seeds 5000000 -nthreads 8 -maxlength 250 -cutoff 0.06 -select 10000 sub-113_fod_norm.mif sub-113_tracks_cc_noactseed_nobacktrack_leftright_sn5m_10k.tck

tcksift2 -force -act sub-113_5tt_coreg.mif -out_mu sub-113_sift_cc_mu_6.txt -out_coeffs sub-113_sift_cc_coeffs_6.txt -nthreads 8 sub-113_tracks_cc_noactseed_nobacktrack_leftright_sn5m_10k.tck sub-113_fod_norm.mif sub-113_sift_cc_noactseed_nobacktrack_leftright_sn5m_10k.txt

tckedit -force sub-113_tracks_cc_noactseed_nobacktrack_leftright_sn5m_10k.tck -tck_weights_in sub-113_sift_cc_noactseed_nobacktrack_leftright_sn5m_10k.txt sub-113_tracks_cc_10k_sift2_5.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_cc_10k_sift2_5.tck


#### track number 10000, cc conservative, tckgen seed_image with cc, no act seed option, no backtrack, seed_direction added, seed_number 1m

tckgen -force -act sub-113_5tt_coreg.mif -seed_image sub-113_cctest2.mif -seed_direction 1,0,0 -seeds 1000000 -nthreads 8 -maxlength 250 -cutoff 0.06 -select 10000 sub-113_fod_norm.mif sub-113_tracks_cc_noactseed_nobacktrack_leftright_sn1m_10k.tck

tcksift2 -force -act sub-113_5tt_coreg.mif -out_mu sub-113_sift_cc_mu_7.txt -out_coeffs sub-113_sift_cc_coeffs_7.txt -nthreads 8 sub-113_tracks_cc_noactseed_nobacktrack_leftright_sn1m_10k.tck sub-113_fod_norm.mif sub-113_sift_cc_noactseed_nobacktrack_leftright_sn1m_10k.txt

tckedit -force sub-113_tracks_cc_noactseed_nobacktrack_leftright_sn1m_10k.tck -tck_weights_in sub-113_sift_cc_noactseed_nobacktrack_leftright_sn1m_10k.txt sub-113_tracks_cc_10k_sift2_6.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_cc_10k_sift2_6.tck


#### track number 10000, cc conservative2 (thicker CC), tckgen seed_image with cc, no act seed option, no backtrack, seed_direction added.

tckgen -act sub-113_5tt_coreg.mif -seed_image sub-113_cctest3.mif -seed_direction 1,0,0 -nthreads 8 -maxlength 250 -cutoff 0.06 -select 10000 sub-113_fod_norm.mif sub-113_tracks_cc2_noactseed_nobacktrack_leftright_10k.tck

tcksift2 -act sub-113_5tt_coreg.mif -out_mu sub-113_sift_cc_mu_8.txt -out_coeffs sub-113_sift_cc_coeffs_8.txt -nthreads 8 sub-113_tracks_cc2_noactseed_nobacktrack_leftright_10k.tck sub-113_fod_norm.mif sub-113_sift_cc2_noactseed_nobacktrack_leftright_10k.txt

tckedit sub-113_tracks_cc2_noactseed_nobacktrack_leftright_10k.tck -tck_weights_in sub-113_sift_cc2_noactseed_nobacktrack_leftright_10k.txt sub-113_tracks_cc_10k_sift2_7.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_cc_10k_sift2_7.tck


#### track number 10000, cc conservative, tckgen seed_image with cc, no act seed option, no backtrack, seed_direction added, exclusion mask added

tckgen -act sub-113_5tt_coreg.mif -seed_image sub-113_cctest2.mif -seed_direction 1,0,0 -exclude sub-113_cctest_exclusion.mif -nthreads 8 -maxlength 250 -cutoff 0.06 -select 10000 sub-113_fod_norm.mif sub-113_tracks_cc_noactseed_nobacktrack_leftright_excl_10k.tck

tcksift2 -act sub-113_5tt_coreg.mif -out_mu sub-113_sift_cc_mu_9.txt -out_coeffs sub-113_sift_cc_coeffs_9.txt -nthreads 8 sub-113_tracks_cc_noactseed_nobacktrack_leftright_excl_10k.tck sub-113_fod_norm.mif sub-113_sift_cc_noactseed_nobacktrack_leftright_excl_10k.txt

tckedit sub-113_tracks_cc_noactseed_nobacktrack_leftright_excl_10k.tck -tck_weights_in sub-113_sift_cc_noactseed_nobacktrack_leftright_excl_10k.txt sub-113_tracks_cc_10k_sift2_8.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_cc_10k_sift2_8.tck


#### track number 10000, cc conservative, no act.

tckgen -force -seed_image sub-113_cctest2.mif -include sub-113_cctest2.mif -seed_direction 1,0,0 -select 10000 sub-113_fod_norm.mif sub-113_tracks_cc_noact_10k.tck
mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_cc_noact_10k.tck


#### track number 10000, cc very conservative, tckgen seed_image with newly drawn cc, no act seed option, 2.5k streamlines (best so far?).

tckgen -act sub-113_5tt_coreg.mif -seed_image sub-113_cctest7.mif -seed_direction 1,0,0 -nthreads 8 -maxlength 250 -cutoff 0.06 -select 2500 sub-113_fod_norm.mif sub-113_tracks_newcc_2halfk.tck

tcksift2 -act sub-113_5tt_coreg.mif -out_mu sub-113_sift_cc_mu_10.txt -out_coeffs sub-113_sift_cc_coeffs_10.txt -nthreads 8 sub-113_tracks_newcc_2halfk.tck sub-113_fod_norm.mif sub-113_sift_newcc_2halfk.txt

tckedit sub-113_tracks_newcc_2halfk.tck -tck_weights_in sub-113_sift_newcc_2halfk.txt sub-113_tracks_newcc_2halfk_sift2_9.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_newcc_2halfk_sift2_9.tck



#### track number 10000, cc very conservative, tckgen seed_image with newly drawn cc, no act seed option, 2k streamlines.

tckgen -act sub-113_5tt_coreg.mif -seed_image sub-113_cctest7.mif -seed_direction 1,0,0 -nthreads 8 -maxlength 250 -cutoff 0.06 -select 2000 sub-113_fod_norm.mif sub-113_tracks_newcc_2k.tck

tcksift2 -act sub-113_5tt_coreg.mif -out_mu sub-113_sift_cc_mu_11.txt -out_coeffs sub-113_sift_cc_coeffs_11.txt -nthreads 8 sub-113_tracks_newcc_2k.tck sub-113_fod_norm.mif sub-113_sift_newcc_2k.txt

tckedit sub-113_tracks_newcc_2k.tck -tck_weights_in sub-113_sift_newcc_2k.txt sub-113_tracks_newcc_2k_sift2_10.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_newcc_2k_sift2_10.tck


### Arcuate fasciculus:


#### include the two ROIs, exclude CC.
tckedit sub-113_tracks_10M.tck -tck_weights_in sub-113_sift_1M.txt -include sub-113_seed_leftaf.mif -include sub-113_incl_leftaf.mif -exclude sub-113_cctest.mif sub-113_tracks_af_10M_sift2_1.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_af_10M_sift2_1.tck

#### include the two ROIs in order, exclude CC.
tckedit sub-113_tracks_10M.tck -tck_weights_in sub-113_sift_1M.txt -include_ordered sub-113_seed_leftaf.mif -include_ordered sub-113_incl_leftaf.mif -exclude sub-113_cctest.mif sub-113_tracks_af_10M_sift2_2.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_af_10M_sift2_2.tck


#### tckgen, seed leftaf, include leftaf, exclude cc test


tckgen -act sub-113_5tt_coreg.mif -seed_image sub-113_seed_leftaf.mif -include sub-113_incl_leftaf.mif -exclude sub-113_cctest7.mif -nthreads 8 -maxlength 250 -cutoff 0.06 sub-113_fod_norm.mif sub-113_tracks_leftaf1.tck

tcksift2 -act sub-113_5tt_coreg.mif -out_mu sub-113_sift_leftaf_mu_1.txt -out_coeffs sub-113_sift_leftaf_coeffs_1.txt -nthreads 8 sub-113_tracks_leftaf1.tck sub-113_fod_norm.mif sub-113_sift_leftaf1.txt

tckedit sub-113_tracks_leftaf1.tck -tck_weights_in sub-113_sift_leftaf1.txt sub-113_tracks_leftaf_sift2_1.tck

mrview sub-113_den_preproc_unbiased.mif -tractography.load sub-113_tracks_leftaf_sift2_1.tck


tckgen -act sub-113_5tt_coreg.mif -seed_image sub-113_seed_leftaf.mif -include sub-113_incl_leftaf.mif -exclude sub-113_cctest7.mif -nthreads 8 -cutoff 0.1 -select 5000 sub-113_fod_norm.mif sub-113_tracks_leftaf1.tck

### check weighted-mean for FA, etc.

