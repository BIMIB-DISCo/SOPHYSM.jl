# cellpose_worker.jl
using JSON
using Dates
using CSV

using CellposeWrapper

include("CellposeGraph.jl")
using .CellposeGraph

"""
    write_json_atomic(path::String, obj)
    Writes a JSON object to a file atomically by first writing to a temporary file
    and then renaming it to the target path.
"""
function write_json_atomic(path::String, obj)
  tmp = path * ".tmp"
  open(tmp, "w") do io
    JSON.print(io, obj)
  end
  mv(tmp, path; force=true)
end

"""
    main()
    Main function to run Cellpose segmentation as a worker process.
    Reads command-line arguments for input/output paths and thresholds,
    executes segmentation, and writes status and results to JSON files.
"""
function main()
  if length(ARGS) < 6
    println("Usage: julia cellpose_worker.jl <input> <output_png> <status_json> <done_json> <minT> <maxT>")
    exit(2)
  end

  input_path = ARGS[1]
  output_path = ARGS[2]
  status_path = ARGS[3]
  done_path = ARGS[4]
  minT = parse(Float32, ARGS[5])
  maxT = parse(Float32, ARGS[6])

  try
    write_json_atomic(status_path, Dict(
      "state" => "starting",
      "time" => string(now()),
      "msg" => "Initializing Cellpose/Python..."
    ))

    CellposeWrapper._init_py!()

    write_json_atomic(status_path, Dict(
      "state" => "running",
      "time" => string(now()),
      "msg" => "Running segmentation..."
    ))

    res = CellposeWrapper.segment_image(input_path; return_flows=false)
    masks = Int.(res.masks)

    # 1) basic segmented image (output_path)
    CellposeGraph.save_segmented_png_from_masks(masks, output_path)

    # 2) pipeline CSV + edges + adjacency
    df_cells, df_noisy, df_total = CellposeGraph.cellpose_masks_to_dataframes(
      masks; min_threshold=minT, max_threshold=maxT
    )

    base_path = splitext(output_path)[1]
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
