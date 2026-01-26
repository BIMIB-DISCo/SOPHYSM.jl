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
export start_GUI, run_segmentation_pure, start_tessellation

### Constants
const workspace_dir = Observable(Workspace.get_workspace_dir())

### Main Functions

"""
    run_segmentation_pure(segmentation_method::AbstractString, model_path::AbstractString, 
                          img_path::AbstractString, output_path::AbstractString; rsize = (512, 512))

Executes the segmentation process synchronously and returns the output path.
Designed to be memory-safe by avoiding direct UI interaction during computation.

# Arguments:
- `segmentation_method`: Method to use ("jnet" or "graph").
- `model_path`: Path to the .bson model (only for jnet).
- `img_path`: Input image path.
- `output_path`: Output destination path.
"""
function run_segmentation_pure(segmentation_method::AbstractString,
    model_path::AbstractString,
    img_path::AbstractString,
    output_path::AbstractString;
    rsize=(512, 512))

    # Pre-computation cleanup to ensure memory stability
    GC.gc()

    try
        # Convert QML strings to Julia strings
        method_str = String(segmentation_method)
        model_str = String(model_path)
        img_str = String(img_path)
        output_str = String(output_path)

        # Windows path normalization
        if Sys.iswindows() && startswith(img_str, "/")
            img_str = img_str[2:end]
            output_str = output_str[2:end]
        end

        s_log_message("@info", string("Starting segmentation on: ", img_str))

        if method_str == "jnet"
            # Use JNet (neural network) segmentation
            s_log_message("@info", "Using JNet segmentation...")

            model = JNet.load_model(model_str)
            img = JNet.load_input(img_str; rsize=rsize)

            # Reshape for prediction
            img = reshape(img, size(img)..., 1)

            s_log_message("@info", "Generating prediction...")
            pred = JNet.prediction(model, img)

            JNet.save_prediction(pred, output_str)

        elseif method_str == "graph"
            # Use Graph-based segmentation
            s_log_message("@info", "Using graph-based segmentation...")

            # Retrieve parameters safely
            tGray = 0.5
            tMarker = 0.3
            minT = 50.0
            maxT = 1000.0

            if isdefined(SOPHYSM, :propmap)
                tGray = haskey(propmap, "threshold_gray") ? Float64(propmap["threshold_gray"]) : 0.5
                tMarker = haskey(propmap, "threshold_marker") ? Float64(propmap["threshold_marker"]) : 0.3
                minT = haskey(propmap, "min_threshold") ? Float64(propmap["min_threshold"]) : 50.0
                maxT = haskey(propmap, "max_threshold") ? Float64(propmap["max_threshold"]) : 1000.0
            end

            s_log_message("@info", string("Graph Params: Gray=", tGray, ", Marker=", tMarker, ", Min=", minT, ", Max=", maxT))

            ThresholdSegmentation.start_segmentation_SOPHYSM_graph(
                img_str,
                output_str,
                tGray,
                tMarker,
                Float32(minT),
                Float32(maxT)
            )
        else
            s_log_message("@error", string("Unknown segmentation method: ", method_str))
            return ""
        end

        s_log_message("@info", string("Saving result to: ", output_str))

        # Ensure file system flush and memory cleanup
        sleep(0.1)
        GC.gc()

        return output_str

    catch e
        s_log_message("@error", string("An error occurred: ", e))
        s_log_message("@error", string("Stacktrace: ", stacktrace(catch_backtrace())))
        return ""
    end
end

"""
    async_download_single_slide_from_collection(args...)

Mock function for download logic.
"""
function async_download_single_slide_from_collection(args...)
    s_log_message("@info", "Requested download (mock).")
    return 0
end

"""
    start_GUI()

Starts SOPHYSM UI.
"""
function start_GUI()
    s_open_logger()
    s_log_message("@info", "Start GUI")

    Workspace.set_environment()

    qmlfile = joinpath(@__DIR__, "qml", "SOPHYSM.qml")

    ### QML Functions
    qmlfunction("download_single_slide_from_collection", async_download_single_slide_from_collection)
    qmlfunction("log_message", s_log_message)
    # Note: display_img is handled natively by QML Image component for stability

    qmlfunction("run_segmentation_pure", run_segmentation_pure)
    qmlfunction("start_tessellation", start_tessellation)

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

    on(workspace_dir) do x
        Workspace.set_workspace_dir(x)
        s_log_message("@info", "WS Changed to $x")
    end

    loadqml(qmlfile, propmap=propmap)
    exec_async()

    s_log_message("@info", "Close GUI")
    s_close_logger()
end

"""
    start_tessellation(img_path::AbstractString, output_path::AbstractString)

Starts the tessellation process.
"""
function start_tessellation(img_path::AbstractString, output_path::AbstractString)
    try
        img_path_str = String(img_path)
        output_path_str = String(output_path)

        if Sys.iswindows() && startswith(img_path_str, "/")
            img_path_str = img_path_str[2:end]
            output_path_str = output_path_str[2:end]
        end

        s_log_message("@info", "Starting tessellation...")

        tGray = get(propmap, "threshold_gray", 0.5)
        tMarker = get(propmap, "threshold_marker", 0.3)
        minT = get(propmap, "min_threshold", 50.0)
        maxT = get(propmap, "max_threshold", 1000.0)

        # Uses the Graph logic as per working configuration
        ThresholdSegmentation.start_segmentation_SOPHYSM_graph(
            img_path_str, output_path_str, Float64(tGray), Float64(tMarker), Float32(minT), Float32(maxT)
        )

        s_log_message("@info", "Tessellation completed.")

    catch e
        s_log_message("@error", string("Tessellation error: ", e))
    end
end

end # module SOPHYSM