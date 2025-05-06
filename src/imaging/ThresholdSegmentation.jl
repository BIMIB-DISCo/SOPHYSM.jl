module ThresholdSegmentation

using FileIO
using Images

export segment_with_threshold, load_input, save_segmentation

"""
    load_input(img_path::AbstractString; rsize = (512, 512))

Loads and preprocesses an image for threshold-based segmentation.

# Arguments:
- `img_path`: Path to the image file.
- `rsize`: Tuple specifying the dimensions for resizing. Default is (512, 512).

# Returns:
- Processed image as a grayscale array.
"""
function load_input(img_path::AbstractString; rsize = (512, 512))
    # Load and resize the image
    img = load(img_path)
    img = imresize(img, rsize...)
    
    # Convert to grayscale if needed
    if eltype(img) <: RGB
        img = Gray.(img)
    end
    
    # Convert to array
    img_array = Float32.(img)
    
    return img_array
end

"""
    segment_with_threshold(img_array::Array; threshold = 0.5)

Segments an image using a simple threshold method.

# Arguments:
- `img_array`: Input image array.
- `threshold`: Threshold value between 0 and 1. Default is 0.5.

# Returns:
- Binary mask after applying threshold.
"""
function segment_with_threshold(img_array::Array; threshold = 0.5)
    # Apply threshold
    mask = img_array .> threshold
    
    # Return binary mask as Float32 for compatibility with JNet output
    return Float32.(mask)
end

"""
    save_segmentation(segmentation::Array, filepath::AbstractString)

Saves the segmentation mask as an image.

# Arguments:
- `segmentation`: A 2D array representing the segmentation mask.
- `filepath`: The path where the image will be saved.
"""
function save_segmentation(segmentation::Array, filepath::AbstractString)
    save(filepath, segmentation)
    println("Segmentation saved at: ", filepath)
end

end # module
