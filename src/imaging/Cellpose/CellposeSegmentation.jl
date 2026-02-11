module CellposeSegmentation

using Colors
using PNGFiles
using JSON
using Dates
using Base.Threads
using CSV

import CellposeWrapper

export start_segmentation_SOPHYSM_cellpose
export start_cellpose_job, poll_cellpose_job

include("CellposeGraph.jl")
using .CellposeGraph

# -----------------------------
# 1) Direct (sync) segmentation
# -----------------------------

"""
    start_segmentation_SOPHYSM_cellpose(
        input_path::String,
        output_path::String;
        min_threshold::Float32=50.0f0,
        max_threshold::Float32=1000.0f0,
        diameter=nothing,
        pretrained_model=nothing,
        flow_threshold::Float64=0.4,
        cellprob_threshold::Float64=0.0,
        augment::Bool=false,
        invert::Bool=false,
        min_size::Int=15,
        cache_models::Bool=true,
        max_cached_models::Int=2
    )

Segmentation Cellpose (in-process) con parametri custom.
"""
function start_segmentation_SOPHYSM_cellpose(
    input_path::String,
    output_path::String;
    min_threshold::Float32=50.0f0,
    max_threshold::Float32=1000.0f0,
    diameter=nothing,
    pretrained_model=nothing,
    flow_threshold::Float64=0.4,
    cellprob_threshold::Float64=0.0,
    augment::Bool=false,
    invert::Bool=false,
    min_size::Int=15,
    cache_models::Bool=true,
    max_cached_models::Int=2
)
    # Warm init (lazy)
    CellposeWrapper.init!()

    res = CellposeWrapper.segment_image(
        input_path;
        return_flows=false,
        diameter=diameter,
        pretrained_model=pretrained_model,
        flow_threshold=flow_threshold,
        cellprob_threshold=cellprob_threshold,
        augment=augment,
        invert=invert,
        min_size=min_size,
        cache_models=cache_models,
        max_cached_models=max_cached_models
    )

    masks = Int.(res.masks)

    # save segmented png
    CellposeGraph.save_segmented_png_from_masks(masks, output_path)

    base_path = splitext(output_path)[1]

    # save effective params (riproducibilità)
    try
        open(base_path * "_cellpose_params.json", "w") do io
            JSON.print(io, res.params)
        end
    catch e
        @warn "Failed to save cellpose params json" exception = (e, catch_backtrace())
    end

    # dataframe labels
    df_cells, df_noisy, df_total = CellposeGraph.cellpose_masks_to_dataframes(
        masks; min_threshold=min_threshold, max_threshold=max_threshold
    )

    CSV.write(base_path * "_dataframe_labels.csv", df_cells)
    CSV.write(base_path * "_dataframe_total_labels.csv", df_total)
    CSV.write(base_path * "_dataframe_noisy_labels.csv", df_noisy)

    # edges + adjacency
    h, w = size(masks)
    df_edges, edges = CellposeGraph.build_graph_from_tessellation_cellpose(
        df_cells, df_noisy, df_total,
        h, w,
        base_path * "_total_tessellation.png",
        base_path * "_cell_tessellation.png"
    )
    CSV.write(base_path * "_dataframe_edges.csv", df_edges)

    mat = CellposeGraph.adjacency_from_edges_weight(df_total, df_edges, edges)
    CellposeGraph.save_adjacency_matrix(mat, base_path * ".txt")

    # overlay images (VERTEX e EDGES) su immagine segmentata
    vertex_png, edges_png = CellposeGraph.graph_overlay_paths(output_path)
    CellposeGraph.render_graph_overlay_images(
        output_path,
        base_path * "_dataframe_edges.csv",
        base_path * "_dataframe_total_labels.csv",
        vertex_png,
        edges_png
    )

    # original + edges overlay
    edges_orig_png = CellposeGraph.graph_edges_overlay_path_original(output_path)
    CellposeGraph.render_edges_overlay_on_original(
        input_path,
        base_path * "_dataframe_edges.csv",
        base_path * "_dataframe_total_labels.csv",
        edges_orig_png
    )

    # original + Voronoi overlay
    voronoi_orig_png = CellposeGraph.voronoi_overlay_path_original(output_path)
    CellposeGraph.render_voronoi_overlay_image(
        input_path,
        df_total,
        voronoi_orig_png
    )

    return output_path
end

# -----------------------------------
# 2) Async job via external Julia worker
# -----------------------------------

const _DONE_JSON = Ref{String}("")
const _STATUS_JSON = Ref{String}("")
const _OUT_PATH = Ref{String}("")
const _RUNNING = Threads.Atomic{Bool}(false)

"""
    start_cellpose_job(...)
Avvia un worker Julia separato passando parametri via JSON.
Ritorna 0 se parte, -1 se già running.
"""
function start_cellpose_job(
    input_path::String,
    output_path::String;
    min_threshold::Float32=50.0f0,
    max_threshold::Float32=1000.0f0,
    diameter=nothing,
    pretrained_model=nothing,
    flow_threshold::Float64=0.4,
    cellprob_threshold::Float64=0.0,
    augment::Bool=false,
    invert::Bool=false,
    min_size::Int=15,
    cache_models::Bool=true,
    max_cached_models::Int=2
)
    if _RUNNING[]
        return -1
    end
    _RUNNING[] = true

    tmpdir = mktempdir()
    _STATUS_JSON[] = joinpath(tmpdir, "status.json")
    _DONE_JSON[] = joinpath(tmpdir, "done.json")
    _OUT_PATH[] = output_path

    params_json = joinpath(tmpdir, "params.json")

    params = Dict(
        "min_threshold" => min_threshold,
        "max_threshold" => max_threshold,
        "cellpose" => Dict(
            "diameter" => diameter === nothing ? nothing : Float64(diameter),
            "pretrained_model" => pretrained_model === nothing ? "" : String(pretrained_model),
            "flow_threshold" => Float64(flow_threshold),
            "cellprob_threshold" => Float64(cellprob_threshold),
            "augment" => Bool(augment),
            "invert" => Bool(invert),
            "min_size" => Int(min_size),
            "cache_models" => Bool(cache_models),
            "max_cached_models" => Int(max_cached_models)
        )
    )

    open(params_json, "w") do io
        JSON.print(io, params)
    end

    worker = joinpath(@__DIR__, "cellpose_worker.jl")

    projfile = Base.active_project()
    projdir = dirname(projfile)

    cmd = `$(Base.julia_cmd()) -t 1 --project=$(projdir) $worker $input_path $output_path $(_STATUS_JSON[]) $(_DONE_JSON[]) $params_json`

    run(cmd; wait=false)
    return 0
end

"""
    poll_cellpose_job()
"""
function poll_cellpose_job()
    if _DONE_JSON[] == "" || !isfile(_DONE_JSON[])
        return ""
    end

    try
        obj = JSON.parsefile(_DONE_JSON[])
        ok = get(obj, "ok", false)

        _RUNNING[] = false

        if ok == true
            return String(get(obj, "output", _OUT_PATH[]))
        else
            err = get(obj, "error", "unknown error")
            println("[CELLPOSE WORKER ERROR] ", err)
            return "ERROR"
        end
    catch e
        _RUNNING[] = false
        println("[CELLPOSE POLL ERROR] ", sprint(showerror, e))
        return "ERROR"
    end
end

end # module
