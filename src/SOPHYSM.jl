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
export start_GUI, run_segmentation_pure, start_tessellation, start_async_job, check_job_status

### Constants
const workspace_dir = Observable(Workspace.get_workspace_dir())

# Global property map for QML
const JOB_RESULT = Ref{String}("")
const IS_BUSY = Ref{Bool}(false)

# Warmup JIT compilation (helps with initial lag of first run)
function perform_warmup()
    s_log_message("@info", "[WARMUP] Starting warmup JIT compilation...")
    Base.Threads.@spawn begin
        try
            # Warmup JNet with dummy data
            run_segmentation_pure("graph", "dummy", "dummy_in", "dummy_out")
        catch
            # Silently ignore warmup errors
        end

    end

end

"""
    run_segmentation_pure(method_arg::String, model_arg::String, img_arg::String, output_arg::String) -> String
    Run segmentation using the specified method and model on the input image, saving the result to the output path.
    - `method_arg`: Segmentation method ("jnet" or "graph").
    - `model_arg`: Path to the model file.
    - `img_arg`: Path to the input image file.
    - `output_arg`: Path to save the output segmentation.
    Returns the output path on success, or "ERROR" on failure.
"""
function run_segmentation_pure(method_arg, model_arg, img_arg, output_arg)
    # Initial micro-sleep forces a context switch. This allows other threads to run first,
    # which is useful during warmup to avoid blocking the main thread.
    sleep(0.05)
    try
        m_str = String(method_arg)
        mod_str = String(model_arg)
        i_str = String(img_arg)
        o_str = String(output_arg)

        # Skip if dummy input (WARMUP)
        if i_str == "dummy_in"
            # Load only JNet to compile it, then exit
            return ""
        end

        if Sys.iswindows() && startswith(i_str, "/")
            i_str = i_str[2:end]
            o_str = o_str[2:end]
        end

        if m_str == "jnet"
            s_log_message("@info", "[THREAD-$(Threads.threadid())] JNet Start...")
            model = JNet.load_model(mod_str)
            img = JNet.load_input(i_str; rsize=(512, 512))
            img = reshape(img, size(img)..., 1)
            pred = JNet.prediction(model, img)
            JNet.save_prediction(pred, o_str)

        elseif m_str == "graph"
            # Parametri sicuri
            tGray = 0.5
            tMarker = 0.3
            minT = 50.0
            maxT = 1000.0

            s_log_message("@info", "[THREAD-$(Threads.threadid())] Graph Algorithm Start...")
            ThresholdSegmentation.start_segmentation_SOPHYSM_graph(i_str, o_str, Float64(tGray), Float64(tMarker), Float32(minT), Float32(maxT))
        end

        s_log_message("@info", "[THREAD-$(Threads.threadid())] Saving: $o_str")
        sleep(0.1) # Flush I/O
        GC.gc()

        return o_str

    catch e
        # Silent error during warmup
        if img_arg != "dummy_in"
            s_log_message("@error", "[THREAD ERROR] $e")
            showerror(stdout, e, catch_backtrace())
        end
        return "ERROR"
    end
end

"""
    start_async_job(method::String, model::String, img::String, output::String) -> Int
    Start an asynchronous segmentation job on a separate thread.
    - `method`: Segmentation method ("jnet" or "graph").
    - `model`: Path to the model file.
    - `img`: Path to the input image file.
    - `output`: Path to save the output segmentation.
    Returns 0 if the job was started successfully, or -1 if the system is already busy.
"""
function start_async_job(method, model, img, output)
    if IS_BUSY[]
        s_log_message("@warn", "[UI] Job Refused, system is already busy.")
        return -1
    end

    if Threads.nthreads() == 1
        s_log_message("@warn", "WARNING: Julia is running in Single Thread mode! The GUI will freeze. Start with 'julia -t auto'")
    end

    s_log_message("@info", "[UI] Starting job on separate thread.")
    IS_BUSY[] = true
    JOB_RESULT[] = ""

    if isdefined(SOPHYSM, :s_log_message)
        s_log_message("@info", "Background processing...")
    end

    Base.Threads.@spawn begin
        try
            path = run_segmentation_pure(method, model, img, output)
            JOB_RESULT[] = path
        catch err
            s_log_message("@error", "[SPAWN ERROR] $err")
            JOB_RESULT[] = "ERROR"
        finally
            IS_BUSY[] = false
            s_log_message("@info", "[THREAD] Job finished. Result ready.")
        end
    end
    return 0
end



"""
    check_job_status() -> String
    Check the status of the asynchronous job.
    Returns an empty string if the job is still running, or the result path/error message if completed.
"""
function check_job_status()
    if IS_BUSY[]
        return ""
    end
    res = JOB_RESULT[]

    if res != ""
        JOB_RESULT[] = ""
    end

    return res
end




"""
    async_download_single_slide_from_collection(args...) -> Int
    Mock function to simulate downloading a slide from a collection asynchronously.
    Currently, it just prints an info message and returns 0.
"""
function async_download_single_slide_from_collection(args...)
    s_log_message("@info", "[INFO] Download mock.")
    return 0
end

"""
    start_GUI()
    Start the SOPHYSM GUI application.
"""
function start_GUI()

    s_open_logger()

    n_threads = Threads.nthreads()
    s_log_message("@info", "Start GUI (Available threads: $n_threads)")

    Workspace.set_environment()

    qmlfile = joinpath(@__DIR__, "qml", "SOPHYSM.qml")

    qmlfunction("download_single_slide_from_collection", async_download_single_slide_from_collection)
    qmlfunction("log_message", s_log_message)
    qmlfunction("start_async_job", start_async_job)
    qmlfunction("check_job_status", check_job_status)
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

    #Start warmup in background
    perform_warmup()

    exec_async()
    s_log_message("@info", "Close GUI")
    s_close_logger()

end


"""
    start_tessellation(img_path::AbstractString, output_path::AbstractString)
    Start the tessellation process on the given image and save the output.
    - `img_path`: Path to the input image file.
    - `output_path`: Path to save the tessellated output.
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

        ThresholdSegmentation.start_segmentation_SOPHYSM_graph(img_path_str, output_path_str, Float64(tGray), Float64(tMarker), Float32(minT), Float32(maxT))
        s_log_message("@info", "Tessellation completed.")

    catch e
        s_log_message("@error", string("Tessellation error: ", e))
    end
end



end # module SOPHYSM