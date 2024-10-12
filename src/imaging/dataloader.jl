"""
    binarize_mask(mask, threshold = 0.5)

Binarizes the input mask based on a specified threshold.

- `mask`: The input mask array.
- `threshold`: Threshold value. Pixels with values less than or equal to this
  value are set to `true`, otherwise to `false`.

Returns a binary mask with `true` or `false` values.
"""
function binarize_mask(mask, threshold = 0.5)
    return .!(mask .> threshold)
end

"""
    load_image(img_path::String, mask_path::String; rsize = (512, 512))

Loads an image and its corresponding mask, resizing them to the specified
`rsize`.

- `img_path`: Path to the image file.
- `mask_path`: Path to the mask file.
- `rsize`: Tuple specifying the dimensions for resizing.
  Default is `(512, 512)`.

The function resizes the image and mask, converts the mask to grayscale, if
necessary, and binarizes the mask using a predefined threshold.

Returns:
- `img`: The processed image.
- `mask`: The binarized mask as a `Gray{Float32}` array.
"""
function load_image(img_path::String, mask_path::String; rsize = (512, 512))
    # Load and resize the image
    img = load(img_path)
    img = imresize(img, rsize...)

    # Load and resize the mask
    mask = load(mask_path)
    mask = imresize(mask, rsize...)

    # Convert the mask to grayscale, if necessary
    if eltype(mask) <: Gray
        mask_gray = mask
    elseif eltype(mask) <: RGB
        mask_gray = Gray.(mask)
    else
        error("Unsupported mask element type: $(eltype(mask))")
    end

    # Binarize the mask
    mask_binary = binarize_mask(Float32.(mask_gray), 0.004)
    mask_binary = Gray{Float32}.(mask_binary)

    return img, mask_binary
end

"""
    compute_weight_map(mask::Array{Float32, 2};
                       w0::Float32 = 10.0, sigma::Float32 = 5.0)

Computes the weight map for a given mask.

- `mask`: The binary mask array of shape `(H, W)`.
- `w0`: Constant to control the weight of the border emphasis term.
- `sigma`: Controls the decay rate of the border emphasis term.

Returns:
- `weight_map`: An array of the same shape as `mask` containing the weights
  for each pixel.
"""
function compute_weight_map(mask::Array{Float32, 2};
                            w0::Float32 = Float32(10.0),
                            sigma::Float32 = Float32(5.0))
    # Identify foreground and background
    foreground = mask .== Float32(0.0)
    background = mask .== Float32(1.0)

    # Compute the number of pixels for each class
    n_foreground = sum(foreground)
    n_background = sum(background)
    total_pixels = n_foreground + n_background

    if n_foreground == 0 || n_background == 0
        error("One of the classes has no pixels in the dataset.")
    end

    # Compute class weights inversely proportional to the class frequencies
    w_foreground = total_pixels / (2 * n_foreground)
    w_background = total_pixels / (2 * n_background)

    # Normalize the weights to maintain an average of 1
    sum_weights = w_foreground * (n_foreground / total_pixels) + 
                    w_background * (n_background / total_pixels)
    w_foreground /= sum_weights
    w_background /= sum_weights

    # Create the class weight map
    class_weights = zeros(Float32, size(mask))
    class_weights[foreground] .= w_foreground
    class_weights[background] .= w_background

    # Compute the distance transforms
    distance_foreground = distance_transform(feature_transform(.!foreground))
    distance_background = distance_transform(feature_transform(.!background))

    # Compute the border emphasis term
    border_term = w0 .* exp.(- (distance_foreground .+ distance_background).^2
                    ./ (2 * sigma^2))

    # Total weight map
    weight_map = class_weights .+ border_term

    return weight_map
end

"""
    augmenter(img, mask)

Applies augmentations to both the image and the mask using an augmentation
pipeline.

- `img`: The input image to augment.
- `mask`: The corresponding mask to augment.

The function defines an augmentation pipeline with various transformations,
applying them to both the image and the mask.

Returns:
- `img_array`: The augmented image array.
- `mask_array`: The augmented mask array.
"""
function augmenter(img, mask)
    # Define the augmentation pipeline
    pipeline = Either(ElasticDistortion(3, 3, 0.2; sigma = 10), NoOp()) |>
               Either(2 => Rotate([-90, 90, 180]), 1 => NoOp()) |>
               Either(2 => ColorJitter(0.8:0.1:1.2, -0.2:0.1:0.2),
                      1 => NoOp()) |>
               Either(2 => GaussianBlur(3), 1 => NoOp())

    # Apply the pipeline to the image and mask
    new_img, new_mask = augment(img => mask, pipeline)

    # Convert the augmented images to arrays suitable for the model
    if eltype(new_img) <: Gray
        img_array = Float32.(new_img)
        img_array = reshape(img_array,
                            size(img_array, 1),
                            size(img_array, 2),
                            1)
    elseif eltype(new_img) <: RGB
        img_array = Float32.(channelview(new_img))
        img_array = permutedims(img_array, (2, 3, 1))
    else
        error("Unsupported image element type after augmentation: ",
              "$(eltype(new_img))")
    end

    # Masks
    mask_array = binarize_mask(Float32.(new_mask), 0.004)
    mask_array = Float32.(mask_array)
    mask_array = reshape(mask_array,
                            size(mask_array, 1),
                            size(mask_array, 2),
                            1)

    return img_array, mask_array
end

"""
    dataloader(img_paths::Vector{String}, mask_paths::Vector{String};
               batch_size::Int = 4, rsize = (512, 512),
               augmentation_factor::Int = 0)

Loads images and masks in batches, with optional augmentations.

- `img_paths`: Vector of image file paths.
- `mask_paths`: Vector of mask file paths.
- `batch_size`: Number of images and masks per batch. Default is `4`.
- `rsize`: Tuple specifying the dimensions for resizing.
  Default is `(512, 512)`.
- `augmentation_factor`: Number of augmented versions to generate per image.
  Default is `0` (no augmentation).

The function loads images and masks, applies augmentations, if requested,
and collects images and masks into batches, concatenated along the fourth
dimension (batch dimension).

Augmented data are shuffled along with the original data to ensure that
augmented images do not all end up in the same batches.

Returns:
- `img_batches`: A list of image batches.
- `mask_batches`: A list of mask batches.
"""
function dataloader(img_paths::Vector{String},
                    mask_paths::Vector{String};
                    batch_size::Int = 1,
                    rsize = (512, 512),
                    augmentation_factor::Int = 0)
    println("\nTotal dataset size: ", length(img_paths))

    X = []
    Y = []
    W = []

    # Collect all images, masks and weight maps
    for idx in ProgressBar(1:length(img_paths))
        img_path = img_paths[idx]
        mask_path = mask_paths[idx]

        img, mask = load_image(img_path, mask_path, rsize = rsize)

        # Convert images to arrays suitable for the model
        if eltype(img) <: Gray
            img_array = Float32.(img)
            img_array = reshape(img_array,
                                size(img_array, 1),
                                size(img_array, 2),
                                1)
        elseif eltype(img) <: RGB
            img_array = Float32.(channelview(img))
            img_array = permutedims(img_array, (2, 3, 1))
        else
            error("Unsupported image element type: ",
                  "$(eltype(img))")
        end

        mask_array = Float32.(mask)
        mask_array = reshape(mask_array,
                                size(mask_array, 1),
                                size(mask_array, 2),
                                1)

        # Compute weight map
        weight_map = compute_weight_map(reshape(mask_array,
                                                size(mask_array, 1),
                                                size(mask_array, 2)),
                                        sigma = Float32(1.0))

        # Add channel dimension to weight map
        weight_map = reshape(weight_map,
                            size(weight_map, 1),
                            size(weight_map, 2),
                            1)
        weight_map = Float32.(weight_map)

        # Add the original image, mask, and weight map
        push!(X, img_array)
        push!(Y, mask_array)
        push!(W, weight_map)

        # Apply augmentations, if requested
        if augmentation_factor > 0
            for _ in 1 : augmentation_factor
                img_aug, mask_aug = augmenter(img, mask)

                # Compute weight map for augmented mask
                weight_map_aug = compute_weight_map(reshape(mask_aug,
                                                            size(mask_aug, 1),
                                                            size(mask_aug, 2)),
                                                    sigma = Float32(1.0))
                weight_map_aug = reshape(weight_map_aug,
                                            size(weight_map_aug, 1),
                                            size(weight_map_aug, 2),
                                            1)

                push!(X, img_aug)
                push!(Y, mask_aug)
                push!(W, weight_map_aug)
            end
        end
    end

    println("Creating batches...")

    # Shuffle the data
    total_samples = length(X)
    indices = randperm(total_samples)

    X_shuffled = X[indices]
    Y_shuffled = Y[indices]
    W_shuffled = W[indices]

    # Create batches from the shuffled data
    img_batches = []
    mask_batches = []
    weight_batches = []
    batch_num = 1

    # Calculate total number of batches
    num_batches = ceil(Int, length(X_shuffled) / batch_size)

    # Process all batches
    for i in ProgressBar(1:num_batches)
        batch_num += 1

        start_idx = (i - 1) * batch_size + 1
        end_idx = min(i * batch_size, length(X_shuffled))

        img_batch = cat(X_shuffled[start_idx:end_idx]...; dims = 4)
        mask_batch = cat(Y_shuffled[start_idx:end_idx]...; dims = 4)
        weight_batch = cat(W_shuffled[start_idx:end_idx]...; dims = 4)

        push!(img_batches, img_batch)
        push!(mask_batches, mask_batch)
        push!(weight_batches, weight_batch)
    end

    return img_batches, mask_batches, weight_batches
end
