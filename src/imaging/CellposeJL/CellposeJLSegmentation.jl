# imaging/CellposeJL/CellposeJLSegmentation.jl
module CellposeJLSegmentation

using Cellpose
using Images, FileIO, Colors, PNGFiles, CSV, JSON
using Logging

include("../Cellpose/CellposeGraph.jl")
using .CellposeGraph

export start_segmentation_SOPHYSM_cellpose_jl

"""
    start_segmentation_SOPHYSM_cellpose_jl(input_path, output_path; kwargs...)
Segmentazione con Cellpose.jl nativo. Output compatibile con la pipeline SOPHYSM.
"""
function start_segmentation_SOPHYSM_cellpose_jl(
    input_path::String,
    output_path::String;
    min_threshold::Float32=50.0f0,
    max_threshold::Float32=1000.0f0,
    diameter::Union{Float64, Nothing}=nothing,
    pretrained_model::Union{AbstractString, Nothing}=nothing,
    # Parametri mantenuti per compatibilità UI, ma attualmente ignorati da Cellpose.jl
    flow_threshold::Float64=0.4,
    cellprob_threshold::Float64=0.0,
    augment::Bool=false,
    invert::Bool=false,
    min_size::Int=15
)
    try
        @info "[CELLPOSE_JL] Loading image: $input_path"
        
        # Verifica model_path
        model_path = if pretrained_model === nothing || isempty(pretrained_model)
            error("Cellpose.jl requires a valid ONNX model path. Please set 'cellpose_pretrained_model' in Settings to the path of your .onnx model file.")
        else
            String(pretrained_model)
        end
        
        if !isfile(model_path)
            error("Model file not found: $model_path")
        end
        
        diam_val = diameter === nothing ? 0.0 : Float64(diameter)
        
        @info "[CELLPOSE_JL] Running segmentation | model: $model_path | diameter: $(diam_val == 0.0 ? "auto" : string(diam_val))px"
        
        # Chiama l'API pubblica di Cellpose.jl
        # Nota: flow_threshold, cellprob_threshold, min_size sono hardcoded internamente
        masks = Cellpose.segment(input_path, model_path; diameter=diam_val, use_gpu=false)
        
        masks_int = Int.(masks)
        base_path = splitext(output_path)[1]

        # 1) Salva PNG segmentato
        CellposeGraph.save_segmented_png_from_masks(masks_int, output_path)

        # 2) Salva parametri usati (riproducibilità)
        try
            open(base_path * "_cellpose_jl_params.json", "w") do io
                JSON.print(io, Dict(
                    "model_path" => model_path,
                    "diameter" => diam_val,
                    "min_threshold" => min_threshold,
                    "max_threshold" => max_threshold,
                    "note" => "flow_threshold/cellprob_threshold/min_size are hardcoded in Cellpose.jl internals"
                ))
            end
        catch e
            @warn "Failed to save cellpose_jl params" exception=(e, catch_backtrace())
        end

        # 3) DataFrames & Grafo (riutilizza CellposeGraph)
        df_cells, df_noisy, df_total = CellposeGraph.cellpose_masks_to_dataframes(
            masks_int; min_threshold=min_threshold, max_threshold=max_threshold
        )

        CSV.write(base_path * "_dataframe_labels.csv", df_cells)
        CSV.write(base_path * "_dataframe_total_labels.csv", df_total)
        CSV.write(base_path * "_dataframe_noisy_labels.csv", df_noisy)

        h, w = size(masks_int)
        df_edges, edges = CellposeGraph.build_graph_from_tessellation_cellpose(
            df_cells, df_noisy, df_total, h, w,
            base_path * "_total_tessellation.png", base_path * "_cell_tessellation.png"
        )
        CSV.write(base_path * "_dataframe_edges.csv", df_edges)

        mat = CellposeGraph.adjacency_from_edges_weight(df_total, df_edges, edges)
        CellposeGraph.save_adjacency_matrix(mat, base_path * ".txt")

        # 4) Overlay images
        vertex_png, edges_png = CellposeGraph.graph_overlay_paths(output_path)
        CellposeGraph.render_graph_overlay_images(
            output_path, base_path * "_dataframe_edges.csv",
            base_path * "_dataframe_total_labels.csv", vertex_png, edges_png
        )

        edges_orig_png = CellposeGraph.graph_edges_overlay_path_original(output_path)
        CellposeGraph.render_edges_overlay_on_original(
            input_path, base_path * "_dataframe_edges.csv",
            base_path * "_dataframe_total_labels.csv", edges_orig_png
        )

        voronoi_orig_png = CellposeGraph.voronoi_overlay_path_original(output_path)
        CellposeGraph.render_voronoi_overlay_image(input_path, df_total, voronoi_orig_png)

        @info "[CELLPOSE_JL] Segmentation completed: $output_path (found $(maximum(masks_int)) cells)"
        return output_path

    catch e
        @error "[CELLPOSE_JL] Segmentation failed" exception=(e, catch_backtrace())
        rethrow()  # Propaga a run_segmentation_pure per la gestione errori UI
    end
end

end # module