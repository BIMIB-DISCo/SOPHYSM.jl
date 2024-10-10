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
export start_GUI, segment_iamge

### Constants
global propmap = JuliaPropertyMap()
workspace_dir = Observable(Workspace.get_workspace_dir())

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
function segment_image(model_path::AbstractString,
    img_path::AbstractString,
    output_path::AbstractString;
    rsize = (512, 512))
    try
        # Load the model
        model_path = "/Users/chriselleannguillermo/Downloads/best_model.bson"

        if Sys.iswindows() && img_path[1] == '/'
            img_path = img_path[2:end]
            output_path = output_path[2:end]
        end
        s_log_message("@info", img_path)

        s_log_message("@info", string("Loading model from: ", model_path))
        model = Net.load_model(model_path)
        s_log_message("@info", "Model loaded successfully.")

        # Load and preprocess the input image
        s_log_message("@info", string("Loading and preprocessing input image from: ", img_path))
        img = Net.load_input(img_path; rsize = rsize)
        s_log_message("@info", string("Input image loaded and preprocessed with size: ", size(img)))

        # Add batch dimension to the image
        img = reshape(img, size(img)..., 1)

        # Generate the prediction
        s_log_message("@info", "Generating prediction...")
        pred = Net.prediction(model, img)
        s_log_message("@info", string("Prediction generated with size: ", size(pred)))

        # Save the predicted mask
        s_log_message("@info", string("Saving predicted mask to: ", output_path))
        Net.save_prediction(pred, output_path)
        s_log_message("@info", "Predicted mask saved successfully.")
        propmap["segmentation_update_text"] = "Predicted mask saved successfully."

    catch e
        s_log_message("@error", string("An error occurred: ", e))
        s_log_message("@error", string("Stacktrace: ", stacktrace(catch_backtrace())))
        propmap["segmentation_update_text"] = "Predicted mask saved successfully."
    end
end

function async_segment_image(model_path::AbstractString,
    img_path::AbstractString,
    output_path::AbstractString;
    rsize = (512, 512))
    task = @task segment_image(model_path, img_path, output_path: rsize(512, 512))
    schedule(task)
    return task
end

"""
    start_GUI()

Starts SOPHYSM UI.

"""
### GUI logic
function start_GUI()
    s_open_logger()
    s_log_message("@info", "Start GUI")

    workspace_dir = Observable(Workspace.get_workspace_dir())
    Workspace.set_environment()

    qmlfile = joinpath(@__DIR__, "qml", "SOPHYSM.qml")

    ### QML Functions
    qmlfunction("download_single_slide_from_collection", async_download_single_slide_from_collection)
    qmlfunction("log_message", s_log_message)
    qmlfunction("display_img", Workspace.display_img)
    qmlfunction("segment_image", segment_image)
    
    # Propmap
    propmap["workspace_dir"] = workspace_dir
    propmap["selected_image_path"] = selected_image_path
    propmap["segmentation_update_text"] = segmentation_update_text

    # Listening if there is any changes on workspace_dir
    on(workspace_dir) do x
        Workspace.set_workspace_dir(x)
        workspace_dir = Observable(Workspace.get_workspace_dir())
        s_log_message("@info", "WS Changed to $workspace_dir")
    end

    # All keyword arguments to load are added as context properties on the QML side
    loadqml(qmlfile, propmap = propmap)
    
    exec_async()

    s_log_message("@info", "Close GUI")
    s_close_logger()
end

end # SOPHYSM module
