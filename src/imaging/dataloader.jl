function binarize_mask(mask, threshold = 0.5)
    return mask .> threshold
end

"""
    load_image(base::String, stub::String; rsize = (256, 256))

    Loads an image and its corresponding mask, resizing them to `rsize`.

    - `base`: Path to the base directory where the images and masks are stored.
    - `stub`: Prefix of the filenames for the image and mask.
    - `rsize`: Tuple specifying the dimensions to resize the images and masks
      to.

    Constructs the full paths for the image and mask files, loads them, resizes
    them, converts them to a channel view, reshapes them, and returns the
    processed image and mask.
"""
function load_image(img_path::String, mask_path::String; rsize = (512, 512))
    # Carica l'immagine
    img = load(img_path)
    img = imresize(img, rsize...)
    img = channelview(img)
    img = reshape(img, (size(img, 1), rsize..., 1))
    img = permutedims(img, (2, 3, 1, 4))
    #img = Float32.(img) / 255.0  # Normalizza tra 0 e 1

    # Carica la maschera
    mask = load(mask_path)
    mask = imresize(mask, rsize...)
    mask = channelview(mask)[1, :, :]
    mask = reshape(mask, (rsize..., 1, 1))
    mask = binarize_mask(mask, 0.004)

    # Controlla la dimensione dell'immagine e della maschera
    println("Dimensione dell'immagine (WHCB): ", size(img))
    println("Dimensione della maschera (WHCB): ", size(mask))

    # Verifica i valori unici nella maschera binarizzata
    println("Valori unici nella maschera binarizzata: ", unique(mask))

    return img, mask
end

"""
    create_augmenter()

    Creates an augmentation pipeline.

    Adds the following augmentations to the pipeline:
    - Rotation up to ±15 degrees.
    - Translation up to ±10 pixels.
    - Elastic transformation with 10 pixel deformation on a 3x3 grid.
"""
function create_augmenter()
    augmenter = Augmentor.Pipeline()

    Augmentor.add!(augmenter, Augmentor.Rotate(15))
    Augmentor.add!(augmenter, Augmentor.Translation(10.0, 10.0))

    return augmenter
end

"""
    augment_image(img, mask, augmenter)

    Applies the augmentation pipeline to the images and masks.

    - `img`: The input image to be augmented.
    - `mask`: The corresponding mask to be augmented.
    - `augmenter`: The augmentation pipeline.

    Returns the augmented image and mask.
"""
function create_mask_augmenter()
    augmenter = Augmentor.Pipeline()
    
    Augmentor.add!(augmenter,
                   Augmentor.Rotate(15, interpolation = Augmentor.NEAREST)
                  )
    Augmentor.add!(augmenter,
                   Augmentor.Translation(10.0, 10.0, interpolation = Augmentor.NEAREST)
                  )
    
    return augmenter
end

# Funzione per applicare l'augmentazione sincronizzata
function augment_image(img, mask, augmenter, mask_augmenter)
    # Genera un seed casuale
    seed = rand(UInt)

    # Imposta il seed su entrambi gli augmenter
    Augmentor.seed!(augmenter, seed)
    Augmentor.seed!(mask_augmenter, seed)

    # Applica l'augmentazione
    img_aug = Augmentor.apply(augmenter, img)
    mask_aug = Augmentor.apply(mask_augmenter, mask)

    return img_aug, mask_aug
end

"""
    load_batch(base::String;
                n = 10,
                rsize = (256, 256),
                augmenter = nothing)

    Loads a batch of `n` images and masks randomly sampled from the `base`
    directory.
    Applies augmentation if `augmenter` is provided.

    - `base`: Path to the base directory where the images and masks are stored.
    - `n`: Number of images and masks to load in the batch. Default is 10.
    - `rsize`: Tuple specifying the dimensions to resize the images and masks
      to. Default is (256, 256).
    - `augmenter`: The augmentation pipeline. Default is `nothing`.

    Returns the batch of images and masks as arrays of Float32.
"""
function load_batch(img_paths::Vector{String}, mask_paths::Vector{String};
                    batch_size::Int = 10, rsize = (512, 512),
                    augmenter = nothing, mask_augmenter = nothing)

    n = length(img_paths)
    indices = randperm(n)[1:batch_size]

    X = []
    Y = []

    for idx in indices
        img_path = img_paths[idx]
        mask_path = mask_paths[idx]

        img, mask = load_image(img_path, mask_path, rsize = rsize)

        if augmenter !== nothing && mask_augmenter !== nothing
            img, mask = augment_image(img, mask, augmenter, mask_augmenter)
        end

        push!(X, img)
        push!(Y, mask)
    end

    # Concatenazione lungo la dimensione del batch (4° dimensione)
    X_batch = cat(X...; dims=4)  # WHCB
    Y_batch = cat(Y...; dims=4)  # WHCB

    return X_batch, Y_batch
end

"""
    create_dataloader(base::String, batch_size::Int;
                        rsize = (256, 256),
                        augmenter = nothing
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
"""
function create_dataloader(base::String, batch_size::Int;
                            rsize = (256, 256),
                            augmenter = nothing)
    function data_gen()
        #load_batch(base, n = batch_size, rsize = rsize, augmenter = augmenter)
    end

    DataLoader(data_gen, batch_size=batch_size, shuffle = true)
end
