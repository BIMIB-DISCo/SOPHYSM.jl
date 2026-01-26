### SOPHYSM-- SOlid tumors PHYlogentic Spatial Modeller
### SOPHYSM.jl

module SOPHYSM

### Packages
using QML
using Observables
using JSON
using JHistint
using Base.Threads

### Included modules
include("Workspace.jl")
include("SOPHYSMLogger.jl")
include("imaging/JNet/JNet.jl")
include("imaging/Threshold/ThresholdSegmentation.jl")

### Exported functions
export start_GUI, run_segmentation_pure, start_tessellation, start_async_job, check_job_status, check_system_ready, perform_warmup

### Constants
const workspace_dir = Observable(Workspace.get_workspace_dir())

# ============================================================
# SHARED STATE (THREAD SAFE)
# ============================================================
const JOB_RESULT = Ref{String}("")
const IS_BUSY = Ref{Bool}(false)
const SYSTEM_READY = Ref{Bool}(false)

"""
    perform_warmup()

Executes a mock segmentation in a background thread to force JIT compilation
of heavy functions before the user interacts with the GUI.
This prevents the UI from freezing on the first real operation.
"""
function perform_warmup()
    s_log_message("@info", "System: Starting JIT Warm-up in background...")

    Base.Threads.@spawn begin
        try
            # 1. Create a dummy image using standard Julia arrays
            # JNet and ThresholdSegmentation work with Float32/64 Arrays
            dummy_path = joinpath(tempdir(), "sophysm_warmup.png")
            dummy_out = joinpath(tempdir(), "sophysm_warmup_seg.png")

            # Create a 512x512 random array
            dummy_img = rand(Float32, 512, 512)

            # 2. Save the image to disk using JNet (which already has dependencies)
            JNet.save_prediction(dummy_img, dummy_path)

            # 3. Execute the Graph algorithm
            # This forces compilation of the heaviest path
            ThresholdSegmentation.start_segmentation_SOPHYSM_graph(
                dummy_path, dummy_out, 0.5, 0.3, 50.0f0, 1000.0f0
            )

            # 4. Cleanup
            rm(dummy_path, force=true)
            rm(dummy_out, force=true)

            s_log_message("@info", "System: Warm-up completed. Engine ready.")
        catch e
            # Non-critical error during warmup
            s_log_message("@warn", string("System: Warm-up partial skip: ", e))
        finally
            SYSTEM_READY[] = true
        end
    end
    return 0
end

"""
    check_system_ready() -> Bool

Checks if the JIT warm-up process has completed.
"""
function check_system_ready()
    return SYSTEM_READY[]
end

"""
    run_segmentation_pure(segmentation_method::AbstractString, model_path::AbstractString, 
                          img_path::AbstractString, output_path::AbstractString; rsize = (512, 512))

Executes the segmentation process synchronously on a dedicated thread and returns the output path.
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

    # Micro-sleep to allow UI context switch before heavy calculation
    sleep(0.01)

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

        # Skip logging/logic if this is the dummy warmup call
        if img_str == "dummy_in"
            return ""
        end

        s_log_message("@info", string("Starting segmentation on: ", img_str))

        if method_str == "jnet"
            # Use JNet (neural network) segmentation
            s_log_message("@info", string("Using JNet segmentation with model: ", model_str))

            model = JNet.load_model(model_str)
            s_log_message("@info", "Model loaded successfully.")

            # Load and preprocess
            img = JNet.load_input(img_str; rsize=rsize)
            s_log_message("@info", "Input image loaded and preprocessed.")

            # Add batch dimension
            img = reshape(img, size(img)..., 1)

            s_log_message("@info", "Generating prediction...")
            pred = JNet.prediction(model, img)

            s_log_message("@info", string("Saving predicted mask to: ", output_str))
            JNet.save_prediction(pred, output_str)

        elseif method_str == "graph"
            # Use Graph-based segmentation
            s_log_message("@info", "Using graph-based segmentation...")

            # Retrieve parameters safely
            # Note: We use local fallbacks to avoid threading issues with global propmap
            tGray = 0.5
            tMarker = 0.3
            minT = 50.0
            maxT = 1000.0

            if isdefined(SOPHYSM, :propmap)
                try
                    tGray = haskey(propmap, "threshold_gray") ? Float64(propmap["threshold_gray"]) : 0.5
                    tMarker = haskey(propmap, "threshold_marker") ? Float64(propmap["threshold_marker"]) : 0.3
                    minT = haskey(propmap, "min_threshold") ? Float64(propmap["min_threshold"]) : 50.0
                    maxT = haskey(propmap, "max_threshold") ? Float64(propmap["max_threshold"]) : 1000.0
                catch
                    # Ignore concurrent access errors, use defaults
                end
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

        s_log_message("@info", "Segmentation saved successfully.")

        # Ensure file system flush
        sleep(0.1)

        # Cleanup memory AFTER the heavy work is done
        GC.gc()

        return output_str

    catch e
        # Suppress errors during dummy warmup
        if img_arg != "dummy_in"
            s_log_message("@error", string("An error occurred: ", e))
            showerror(stdout, e, catch_backtrace())
        end
        return "ERROR"
    end
end

"""
    start_async_job(method, model, img, output)

Initiates the segmentation process on a separate thread using `Base.Threads.@spawn`.
This prevents the GUI from freezing during computation.
"""
function start_async_job(method, model, img, output)
    if IS_BUSY[]
        s_log_message("@warn", "Job rejected: System is busy.")
        return -1
    end

    if Threads.nthreads() == 1
        s_log_message("@warn", "WARNING: Julia is running with 1 thread. GUI will freeze. Restart with 'julia -t auto'")
    end

    s_log_message("@info", "Starting job on background thread.")
    IS_BUSY[] = true
    JOB_RESULT[] = ""

    # Spawn task on a separate thread
    Base.Threads.@spawn begin
        try
            path = run_segmentation_pure(method, model, img, output)
            JOB_RESULT[] = path
        catch err
            s_log_message("@error", string("Async job error: ", err))
            JOB_RESULT[] = "ERROR"
        finally
            IS_BUSY[] = false
            s_log_message("@info", "Job finished. Result ready.")
        end
    end

    return 0
end

"""
    check_job_status() -> String

Polled by QML to check if the background job is finished.
Returns an empty string if busy, or the file path if finished.
"""
function check_job_status()
    if IS_BUSY[]
        return ""
    end

    res = JOB_RESULT[]

    if res != ""
        # Reset after reading
        JOB_RESULT[] = ""
    end

    return res
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

    n_threads = Threads.nthreads()
    s_log_message("@info", string("Start GUI (Available Threads: ", n_threads, ")"))

    Workspace.set_environment()

    qmlfile = joinpath(@__DIR__, "qml", "SOPHYSM.qml")

    ### QML Functions
    qmlfunction("download_single_slide_from_collection", async_download_single_slide_from_collection)
    qmlfunction("log_message", s_log_message)

    # Threading & Polling Functions
    qmlfunction("start_async_job", start_async_job)
    qmlfunction("check_job_status", check_job_status)
    qmlfunction("check_system_ready", check_system_ready)
    qmlfunction("perform_warmup", perform_warmup)

    qmlfunction("start_tessellation", start_tessellation)

    # Propmap definition
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

    # Note: Warmup is triggered by QML after load

    exec_async()

    s_log_message("@info", "Close GUI")
    s_close_logger()
end

"""
    start_tessellation(img_path::AbstractString, output_path::AbstractString)

Starts the tessellation process on the input image.
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

        ThresholdSegmentation.start_segmentation_SOPHYSM_graph(
            img_path_str, output_path_str, Float64(tGray), Float64(tMarker), Float32(minT), Float32(maxT)
        )
        s_log_message("@info", "Tessellation completed.")
    catch e
        s_log_message("@error", string("Tessellation error: ", e))
    end
end

end # module SOPHYSM