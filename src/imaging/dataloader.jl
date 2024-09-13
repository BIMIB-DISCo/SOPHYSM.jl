"""
    binarize_mask(mask, threshold = 0.5)

    Binarizes the input mask based on a specified threshold.

    - `mask`: The input mask array.
    - `threshold`: A threshold value. Pixels greater than this value are set to
      1 (True), and pixels less than or equal to this value are set to 0
      (False).

    Returns a binary mask with values 0 or 1.
"""
function binarize_mask(mask, threshold = 0.5)
    return mask .> threshold
end

"""
    load_image(img_path::String, mask_path::String; rsize = (512, 512))

    Loads an image and its corresponding mask, resizing them to the specified
    `rsize`.

    - `img_path`: Path to the image file (usually in JPG format).
    - `mask_path`: Path to the mask file (usually in BMP format).
    - `rsize`: Tuple specifying the dimensions to resize the images and masks
       to. Default is (512, 512).

    The function resizes the image and mask, converts them to channel view (for
    image processing),
    reshapes them to match the WHC format, and binarizes the mask using a
    predefined threshold.

    Prints out the size of the image and mask, and checks for unique values in
    the binarized mask.

    Returns:
    - `img`: The processed image with dimensions (width, height, channels).
    - `mask`: The binarized mask with dimensions (width, height, 1).
"""
function load_image(img_path::String, mask_path::String; rsize = (512, 512))
    # Load and process the image
    img = load(img_path)
    img = imresize(img, rsize...)
    img = channelview(img)
    img = reshape(img, (size(img, 1), rsize...))
    img = permutedims(img, (2, 3, 1))

    # Load and process the mask
    mask = load(mask_path)
    mask = imresize(mask, rsize...)
    mask = channelview(mask)[1, :, :]
    mask = reshape(mask, (rsize..., 1))
    mask = binarize_mask(mask, 0.004)

    # Check sizes and values
    println("Image size: ", size(img))
    println("Mask size: ", size(mask))
    println("Unique values in binarized mask: ", unique(mask))

    return img, mask
end

"""
    create_augmenter()

    Creates an augmentation pipeline for images.

    The pipeline includes:
    - Rotation of up to ±15 degrees.
    - Translation (shifting) of up to ±10 pixels in both x and y directions.

    Returns:
    - The configured augmentation pipeline for images.
"""
function create_augmenter()
    augmenter = Augmentor.Pipeline()

    Augmentor.add!(augmenter, Augmentor.Rotate(15))
    Augmentor.add!(augmenter, Augmentor.Translation(10.0, 10.0))

    return augmenter
end

"""
    create_mask_augmenter()

    Creates an augmentation pipeline for masks.

    The pipeline includes:
    - Rotation of up to ±15 degrees with nearest neighbor interpolation.
    - Translation (shifting) of up to ±10 pixels with nearest neighbor
      interpolation.

    Nearest neighbor interpolation is used to ensure that mask values (0 and 1)
    are preserved.

    Returns:
    - The configured augmentation pipeline for masks.
"""
function create_mask_augmenter()
    augmenter = Augmentor.Pipeline()

    Augmentor.add!(augmenter,
                   Augmentor.Rotate(15, interpolation = Augmentor.NEAREST))

    Augmentor.add!(augmenter,
                   Augmentor.Translation(10.0,
                                         10.0,
                                         interpolation = Augmentor.NEAREST))

    return augmenter
end

"""
    augment_image(img, mask, augmenter, mask_augmenter)

    Applies augmentations to both the image and mask using separate pipelines.

    - `img`: The input image to be augmented.
    - `mask`: The corresponding mask to be augmented.
    - `augmenter`: The augmentation pipeline for the image.
    - `mask_augmenter`: The augmentation pipeline for the mask.

    Both pipelines are synchronized using a shared random seed to ensure that
    the augmentations applied to the image and mask are aligned.

    Returns:
    - `img_aug`: The augmented image.
    - `mask_aug`: The augmented mask.
"""
function augment_image(img, mask, augmenter, mask_augmenter)
    seed = rand(UInt)  # Generate a random seed

    # Set the same seed for both augmenters to synchronize augmentations
    Augmentor.seed!(augmenter, seed)
    Augmentor.seed!(mask_augmenter, seed)

    # Apply augmentations
    img_aug = Augmentor.apply(augmenter, img)
    mask_aug = Augmentor.apply(mask_augmenter, mask)

    return img_aug, mask_aug
end

"""
    dataloader(img_paths::Vector{String},
               mask_paths::Vector{String};
               batch_size::Int = 10,
               rsize = (512, 512),
               augmenter = nothing,
               mask_augmenter = nothing)

    Loads images and masks in batches, with optional augmentations.

    - `img_paths`: Vector of paths to the image files.
    - `mask_paths`: Vector of paths to the mask files.
    - `batch_size`: Number of images and masks per batch. Default is 10.
    - `rsize`: Tuple specifying the dimensions to resize the images and masks
       to. Default is (512, 512).
    - `augmenter`: The augmentation pipeline for images. Default is `nothing`.
    - `mask_augmenter`: The augmentation pipeline for masks. Default is
      `nothing`.

    The function loads the images and masks, applies augmentations if provided,
    and collects
    the images and masks into batches, which are concatenated along the 4th
    dimension (batch dimension).

    Returns:
    - `img_batches`: A list of image batches.
    - `mask_batches`: A list of mask batches.
"""
function dataloader(img_paths::Vector{String},
                    mask_paths::Vector{String};
                    batch_size::Int = 10,
                    rsize = (512, 512),
                    augmenter = nothing,
                    mask_augmenter = nothing)

    img_batches = []
    mask_batches = []
    X = []
    Y = []
    counter = 0
    i = 1

    dataset_size = length(img_paths)
    println("Total dataset size: ", dataset_size)

    indices = randperm(dataset_size)  # Shuffle the dataset

    for idx in indices
        counter += 1
        println("\nProcessing image #", counter)

        img_path = img_paths[idx]
        mask_path = mask_paths[idx]

        img, mask = load_image(img_path, mask_path, rsize = rsize)

        # Apply augmentations, if provided
        if augmenter !== nothing && mask_augmenter !== nothing
            img, mask = augment_image(img, mask, augmenter, mask_augmenter)
        end

        push!(X, img)
        push!(Y, mask)

        # When batch is full, concatenate and store the batch
        if counter % batch_size == 0 || counter == dataset_size
            println("Storing batch #", i)
            i += 1

            img_batches = push!(img_batches, cat(X...; dims = 4))
            mask_batches = push!(mask_batches, cat(Y...; dims = 4))

            empty!(X)  # Clear temporary image list
            empty!(Y)  # Clear temporary mask list
        end
    end

    return (img_batches, mask_batches)
end
