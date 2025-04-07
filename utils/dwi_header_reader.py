# Author: Han Wang
## This script reads the header of a DICOM file and extracts the scanning sequence details.
## The scanning sequence details include Scanning Sequence, Sequence Variant, and Diffusion B-Value.

# Import necessary libraries

import os
import pydicom

# Set DICOM directory path
dicom_dir = "/home/hanwang/Documents/gos_ich/cre_project/Data/data_proc/grin2aproj/raw/sub-0020/DWI/031_-_MDDW_64_directions_ep2d_diff_p2"

# Initialize lists for extracted information
scanning_sequences = []
sequence_variants = []
b_values = []
voxel_sizes = []
tr_values = []
te_values = []
field_of_view = []
image_orientations = []
image_positions = []
diffusion_gradients = []

# Read all DICOM files in the folder
for file in os.listdir(dicom_dir):
    filepath = os.path.join(dicom_dir, file)
    if not filepath.endswith(".dcm"):
        continue  # Skip non-DICOM files

    ds = pydicom.dcmread(filepath, force=True)

    # Extract scanning sequence and sequence variant
    scanning_sequence = ds.get((0x0018, 0x0020), "Unknown")  # Scanning Sequence
    sequence_variant = ds.get((0x0018, 0x0021), "Unknown")   # Sequence Variant

    # Extract diffusion b-values
    b_value = ds.get((0x0018, 0x9087), "Unknown")

    # Extract voxel size (Pixel Spacing + Slice Thickness)
    pixel_spacing = ds.get((0x0028, 0x0030), ["Unknown", "Unknown"])  # X, Y resolution
    slice_thickness = ds.get((0x0018, 0x0050), "Unknown")  # Z resolution

    pixel_spacing = pixel_spacing.value if hasattr(pixel_spacing, "value") else ["Unknown", "Unknown"]
    slice_thickness = slice_thickness.value if hasattr(slice_thickness, "value") else "Unknown"

    voxel_size = (
        float(pixel_spacing[0]) if pixel_spacing[0] != "Unknown" else "Unknown",
        float(pixel_spacing[1]) if pixel_spacing[1] != "Unknown" else "Unknown",
        float(slice_thickness) if slice_thickness != "Unknown" else "Unknown",
    )

    # Extract TR (Repetition Time) and TE (Echo Time)
    tr = ds.get((0x0018, 0x0080), "Unknown")
    te = ds.get((0x0018, 0x0081), "Unknown")

    # Extract field of view (FOV)
    fov_x = ds.get((0x0018, 0x1100), "Unknown")  # Width
    fov_y = ds.get((0x0018, 0x1101), "Unknown")  # Height
    fov = (fov_x, fov_y)

    # Extract Image Orientation & Position
    image_orientation = ds.get((0x0020, 0x0037), "Unknown")
    image_position = ds.get((0x0020, 0x0032), "Unknown")

    # Extract Diffusion Gradient Directions (if available)
    diffusion_gradient = ds.get((0x0018, 0x9089), "Unknown")

    # Store extracted values
    if scanning_sequence != "Unknown":
        scanning_sequences.append(scanning_sequence)

    if sequence_variant != "Unknown":
        sequence_variants.append(sequence_variant)

    if b_value != "Unknown":
        b_values.append(b_value)

    if voxel_size != ("Unknown", "Unknown", "Unknown"):
        voxel_sizes.append(voxel_size)

    if tr != "Unknown":
        tr_values.append(tr)

    if te != "Unknown":
        te_values.append(te)

    if fov != ("Unknown", "Unknown"):
        field_of_view.append(fov)

    if image_orientation != "Unknown":
        image_orientations.append(image_orientation)

    if image_position != "Unknown":
        image_positions.append(image_position)

    if diffusion_gradient != "Unknown":
        diffusion_gradients.append(diffusion_gradient)

# Print extracted scanning sequences, sequence variants, and b-values
print(f"Extracted Scanning Sequences: {set(str(seq.value) for seq in scanning_sequences)}\n")
print(f"Extracted Sequence Variants: {set(str(var.value) for var in sequence_variants)}\n")
print(f"Extracted B-Values: {set(str(bval.value) for bval in b_values)}\n")
print(f"Extracted Voxel Sizes (X, Y, Z in mm): {set(voxel_sizes)}\n")
print(f"Extracted Repetition Times (TR): {set(str(tr) for tr in tr_values)} ms\n")
print(f"Extracted Echo Times (TE): {set(str(te) for te in te_values)} ms\n")
print(f"Extracted Field of View (FOV X, Y in mm): {set(str(f) for f in field_of_view)}\n")
print(f"Extracted Image Orientations: {set(str(ori) for ori in image_orientations)}\n")
print(f"Extracted Image Positions: {set(str(pos) for pos in image_positions)}\n")
print(f"Extracted Diffusion Gradient Directions: {set(str(grad.value) for grad in diffusion_gradients)}\n")
