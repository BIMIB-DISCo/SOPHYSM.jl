### SOPHYSM-- SOlid tumors PHYlogentic Spatial Modeller
### SOPHYSM.jl

module SOPHYSM

### Packages
using QML
using Observables
using JSON
using JHistint

### Included modules
include("Workspace.jl")
include("SOPHYSMLogger.jl")
include("imaging/Net.jl")

### Exported functions
export start_GUI

### Constants
workspace_dir = Observable(Workspace.get_workspace_dir())
selected_image_path = Observable("")
segmentation_update_text = Observable("{...}")

### Main Functions

"""
    segment_image(model_path::String, img_path::String, output_path::String;
                    rsize = (512, 512))

Segments an input image using a pre-trained U-Net model and saves the predicted
mask.

# Arguments:
- `model_path`: Path to the BSON file where the U-Net model is saved.
- `img_path`: Path to the input image file to be segmented.
- `output_path`: Path where the predicted segmentation mask will be saved.
- `rsize`: Tuple specifying the dimensions for resizing.
  Default is `(512, 512)`.
"""
function segment_image(model_path::String, img_path::String,
                        output_path::String;
                        rsize = (512, 512))
    # Load the model
    println("\nLoading model from: $model_path")
    model = Net.load_model(model_path)
    println("Model loaded successfully.")

    # Load and preprocess the input image
    println("\nLoading and preprocessing input image from: $img_path")
    img = Net.load_input(img_path; rsize = rsize)
    println("Input image loaded and preprocessed with size: ", size(img))

    # Add batch dimension to the image
    img = reshape(img, size(img)..., 1)

    # Generate the prediction
    println("\nGenerating prediction...")
    pred = Net.prediction(model, img)
    println("Prediction generated with size: ", size(pred))

    # Save the predicted mask
    println("\nSaving the predicted mask to: $output_path")
    Net.save_prediction(pred, output_path)
    println("Predicted mask saved successfully.")
end


### GUI logic
function start_GUI()
    s_open_logger()
    s_log_message("@info", "Start GUI")

    workspace_dir = Observable(Workspace.get_workspace_dir())
    Workspace.set_environment()
    selected_image_path = Observable("")

    qmlfile = joinpath(@__DIR__, "qml", "SOPHYSM.qml")

    ### QML Functions
    qmlfunction("download_single_slide_from_collection", async_download_single_slide_from_collection)
    qmlfunction("log_message", s_log_message)
    qmlfunction("display_img", Workspace.display_img)
    qmlfunction("UNet_Segmentation", UNet_Segmentation)
    
    # Propmap
    propmap = JuliaPropertyMap()
    propmap["workspace_dir"] = workspace_dir
    propmap["selected_image_path"] = selected_image_path
    propmap["segmentation_update_text"] = segmentation_update_text

    # Listening if there is any changes on workspace_dir
    on(workspace_dir) do x
        Workspace.set_workspace_dir(x)
        workspace_dir = Observable(Workspace.get_workspace_dir())
        s_log_message("@info", "WS Changed to $workspace_dir")
    end

    # Listening if there is any changes on the image the user selected
    on(selected_image_path) do x
        selected_image_path = x
    end

    # All keyword arguments to load are added as context properties on the QML side
    loadqml(qmlfile, propmap = propmap)
    
    exec_async()

    s_log_message("@info", "Close GUI")
    s_close_logger()
end

end # SOPHYSM module
