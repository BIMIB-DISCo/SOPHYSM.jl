# cellpose_worker.jl
using JSON
using Dates
using CSV

using CellposeWrapper

include("CellposeGraph.jl")
using .CellposeGraph

function write_json_atomic(path::String, obj)
  tmp = path * ".tmp"
  open(tmp, "w") do io
    JSON.print(io, obj)
  end
  mv(tmp, path; force=true)
end

function main()
  if length(ARGS) < 5
    println("Usage: julia cellpose_worker.jl <input> <output_png> <status_json> <done_json> <params_json>")
    exit(2)
  end

  input_path = ARGS[1]
  output_path = ARGS[2]
  status_path = ARGS[3]
  done_path = ARGS[4]
  params_path = ARGS[5]

  try
    write_json_atomic(status_path, Dict(
      "state" => "starting",
      "time" => string(now()),
      "msg" => "Loading params + initializing Cellpose/Python..."
    ))

    # --- read params.json
    p = JSON.parsefile(params_path)

    # SOPHYSM postprocess thresholds
    minT = Float32(get(p, "min_threshold", 50.0))
    maxT = Float32(get(p, "max_threshold", 1000.0))

    cp = get(p, "cellpose", Dict{String,Any}())

    # Wrapper kwargs (solo quelli che il wrapper supporta oggi)
    diam_val = get(cp, "diameter", nothing)
    diameter = (diam_val === nothing) ? nothing : Float64(diam_val)
    pretrained = strip(String(get(cp, "pretrained_model", "")))
    pretrained_model = (pretrained == "") ? nothing : pretrained

    flow_threshold = Float64(get(cp, "flow_threshold", 0.4))
    cellprob_threshold = Float64(get(cp, "cellprob_threshold", 0.0))
    augment = Bool(get(cp, "augment", false))
    invert = Bool(get(cp, "invert", false))
    min_size = Int(get(cp, "min_size", 15))
    cache_models = Bool(get(cp, "cache_models", true))
    max_cached_models = Int(get(cp, "max_cached_models", 2))

    # init python (lazy)
    CellposeWrapper.init!()

    write_json_atomic(status_path, Dict(
      "state" => "running",
      "time" => string(now()),
      "msg" => "Running segmentation..."
    ))

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

    # 1) segmented image (output_path)
    CellposeGraph.save_segmented_png_from_masks(masks, output_path)

    base_path = splitext(output_path)[1]

    # 1b) save effective params (riproducibilità)
    try
      open(base_path * "_cellpose_params.json", "w") do io
        JSON.print(io, res.params)
      end
    catch
      # non blocchiamo il worker se fallisce il log
    end

    # 2) pipeline CSV + edges + adjacency
    df_cells, df_noisy, df_total = CellposeGraph.cellpose_masks_to_dataframes(
      masks; min_threshold=minT, max_threshold=maxT
    )

    labels_csv = base_path * "_dataframe_labels.csv"
    total_labels_csv = base_path * "_dataframe_total_labels.csv"
    noisy_labels_csv = base_path * "_dataframe_noisy_labels.csv"
    edges_csv = base_path * "_dataframe_edges.csv"
    adj_txt = base_path * ".txt"

    CSV.write(labels_csv, df_cells)
    CSV.write(total_labels_csv, df_total)
    CSV.write(noisy_labels_csv, df_noisy)

    h, w = size(masks)
    df_edges, edges = CellposeGraph.build_graph_from_tessellation_cellpose(
      df_cells, df_noisy, df_total,
      h, w,
      base_path * "_total_tessellation.png",
      base_path * "_cell_tessellation.png"
    )
    CSV.write(edges_csv, df_edges)

    mat = CellposeGraph.adjacency_from_edges_weight(df_total, df_edges, edges)
    CellposeGraph.save_adjacency_matrix(mat, adj_txt)

    # 3) overlay images (vertex + edges)
    vertex_png, edges_png = CellposeGraph.graph_overlay_paths(output_path)
    CellposeGraph.render_graph_overlay_images(
      output_path,
      edges_csv,
      total_labels_csv,
      vertex_png,
      edges_png
    )

    write_json_atomic(done_path, Dict(
      "ok" => true,
      "output" => output_path,
      "vertex_png" => vertex_png,
      "edges_png" => edges_png,
      "time" => string(now())
    ))

    write_json_atomic(status_path, Dict(
      "state" => "done",
      "time" => string(now()),
      "msg" => "Completed."
    ))

    exit(0)

  catch e
    write_json_atomic(done_path, Dict(
      "ok" => false,
      "error" => sprint(showerror, e),
      "time" => string(now())
    ))

    write_json_atomic(status_path, Dict(
      "state" => "error",
      "time" => string(now()),
      "msg" => sprint(showerror, e)
    ))

    exit(1)
  end
end

main()
