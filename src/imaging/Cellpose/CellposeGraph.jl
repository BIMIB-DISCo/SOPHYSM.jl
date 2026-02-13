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
using FileIO

using J_Space

export cellpose_masks_to_dataframes,
  build_graph_from_tessellation_cellpose,
  adjacency_from_edges_weight,
  save_adjacency_matrix,
  save_jspace_adjacency_matrix,
  save_segmented_png_from_masks,
  graph_overlay_paths,
  render_graph_overlay_images,
  voronoi_overlay_path_original,
  graph_edges_overlay_path_original,
  render_voronoi_overlay_image,
  render_edges_overlay_on_original

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

"""
  Clamps the row and column indices to be within the bounds of the image dimensions.
  - r: row index (1-based)
  - c: column index (1-based)
  - h: height of the image
  - w: width of the image
  Returns a tuple (rr, cc) where:
  - rr: clamped row index (1 <= rr <= h)
"""
@inline function _clamp_rc(r::Real, c::Real, h::Real, w::Real)
  rr = clamp(round(Int, r), 1, floor(Int, h))
  cc = clamp(round(Int, c), 1, floor(Int, w))
  return rr, cc
end

"""
  _sanitize_edges(edges::Vector{Any}, n::Int) -> Vector{Tuple{Int,Int}}
  Takes a vector of edges (which may be in various formats) and sanitizes them to ensure they are valid tuples of integer indices within the range of 1 to n.
  Each edge is expected to represent a connection between two nuclei, where the indices correspond to rows in the DataFrame of nuclei.
  The function checks each edge for validity, including:
    - It must be a Tuple or AbstractVector with at least 2 elements.
    - The first two elements must be integers representing the connected nuclei.
    - The indices must be within the range [1, n] and not equal to each other (no self-loops).
  Returns a vector of sanitized edges as Tuple{Int, Int} that can be safely used for graph construction.
"""
@inline function _sanitize_edges(edges::Vector{Any}, n::Int)
  out = Vector{Tuple{Int,Int}}()
  for e in edges
    if !(e isa Tuple || e isa AbstractVector) || length(e) < 2
      continue
    end
    a = e[1]
    b = e[2]
    if !(a isa Integer && b isa Integer)
      continue
    end
    ia = Int(a)
    ib = Int(b)
    if ia < 1 || ib < 1 || ia > n || ib > n || ia == ib
      continue
    end
    push!(out, (ia, ib))
  end
  return out
end

"""
  Converts a point from Voronoi/GeometryBasics coordinates (x, y_neg) to Luxor coordinates (x, y) where y is flipped and centered.
  Voronoi/GeometryBasics: y increases downwards (like image coordinates), so y_neg = -y
  Luxor: y increases upwards, and (0,0) is at the center of the image
  W, H are the width and height of the image for centering the coordinates
"""
@inline function _to_luxor_from_voronoi(p::GeometryBasics.Point2{Float64}, W::Int, H::Int)
  # p = (x, y_neg) where y_neg = -r
  x = p[1]
  y = -p[2]
  return Luxor.Point(x - W / 2, y - H / 2)
end

"""
  _edge_segment(e)
  Attempts to extract the endpoints of an edge from a given edge object.
  The function tries multiple approaches to find the endpoints, including:
    1) Checking if the edge is a Tuple or AbstractVector with at least 2 elements (e[1], e[2]).
    2) Checking for common property names that might contain the endpoints (e.g., :p1, :p2 or :a, :b).
  Returns a tuple (a, b) if the endpoints are successfully extracted, or nothing if no suitable endpoints are found.
  Note: This function is designed to be robust against different edge object structures that may arise from VoronoiCells or other libraries
"""
function _edge_segment(e)
  if e isa Tuple || e isa AbstractVector
    if length(e) >= 2
      return e[1], e[2]
    end
  end
  try
    a = getproperty(e, :p1)
    b = getproperty(e, :p2)
    return a, b
  catch
  end
  try
    a = getproperty(e, :a)
    b = getproperty(e, :b)
    return a, b
  catch
  end
  return nothing
end

"""
  Normalize a point to GeometryBasics.Point2{Float64} if possible.
  Accepts:
    - GeometryBasics.Point2{Float64} (returns as is)
    - GeometryBasics.Point2 with other numeric type (converts to Float64)
    - Tuple with at least 2 numeric elements (converts to Point2{Float64})
  Returns:
    - GeometryBasics.Point2{Float64} if conversion is successful
    - nothing if the input cannot be converted to a valid _as_point2
"""
function _as_point2(p)
  if p isa GeometryBasics.Point2{Float64}
    return p
  elseif p isa GeometryBasics.Point2
    return GeometryBasics.Point2{Float64}(Float64(p[1]), Float64(p[2]))
  elseif p isa Tuple && length(p) >= 2
    return GeometryBasics.Point2{Float64}(Float64(p[1]), Float64(p[2]))
  end
  return nothing
end

"""
  Converts row/column indices (r, c) to a GeometryBasics.Point2 with coordinates (x=c, y=-r) for Voronoi plotting.
  This is necessary because VoronoiCells and GeometryBasics use a coordinate system where y increases downwards (like image coordinates), 
  while Luxor uses a coordinate system where y increases upwards.
"""
@inline function _to_voronoi_point(r::Int, c::Int)
  return GeometryBasics.Point2(Float64(c), -Float64(r))
end

"""
  _luxor_read_any_image(path::AbstractString) -> (img, tmp_png)
  Reads an image from the given path and returns it as a Luxor image object.
  If the image format is not directly supported by Luxor, it attempts to load it using FileIO or Images,
  convert it to RGB, and save it as a temporary PNG file that Luxor can read.
  Returns a tuple (img, tmp_png) where:
    - img: the Luxor image object read from the file
    - tmp_png: the path to the temporary PNG file if conversion was needed, or nothing if the original image was directly read by Luxor
  Note: the caller is responsible for deleting the temporary PNG file if it was created.
"""
function _luxor_read_any_image(path::AbstractString)
  p = String(path)
  ext = lowercase(splitext(p)[2])

  if ext == ".png"
    return Luxor.readpng(p), nothing
  end

  img = nothing
  try
    img = FileIO.load(p)
  catch
    img = Images.load(p)
  end

  img_rgb = RGB.(img)
  tmp_png = tempname() * ".png"
  PNGFiles.save(tmp_png, img_rgb)

  return Luxor.readpng(tmp_png), tmp_png
end

"""
  _tess_cells(tess)
  Attempts to extract the cells (polygons) from a Voronoi tessellation object.
  The function tries multiple approaches to find the cells, including:
    1) Checking for a direct property (e.g., tess.Cells).
    2) Checking for known functions in VoronoiCells that might return cells.
    3) Checking for common property names that might contain the cells.
    4) As a last resort, iterating over all properties of the tessellation to find any that contain a vector of polygons.
  Returns the cells as an AbstractVector if found, or nothing if no suitable cells are found.
  Note: This function is designed to be robust against different versions of VoronoiCells or different tessellation object structures.
"""
function _tess_cells(tess)
  try
    v = getproperty(tess, :Cells)
    if v isa AbstractVector
      return v
    end
  catch
  end

  for f in (
    () -> VoronoiCells.cells(tess),
    () -> VoronoiCells.polygons(tess),
    () -> VoronoiCells.cellpolygons(tess),
  )
    try
      v = f()
      if v isa AbstractVector || v isa Tuple
        return v
      end
    catch
    end
  end

  for name in (:Cells, :cells, :polygons, :cellpolygons, :cell_polygons, :cellpolygon)
    try
      v = getproperty(tess, name)
      if v isa AbstractVector || v isa Tuple
        return v
      end
    catch
    end
  end

  try
    for name in propertynames(tess)
      name in (:rect, :bbox, :rectangle, :edges, :sites, :points) && continue
      v = getproperty(tess, name)

      if v isa AbstractVector && !isempty(v)
        return v
      end
      if v isa Tuple
        for vv in v
          if vv isa AbstractVector && !isempty(vv)
            return vv
          end
        end
      end
    end
  catch
  end

  return nothing
end

"""
  _cell_vertices(cell)
  Attempts to extract the vertices of a Voronoi cell from a given cell object.
  The function tries multiple approaches to find the vertices, including:
    1) Checking for known functions in VoronoiCells that might return vertices.
    2) Checking for common property names that might contain the vertices.
    3) As a last resort, iterating over all properties of the cell to find any that contain a vector of points.
  Returns the vertices as an AbstractVector if found, or nothing if no suitable vertices are found.
  Note: This function is designed to be robust against different versions of VoronoiCells or different cell object structures.
"""
function _cell_vertices(cell)
  for f in (
    () -> VoronoiCells.vertices(cell),
  )
    try
      v = f()
      if v isa AbstractVector
        return v
      end
    catch
    end
  end

  for name in (:vertices, :polygon, :poly, :points, :coords)
    try
      v = getproperty(cell, name)
      if v isa AbstractVector
        return v
      end
    catch
    end
  end

  try
    for name in propertynames(cell)
      v = getproperty(cell, name)
      if v isa AbstractVector && length(v) >= 2
        return v
      end
    end
  catch
  end

  return nothing
end

"""
  graph_overlay_paths(output_png::AbstractString) -> (vertex_path, edges_path)
  Returns the file paths for the graph overlay images based on the given output PNG path.
    - output_png: path to the original output PNG
    - vertex_path: path to the PNG image for graph vertices
    - edges_path: path to the PNG image for graph edges
"""
function graph_overlay_paths(output_png::AbstractString)
  base = splitext(String(output_png))[1]
  return (base * "_graph_vertex.png", base * "_graph_edges.png")
end

"""
  graph_edges_overlay_path_original(output_png::AbstractString) -> String
  Returns the file path for the graph edges overlay image on the original image, based on the given output PNG path.
    - output_png: path to the original output PNG
    - returns: path to the PNG image for graph edges overlay on the original image
"""
function graph_edges_overlay_path_original(output_png::AbstractString)
  base = splitext(String(output_png))[1]
  return base * "_graph_edges_orig.png"
end

"""
  voronoi_overlay_path_original(output_png::AbstractString) -> String
  Returns the file path for the Voronoi overlay image on the original image, based on the given output PNG path.
    - output_png: path to the original output PNG
    - returns: path to the PNG image for Voronoi overlay on the original image
"""
function voronoi_overlay_path_original(output_png::AbstractString)
  base = splitext(String(output_png))[1]
  return base * "_voronoi_orig.png"
end

"""
  save_adjacency_matrix(matrix::Matrix{Int}, filepath_matrix::AbstractString)
  Saves the given adjacency matrix to a text file with space-separated values.
    - matrix: NxN matrix of integers representing the adjacency (e.g., weights or binary connections)
    - filepath_matrix: path to save the output text file
  The output file will have N lines, each containing N space-separated integers corresponding to the rows of the matrix.
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
  save_segmented_png_from_masks(masks, filepath_output)
    Saves a PNG image where each unique integer in the masks matrix is colored with a distinct color.
    - masks: HxW matrix of integers where 0 = background, and positive integers = nucleus labels
    - filepath_output: path to save the output PNG
    The output PNG will have the same dimensions as masks, with each nucleus colored differently for visualization.
"""
function save_segmented_png_from_masks(
  masks::AbstractMatrix{<:Integer},
  filepath_output::AbstractString
)
  h, w = size(masks)
  maxid = maximum(masks)

  if maxid == 0
    out = fill(RGB{N0f8}(0, 0, 0), h, w)
    PNGFiles.save(filepath_output, out)
    return filepath_output
  end

  cols = distinguishable_colors(maxid)

  out = Matrix{RGB{N0f8}}(undef, h, w)
  @inbounds for r in 1:h, c in 1:w
    id = Int(masks[r, c])
    if id == 0
      out[r, c] = RGB{N0f8}(0, 0, 0)
    else
      col = cols[id]
      out[r, c] = RGB{N0f8}(col.r, col.g, col.b)
    end
  end

  PNGFiles.save(filepath_output, out)
  return filepath_output
end

"""
  cellpose_masks_to_dataframes(masks, min_threshold, max_threshold) -> (df_cells, df_noisy, df_total)
  Converts Cellpose masks to DataFrames with properties for each detected nucleus.
    - masks: HxW matrix of integers where 0 = background, and positive integers = nucleus labels
    - min_threshold: minimum area (in pixels) for a detection to be considered valid (included in df_total)
    - max_threshold: area threshold above which a detection is considered a "good cell" (is_cell == true in df_total, included in df_cells)
  Returns a tuple of DataFrames:
    - df_cells: subset of detections with area > max_threshold (is_cell == true)
    - df_noisy: subset of detections with min_threshold < area <= max_threshold (is_cell == false)
    - df_total: all detections with area > min_threshold, with a boolean column :is_cell indicating if they are "good cells" or "noisy"
  Each DataFrame contains columns:
    - :label (integer label from masks)
    - :position_label (CartesianIndex of the top-left pixel of the bounding box)
    - :color_label (assigned color for visualization)
    - :area (number of pixels in the mask)
    - :centroid (CartesianIndex of the centroid of the mask)
    - :is_cell (boolean, true if area > max_threshold, false if min_threshold < area <= max_threshold)
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

  area = zeros(Int, maxid)
  sum_r = zeros(Int, maxid)
  sum_c = zeros(Int, maxid)

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
  build_dataframe_edges_from_grid_cellpose(edges, df_total)
    Builds a DataFrame with columns :origin, :destination, :weight from the given edges and df_total.
      - edges: Vector of Tuple{Int,Int} with 1-based indices corresponding to rows in df_total
      - df_total: DataFrame with columns :label and :area for all nuclei
    The weight is defined as the absolute difference in area between the two nuclei connected by the edge.
    Returns a DataFrame where each row corresponds to an edge, with the original labels and computed weights.
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
  build_graph_from_tessellation_cellpose(df_cells, df_noisy, df_total, h, w, filepath_total_tess, filepath_cell_tess)
    Builds a graph from the Voronoi tessellation of the nuclei centroids, and saves two PNG visualizations:
      - filepath_total_tess: Voronoi tessellation of all nuclei (df_total)
      - filepath_cell_tess: Voronoi tessellation of all nuclei with highlighted subset (df_cells)
    Returns a tuple (df_edges, edges_sane) where:
      - df_edges: DataFrame with columns :origin, :destination, :weight for each edge
      - edges_sane: Vector of Tuple{Int,Int} with the valid edges (1
      -based indices corresponding to df_total rows)
  Expects:
    - df_total: DataFrame with columns :label, :area, :centroid (CartesianIndex), etc. for all nuclei
    - df_cells: subset of df_total with "good" cells (is_cell == true)
    - df_noisy: subset of df_total with "noisy" detections (is_cell == false)
    - h, w: dimensions of the original image (for clamping centroids and plotting)
"""
function build_graph_from_tessellation_cellpose(
  df_cells::DataFrame,
  df_noisy::DataFrame,
  df_total::DataFrame,
  h::Int, w::Int,
  filepath_total_tess::AbstractString,
  filepath_cell_tess::AbstractString
)
  total_list = df_total.centroid
  total_label_list = df_total.label

  position_array = GeometryBasics.Point2{Float64}[]
  for v in total_list
    r, c = Tuple(v)
    r, c = _clamp_rc(r, c, h, w)
    push!(position_array, _to_voronoi_point(r, c))
  end

  cell_position_array = GeometryBasics.Point2{Float64}[]
  cell_label_list = Int[]
  if nrow(df_cells) > 0
    for (v, lab) in zip(df_cells.centroid, df_cells.label)
      r, c = Tuple(v)
      r, c = _clamp_rc(r, c, h, w)
      push!(cell_position_array, _to_voronoi_point(r, c))
      push!(cell_label_list, lab)
    end
  end

  rect = VoronoiCells.Rectangle(
    GeometryBasics.Point2(1.0, -Float64(h)),
    GeometryBasics.Point2(Float64(w), -1.0)
  )

  raw_edges = Any[]
  tess_total = VoronoiCells.voronoicells(position_array, rect; edges=raw_edges)

  n = nrow(df_total)
  edges_sane = _sanitize_edges(raw_edges, n)

  df_edges = build_dataframe_edges_from_grid_cellpose(edges_sane, df_total)

  dx, dy = 6.0, 6.0
  Plots.scatter(position_array, markersize=3, label="All nuclei centroids")
  if length(position_array) > 0
    Plots.annotate!([
      (position_array[k][1] + dx,
        position_array[k][2] + dy,
        Plots.text(total_label_list[k], 6, RGBA(1, 1, 1, 0.25)))
      for k in 1:length(position_array)
    ])
  end
  p1 = Plots.plot!(tess_total, legend=:topleft)
  Plots.savefig(p1, filepath_total_tess)

  Plots.plot(tess_total, legend=:topleft, label="Voronoi (all nuclei)")
  Plots.scatter!(position_array, markersize=2, label="All nuclei")

  if length(cell_position_array) > 0
    Plots.scatter!(cell_position_array, markersize=4, label="Highlighted subset (df_cells)")
    Plots.annotate!([
      (cell_position_array[k][1] + dx,
        cell_position_array[k][2] + dy,
        Plots.text(cell_label_list[k], 6, RGBA(1, 1, 1, 0.45)))
      for k in 1:length(cell_position_array)
    ])
  end

  Plots.savefig(filepath_cell_tess)

  return df_edges, edges_sane
end

"""
  adjacency_from_edges_weight(df_total, df_edges, edges)
    Creates an adjacency matrix from the edges and their weights.
  - df_total: DataFrame with all nuclei (used to determine size n)
  - df_edges: DataFrame with columns :origin, :destination, :weight (weights must be in same order as edges)
  - edges: Vector of Tuple{Int,Int} with the edges (1-based indices corresponding to df_total rows)
  Returns an n x n matrix where entry (i, j) is the weight of the edge between nuclei i and j, or -1 if no edge exists.
  Note: expects that the order of weights in df_edges corresponds exactly to the order of edges in the edges vector (i.e., df_edges[k, :] corresponds to edges[k]).
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
    render_graph_overlay_images(filepath_background, filepath_dataframe_edges, filepath_dataframe_labels, out_vertex_png, out_edges_png)
    Renders two PNG images with graph overlays:
    - out_vertex_png: only vertices (no edges)
    - out_edges_png: vertices + edges
    Uses the background image and the graph data from the dataframes.
      - filepath_background: path to the background image (any format supported by FileIO/Images)
      - filepath_dataframe_edges: CSV with columns :origin, :destination, :weight
      - filepath_dataframe_labels: CSV with columns :label, :centroid, :color_label
      - out_vertex_png: output path for the PNG with vertices overlay
      - out_edges_png: output path for the PNG with edges overlay
"""
function render_graph_overlay_images(
  filepath_background::AbstractString,
  filepath_dataframe_edges::AbstractString,
  filepath_dataframe_labels::AbstractString,
  out_vertex_png::AbstractString,
  out_edges_png::AbstractString
)
  img_graph, tmp_png = _luxor_read_any_image(filepath_background)
  w = img_graph.width
  h = img_graph.height

  g_meta = J_Space.spatial_graph(String(filepath_dataframe_edges), String(filepath_dataframe_labels))

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

  if tmp_png !== nothing
    try
      rm(tmp_png; force=true)
    catch
    end
  end

  return out_vertex_png, out_edges_png
end

"""
  render_edges_overlay_on_original(filepath_original, filepath_dataframe_edges, filepath_dataframe_labels, out_edges_png)
    Overlay of Voronoi edges on the original image, using the graph edges from the dataframe.
      - filepath_original: path to the original image (any format supported by FileIO/Images)
      - filepath_dataframe_edges: CSV with columns :origin, :destination, :weight
      - filepath_dataframe_labels: CSV with columns :label, :centroid, :color_label
      - out_edges_png: output path for the PNG with edges overlay
"""
function render_edges_overlay_on_original(
  filepath_original::AbstractString,
  filepath_dataframe_edges::AbstractString,
  filepath_dataframe_labels::AbstractString,
  out_edges_png::AbstractString
)
  tmp_vertex = splitext(String(out_edges_png))[1] * "_tmp_vertex.png"
  render_graph_overlay_images(
    filepath_original,
    filepath_dataframe_edges,
    filepath_dataframe_labels,
    tmp_vertex,
    out_edges_png
  )
  # pulizia
  try
    rm(tmp_vertex; force=true)
  catch
  end
  return out_edges_png
end

"""
  render_voronoi_overlay_image(filepath_original, df_total, out_voronoi_png; line_alpha=0.65, line_width=1.2)
    Overlay of Voronoi tessellation on the original image, using centroids from df_total.
      - filepath_original: path to the original image (any format supported by FileIO/Images)
      - df_total: DataFrame with column :centroid containing CartesianIndex(r, c) for each nucleus
      - out_voronoi_png: output path for the PNG with Voronoi overlay
      - line_alpha: transparency of Voronoi edges (default 0.65)
      - line_width: width of Voronoi edges (default 1.2)
"""
function render_voronoi_overlay_image(
  filepath_original::AbstractString,
  df_total::DataFrame,
  out_voronoi_png::AbstractString;
  line_alpha::Float64=0.65,
  line_width::Float64=1.2
)
  img, tmp_png = _luxor_read_any_image(filepath_original)

  W = Int(round(img.width))
  H = Int(round(img.height))

  position_array = GeometryBasics.Point2{Float64}[]
  for v in df_total.centroid
    r, c = Tuple(v)
    r, c = _clamp_rc(r, c, H, W)
    push!(position_array, _to_voronoi_point(r, c))
  end

  rect = VoronoiCells.Rectangle(
    GeometryBasics.Point2(1.0, -Float64(H)),
    GeometryBasics.Point2(Float64(W), -1.0)
  )

  tess = VoronoiCells.voronoicells(position_array, rect)

  cells = _tess_cells(tess)
  cells === nothing && error("VoronoiCells: cannot extract cells from tessellation (try tess.Cells).")

  @png begin
    Luxor.placeimage(img, 0, 0, 1.0, centered=true)

    Luxor.setline(line_width)
    Luxor.sethue(RGBA(1, 1, 1, line_alpha))

    for poly in cells
      if !(poly isa AbstractVector) || length(poly) < 2
        continue
      end

      p1 = _as_point2(poly[1])
      p1 === nothing && continue

      Luxor.newpath()
      Luxor.move(_to_luxor_from_voronoi(p1, W, H))

      for k in 2:length(poly)
        pk = _as_point2(poly[k])
        pk === nothing && continue
        Luxor.line(_to_luxor_from_voronoi(pk, W, H))
      end

      Luxor.closepath()
      Luxor.strokepath()
    end
  end W H String(out_voronoi_png)

  if tmp_png !== nothing
    try
      rm(tmp_png; force=true)
    catch
    end
  end

  return out_voronoi_png
end

"""
  save_jspace_adjacency_matrix(df_total, df_edges, filepath)
  Export adjacency matrix in J-SPACE format:
  - NxN where N = nrow(df_total)
  - symmetric
  - binary (0/1)
  - space-separated rows
  - works even if df_total.label is NOT 1..N consecutive (uses label->index mapping)
  - expects df_edges columns :origin and :destination to contain LABELS (not indices)
"""
function save_jspace_adjacency_matrix(
  df_total::DataFrame,
  df_edges::DataFrame,
  filepath::AbstractString
)
  n = nrow(df_total)

  if n == 0
    open(filepath, "w") do io
    end
    return String(filepath)
  end

  total_cols = Set(Symbol.(names(df_total)))
  edge_cols = Set(Symbol.(names(df_edges)))

  (:label in total_cols) ||
    error("df_total must contain column :label (found: $(names(df_total)))")

  (:origin in edge_cols && :destination in edge_cols) ||
    error("df_edges must contain columns :origin and :destination (found: $(names(df_edges)))")

  label_to_idx = Dict{Int,Int}()

  @inbounds for (idx, lab) in enumerate(df_total.label)
    lab === missing && continue
    label_to_idx[Int(lab)] = idx
  end

  A = fill(0, n, n)

  @inbounds for row in eachrow(df_edges)
    lab_i = row.origin
    lab_j = row.destination

    (lab_i === missing || lab_j === missing) && continue

    i = get(label_to_idx, Int(lab_i), 0)
    j = get(label_to_idx, Int(lab_j), 0)

    if i != 0 && j != 0 && i != j
      A[i, j] = 1
      A[j, i] = 1
    end
  end

  @inbounds for i in 1:n
    A[i, i] = 0
  end


  open(filepath, "w") do io
    @inbounds for i in 1:n
      println(io, join(@view(A[i, :]), " "))
    end
  end

  return String(filepath)
end


end # module