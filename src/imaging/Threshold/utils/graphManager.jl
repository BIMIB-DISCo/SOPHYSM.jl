export weighted_graph_to_adjacency_matrix
export weighted_graph_to_adjacency_matrix_weight
export save_adjacency_matrix
export region_adjacency_graph_JHistint
export build_dataframe_as_edgelist
export extract_vertex_position
export extract_vertex_color

"""
`SegmentedImage` type contains the index-label mapping, assigned labels,
segment mean intensity and pixel count of each segment.
struct SegmentedImage{T<:AbstractArray,U<:Union{Colorant,Real}}
    image_indexmap::T
    segment_labels::Vector{Int}
    segment_means::Dict{Int,U}
    segment_pixel_count::Dict{Int,Int}
end
"""
@static if Base.VERSION <= v"1.0.5"
    _oneunit(::CartesianIndex{N}) where {N} = _oneunit(CartesianIndex{N})
    _oneunit(::Type{CartesianIndex{N}}) where {N} = CartesianIndex(ntuple(x -> 1, Val(N)))
else
    const _oneunit = Base.oneunit
end

# Once Base has colon defined here we can replace this
_colon(I::CartesianIndex{N}, J::CartesianIndex{N}) where N =
    CartesianIndices(map((i,j) -> i:j, Tuple(I), Tuple(J)))

"""
    region_adjacency_graph_JHistint(s::SegmentedImage, weight_fn::Function,
                                min_threshold::Float32, max_threshold::Float32)

Constructs a region adjacency graph (RAG) from the `SegmentedImage`. It returns
the RAGalong with a Dict(label=>vertex) map and a dataframe containing the
information about the label. `weight_fn` is used to assign weights to the edges.

# Arguments :
- `s::SegmentedImage`: The input segmented image containing regions.
- `weight_fn::Function`: A function that calculates the weight between
two adjacent regions. The function should accept two region labels as arguments
and return a numeric value representing the weight.

# Return value :
- `G::SimpleWeightedGraph`: The adjacency graph between regions with weights
on the edges.
- `vert_map::Dict{Int, Int}`: A dictionary that maps region labels to nodes
in the graph.
- `df_label::DataFrame`: A DataFrame containing information about regions,
including their identifiers, positions, colors, and areas.

# Notes:
weight_fn(label1, label2): Returns a real number corresponding to the weight of
the edge between label1 and label2.
"""
function region_adjacency_graph_JHistint(s::SegmentedImage, weight_fn::Function,
                                min_threshold::Float32, max_threshold::Float32)

    function neighbor_regions!(df_cartesian_indices::AbstractArray,
                                G::SimpleWeightedGraph,
                                visited::AbstractArray,
                                s::SegmentedImage,
                                I::CartesianIndex)
        # n = Set{Int} - visited = Array - s = segmented image -
        # p = CartesianIndex which define neighbors
        # R contains each possible index in s
        R = CartesianIndices(axes(s.image_indexmap))
        # I1 contains a Vector of only 1 with dimension equal to visited
        I1 = _oneunit(CartesianIndex{ndims(visited)})
        # Ibegin and Iend contains the first and last index of R
        Ibegin, Iend = first(R), last(R)
        # t is only a empty Vector with dimension equal to visited
        t = Vector{CartesianIndex{ndims(visited)}}()
        # add index I to Vector t
        push!(t, I)
        while !isempty(t)
            # Extract last element of t and save it in temp
            temp = pop!(t)
            # set index temp to true
            visited[temp] = true
            # _colon build an object CartesianIndices which include
            # all the index from I to J (range) :
            for J in _colon(max(Ibegin, temp-I1), min(Iend, temp+I1))
                if s.image_indexmap[temp] != s.image_indexmap[J]
                    if !Graphs.has_edge(G, vert_map[s.image_indexmap[I]],
                                            vert_map[s.image_indexmap[J]])
                        Graphs.add_edge!(G, vert_map[s.image_indexmap[I]],
                                            vert_map[s.image_indexmap[J]],
                                            weight_fn(s.image_indexmap[I],
                                            s.image_indexmap[J]))
                    end
                elseif !visited[J]
                    push!(t,J)
                end
            end
        end
    end
    # Start
    # Array to mark the pixels that are already visited
    visited  = fill(false, axes(s.image_indexmap))
    # The region_adjacency_graph
    G        = SimpleWeightedGraph()
    # Map that stores (label, vertex) pairs
    vert_map = Dict{Int,Int}()
    # Build object for label (vertex) dataframe
    df_label = DataFrame()
    df_noisy_label = DataFrame()
    df_total_label = DataFrame()
    df_cartesian_indices = []
    df_color_indices = []
    # add vertices to graph
    Graphs.add_vertices!(G,length(s.segment_labels))
    # setup `vert_map`
    for (i,l) in enumerate(s.segment_labels)
        vert_map[l] = i
    end
    # add edges to graph
    for p in CartesianIndices(axes(s.image_indexmap))
        if !visited[p]
            push!(df_cartesian_indices, p)
            try
                neighbor_regions!(df_cartesian_indices, G, visited, s, p)
            catch oom
                if isa(oom, OutOfMemoryError)
                    GC.gc()
                    println(">>> OOM")
                    exit()
                end
            end
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

    G, vert_map, df_label, df_noisy_label, df_total_label
end


"""
    weighted_graph_to_adjacency_matrix(G::SimpleWeightedGraph{Int64, Float64}, n::Int64)

Converts a weighted graph represented as a `SimpleWeightedGraph`
into an unweighted boolean adjacency matrix.

# Arguments:
- `G::SimpleWeightedGraph{Int64, Float64}`: Weighted graph represented as a
`SimpleWeightedGraph` with integer vertex labels and floating-point edge weights.
- `n::Int64`: Number of nodes in the adjacency matrix.

# Return value:
- `adjacency_matrix`: `Matrix{Int64}` boolean adjacency matrix.

# Notes:
The function returns an `n` x `n` adjacency matrix representing the unweighted graph.
If nodes `i` and `j` are adjacent,the adjacency matrix will contain a value of
`1` at position `(i,j)` and `(j,i)`. Otherwise, the adjacency matrix will
contain a value of `0`.
"""
function weighted_graph_to_adjacency_matrix(G::SimpleWeightedGraph{Int64, Float64}, n::Int64)
    adjacency_matrix = zeros(Int, n, n)
    for i in 1:n
        for j in 1:n
            if Graphs.has_edge(G, i, j)
                adjacency_matrix[i, j] = 1
                adjacency_matrix[j, i] = 1
            end
        end
    end
    return adjacency_matrix
end

"""
    weighted_graph_to_adjacency_matrix_weight(G::SimpleWeightedGraph{Int64, Float64}, n::Int64)

Converts a weighted graph represented as a `SimpleWeightedGraph`
into an weighted adjacency matrix.

# Arguments:
- `G::SimpleWeightedGraph{Int64, Float64}`: Weighted graph represented as a
`SimpleWeightedGraph` with integer vertex labels and floating-point edge weights.
- `n::Int64`: Number of nodes in the adjacency matrix.

# Return value:
- `adjacency_matrix`: `Matrix{Float32}` boolean adjacency matrix.

# Notes:
The function returns an `n` x `n` adjacency matrix representing the weighted graph.
If nodes `i` and `j` are adjacent,the adjacency matrix will contain a value
associated with the edge weight at position `(i,j)` and `(j,i)`.
Otherwise, the adjacency matrix will contain a value of `-1`.
"""
function weighted_graph_to_adjacency_matrix_weight(G::SimpleWeightedGraph{Int64, Float64}, n::Int64)
    adjacency_matrix = zeros(Float32, n, n)
    for i in 1:n
        for j in 1:n
            adjacency_matrix[i, j] = -1
            adjacency_matrix[j, i] = -1
        end
    end

    for i in 1:n
        for j in 1:n
            if Graphs.has_edge(G, i, j)
                adjacency_matrix[i, j] = SimpleWeightedGraphs.get_weight(G, i, j)
                adjacency_matrix[j, i] = SimpleWeightedGraphs.get_weight(G, i, j)
            end
        end
    end
    return adjacency_matrix
end


"""
    build_dataframe_as_edgelist(mat::Matrix{Int64}, label_list::Vector{Int64})

Builds a DataFrame representing an edge list from an input adjacency matrix `mat`
and a list of labels `label_list`.

# Arguments:
- `mat::Matrix{Int64}`: The input adjacency matrix where elements represent
connections between nodes.
- `label_list::Vector{Int64}`: A list of node labels to consider when
constructing the edge list.

# Return value:
- `df::DataFrame`: A DataFrame representing the edges in the graph,
with columns 'origin', 'destination', and 'weight' indicating the source node,
target node, and edge weight, respectively.

# Notes:
The `build_dataframe_as_edgelist` function constructs a DataFrame that
represents the edges in a graph based on the adjacency matrix `mat`.
It iterates through the upper triangular part of the matrix and adds edges to
the DataFrame for non-zero values while considering only nodes
with labels present in `label_list`.
"""
function build_dataframe_as_edgelist(mat::Matrix{Int64}, label_list::Vector{Int64})
    df = DataFrame()
    df_origin_column = []
    df_destination_column = []
    df_weight_column = []
    n = size(mat, 1)
    for i in 1:n
        for j in 1:i
            if mat[i,j] != 0 && i in label_list && j in label_list
                push!(df_origin_column, i)
                push!(df_destination_column, j)
                push!(df_weight_column, mat[i,j])
            end
        end
    end
    df.origin = df_origin_column
    df.destination = df_destination_column
    df.weight = df_weight_column
    return df
end

"""
    build_dataframe_as_edgelist(mat::Matrix{Float32}, label_list::Vector{Int64})

Builds a DataFrame representing an edge list from an input adjacency matrix `mat`
and a list of labels `label_list`.

# Arguments:
- `mat::Matrix{Float32}`: The input adjacency matrix where elements represent
connections between nodes. In this case, the matrix has Float value.
- `label_list::Vector{Int64}`: A list of node labels to consider when
constructing the edge list.

# Return value:
- `df::DataFrame`: A DataFrame representing the edges in the graph,
with columns 'origin', 'destination', and 'weight' indicating the source node,
target node, and edge weight, respectively.

# Notes:
The `build_dataframe_as_edgelist` function constructs a DataFrame that
represents the edges in a graph based on the adjacency matrix `mat`.
It iterates through the upper triangular part of the matrix and adds edges to
the DataFrame for values different from `-1` while considering only nodes
with labels present in `label_list`.
"""
function build_dataframe_as_edgelist(mat::Matrix{Float32}, label_list::Vector{Int64})
    df = DataFrame()
    df_origin_column = []
    df_destination_column = []
    df_weight_column = []
    n = size(mat, 1)
    for i in 1:n
        for j in 1:i
            if mat[i,j] != -1 && i in label_list && j in label_list
                push!(df_origin_column, i)
                push!(df_destination_column, j)
                push!(df_weight_column, mat[i,j])
            end
        end
    end
    df.origin = df_origin_column
    df.destination = df_destination_column
    df.weight = df_weight_column
    return df
end


"""
    save_adjacency_matrix(matrix::Matrix{Int64}, filepath_matrix::AbstractString)

Function to save an adjacency matrix represented as an integer matrix to a
text file.

# Arguments:
- `matrix::Matrix{Int64}`: The integer matrix representing the adjacency matrix.
- `filepath_matrix::AbstractString`: The file path represented as a string
indicating where to save the matrix.

# Notes
The function opens the file specified by the `filepath_matrix` path in write
mode and writes the matrix in adjacency matrix format, where each row represents
the adjacent nodes of a node. The numbers in the matrix are separated by spaces.
"""
function save_adjacency_matrix(matrix::Matrix{Int64}, filepath_matrix::AbstractString)
    # Open txt file
    f = open(filepath_matrix, "w")
    # Write matrix dimensions
    n_rows, n_cols = size(matrix)
    matrix_string = ""
    for i in 1:n_rows
        write(f, " ")
        for j in 1:n_cols
            matrix_string = string("", matrix[i, j], "  ")
            write(f, matrix_string)
        end
        write(f, "\n")
    end
    close(f)
end

"""
    save_adjacency_matrix(matrix::Matrix{Float32}, filepath_matrix::AbstractString)

Function to save an adjacency matrix represented as a float matrix to a
text file.

# Arguments:
- `matrix::Matrix{Float32}`: The float matrix representing the adjacency matrix.
- `filepath_matrix::AbstractString`: The file path represented as a string
indicating where to save the matrix.

# Notes
The function opens the file specified by the `filepath_matrix` path in write
mode and writes the matrix in adjacency matrix format, where each row represents
the adjacent nodes of a node. The numbers in the matrix are separated by spaces.
"""
function save_adjacency_matrix(matrix::Matrix{Float32}, filepath_matrix::AbstractString)
    # Open txt file
    f = open(filepath_matrix, "w")
    # Write matrix dimensions
    n_rows, n_cols = size(matrix)
    matrix_string = ""
    for i in 1:n_rows
        write(f, " ")
        for j in 1:n_cols
            matrix_string = string("", matrix[i, j], "  ")
            write(f, matrix_string)
        end
        write(f, "\n")
    end
    close(f)
end

"""
    extract_vertex_position(G::MetaGraph)

Extracts the vertex positions from a MetaGraph `G`.

# Arguments:
- `G::MetaGraph`: The input MetaGraph containing vertices with
associated positions.

# Return value:
- `position_array::Vector{Luxor.Point}`: An array containing `Luxor.Points`
representing the positions of the vertices in `G`.
"""
function extract_vertex_position(G::MetaGraph)
    # Verifica che il grafo abbia vertici
    if MetaGraphs.nv(G) == 0
        error("Il grafo non contiene vertici. Verifica l'inizializzazione del grafo.")
    end

    position_array = Luxor.Point[]
    for v in MetaGraphs.vertices(G)
        # Verifica che la proprietà :centroid esista per il vertice
        if !haskey(G.vprops[v], :centroid)
            error("Il vertice $v non contiene la proprietà :centroid. Verifica la costruzione del grafo.")
        end

        s = MetaGraphs.get_prop(G, v, :centroid)
        coordinates_str = match(r"\((.*)\)", string(s)).captures[1]
        coordinates = parse.(Int, split(coordinates_str, ", "))
        
        # Handle both 2D and 3D coordinates
        if length(coordinates) >= 2
            # For 2D coordinates, use only x and y
            if length(coordinates) == 2
                x, y = coordinates
                point = Luxor.Point(y, x)
            # For 3D or more coordinates, use first three
            else
                x, y, z = coordinates
                point = Luxor.Point(y, x)
            end
            push!(position_array, point)
        else
            error("Il vertice $v ha un formato di coordinate non valido: $coordinates")
        end
    end
    return position_array
end

"""
    extract_vertex_color(G::MetaGraph)

Extracts the vertex colors from a MetaGraph `G`.

# Arguments:
- `G::MetaGraph`: The input MetaGraph containing vertices with associated colors.

# Return value:
- `color_array::Vector{Any}`: An array containing the extracted color
information associated with the vertices in `G`.
"""
function extract_vertex_color(G::MetaGraph)
    color_array = []
    for v in MetaGraphs.vertices(G)
        color_float = MetaGraphs.get_prop(G, v, :color_label)
        push!(color_array, color_float)
    end
    return color_array
end
