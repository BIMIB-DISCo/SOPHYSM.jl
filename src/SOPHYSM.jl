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
include("imaging/Cellpose/CellposeSegmentation.jl")

### Exported functions
export start_GUI, run_segmentation_pure, start_tessellation, start_async_job, check_job_status

### Constants
const workspace_dir = Observable(Workspace.get_workspace_dir())

# --- Job state (UI <-> worker) ---
const JOB_RESULT = Ref{String}("")                # path / "ERROR" / "ERROR_TIMEOUT"
const IS_BUSY = Threads.Atomic{Bool}(false)
const JOB_LOCK = ReentrantLock()

# watchdog
const JOB_START_NS = Threads.Atomic{Int}(0)         # time_ns() at job start, 0 if none
const JOB_TIMEOUT_S = 120.0                         # seconds

# track current spawned task (graph/jnet)
const JOB_TASK = Ref{Union{Task,Nothing}}(nothing)

# method tracking
const JOB_METHOD = Ref{String}("")                  # "graph" / "jnet" / "cellpose"
const JOB_KIND = Ref{String}("")                  # "spawn" / "cellpose_worker"

const DEBUG_LOGS = Ref(false)

const _LAST_JOB_STATE = Ref{String}("")      # per log-on-change
const _LAST_POLL_LOG_NS = Ref{Int}(0)        # per rate-limit
const POLL_LOG_EVERY_S = 2.0                 # ogni 2s al massimo in DEBUG

# (optional) avoid qmlfunction re-registration errors if you restart GUI in same Julia session
const _QML_FUNCS_REGISTERED = Ref(false)

# Warmup JIT compilation (helps with initial lag of first run)
function perform_warmup()
    s_log_message("@info", "[WARMUP] Starting warmup JIT compilation...")
    Threads.@spawn begin
        try
            run_segmentation_pure("graph", "dummy", "dummy_in", "dummy_out")
        catch
        end
    end
end

"""
    run_segmentation_pure(method_arg, model_arg, img_arg, output_arg) -> String

Esegue davvero l’algoritmo e salva output.
Questa funzione non fa spawn di per sé (viene chiamata da job thread o sync).
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
            # IMPORTANT: in modalità async "buona", la GUI NON deve chiamare PyCall qui.
            # Il cellpose async viene gestito dal worker (vedi start_async_job + CellposeSegmentation).
            # Qui lasciamo solo per eventuali chiamate sync (debug), ma normalmente non verrà usato.
            s_log_message("@info", "[THREAD-$(Threads.threadid())] Cellpose (direct) Start...")
            CellposeSegmentation.start_segmentation_SOPHYSM_cellpose(i_str, o_str)

        else
            error("Unknown segmentation method: $m_str")
        end

        s_log_message("@info", "[THREAD-$(Threads.threadid())] Saving: $o_str")
        sleep(0.1) # flush I/O
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
- -1 se già occupato o errore immediato
"""
function start_async_job(method, model, img, output)
    # rifiuto veloce
    if IS_BUSY[]
        s_log_message("@warn", "[UI] Job Refused, system is already busy.")
        _log_state_change("refused_busy")
        return -1
    end

    # acquisizione atomica (race-safe)
    if Threads.atomic_xchg!(IS_BUSY, true)
        s_log_message("@warn", "[UI] Job Refused (race), system is already busy.")
        _log_state_change("refused_race")
        return -1
    end

    # init stato job
    JOB_METHOD[] = String(method)
    JOB_KIND[] = ""
    JOB_TASK[] = nothing
    JOB_START_NS[] = time_ns()

    lock(JOB_LOCK) do
        JOB_RESULT[] = ""
    end

    # log evento "start" UNA volta
    s_log_message("@info", "[UI] Starting job async. method=$(JOB_METHOD[])")
    _log_state_change("started")

    # ---------------------------
    # CELLPOSE: worker Julia separato (stabile, GUI responsive)
    # ---------------------------
    if JOB_METHOD[] == "cellpose"
        JOB_KIND[] = "cellpose_worker"
        s_log_message("@info", "[UI] Starting Cellpose via Julia worker process.")

        rc = CellposeSegmentation.start_cellpose_job(String(img), String(output))
        if rc != 0
            s_log_message("@error", "[UI] Failed to start cellpose worker.")
            lock(JOB_LOCK) do
                JOB_RESULT[] = "ERROR"
            end
            IS_BUSY[] = false
            JOB_START_NS[] = 0
            JOB_METHOD[] = ""
            JOB_KIND[] = ""
            _log_state_change("error_start_cellpose")
            return -1
        end

        # job avviato, ritorna subito
        _log_state_change("running")  # stato iniziale
        return 0
    end

    # ---------------------------
    # BONUS: graph/jnet async vero con spawn
    # ---------------------------
    JOB_KIND[] = "spawn"
    s_log_message("@info", "[UI] Spawning background task for $(JOB_METHOD[]).")
    _log_state_change("running")

    JOB_TASK[] = Threads.@spawn begin
        try
            path = run_segmentation_pure(method, model, img, output)
            lock(JOB_LOCK) do
                JOB_RESULT[] = path
            end
        catch err
            s_log_message("@error", "[SPAWN ERROR] $err")
            lock(JOB_LOCK) do
                JOB_RESULT[] = "ERROR"
            end
        finally
            IS_BUSY[] = false
            JOB_START_NS[] = 0
            JOB_METHOD[] = ""
            JOB_KIND[] = ""
            s_log_message("@info", "[THREAD] Job finished. Result ready.")
            # NON chiamare _log_state_change qui: è UI-facing, lasciamolo al poller quando legge JOB_RESULT
        end
    end

    return 0
end


"""
    check_job_status() -> String

- Se c'è un risultato pronto, lo restituisce e lo consuma (JOB_RESULT="").
- Se job ancora running, ritorna "".
- Se scatta timeout, mette JOB_RESULT="ERROR_TIMEOUT" (una sola volta) ma NON uccide il job.
"""
function check_job_status()
    # 0) se siamo busy, logga stato running (solo se cambia) + debug rate-limited
    if IS_BUSY[]
        _log_state_change("running")

        t0 = JOB_START_NS[]
        if t0 != 0
            elapsed_s = (time_ns() - t0) / 1e9
            _debug_poll_log("method=$(JOB_METHOD[]) kind=$(JOB_KIND[]) elapsed=$(round(elapsed_s, digits=1))s")
        end
    else
        _log_state_change("idle")
    end

    # 1) poll cellpose worker (solo se attivo)
    if IS_BUSY[] && JOB_KIND[] == "cellpose_worker"
        r = CellposeSegmentation.poll_cellpose_job()
        if r != ""
            # r è path oppure "ERROR"
            lock(JOB_LOCK) do
                JOB_RESULT[] = r
            end
            IS_BUSY[] = false
            JOB_START_NS[] = 0
            JOB_METHOD[] = ""
            JOB_KIND[] = ""
            # non loggare qui: lo facciamo quando consumiamo JOB_RESULT (punto 3)
        end
    end

    # 2) watchdog timeout (una sola volta)
    if IS_BUSY[]
        t0 = JOB_START_NS[]
        if t0 != 0
            elapsed_s = (time_ns() - t0) / 1e9
            if elapsed_s > JOB_TIMEOUT_S
                lock(JOB_LOCK) do
                    if JOB_RESULT[] == ""
                        s_log_message("@error", "[UI] Job timeout after $(round(elapsed_s, digits=1))s.")
                        JOB_RESULT[] = "ERROR_TIMEOUT"
                        _log_state_change("timeout")
                    end
                end
            end
        end
    end

    # 3) se c'è un risultato pronto, restituiscilo e logga UNA volta (evento)
    lock(JOB_LOCK) do
        res = JOB_RESULT[]
        if res != ""
            JOB_RESULT[] = ""

            if res == "ERROR"
                s_log_message("@error", "[UI] Job failed.")
                _log_state_change("error")
            elseif res == "ERROR_TIMEOUT"
                # già loggato sopra, ma teniamo stato coerente
                _log_state_change("timeout")
            else
                s_log_message("@info", "[UI] Job completed: $res")
                _log_state_change("completed")
            end

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

    # register QML functions once per Julia session (avoids error if GUI reopened)
    if !_QML_FUNCS_REGISTERED[]
        qmlfunction("download_single_slide_from_collection", async_download_single_slide_from_collection)
        qmlfunction("log_message", s_log_message)
        qmlfunction("start_async_job", start_async_job)
        qmlfunction("check_job_status", check_job_status)
        qmlfunction("start_tessellation", start_tessellation)
        _QML_FUNCS_REGISTERED[] = true
    end

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

function _log_state_change(new_state::String)
    if new_state != _LAST_JOB_STATE[]
        s_log_message("@info", "[JOB] state=$new_state method=$(JOB_METHOD[]) kind=$(JOB_KIND[])")
        _LAST_JOB_STATE[] = new_state
    end
end

function _debug_poll_log(msg::String)
    DEBUG_LOGS[] || return
    now_ns = time_ns()
    last = _LAST_POLL_LOG_NS[]
    if last == 0 || (now_ns - last) / 1e9 >= POLL_LOG_EVERY_S
        s_log_message("@info", "[POLL] $msg")
        _LAST_POLL_LOG_NS[] = now_ns
    end
end


end # module SOPHYSM
