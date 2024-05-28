using Flux.Data: DataLoader
using Images
using FileIO
using Random
using Augmentor

#=
    load_image(base::String, stub::String; rsize=(256, 256))

    Loads an image and its corresponding mask, resizing them to `rsize`.

    - `base`: Path to the base directory where the images and masks are stored.
    - `stub`: Prefix of the filenames for the image and mask.
    - `rsize`: Tuple specifying the dimensions to resize the images and masks
      to.

    Constructs the full paths for the image and mask files, loads them, resizes
    them, converts them to a channel view, reshapes them, and returns the
    processed image and mask.
=#
function load_image(base::String, stub::String; rsize = (256, 256))
    im_path = joinpath(base, stub * "_im.tif")
    cr_path = joinpath(base, stub * "_cr.tif")

    img = load(im_path)
    mask = load(cr_path)

    img = imresize(img, rsize...)
    mask = imresize(mask, rsize...)

    img = channelview(img)
    mask = channelview(mask)

    img = reshape(img, rsize..., 1, 1)
    mask = reshape(mask, rsize..., 1, 1)

    return img, mask
end

#=
    create_augmenter()

    Creates an augmentation pipeline.

    Adds the following augmentations to the pipeline:
    - Rotation up to ±15 degrees.
    - Translation up to ±10 pixels.
    - Elastic transformation with 10 pixel deformation on a 3x3 grid.
=#
function create_augmenter()
    augmenter = Augmentor.Pipeline()
    Augmentor.add!(augmenter, Augmentor.Rotate(15))
    Augmentor.add!(augmenter, Augmentor.Translation(10.0, 10.0))
    Augmentor.add!(augmenter, Augmentor.ElasticTransform(10.0, 3, 3))
    return augmenter
end

#=
    augment_image(img, mask, augmenter)

    Applies the augmentation pipeline to the images and masks.

    - `img`: The input image to be augmented.
    - `mask`: The corresponding mask to be augmented.
    - `augmenter`: The augmentation pipeline.

    Returns the augmented image and mask.
=#
function augment_image(img, mask, augmenter)
    img_aug = Augmentor.apply(augmenter, img)
    mask_aug = Augmentor.apply(augmenter, mask)
    return img_aug, mask_aug
end

#=
    load_batch(base::String; n=10, rsize=(256, 256), augmenter=nothing)

    Loads a batch of `n` images and masks randomly sampled from the `base`
    directory.
    Applies augmentation if `augmenter` is provided.

    - `base`: Path to the base directory where the images and masks are stored.
    - `n`: Number of images and masks to load in the batch. Default is 10.
    - `rsize`: Tuple specifying the dimensions to resize the images and masks
      to. Default is (256, 256).
    - `augmenter`: The augmentation pipeline. Default is `nothing`.

    Returns the batch of images and masks as arrays of Float32.
=#
function load_batch(base::String; n=10, rsize=(256, 256), augmenter=nothing)
    all_files = readdir(base)
    all_stubs = unique(filter(x -> endswith(x, "_im.tif"), all_files))
    all_stubs = map(x -> replace(x, "_im.tif" => ""), all_stubs)
    
    selected_stubs = Random.sample(all_stubs, n, replace=false)
    
    X = []
    Y = []

    for stub in selected_stubs
        img, mask = load_image(base, stub, rsize=rsize)
        if augmenter !== nothing
            img, mask = augment_image(img, mask, augmenter)
        end

        push!(X, img)
        push!(Y, mask)
    end
    
    X = hcat(X...) |> Array{Float32}
    Y = hcat(Y...) |> Array{Float32}

    return X, Y
end

#=
    create_dataloader(base::String, batch_size::Int;
                        rsize=(256, 256),
                        augmenter=nothing
    )

    Creates a DataLoader to iterate over the data in batches.

    - `base`: Path to the base directory where the images and masks are stored.
    - `batch_size`: Number of images and masks to load in each batch.
    - `rsize`: Tuple specifying the dimensions to resize the images and masks
      to. Default is (256, 256).
    - `augmenter`: The augmentation pipeline. Default is `nothing`.

    Defines a data generator function that loads a batch of data using
    `load_batch`
    and returns a DataLoader that shuffles the data for each epoch.
=#
function create_dataloader(base::String, batch_size::Int;
                            rsize = (256, 256),
                            augmenter = nothing)
    function data_gen()
        load_batch(base, n=batch_size, rsize=rsize, augmenter=augmenter)
    end

    DataLoader(data_gen, batch_size=batch_size, shuffle=true)
end
