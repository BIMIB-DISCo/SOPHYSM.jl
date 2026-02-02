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

"""
    start_segmentation_SOPHYSM_cellpose(
        input_path::String,
        output_path::String;
        min_threshold::Float32=50.0f0,
        max_threshold::Float32=1000.0f0
    )
    Starts the SOPHYSM Cellpose-based segmentation process with given parameters.
    # Arguments
    - `input_path`: Path to the input image file
    - `output_path`: Path where output will be saved
    - `min_threshold`: Minimum area threshold for segments
    - `max_threshold`: Maximum area threshold for segments
    # Returns
    - The filepath of the generated output
"""
function start_segmentation_SOPHYSM_cellpose(
    input_path::String,
    output_path::String;
    min_threshold::Float32=50.0f0,
    max_threshold::Float32=1000.0f0
)
    CellposeWrapper._init_py!()
    res = CellposeWrapper.segment_image(input_path; return_flows=false)

    masks = Int.(res.masks)

    # save segmented png
    CellposeGraph.save_segmented_png_from_masks(masks, output_path)

    # dataframe labels
    df_cells, df_noisy, df_total = CellposeGraph.cellpose_masks_to_dataframes(
        masks; min_threshold=min_threshold, max_threshold=max_threshold
    )

    base_path = splitext(output_path)[1]
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

    # overlay images (VERTEX e EDGES)
    vertex_png, edges_png = CellposeGraph.graph_overlay_paths(output_path)
    CellposeGraph.render_graph_overlay_images(
        output_path,
        base_path * "_dataframe_edges.csv",
        base_path * "_dataframe_total_labels.csv",
        vertex_png,
        edges_png
    )

    return output_path
end

"""
    start_cellpose_job(
      input_path::String,
      output_path::String;
      min_threshold::Float32=50.0f0,
      max_threshold::Float32=1000.0f0
    )
    Starts an asynchronous Cellpose segmentation job.
    # Arguments
    - `input_path`: Path to the input image file
    - `output_path`: Path where output will be saved
    - `min_threshold`: Minimum area threshold for segments
    - `max_threshold`: Maximum area threshold for segments
    # Returns
    - `0` if the job started successfully, `-1` if a job is already running
"""

const _DONE_JSON = Ref{String}("")           # path to done.json
const _STATUS_JSON = Ref{String}("")         # path to status.json
const _OUT_PATH = Ref{String}("")            # output path
const _RUNNING = Threads.Atomic{Bool}(false) # is a job running

"""
    start_cellpose_job(
        input_path::String,
        output_path::String;
        min_threshold::Float32=50.0f0,
        max_threshold::Float32=1000.0f0
    )
    Starts an asynchronous Cellpose segmentation job.
    # Arguments
    - `input_path`: Path to the input image file
    - `output_path`: Path where output will be saved
    - `min_threshold`: Minimum area threshold for segments
    - `max_threshold`: Maximum area threshold for segments
    # Returns
    - `0` if the job started successfully, `-1` if a job is already running
"""
function start_cellpose_job(
    input_path::String,
    output_path::String;
    min_threshold::Float32=50.0f0,
    max_threshold::Float32=1000.0f0
)
    if _RUNNING[]
        return -1
    end
    _RUNNING[] = true

    tmpdir = mktempdir()
    _STATUS_JSON[] = joinpath(tmpdir, "status.json")
    _DONE_JSON[] = joinpath(tmpdir, "done.json")
    _OUT_PATH[] = output_path

    worker = joinpath(@__DIR__, "cellpose_worker.jl")

    projfile = Base.active_project()
    projdir = dirname(projfile)

    cmd = `$(Base.julia_cmd()) -t 1 --project=$(projdir) $worker $input_path $output_path $(_STATUS_JSON[]) $(_DONE_JSON[]) $(min_threshold) $(max_threshold)`

    run(cmd; wait=false)
    return 0
end

"""
    poll_cellpose_job()
    Polls the status of the asynchronous Cellpose segmentation job.
    # Returns
    - The output filepath if the job is done successfully
    - `"ERROR"` if there was an error during processing
    - An empty string `""` if the job is still running
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
            # ritorniamo SEMPRE output base (segmentata)
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
