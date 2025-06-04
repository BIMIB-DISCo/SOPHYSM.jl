export get_random_color
export apply_segmentation_without_download
export apply_segmentation_with_download
export apply_segmentation_SOPHYSM_tessellation
export apply_segmentation_SOPHYSM_graph

"""
    get_random_color(seed)

Function to return a random 8-bit RGB format color, using a specified seed.

# Arguments
- `seed`: An integer used to initialize the random number generator.
If two calls to the function use the same seed, the same color will be generated.

# Return value
The function returns a random 8-bit RGB format color.
"""
function get_random_color(seed)
    Random.seed!(seed)
    rand(RGB{N0f8})
end

"""
    apply_segmentation_SOPHYSM_tessellation(filepath_input::AbstractString,
                                    filepath_output::AbstractString,
                                    thresholdGray::Float64,
                                    thresholdMarker::Float64,
                                    min_threshold::Float32,
                                    max_threshold::Float32)

The function performs segmentation of a histological slide, saves the segmented
image in `.png` format, generates the corresponding tessellation,
and translates it into an adjacency matrix and build the corresponding dataframe.

# Arguments
- `filepath_input::AbstractString`: The file path to the input image.
- `filepath_output::AbstractString`: The file path where the output files will be saved.
- `thresholdGray::Float64`: The grayscale threshold for image binarization.
- `thresholdMarker::Float64`: The threshold for marker-based segmentation.
- `min_threshold`: Minimal threshold for considering segments area.
- `max_threshold`: Maximal threshold for considering segments area.

# Notes
The function uses the watershed segmentation algorithm to segment the image into
different groups of pixels. Segmentation is performed using an image feature
transformation (`feature_transform`) and connected component labeling.
The `apply_segmentation_SOPHYSM` function reads an `.tif` image,
applies the SOPHYSM segmentation algorithm, and generates the following outputs:
1. Segmented image saved as "_seg.png" in the output directory.
2. Dataframe containing label information saved as "_dataframe_labels.csv"
in the output directory. Also, the dataframe contaning extra information about
the segment and label computed by the segmentation algorithm.
3. Adjacency matrix saved as ".txt" in the output directory.
4. Dataframe containing edge information saved as "_dataframe_edges.csv"
in the output directory.
5. Visualizations of the graph with vertices and edges saved as
"_graph_vertex.png" and "_graph_edges.png" in the output directory.
"""
function apply_segmentation_SOPHYSM_tessellation(filepath_input::AbstractString,
                                    filepath_output::AbstractString,
                                    thresholdGray::Float64,
                                    thresholdMarker::Float64,
                                    min_threshold::Float32,
                                    max_threshold::Float32)
    # load slide
    svs_image = read(filepath_input)
    img = ImageMagick.load_(svs_image)
    bw = Gray.(img) .> thresholdGray
    # define img dimensions
    width = size(img, 1)
    height = size(img, 2)
    dist = 1 .- distance_transform(feature_transform(bw))
    markers = label_components(dist .< thresholdMarker)
    # watershed
    segments = watershed(dist, markers)
    # build segmented slide
    labels = labels_map(segments)
    colored_labels = IndirectArray(labels, distinguishable_colors(maximum(labels)))
    masked_colored_labels = colored_labels .* (1 .- bw)
    # build dataframe
    df_labels = DataFrame()
    df_noisy_labels = DataFrame()
    df_total_labels = DataFrame()
    df_edges = DataFrame()
    df_labels, df_noisy_labels, df_total_labels = build_df_label(segments, min_threshold, max_threshold)
    # define centroids
    df_total_labels = compute_centroid_total_cells(segments, df_total_labels, min_threshold)
    df_labels = filter_dataframe_cells(df_total_labels, max_threshold)
    df_noisy_labels = filter_dataframe_extras(df_total_labels, min_threshold, max_threshold)
    # add column is_cell
    df_total_labels = add_column_is_cell(df_labels, df_noisy_labels, df_total_labels)
    # build tessellation
    base_path = splitext(filepath_output)[1]
    filepath_total_tess = base_path * "_total_tessellation.png"
    filepath_cell_tess = base_path * "_cell_tessellation.png"
    df_edges, edges = build_graph_from_tessellation(df_labels, df_noisy_labels, df_total_labels, width, height, filepath_total_tess, filepath_cell_tess)
    # save dataframe label as .CSV
    filepath_dataframe_labels = base_path * "_dataframe_labels.csv"
    CSV.write(filepath_dataframe_labels, df_labels)
    filepath_dataframe_total_labels = base_path * "_dataframe_total_labels.csv"
    CSV.write(filepath_dataframe_total_labels, df_total_labels)
    filepath_dataframe_noisy_labels = base_path * "_dataframe_noisy_labels.csv"
    CSV.write(filepath_dataframe_noisy_labels, df_noisy_labels)
    # build and save adjacency matrix
    matrix = tess_dataframe_to_adjacency_matrix_weight(df_total_labels, df_edges, edges)
    filepath_matrix = base_path * ".txt"
    save_adjacency_matrix(matrix, filepath_matrix)
    # build and save dataframe edgelist as .CSV
    filepath_dataframe_edges = base_path * "_dataframe_edges.csv"
    CSV.write(filepath_dataframe_edges, df_edges)
    # save segmented slide directly to filepath_output
    save(filepath_output, masked_colored_labels)

    # Derive the correct background file path
    filepath_background = filepath_output  # Use the same file as the segmented image

    # Generate accessory file paths
    filepath_img_graph_vertex = base_path * "_graph_vertex.png"
    filepath_img_graph_edges = base_path * "_graph_edges.png"
    img_graph = Luxor.readpng(filepath_background)  # Read the segmented image as background
    w = img_graph.width
    h = img_graph.height
    # g_meta_labels = J_Space.spatial_graph(filepath_dataframe_edges, filepath_dataframe_labels)
    g_meta_total_labels = J_Space.spatial_graph(filepath_dataframe_edges, filepath_dataframe_total_labels)
    # Image with Vertices
    @png begin
        Luxor.placeimage(img_graph, 0, 0, 0.8, centered=true)
        sethue("slateblue")
        Karnak.fontsize(7)
        
        # Extract graph information first
        vertex_positions = extract_vertex_position(g_meta_total_labels)
        vertex_labels = [MetaGraphs.get_prop(g_meta_total_labels, v, :name) for v in MetaGraphs.vertices(g_meta_total_labels)]
        vertex_colors = extract_vertex_color(g_meta_total_labels)
        
        # Draw the graph with extracted information - use the underlying graph
        Karnak.drawgraph(
            Graphs.SimpleGraph(MetaGraphs.nv(g_meta_total_labels)),  # Create empty simple graph with the right number of vertices
            layout = vertex_positions .+ Karnak.Point(-w/2, -h/2),
            vertexlabels = vertex_labels,
            vertexfillcolors = vertex_colors,
            edgelines=:none
        )
    end w h filepath_img_graph_vertex
    
    # Image with Edges
    @png begin
        Luxor.placeimage(img_graph, 0, 0, 0.8, centered=true)
        sethue("slateblue")
        Karnak.fontsize(7)
        
        # Extract graph information first
        vertex_positions = extract_vertex_position(g_meta_total_labels)
        vertex_labels = [MetaGraphs.get_prop(g_meta_total_labels, v, :name) for v in MetaGraphs.vertices(g_meta_total_labels)]
        vertex_colors = extract_vertex_color(g_meta_total_labels)
        
        # Create a graph with the same edges as g_meta_total_labels
        graph_with_edges = Graphs.SimpleGraph(MetaGraphs.nv(g_meta_total_labels))
        for e in MetaGraphs.edges(g_meta_total_labels)
            # Use the edge properties directly instead of Graphs.src/dst
            src_vertex = e.src
            dst_vertex = e.dst
            Graphs.add_edge!(graph_with_edges, src_vertex, dst_vertex)
        end
        
        # Draw the graph with extracted information - now including edges
        Karnak.drawgraph(
            graph_with_edges,  # Use the graph with edges instead of empty graph
            layout = vertex_positions .+ Karnak.Point(-w/2, -h/2),
            vertexlabels = vertex_labels,
            vertexfillcolors = vertex_colors
        )
    end w h filepath_img_graph_edges
end

"""
    apply_segmentation_SOPHYSM_graph(filepath_input::AbstractString,
                                    filepath_output::AbstractString,
                                    thresholdGray::Float64,
                                    thresholdMarker::Float64,
                                    min_threshold::Float32,
                                    max_threshold::Float32)

The function performs segmentation of a histological slide, saves the segmented
image in `.png` format, generates the corresponding graph,
and translates it into an adjacency matrix and build the corresponding dataframe.

# Arguments
- `filepath_input::AbstractString`: The file path to the input image.
- `filepath_output::AbstractString`: The file path where the output files will be saved.
- `thresholdGray::Float64`: The grayscale threshold for image binarization.
- `thresholdMarker::Float64`: The threshold for marker-based segmentation.
- `min_threshold`: Minimal threshold for considering segments area.
- `max_threshold`: Maximal threshold for considering segments area.

# Notes
The function uses the watershed segmentation algorithm to segment the image into
different groups of pixels. Segmentation is performed using an image feature
transformation (`feature_transform`) and connected component labeling.
The `apply_segmentation_SOPHYSM` function reads an `.tif` image,
applies the SOPHYSM segmentation algorithm, and generates the following outputs:
1. Segmented image saved as "_seg.png" in the output directory.
2. Dataframe containing label information saved as "_dataframe_labels.csv"
in the output directory. Also, the dataframe contaning extra information about
the segment and label computed by the segmentation algorithm.
3. Adjacency matrix saved as ".txt" in the output directory.
4. Dataframe containing edge information saved as "_dataframe_edges.csv"
in the output directory.
5. Visualizations of the graph with vertices and edges saved as
"_graph_vertex.png" and "_graph_edges.png" in the output directory.
"""
function apply_segmentation_SOPHYSM_graph(filepath_input::AbstractString,
                                    filepath_output::AbstractString,
                                    thresholdGray::Float64,
                                    thresholdMarker::Float64,
                                    min_threshold::Float32,
                                    max_threshold::Float32)
    # load slide
    svs_image = read(filepath_input)
    img = ImageMagick.load_(svs_image)
    bw = Gray.(img) .> thresholdGray
    dist = 1 .- distance_transform(feature_transform(bw))
    markers = label_components(dist .< thresholdMarker)
    # watershed
    segments = watershed(dist, markers)
    # build segmented slide
    labels = labels_map(segments)
    colored_labels = IndirectArray(labels, distinguishable_colors(maximum(labels)))
    masked_colored_labels = colored_labels .* (1 .- bw)
    # build dataframe
    weight_fn(i,j) = euclidean(segment_pixel_count(segments,i), segment_pixel_count(segments,j))
    df_label = DataFrame()
    df_noisy_labels = DataFrame()
    df_total_labels = DataFrame()
    G, vert_map, df_label, df_noisy_labels, df_total_labels = region_adjacency_graph_JHistint(segments, weight_fn, min_threshold, max_threshold)
    nvertices = length(vert_map)
    # define centroids
    df_total_labels = compute_centroid_total_cells(segments, df_total_labels, min_threshold)
    df_label = filter_dataframe_cells(df_total_labels, max_threshold)
    # define matrix
    base_path = splitext(filepath_output)[1]
    matrix = weighted_graph_to_adjacency_matrix(G, nvertices)
    filepath_matrix = base_path * ".txt"
    save_adjacency_matrix(matrix, filepath_matrix)
    df_edges = build_dataframe_as_edgelist(matrix, df_label.label)
    filepath_dataframe_labels = base_path * "_dataframe_labels.csv"
    CSV.write(filepath_dataframe_labels, df_label)
    filepath_dataframe_edges = base_path * "_dataframe_edges.csv"
    CSV.write(filepath_dataframe_edges, df_edges)
    # save segmented slide directly to filepath_output
    save(filepath_output, masked_colored_labels)

    # Derive the correct background file path
    filepath_background = filepath_output  # Use the same file as the segmented image

    # Generate accessory file paths
    filepath_img_graph_vertex = base_path * "_graph_vertex.png"
    filepath_img_graph_edges = base_path * "_graph_edges.png"
    img_graph = Luxor.readpng(filepath_background)  # Read the segmented image as background
    w = img_graph.width
    h = img_graph.height
    g_meta = J_Space.spatial_graph(filepath_dataframe_edges, filepath_dataframe_labels)

    # Verifica che il grafo sia stato costruito correttamente
    if MetaGraphs.nv(g_meta) == 0
        error("Il grafo costruito è vuoto. Verifica i dati di input e la costruzione del grafo.")
    end

    # Verifica che i vertici abbiano le proprietà richieste
    for v in MetaGraphs.vertices(g_meta)
        if !haskey(g_meta.vprops[v], :centroid)
            error("Il vertice $v non contiene la proprietà :centroid. Verifica la costruzione del grafo.")
        end
    end

    # Image with Vertices - graph function
    @png begin
        Luxor.placeimage(img_graph, 0, 0, 0.8, centered=true)
        sethue("slateblue")
        Karnak.fontsize(7)
        
        # Extract graph information first
        vertex_positions = extract_vertex_position(g_meta)
        vertex_labels = [MetaGraphs.get_prop(g_meta, v, :name) for v in MetaGraphs.vertices(g_meta)]
        vertex_colors = extract_vertex_color(g_meta)
        
        # Draw the graph with extracted information - use the underlying graph
        Karnak.drawgraph(
            Graphs.SimpleGraph(MetaGraphs.nv(g_meta)),  # Create empty simple graph with the right number of vertices
            layout = vertex_positions .+ Karnak.Point(-w/2, -h/2),
            vertexlabels = vertex_labels,
            vertexfillcolors = vertex_colors,
            edgelines=:none
        )
    end w h filepath_img_graph_vertex
    
    # Image with Edges
    @png begin
        Luxor.placeimage(img_graph, 0, 0, 0.8, centered=true)
        sethue("slateblue")
        Karnak.fontsize(7)
        
        # Extract graph information first
        vertex_positions = extract_vertex_position(g_meta)
        vertex_labels = [MetaGraphs.get_prop(g_meta, v, :name) for v in MetaGraphs.vertices(g_meta)]
        vertex_colors = extract_vertex_color(g_meta)
        
        # Create a graph with the same edges as g_meta
        graph_with_edges = Graphs.SimpleGraph(MetaGraphs.nv(g_meta))
        for e in MetaGraphs.edges(g_meta)
            # Use the edge properties directly instead of Graphs.src/dst
            src_vertex = e.src
            dst_vertex = e.dst
            Graphs.add_edge!(graph_with_edges, src_vertex, dst_vertex)
        end
        
        # Draw the graph with extracted information - now including edges
        Karnak.drawgraph(
            graph_with_edges,  # Use the graph with edges instead of empty graph
            layout = vertex_positions .+ Karnak.Point(-w/2, -h/2),
            vertexlabels = vertex_labels,
            vertexfillcolors = vertex_colors
        )
    end w h filepath_img_graph_edges
end