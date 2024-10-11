module JNet

using Augmentor
using BSON: @save, @load
using CUDA
using FileIO
using Flux
using Flux: @functor
using Flux.Optimise: Momentum, update!
using Images
using ProgressBars
using Random
using Printf
using Statistics

include("dataloader.jl")
include("model.jl")
include("training.jl")

export load_model, load_input, prediction, save_prediction

"""
    load_model(filepath::String)

Loads a U-Net model from a BSON file.

# Arguments:
- `filepath`: Path to the BSON file where the model is saved.

# Returns:
- The U-Net model loaded from the specified file.
"""
function load_model(filepath::String)
    model = nothing
    @load filepath model

    return model
end

"""
    load_input(img_path::String; rsize = (512, 512))

Processes a single image to prepare it for input into the U-Net model without
adding a batch dimension.

- `img_path`: Path to the image file.
- `rsize`: Tuple specifying the dimensions for resizing.
  Default is `(512, 512)`.

Returns:
- `img_array`: The processed image array ready for input into the model.
"""
function load_input(img_path::AbstractString; rsize = (512, 512))
    # Load and resize the image
    img = load(img_path)
    img = imresize(img, rsize...)

    # Convert images to arrays suitable for the model
    if eltype(img) <: Gray
        img_array = Float16.(img)
        img_array = reshape(img_array,
                            size(img_array, 1),
                            size(img_array, 2),
                            1)
    elseif eltype(img) <: RGB
        img_array = Float16.(channelview(img))
        img_array = permutedims(img_array, (2, 3, 1))
    else
        error("Unsupported image element type: ",
              "$(eltype(img))")
    end

    return img_array
end

"""
    prediction(model, img)

Generates a predicted segmentation mask from a given model and input image.

# Arguments:
- `model`: The U-Net model used for predictions.
- `img`: A 4D array representing the input image.

# Returns:
- A 2D array representing the predicted segmentation mask with values between 0
  and 1.
"""
function prediction(model, img)
    # Get the model predictions
    y_hat = model(img)

    # Apply softmax to obtain probabilities
    y_hat_softmax = softmax(y_hat; dims = 3)

    # Select the class with the highest probability
    y_pred = argmax(y_hat_softmax, dims = 3)
    y_pred = getindex.(y_pred, 3)

    # Remove the batch dimension
    y_pred = dropdims(y_pred, dims = 4)

    # Convert predicted class to float between 0 and 1
    y_pred = Float32.(y_pred .- 1)

    return y_pred
end

"""
    save_prediction(prediction::Array, filepath::String)

Saves the predicted segmentation mask as an image.

# Arguments:
- `prediction`: A 2D array representing the predicted segmentation mask.
- `filepath`: The path where the image will be saved, including the filename.
"""
function save_prediction(prediction::Array, filepath::AbstractString)
    # Save the result as an image
    save(filepath, prediction)
    println("Prediction saved at: ", filepath)
end

end # module
