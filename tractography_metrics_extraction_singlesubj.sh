#!/usr/bin/env bash

## Estimate diffusion tensor based on diffusion-wighted image:
dwi2tensor sub-113_den_preproc_unbiased.mif -mask sub-113_mask.mif sub-113_dt.mif

## Generate tensor-derived measures (ADC, FA, AD, RD, eigenvector):
tensor2metric sub-113_dt.mif -fa sub-113_fa.mif -adc sub-113_md.mif -vector sub-113_ev.mif -ad sub-113_ad.mif -rd sub-113_rd.mif

## Generate a density map based on the ROI tracks (assuming we've generated the ROI's tck file) with a template from a whole-brain we want to look at
tckmap sub-113_tracks_leftaf1_kks.tck sub-113_tracks_leftaf1_kks_density.mif -template sub-113_fa.mif

## keep a note of the max density from the print below as the threshold for the number of streamlines per voxel.
mrstats *_density.mif

## threshold the desity map with the min desity extracted above
mrthreshold -abs 162 sub-113_tracks_leftaf1_kks_density.mif sub-113_tracks_leftaf1_kks_density_thr162.mif

## extract a measure, e.g., fa.
mrstats -mask sub-113_tracks_leftaf1_kks_density_thr162.mif sub-113_fa.mif 


