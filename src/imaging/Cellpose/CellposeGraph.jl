module CellposeGraph

using DataFrames
using CSV
using Colors
using PNGFiles
using Images
using IndirectArrays
using VoronoiCells
using GeometryBasics
using Plots
using Luxor
using Karnak
using Graphs
using MetaGraphs

# se lo usi davvero come in ThresholdSegmentation
using J_Space

export cellpose_masks_to_dataframes,
  build_graph_from_tessellation_cellpose,
  adjacency_from_edges_weight,
  save_adjacency_matrix,
  save_segmented_png_from_masks,
  graph_overlay_paths,
  render_graph_overlay_images

"""
    _clamp_rc(r, c, h, w) -> (rr, cc)
    Clamp r/c in [1..h], [1..w]
"""
@inline function _clamp_rc(r::Int, c::Int, h::Int, w::Int)
  rr = clamp(r, 1, h)
  cc = clamp(c, 1, w)
  return rr, cc
end

"""
    _sanitize_edges(edges, n) -> Vector{Tuple{Int,Int}}
    Removes invalid edges from the raw edge list.
    An edge is considered invalid if:
    - It contains indices less than 1 or greater than n
    - It is a self-loop (i.e., both vertices are the same)
"""
@inline function _sanitize_edges(edges::Vector{Any}, n::Int)
    out = Vector{Tuple{Int,Int}}()
    for e in edges
        # e dovrebbe essere qualcosa tipo (a,b) o [a,b]
        if !(e isa Tuple || e isa AbstractVector) || length(e) < 2
            continue
        end
        a = e[1]
        b = e[2]
        if !(a isa Integer && b isa Integer)
            continue
        end
        ia = Int(a); ib = Int(b)
        # scarta -1/0/out-of-range e self-loop
        if ia < 1 || ib < 1 || ia > n || ib > n || ia == ib
            continue
        end
        push!(out, (ia, ib))
    end
    return out
end

"""
    _to_voronoi_point(r, c) -> Point2{Float64}
    Converts row/column indices to Voronoi point coordinates.
    Note: VoronoiCells uses (x, y) coordinates where x corresponds to columns and y to rows.
          Here, we map (r, c) to (c, -r) to align with image coordinate systems.
"""
@inline function _to_voronoi_point(r::Int, c::Int)
  # tu usi (c, -r)
  return GeometryBasics.Point2(Float64(c), -Float64(r))
end

"""
    save_adjacency_matrix(matrix, filepath_matrix)
    Saves the adjacency matrix to a text file in a human-readable format.
"""
function save_adjacency_matrix(matrix::Matrix{Int}, filepath_matrix::AbstractString)
  open(filepath_matrix, "w") do f
    n_rows, n_cols = size(matrix)
    for i in 1:n_rows
      write(f, " ")
      for j in 1:n_cols
        write(f, string(matrix[i, j], "  "))
      end
      write(f, "\n")
    end
  end
end

"""
    graph_overlay_paths(output_png) -> (vertex_png, edges_png)
    Given output.png returns:
    - output_graph_vertex.png
    - output_graph_edges.png
"""
function graph_overlay_paths(output_png::AbstractString)
  base = splitext(String(output_png))[1]
  return (base * "_graph_vertex.png", base * "_graph_edges.png")
end

"""
    cellpose_masks_to_dataframes(masks; min_threshold, max_threshold)
    Converts Cellpose masks to DataFrames for cells, noisy segments, and total segments.
    Returns:
    - df_cells: "cell" (area > max_threshold)
    - df_noisy: "extra/noisy" (min_threshold < area <= max_threshold)
    - df_total: all (area > min_threshold)

    Columns compatible with ThresholdSegmentation:
    label, position_label, color_label, area, centroid, is_cell
"""
function cellpose_masks_to_dataframes(
  masks::AbstractMatrix{<:Integer};
  min_threshold::Float32,
  max_threshold::Float32
)
  h, w = size(masks)
  maxid = maximum(masks)
  if maxid == 0
    return DataFrame(), DataFrame(), DataFrame()
  end

  # accumuli per centroidi
  area = zeros(Int, maxid)
  sum_r = zeros(Int, maxid)
  sum_c = zeros(Int, maxid)

  # per position_label: primo pixel (min r/c)
  min_r = fill(typemax(Int), maxid)
  min_c = fill(typemax(Int), maxid)

  @inbounds for r in 1:h, c in 1:w
    id = Int(masks[r, c])
    if id > 0
      area[id] += 1
      sum_r[id] += r
      sum_c[id] += c
      if r < min_r[id]
        min_r[id] = r
      end
      if c < min_c[id]
        min_c[id] = c
      end
    end
  end

  cols = distinguishable_colors(maxid)

  labels_total = Int[]
  areas_total = Int[]
  cent_total = CartesianIndex[]
  pos_total = CartesianIndex[]
  col_total = Any[]
  is_cell_vec = Bool[]

  for id in 1:maxid
    a = area[id]
    if a > min_threshold
      cy = sum_r[id] ÷ max(a, 1)
      cx = sum_c[id] ÷ max(a, 1)

      push!(labels_total, id)
      push!(areas_total, a)
      push!(cent_total, CartesianIndex(cy, cx))
      push!(pos_total, CartesianIndex(min_r[id], min_c[id]))
      push!(col_total, cols[id])
      push!(is_cell_vec, a > max_threshold)
    end
  end

  df_total = DataFrame(
    label=labels_total,
    position_label=pos_total,
    color_label=col_total,
    area=areas_total,
    centroid=cent_total,
    is_cell=is_cell_vec
  )

  df_cells = filter(row -> row.is_cell == true, df_total)
  df_noisy = filter(row -> row.is_cell == false, df_total)

  return df_cells, df_noisy, df_total
end


"""
    build_graph_from_tessellation_cellpose(df_cells, df_noisy, df_total, h, w, filepath_total_tess, filepath_cell_tess)
    Builds a graph from the tessellation of Cellpose segmentation results.
    Returns:
    - df_edges (origin, destination, weight) with origin/destination = LABEL
    - edges (list of pairs of indices 1..n with respect to the order in df_total)
"""
function build_graph_from_tessellation_cellpose(
  df_cells::DataFrame,
  df_noisy::DataFrame,
  df_total::DataFrame,
  h::Int, w::Int,
  filepath_total_tess::AbstractString,
  filepath_cell_tess::AbstractString
)
  # ---- fallback: if df_cells is empty, use df_total to show centroids
  use_cells = nrow(df_cells) > 0
  nuclei_df = use_cells ? df_cells : df_total

  nuclei_list = nuclei_df.centroid
  nuclei_label_list = nuclei_df.label
  total_list = df_total.centroid

  position_array = GeometryBasics.Point2{Float64}[]
  cell_position_array = GeometryBasics.Point2{Float64}[]

  # TOTAL points
  for v in total_list
    r, c = Tuple(v)
    r, c = _clamp_rc(r, c, h, w)
    push!(position_array, _to_voronoi_point(r, c)) # (c, -r)
  end

  # NUCLEI/CELL points (fallback on df_total if df_cells is empty)
  for v in nuclei_list
    r, c = Tuple(v)
    r, c = _clamp_rc(r, c, h, w)
    push!(cell_position_array, _to_voronoi_point(r, c))
  end

  # rect consistent with (x=c in [1..w], y=-r in [-h..-1])
  rect = VoronoiCells.Rectangle(
    GeometryBasics.Point2(1.0, -Float64(h)),
    GeometryBasics.Point2(Float64(w), -1.0)
  )

  # --- Total tessellation (edges output) ---
  raw_edges = Any[]
  tess_total = VoronoiCells.voronoicells(position_array, rect; edges=raw_edges)

  n = nrow(df_total)
  edges_sane = _sanitize_edges(raw_edges, n)

  dx = 6.0
  dy = 6.0

  # plot total tessellation + centroids
  Plots.scatter(cell_position_array, markersize=4, label="Nuclei Centroid")
  if length(cell_position_array) > 0
    Plots.annotate!([
      (cell_position_array[k][1] + dx,
        cell_position_array[k][2] + dy,
        Plots.text(nuclei_label_list[k], 6, RGBA(1, 1, 1, 0.35)))
      for k in 1:length(cell_position_array)
    ])
  end
  p1 = Plots.plot!(tess_total, legend=:topleft)
  Plots.savefig(p1, filepath_total_tess)

  # df_edges: use edges_sane, not raw
  df_edges = build_dataframe_edges_from_grid_cellpose(edges_sane, df_total)

  # --- Cell tessellation (image only) ---
  tess_cell = VoronoiCells.voronoicells(cell_position_array, rect)
  Plots.scatter(cell_position_array, markersize=4, label="Centroids")
  if length(cell_position_array) > 0
    Plots.annotate!([
      (cell_position_array[k][1] + dx,
        cell_position_array[k][2] + dy,
        Plots.text(nuclei_label_list[k], 6, RGBA(1, 1, 1, 0.35)))
      for k in 1:length(cell_position_array)
    ])
  end
  p2 = Plots.plot!(tess_cell, legend=:topleft)
  Plots.savefig(p2, filepath_cell_tess)

  return df_edges, edges_sane
end

"""
    build_dataframe_edges_from_grid_cellpose(edges, df_total) -> DataFrame
    Builds a DataFrame of edges from a list of edges (pairs of indices) and the total DataFrame.
    The resulting DataFrame contains:
    - origin: label of the origin node
    - destination: label of the destination node
    - weight: absolute difference in area between the two nodes
"""
function build_dataframe_edges_from_grid_cellpose(edges::Vector{Tuple{Int,Int}}, df_total::DataFrame)
  labels = df_total.label
  areas = df_total.area

  origin_col = Int[]
  dest_col = Int[]
  weight_col = Int[]

  for (a, b) in edges
    origin = labels[a]
    dest = labels[b]
    push!(origin_col, origin)
    push!(dest_col, dest)

    push!(weight_col, abs(areas[a] - areas[b]))
  end

  return DataFrame(origin=origin_col, destination=dest_col, weight=weight_col)
end

"""
    adjacency_from_edges_weight(df_total, df_edges, edges) -> Matrix{Int}
    Constructs an adjacency matrix from the edges and their weights.
    The matrix is of size n x n where n is the number of nodes in df_total.
    Non-existing edges are represented with -1.
"""
function adjacency_from_edges_weight(df_total::DataFrame, df_edges::DataFrame, edges::Vector{Tuple{Int,Int}})
  n = nrow(df_total)
  adjacency_matrix = fill(-1, n, n)

  weights = df_edges.weight
  @assert length(weights) == length(edges)

  for k in 1:length(edges)
    a, b = edges[k]
    w = weights[k]
    adjacency_matrix[a, b] = w
    adjacency_matrix[b, a] = w
  end
  return adjacency_matrix
end


"""
    save_segmented_png_from_masks(masks, filepath_output)
    Saves a segmented PNG image from Cellpose masks.
    Each unique mask ID is assigned a distinct color.
    Background (ID=0) is saved as black.
"""
function save_segmented_png_from_masks(
  masks::AbstractMatrix{<:Integer},
  filepath_output::AbstractString
)
  h, w = size(masks)
  maxid = maximum(masks)

  # Se non ci sono maschere, salva tutto nero
  if maxid == 0
    out = fill(RGB{N0f8}(0, 0, 0), h, w)
    PNGFiles.save(filepath_output, out)
    return filepath_output
  end

  cols = distinguishable_colors(maxid)  # ok anche >256 perché NON è palette

  out = Matrix{RGB{N0f8}}(undef, h, w)
  @inbounds for r in 1:h, c in 1:w
    id = Int(masks[r, c])
    if id == 0
      out[r, c] = RGB{N0f8}(0, 0, 0)
    else
      col = cols[id]  # id in 1..maxid
      out[r, c] = RGB{N0f8}(col.r, col.g, col.b)
    end
  end

  PNGFiles.save(filepath_output, out)
  return filepath_output
end

"""
    render_graph_overlay_images(
      filepath_background,
      filepath_dataframe_edges,
      filepath_dataframe_labels,
      out_vertex_png,
      out_edges_png
    ) -> (out_vertex_png, out_edges_png)
    Renders overlay images of the graph (vertices and edges) on top of the background image.
    Saves two images:
    - out_vertex_png: image with vertices overlaid
    - out_edges_png: image with edges overlaid
"""
function render_graph_overlay_images(
  filepath_background::AbstractString,
  filepath_dataframe_edges::AbstractString,
  filepath_dataframe_labels::AbstractString,
  out_vertex_png::AbstractString,
  out_edges_png::AbstractString
)
  img_graph = Luxor.readpng(String(filepath_background))
  w = img_graph.width
  h = img_graph.height

  g_meta = J_Space.spatial_graph(String(filepath_dataframe_edges), String(filepath_dataframe_labels))

  # estrazione info (stesso schema del tuo threshold)
  vertex_positions = Luxor.Point[]
  vertex_labels = String[]
  vertex_colors = Any[]

  for v in MetaGraphs.vertices(g_meta)
    s = MetaGraphs.get_prop(g_meta, v, :centroid)
    coordinates_str = match(r"\((.*)\)", string(s)).captures[1]
    coords = parse.(Int, split(coordinates_str, ", "))
    x, y = coords[1], coords[2]
    push!(vertex_positions, Luxor.Point(y, x))
    push!(vertex_labels, string(MetaGraphs.get_prop(g_meta, v, :name)))
    push!(vertex_colors, MetaGraphs.get_prop(g_meta, v, :color_label))
  end

  # ---- vertices only
  @png begin
    Luxor.placeimage(img_graph, 0, 0, 0.8, centered=true)
    sethue("slateblue")
    Karnak.fontsize(7)
    Karnak.drawgraph(
      Graphs.SimpleGraph(MetaGraphs.nv(g_meta)),
      layout=vertex_positions .+ Karnak.Point(-w / 2, -h / 2),
      vertexlabels=vertex_labels,
      vertexfillcolors=vertex_colors,
      edgelines=:none
    )
  end w h String(out_vertex_png)

  # ---- edges
  graph_with_edges = Graphs.SimpleGraph(MetaGraphs.nv(g_meta))
  for e in MetaGraphs.edges(g_meta)
    Graphs.add_edge!(graph_with_edges, e.src, e.dst)
  end

  @png begin
    Luxor.placeimage(img_graph, 0, 0, 0.8, centered=true)
    sethue("slateblue")
    Karnak.fontsize(7)
    Karnak.drawgraph(
      graph_with_edges,
      layout=vertex_positions .+ Karnak.Point(-w / 2, -h / 2),
      vertexlabels=vertex_labels,
      vertexfillcolors=vertex_colors
    )
  end w h String(out_edges_png)

  return out_vertex_png, out_edges_png
end

end # module
