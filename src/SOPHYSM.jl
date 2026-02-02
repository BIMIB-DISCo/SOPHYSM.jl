### SOPHYSM-- SOlid tumors PHYlogentic Spatial Modeller
### SOPHYSM.jl
module SOPHYSM

### Packages
using QML
using Observables
using JSON
using JHistint
using Base.Threads
using CellposeWrapper

### Included modules
include("Workspace.jl")
include("SOPHYSMLogger.jl")
include("imaging/JNet/JNet.jl")
include("imaging/Threshold/ThresholdSegmentation.jl")
include("imaging/Cellpose/CellposeSegmentation.jl")

### Exported functions
export start_GUI, run_segmentation_pure, start_tessellation, start_async_job, check_job_status

### Constants
const workspace_dir = Observable(Workspace.get_workspace_dir())

# --- Job state (UI <-> worker thread) ---
const JOB_RESULT = Ref{String}("")            # path / "ERROR" / "ERROR_TIMEOUT"
const IS_BUSY = Threads.Atomic{Bool}(false)
const JOB_LOCK = ReentrantLock()

# watchdog
const JOB_START_NS = Threads.Atomic{Int}(0)     # time_ns() at job start, 0 if none
const JOB_TIMEOUT_S = 120.0                     # seconds

# track current spawned task (to avoid re-entrancy problems)
const JOB_TASK = Ref{Union{Task,Nothing}}(nothing)

# Warmup JIT compilation (helps with initial lag of first run)
function perform_warmup()
    s_log_message("@info", "[WARMUP] Starting warmup JIT compilation...")
    Base.Threads.@spawn begin
        try
            run_segmentation_pure("graph", "dummy", "dummy_in", "dummy_out")
        catch
        end
    end
end

"""
    run_segmentation_pure(method_arg, model_arg, img_arg, output_arg) -> String
"""
function run_segmentation_pure(method_arg, model_arg, img_arg, output_arg)
    # micro sleep per cedere il timeslice durante warmup
    sleep(0.05)

    try
        m_str = String(method_arg)
        mod_str = String(model_arg)
        i_str = String(img_arg)
        o_str = String(output_arg)

        # Skip if dummy input (WARMUP)
        if i_str == "dummy_in"
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
            tGray = 0.5
            tMarker = 0.3
            minT = 50.0
            maxT = 1000.0

            s_log_message("@info", "[THREAD-$(Threads.threadid())] Graph Algorithm Start...")
            ThresholdSegmentation.start_segmentation_SOPHYSM_graph(
                i_str, o_str, Float64(tGray), Float64(tMarker), Float32(minT), Float32(maxT)
            )

        elseif m_str == "cellpose"
            s_log_message("@info", "[THREAD-$(Threads.threadid())] Cellpose Start...")
            CellposeSegmentation.start_segmentation_SOPHYSM_cellpose(i_str, o_str)

        else
            error("Unknown segmentation method: $m_str")
        end

        s_log_message("@info", "[THREAD-$(Threads.threadid())] Saving: $o_str")
        sleep(0.1) # Flush I/O
        GC.gc()

        return o_str

    catch e
        if img_arg != "dummy_in"
            s_log_message("@error", "[THREAD ERROR] $e")
            showerror(stdout, e, catch_backtrace())
        end
        return "ERROR"
    end
end

"""
    start_async_job(method, model, img, output) -> Int

Ritorna:
- 0  se avviato
- -1 se già occupato
"""

function start_async_job(method, model, img, output)
    # Fast refuse
    if IS_BUSY[]
        s_log_message("@warn", "[UI] Job Refused, system is already busy.")
        return -1
    end

    # In safe-mode monothread non serve atomic_xchg!, ma lo teniamo semplice e deterministico
    IS_BUSY[] = true
    JOB_START_NS[] = time_ns()

    lock(JOB_LOCK) do
        JOB_RESULT[] = ""
    end

    s_log_message("@info", "[UI] Starting job in MONOTHREAD safe-mode (GUI will block).")

    try
        # IMPORTANT: init python sul thread chiamante (stabile)
        try
            CellposeWrapper._init_py!()
        catch e
            s_log_message("@error", "[UI] Cellpose init failed: $e")
            lock(JOB_LOCK) do
                JOB_RESULT[] = "ERROR"
            end
            return -1
        end

        # Esegui SINCRONO (nessuno spawn)
        path = run_segmentation_pure(method, model, img, output)

        lock(JOB_LOCK) do
            JOB_RESULT[] = path
        end

        return path == "ERROR" ? -1 : 0

    catch err
        s_log_message("@error", "[MONOTHREAD ERROR] $err")
        lock(JOB_LOCK) do
            JOB_RESULT[] = "ERROR"
        end
        return -1

    finally
        IS_BUSY[] = false
        JOB_START_NS[] = 0
        s_log_message("@info", "[UI] Monothread job finished. Result ready.")
    end
end


"""
    check_job_status() -> String

- Se c'è un risultato pronto, lo restituisce subito (anche se IS_BUSY=true).
- Se il job è ancora running e scatta timeout, mette JOB_RESULT="ERROR_TIMEOUT" (una sola volta),
  ma NON sblocca IS_BUSY finché il task non termina davvero.
"""
function check_job_status()
    lock(JOB_LOCK) do
        res = JOB_RESULT[]
        if res != ""
            JOB_RESULT[] = ""
            return res
        end
        return ""
    end
end

"""
    async_download_single_slide_from_collection(args...) -> Int
"""
function async_download_single_slide_from_collection(args...)
    s_log_message("@info", "[INFO] Download mock.")
    return 0
end

"""
    start_GUI()
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

    perform_warmup()

    exec_async()
    s_log_message("@info", "Close GUI")
    s_close_logger()
end

"""
    start_tessellation(img_path, output_path)
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
            img_path_str, output_path_str,
            Float64(tGray), Float64(tMarker), Float32(minT), Float32(maxT)
        )
        s_log_message("@info", "Tessellation completed.")
    catch e
        s_log_message("@error", string("Tessellation error: ", e))
    end
end

end # module SOPHYSM
