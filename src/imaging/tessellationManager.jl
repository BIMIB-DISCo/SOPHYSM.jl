export build_df_label
export add_column_is_cell
export build_dataframe_edges_from_grid
export build_graph_from_tessellation
export tess_dataframe_to_adjacency_matrix_weight

"""
    build_df_label(s::SegmentedImage, min_threshold::Float32, max_threshold::Float32)

Builds DataFrames containing information about regions in a segmented image,
including labels, positions, colors, and areas, and separates them into noisy,
filtered, and total regions based on pixel count.

# Arguments :
- `s::SegmentedImage`: The segmented image containing regions.
- `min_threshold`: Minimal threshold for considering segments area.
- `max_threshold`: Maximal threshold for considering segments area.

# Return value :
- `df_label::DataFrame`: A DataFrame containing information about filtered regions
, regions associated with cell or nuclei.
- `df_noisy_label::DataFrame`: A DataFrame containing information about noisy regions.
- `df_total_label::DataFrame`: A DataFrame containing information about all regions.

"""
function build_df_label(s::SegmentedImage, min_threshold::Float32, max_threshold::Float32)
    # Array to mark the pixels that are already visited
    visited  = fill(false, axes(s.image_indexmap))
    df_label = DataFrame()
    df_noisy_label = DataFrame()
    df_total_label = DataFrame()
    df_cartesian_indices = []
    df_color_indices = []
    for p in CartesianIndices(axes(s.image_indexmap))
        # check if p of the segmented image s is not visited
        if !visited[p]
            push!(df_cartesian_indices, p)
        end
    end

    for i in s.segment_labels
        push!(df_color_indices, s.segment_means[i])
    end
    # Filter noisy segments from segmentation
    # Building object for DataFrame df_label
    df_label_filtered = Int[]
    df_cartesian_indices_filtered = CartesianIndex[]
    df_color_indices_filtered = []
    df_area_filtered = Int[]

    df_label_filtered_extra = Int[]
    df_cartesian_indices_filtered_extra = CartesianIndex[]
    df_color_indices_filtered_extra = []
    df_area_filtered_extra = Int[]

    df_label_total = Int[]
    df_cartesian_indices_total = CartesianIndex[]
    df_color_indices_total = []
    df_area_total = Int[]
    for i in 1:length(s.segment_labels)
        if(s.segment_pixel_count[i] > max_threshold)
            push!(df_label_filtered, s.segment_labels[i])
            push!(df_cartesian_indices_filtered, df_cartesian_indices[i])
            push!(df_color_indices_filtered, df_color_indices[i])
            push!(df_area_filtered, s.segment_pixel_count[i])
        end
        if(s.segment_pixel_count[i] <= max_threshold &&
            s.segment_pixel_count[i] > min_threshold)
            push!(df_label_filtered_extra, s.segment_labels[i])
            push!(df_cartesian_indices_filtered_extra, df_cartesian_indices[i])
            push!(df_color_indices_filtered_extra, df_color_indices[i])
            push!(df_area_filtered_extra, s.segment_pixel_count[i])
        end
        if(s.segment_pixel_count[i] > min_threshold)
            push!(df_label_total, s.segment_labels[i])
            push!(df_cartesian_indices_total, df_cartesian_indices[i])
            push!(df_color_indices_total, df_color_indices[i])
            push!(df_area_total, s.segment_pixel_count[i])
        end
    end
    df_label.label = df_label_filtered
    df_label.position_label = df_cartesian_indices_filtered
    df_label.color_label = df_color_indices_filtered
    df_label.area = df_area_filtered

    df_noisy_label.label = df_label_filtered_extra
    df_noisy_label.position_label = df_cartesian_indices_filtered_extra
    df_noisy_label.color_label = df_color_indices_filtered_extra
    df_noisy_label.area = df_area_filtered_extra

    df_total_label.label = df_label_total
    df_total_label.position_label = df_cartesian_indices_total
    df_total_label.color_label = df_color_indices_total
    df_total_label.area = df_area_total

    df_label, df_noisy_label, df_total_label
end

"""
    add_column_is_cell(df_labels::DataFrame, df_noisy_labels::DataFrame, df_total_labels::DataFrame)

Adds a boolean column 'is_cell' to the total labels DataFrame,
indicating whether each region is a cell or not.

# Arguments:
- `df_labels::DataFrame`: A DataFrame containing information about filtered
regions (default : areas > 3000 pixels).
- `df_noisy_labels::DataFrame`: A DataFrame containing information about
noisy regions (default : areas between 300 and 3000 pixels).
- `df_total_labels::DataFrame`: A DataFrame containing information about
all regions (default : areas > 300 pixels).

# Return value:
- `df_total_labels::DataFrame`: The `df_total_labels` DataFrame with
the additional `is_cell` column.

# Notes:
"""
function add_column_is_cell(df_labels::DataFrame, df_noisy_labels::DataFrame, df_total_labels::DataFrame)
    nuclei_list = df_labels[!, :label]
    extra_list = df_noisy_labels[!, :label]
    total_list = df_total_labels[!, :label]
    is_cell_list = Bool[]
    for label_index in total_list
        if label_index in nuclei_list
            push!(is_cell_list, true)
        end
        if label_index in extra_list
            push!(is_cell_list, false)
        end
    end
    df_total_labels.is_cell = is_cell_list
    df_total_labels
end

"""
    build_dataframe_edges_from_grid(edge_list::Vector{Any}, df_total_labels::DataFrame)

Builds a DataFrame containing edge information from a given list of grid-based
edges and a DataFrame of total region labels.

# Arguments:
- `edge_list::Vector{Any}`: A list of grid-based edges represented as pairs
of indices.
- `df_total_labels::DataFrame`: A DataFrame containing information about all
regions, including labels and areas.

# Return value:
- `df::DataFrame`: A DataFrame containing information about edges,
including origin, destination, and edge weight.
"""
function build_dataframe_edges_from_grid(edge_list::Vector{Any}, df_total_labels::DataFrame)
    # Build edge_list with label identifier
    cell_label_list = df_total_labels[!, :label]
    cell_area_list = df_total_labels[!, :area]
    edge_label = []
    edge_weight = []
    count = 1
    for pair_label in edge_list
        first_value = pair_label[1]
        second_value = pair_label[2]
        origin = cell_label_list[first_value]
        destination = cell_label_list[second_value]
        push!(edge_label, (origin, destination))
        if(cell_area_list[first_value] > cell_area_list[second_value])
            push!(edge_weight, (cell_area_list[first_value] - cell_area_list[second_value]))
        else
            push!(edge_weight, (cell_area_list[second_value] - cell_area_list[first_value]))
        end
        count = count + 1
    end
    # Build df_edges
    df = DataFrame()
    df_origin_column = []
    df_destination_column = []
    df_weight_column = []
    for pair_label in edge_label
        push!(df_origin_column, pair_label[1])
        push!(df_destination_column, pair_label[2])
    end
    for weight in edge_weight
        push!(df_weight_column, weight)
    end
    df.origin = df_origin_column
    df.destination = df_destination_column
    df.weight = df_weight_column
    df
end

"""
    build_graph_from_tessellation(df_labels::DataFrame,
                               df_noisy_labels::DataFrame,
                               df_total_labels::DataFrame,
                               w::Int64, h::Int64,
                               filepath_total_tess::AbstractString,
                               filepath_cell_tess::AbstractString)

Builds a graph rapresentation of the segmented image based on Voronoi
tessellations and saves visualizations.

# Arguments:
- `df_labels::DataFrame`: A DataFrame containing information about
nuclei and centroids.
- `df_noisy_labels::DataFrame`: A DataFrame containing information
about noisy nuclei centroids.
- `df_total_labels::DataFrame`: A DataFrame containing information
about all centroids.
- `w::Int64`: Width of the tessellation region.
- `h::Int64`: Height of the tessellation region.
- `filepath_total_tess::AbstractString`: The file path to save the
visualization of the total tessellation.
- `filepath_cell_tess::AbstractString`: The file path to save the
visualization of the cell-based tessellation.

# Return value:
- `df_edges::DataFrame`: A DataFrame containing edge information between regions.
- `edges::Vector{Any}`: A vector of pairs representing the connected
regions based on Voronoi edges.

# Notes:
The `build_graph_from_tessellation` function performs the following steps:
1. Extracts centroid positions from the provided DataFrames.
2. Performs Voronoi tessellations for both the total and cell-based centroids.
3. Plots the tessellations, including centroids and labels.
4. Saves the visualizations to the specified file paths.
5. Constructs an edge DataFrame based on Voronoi edges.
"""
function build_graph_from_tessellation(df_labels::DataFrame,
                               df_noisy_labels::DataFrame,
                               df_total_labels::DataFrame,
                               w::Int64, h::Int64,
                               filepath_total_tess::AbstractString,
                               filepath_cell_tess::AbstractString)
    nuclei_list = df_labels[!, :centroid]
    extra_list = df_noisy_labels[!, :centroid]
    total_list = df_total_labels[!, :centroid]
    nuclei_label_list = df_labels[!, :label]
    cell_slot = length(nuclei_list)
    extra_slot = length(extra_list)
    total_slot = length(total_list)
    # VORONOICELLS IMPLEMENTATION
    position_array = Vector{GeometryBasics.Point2{Float64}}()
    cell_position_array = Vector{GeometryBasics.Point2{Float64}}()
    extra_position_array = Vector{GeometryBasics.Point2{Float64}}()
    for vertex in nuclei_list
        coordinates_str = match(r"\((.*)\)", string(vertex)).captures[1]
        coordinates = parse.(Int, split(coordinates_str, ", "))
        # Extract only x and y coordinates (first and second elements)
        if length(coordinates) >= 2
            x, y = coordinates[1], coordinates[2]
            point = GeometryBasics.Point2(y, -x)
            push!(cell_position_array, point)
        end
    end
    for vertex in extra_list
        coordinates_str = match(r"\((.*)\)", string(vertex)).captures[1]
        coordinates = parse.(Int, split(coordinates_str, ", "))
        # Extract only x and y coordinates (first and second elements)
        if length(coordinates) >= 2
            x, y = coordinates[1], coordinates[2]
            point = GeometryBasics.Point2(y, -x)
            push!(extra_position_array, point)
        end
    end
    for vertex in total_list
        coordinates_str = match(r"\((.*)\)", string(vertex)).captures[1]
        coordinates = parse.(Int, split(coordinates_str, ", "))
        # Extract only x and y coordinates (first and second elements)
        if length(coordinates) >= 2
            x, y = coordinates[1], coordinates[2]
            point = GeometryBasics.Point2(y, -x)
            push!(position_array, point)
        end
    end
    
    h = h + 1
    w = w + 1
    # First tessellation
    rect = VoronoiCells.Rectangle(GeometryBasics.Point2(0, 0),
                                  GeometryBasics.Point2(h, -w))
    edges = []
    tess = VoronoiCells.voronoicells(position_array, rect; edges)
    Plots.scatter(cell_position_array, markersize = 4, label = "Nuclei Centroid")
    Plots.annotate!([(cell_position_array[n][1],
                    cell_position_array[n][2],
                    Plots.text(nuclei_label_list[n])) for n in 1:cell_slot])
    plot_tessellation = Plots.plot!(tess, legend = :topleft)
    Plots.savefig(plot_tessellation, filepath_total_tess)
    df_edges = build_dataframe_edges_from_grid(edges, df_total_labels)

    # Second tessellation
    rect = VoronoiCells.Rectangle(GeometryBasics.Point2(0, 0),
                                  GeometryBasics.Point2(h, -w))
    tess = VoronoiCells.voronoicells(cell_position_array, rect)
    Plots.scatter(cell_position_array, markersize = 4, label = "Nuclei Centroid")
    Plots.annotate!([(cell_position_array[n][1],
                    cell_position_array[n][2],
                    Plots.text(nuclei_label_list[n])) for n in 1:cell_slot])
    plot_tessellation = Plots.plot!(tess, legend = :topleft)
    Plots.savefig(plot_tessellation, filepath_cell_tess)
    return df_edges, edges
end

"""
    tess_dataframe_to_adjacency_matrix_weight(df_total_labels::DataFrame, df_edges::DataFrame, edges::Vector{Any})

Converts a DataFrame representation of edges and region labels
into an adjacency matrix with weighted edges.

# Arguments:
- `df_total_labels::DataFrame`: A DataFrame containing information
about all regions, including labels.
- `df_edges::DataFrame`: A DataFrame containing edge information,
including origin, destination, and edge weight.
- `edges::Vector{Any}`: A vector of pairs representing the connected regions.

# Return value:
- `adjacency_matrix::Matrix{Int}`: An adjacency matrix representing the
connectivity of regions with weighted edges.
"""
function tess_dataframe_to_adjacency_matrix_weight(df_total_labels::DataFrame, df_edges::DataFrame, edges::Vector{Any})
    cell_label_list = df_total_labels[!, :label]
    # origin_list = df_edges[!, :origin]
    # destination_list = df_edges[!, :destination]
    weight_list = df_edges[!, :weight]
    n = length(cell_label_list)
    adjacency_matrix = zeros(Int, n, n)
    for i in 1:n
        for j in 1:n
            adjacency_matrix[i, j] = -1
            adjacency_matrix[j, i] = -1
        end
    end
    count = 1
    for label_pair in edges
        adjacency_matrix[label_pair[1], label_pair[2]] =  weight_list[count]
        count = count + 1
    end
    return adjacency_matrix
end