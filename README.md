# Tractography pipeline:

This repository contains a pipeline for **pre-processing** the diffusion-weighted magnetic resonance imaging data and for running the **tractography** analysis, mainly using [MRTrix3](https://www.mrtrix.org/).

**Pipeline (batch processing):**

**_./0_dcmconvert_**: Convert the raw, T1-weighted and the diffusion dicom files to nifti or mif format.

**_./1_dwi_preproc.sh_**: Run the pre-processing pipeline.

**_./2_dwi_tractography.sh_**: Run tractography on pre-processed images for the pre-defined ROIs and extract tensor-based metrics.

**_./utils/dwi_header_reader.py_**: Read the headers of the DWI images.




