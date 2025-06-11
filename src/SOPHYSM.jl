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
include("imaging/JNet/JNet.jl")
include("imaging/Threshold/ThresholdSegmentation.jl")

### Exported functions
export start_GUI, segment_image, start_tessellation

### Constants
workspace_dir = Observable(Workspace.get_workspace_dir())

### Main Functions
"""
    segment_image(segmentation_method::String, model_path::String, img_path::String, output_path::String;
                    rsize = (512, 512))

Segments an input image using the specified segmentation method and saves the predicted mask.

# Arguments:
- `segmentation_method`: Method to use for segmentation ("jnet" or "graph").
- `model_path`: Path to the BSON file where the U-Net model is saved (used only with "jnet").
- `img_path`: Path to the input image file to be segmented.
- `output_path`: Path where the predicted segmentation mask will be saved.
- `rsize`: Tuple specifying the dimensions for resizing. Default is (512, 512).
"""
function segment_image(segmentation_method::AbstractString,
    model_path::AbstractString,
    img_path::AbstractString,
    output_path::AbstractString;
    rsize = (512, 512))
    try
        # Convert QML strings to Julia strings
        method_str = String(segmentation_method)
        img_path_str = String(img_path)
        output_path_str = String(output_path)

        if Sys.iswindows() && img_path_str[1] == '/'
            img_path_str = img_path_str[2:end]
            output_path_str = output_path_str[2:end]
        end
        s_log_message("@info", img_path_str)
        s_log_message("@info", output_path_str)

        if method_str == "jnet"
            # Use JNet (neural network) segmentation
            model_path_str = String(model_path)
            s_log_message("@info", string("Using JNet segmentation with model: ", model_path_str))
            
            s_log_message("@info", string("Loading model from: ", model_path_str))
            model = JNet.load_model(model_path_str)
            s_log_message("@info", "Model loaded successfully.")

            # Load and preprocess the input image
            s_log_message("@info", string("Loading and preprocessing input image from: ", img_path_str))
            img = JNet.load_input(img_path_str; rsize = rsize)
            s_log_message("@info", string("Input image loaded and preprocessed with size: ", size(img)))

            # Add batch dimension to the image
            img = reshape(img, size(img)..., 1)

            # Generate the prediction
            s_log_message("@info", "Generating prediction...")
            try
                pred = JNet.prediction(model, img)
            catch e
                s_log_message("@error", string("An error occurred: ", first(string(e), 300)))
            end
            s_log_message("@info", string("Prediction generated with size: ", size(pred)))

            # Save the predicted mask
            s_log_message("@info", string("Saving predicted mask to: ", output_path_str))
            JNet.save_prediction(pred, output_path_str)
        
        elseif method_str == "graph"
            # Use Graph-based segmentation
            s_log_message("@info", "Using graph-based segmentation")
            
            # Get parameters from propmap if available, otherwise use defaults
            thresholdGray = haskey(propmap, "threshold_gray") ? propmap["threshold_gray"] : 0.5
            thresholdMarker = haskey(propmap, "threshold_marker") ? propmap["threshold_marker"] : 0.3
            min_threshold = haskey(propmap, "min_threshold") ? Float32(propmap["min_threshold"]) : Float32(50)
            max_threshold = haskey(propmap, "max_threshold") ? Float32(propmap["max_threshold"]) : Float32(1000)
            
            s_log_message("@info", string("Processing image with thresholds: Gray=", thresholdGray, 
                                         ", Marker=", thresholdMarker, 
                                         ", Min=", min_threshold, 
                                         ", Max=", max_threshold))
            
            # Apply graph-based segmentation
            ThresholdSegmentation.start_segmentation_SOPHYSM_graph(
                img_path_str,
                output_path_str,
                thresholdGray,
                thresholdMarker,
                min_threshold,
                max_threshold
            )
            
            # Generate paths for graph images
            base_path = splitext(output_path_str)[1]
            graph_vertex_path = base_path * "_graph_vertex.png"
            graph_edges_path = base_path * "_graph_edges.png"
            
            s_log_message("@info", "Graph-based segmentation completed")
            
        else
            s_log_message("@error", string("Unknown segmentation method: ", method_str))
            return
        end
        
        s_log_message("@info", "Segmentation saved successfully.")

    catch e
        s_log_message("@error", string("An error occurred: ", e))
        s_log_message("@error", string("Stacktrace: ", stacktrace(catch_backtrace())))
    end
end

function async_segment_image(segmentation_method::AbstractString,
    model_path::AbstractString,
    img_path::AbstractString,
    output_path::AbstractString;
    rsize = (512, 512))
    task = @task segment_image(segmentation_method, model_path, img_path, output_path; rsize = rsize)
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
    qmlfunction("start_tessellation", start_tessellation)
    
    # Propmap
    global propmap = JuliaPropertyMap()
    propmap["workspace_dir"] = workspace_dir
    propmap["selected_image_path"] = ""
    propmap["segmentation_update_text"] = ""
    propmap["model_bson_path"] = ""
    propmap["segmentation_method"] = ""
    propmap["threshold_gray"] = 0.5
    propmap["threshold_marker"] = 0.3
    propmap["min_threshold"] = 50.0
    propmap["max_threshold"] = 1000.0

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

"""
    start_tessellation(img_path::AbstractString, output_path::AbstractString)

Starts the tessellation process on the input image and saves the results.

# Arguments:
- `img_path`: Path to the input image file for tessellation.
- `output_path`: Path where the tessellation results will be saved.
"""
function start_tessellation(img_path::AbstractString, output_path::AbstractString)
    try
        # Convert QML strings to Julia strings
        img_path_str = String(img_path)
        output_path_str = String(output_path)

        if Sys.iswindows() && img_path_str[1] == '/'
            img_path_str = img_path_str[2:end]
            output_path_str = output_path_str[2:end]
        end

        s_log_message("@info", "Starting tessellation...")
        
        # Get parameters from propmap if available, otherwise use defaults
        thresholdGray = haskey(propmap, "threshold_gray") ? propmap["threshold_gray"] : 0.5
        thresholdMarker = haskey(propmap, "threshold_marker") ? propmap["threshold_marker"] : 0.3
        min_threshold = haskey(propmap, "min_threshold") ? Float32(propmap["min_threshold"]) : Float32(50)
        max_threshold = haskey(propmap, "max_threshold") ? Float32(propmap["max_threshold"]) : Float32(1000)
        
        ThresholdSegmentation.start_segmentation_SOPHYSM_tessellation(
            img_path_str,
            output_path_str,
            thresholdGray,
            thresholdMarker,
            min_threshold,
            max_threshold
        )
        
        # Generate paths for graph images
        base_path = splitext(output_path_str)[1]
        graph_vertex_path = base_path * "_graph_vertex.png"
        graph_edges_path = base_path * "_graph_edges.png"
        
        s_log_message("@info", "Tessellation completed successfully.")
    catch e
        s_log_message("@error", string("An error occurred during tessellation: ", e))
    end
end

end # SOPHYSM module
