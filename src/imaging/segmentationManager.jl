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
    apply_segmentation_without_download(slide_info::Tuple{String, Vector{UInt8}, String})

The function performs the segmentation of a histological image, generates its
corresponding graph, and translates it into a symmetric adjacency
matrix with only 0s and 1s. Define, also, the dataframe
associated with labels and edges.

# Arguments
- `slide_info::Tuple{String, Vector{UInt8}, String}`: A tuple containing the
slide ID, the image obtained from the DB, and the path of the original image file.

# Return values
- `filepath_matrix`: The path where the adjacency matrix is stored in `.txt` format.
- `matrix`: The adjacency matrix constructed from the segmentation.

# Notes
The function uses the watershed segmentation algorithm to segment the image
into different groups of pixels. Segmentation is performed using a feature
transformation of the image (`feature_transform`) and labeling of connected
components. The distance between the different regions is then calculated,
and an adjacency graph of the regions is constructed using the
`region_adjacency_graph` function. The resulting graph is then transformed
into an Int adjacency matrix using the `weighted_graph_to_adjacency_matrix`
function and saved to the path of the original image.
"""
function apply_segmentation_without_download(slide_info::Tuple{String, Vector{UInt8}, String})
    svs_image = slide_info[2]
    slide_id = slide_info[1]
    println("LOAD SLIDE ... ($slide_id)")
    img = ImageMagick.load_(svs_image)
    bw = Gray.(img) .> 0.15
    dist = 1 .- distance_transform(feature_transform(bw))
    markers = label_components(dist .< -0.3)
    println("APPLY SEGMENTATION ... ($slide_id)")
    segments = watershed(dist, markers)
    println("BUILD GRAPH ... ($slide_id)")
    weight_fn(i,j) = euclidean(segment_pixel_count(segments,i), segment_pixel_count(segments,j))
    df_label = DataFrame()
    G, vert_map, df_label, df_noisy_labels, df_total_labels = region_adjacency_graph_JHistint(segments, weight_fn, 0.0f0, 3000.0f0)
    nvertices = length(vert_map)
    df_label = compute_centroid_cells(segments, df_label, 3000)
    println("BUILD & SAVE ADJACENCY MATRIX ... ($slide_id)")
    matrix = weighted_graph_to_adjacency_matrix(G, nvertices)
    filepath_matrix = replace(slide_info[3], ".tif" => ".txt")
    save_adjacency_matrix(matrix, filepath_matrix)
    println("SAVE DATAFRAME ... ($slide_id)")
    df_edges = build_dataframe_as_edgelist(matrix, df_label.label)
    filepath_dataframe_labels = replace(slide_info[3], r"....$" => "_dataframe_labels.csv")
    CSV.write(filepath_dataframe_labels, df_label)
    filepath_dataframe_edges = replace(slide_info[3], r"....$" => "_dataframe_edges.csv")
    CSV.write(filepath_dataframe_edges, df_edges)
    return filepath_matrix, matrix
end

"""
    apply_segmentation_with_download(slide_info::Tuple{String, Vector{UInt8}, String})

The function performs segmentation of a histological image, saves the segmented
image in `.png` format, generates the corresponding graph,
and translates it into an adjacency matrix. Define, also, the dataframe
associated with labels and edges.

# Arguments
- `slide_info::Tuple{String, Vector{UInt8}, String}`: Tuple containing the
slide ID, the image itself obtained from the DB, and the
path of the original image file.

# Return values
- `filepath_seg`: The path where the segmented image is stored in `.tif` format.
- `filepath_matrix`: The path where the graph is stored in `.txt` format.
- `matrix`: The adjacency matrix constructed from the segmentation.

# Notes
The function uses the watershed segmentation algorithm to segment the image into
different groups of pixels. Segmentation is performed using an image feature
transformation (`feature_transform`) and connected component labeling.
The distance between different regions is then calculated, and an adjacency
graph of the regions is constructed using the `region_adjacency_graph` function.
The obtained graph is transformed into an adjacency matrix using the
`weighted_graph_to_adjacency_matrix` function, which is saved
in the path of the original image.
Finally, a segmented `.png` image is saved, and the path of
the segmented slide file is returned. It performs also the visualizations of the
graph with vertices and edges saved as "_graph_vertex.png" and "_graph_edges.png"
in the output directory.
"""
function apply_segmentation_with_download(slide_info::Tuple{String, Vector{UInt8}, String})
    svs_image = slide_info[2]
    slide_id = slide_info[1]
    println("LOAD SLIDE ... ($slide_id)")
    img = ImageMagick.load_(svs_image)
    bw = Gray.(img) .> 0.15
    dist = 1 .- distance_transform(feature_transform(bw))
    markers = label_components(dist .< -0.3)
    println("APPLY SEGMENTATION ... ($slide_id)")
    segments = watershed(dist, markers)
    println("BUILD SEGMENTED SLIDE ... ($slide_id)")
    labels = labels_map(segments)
    colored_labels = IndirectArray(labels, distinguishable_colors(maximum(labels)))
    masked_colored_labels = colored_labels .* (1 .- bw)
    println("BUILD GRAPH ... ($slide_id)")
    weight_fn(i,j) = euclidean(segment_pixel_count(segments,i), segment_pixel_count(segments,j))
    df_label = DataFrame()
    G, vert_map, df_label, df_noisy_labels, df_total_labels = region_adjacency_graph_JHistint(segments, weight_fn, 0.0f0, 3000.0f0)
    nvertices = length(vert_map)
    df_label = compute_centroid_cells(segments, df_label, 3000)
    println("BUILD & SAVE ADJACENCY MATRIX ... ($slide_id)")
    matrix = weighted_graph_to_adjacency_matrix(G, nvertices)
    filepath_matrix = replace(slide_info[3], ".tif" => ".txt")
    save_adjacency_matrix(matrix, filepath_matrix)
    println("SAVE DATAFRAME ... ($slide_id)")
    df_edges = build_dataframe_as_edgelist(matrix, df_label.label)
    filepath_dataframe_labels = replace(slide_info[3], r"....$" => "_dataframe_labels.csv")
    CSV.write(filepath_dataframe_labels, df_label)
    filepath_dataframe_edges = replace(slide_info[3], r"....$" => "_dataframe_edges.csv")
    CSV.write(filepath_dataframe_edges, df_edges)
    println("SAVE SEGMENTED SLIDE ... ($slide_id)")
    filepath_seg_png = replace(slide_info[3], r"....$" => "_seg.png")
    filepath_background = replace(slide_info[3], r"....$" => "_seg-0.png")
    filepath_img_graph_vertex = replace(slide_info[3], r"....$" => "_graph_vertex.png")
    filepath_img_graph_edges = replace(slide_info[3], r"....$" => "_graph_edges.png")
    save(filepath_seg_png, masked_colored_labels)
    img_graph = Luxor.readpng(filepath_background)
    w = img_graph.width
    h = img_graph.height
    g_meta = J_Space.spatial_graph(filepath_dataframe_edges, filepath_dataframe_labels)
    # Image with Vertices
    @png begin
        Luxor.placeimage(img_graph, 0, 0, 0.8, centered=true)
        sethue("slateblue")
        Karnak.fontsize(7)
        drawgraph(g_meta,
            layout = extract_vertex_position(g_meta) .+ Karnak.Point(-w/2, -h/2),
            vertexlabels = [get_prop(g_meta, v, :name) for v in Graphs.vertices(g_meta)],
            vertexfillcolors = extract_vertex_color(g_meta),
            edgelines=:none
        )
    end w h filepath_img_graph_vertex
    # Image with Edges
    @png begin
        Luxor.placeimage(img_graph, 0, 0, 0.8, centered=true)
        sethue("slateblue")
        Karnak.fontsize(7)
        drawgraph(g_meta,
            layout = extract_vertex_position(g_meta) .+ Karnak.Point(-w/2, -h/2),
            vertexlabels = [get_prop(g_meta, v, :name) for v in Graphs.vertices(g_meta)],
            vertexfillcolors = extract_vertex_color(g_meta),
        )
    end w h filepath_img_graph_edges
    return filepath_seg, filepath_matrix, matrix
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
    filepath_total_tess = replace(filepath_output, r"....$" => "_total_tessellation.png")
    filepath_cell_tess = replace(filepath_output, r"....$" => "_cell_tessellation.png")
    df_edges, edges = build_graph_from_tessellation(df_labels, df_noisy_labels, df_total_labels, width, height, filepath_total_tess, filepath_cell_tess)
    # save dataframe label as .CSV
    filepath_dataframe_labels = replace(filepath_output, r"....$" => "_dataframe_labels.csv")
    CSV.write(filepath_dataframe_labels, df_labels)
    filepath_dataframe_total_labels = replace(filepath_output, r"....$" => "_dataframe_total_labels.csv")
    CSV.write(filepath_dataframe_total_labels, df_total_labels)
    filepath_dataframe_noisy_labels = replace(filepath_output, r"....$" => "_dataframe_noisy_labels.csv")
    CSV.write(filepath_dataframe_noisy_labels, df_noisy_labels)
    # build and save adjacency matrix
    matrix = tess_dataframe_to_adjacency_matrix_weight(df_total_labels, df_edges, edges)
    filepath_matrix = replace(filepath_output, r"....$" => ".txt")
    save_adjacency_matrix(matrix, filepath_matrix)
    # build and save dataframe edgelist as .CSV
    filepath_dataframe_edges = replace(filepath_output, r"....$" => "_dataframe_edges.csv")
    CSV.write(filepath_dataframe_edges, df_edges)
    # save segmented slide
    filepath_seg = replace(filepath_output, r"....$" => "_seg.png")
    save(filepath_seg, masked_colored_labels)

    # build metagraph on images
    filepath_background = replace(filepath_output, r"....$" => "_seg-0.png")
    filepath_img_graph_vertex = replace(filepath_output, r"....$" => "_graph_vertex.png")
    filepath_img_graph_edges = replace(filepath_output, r"....$" => "_graph_edges.png")
    img_graph = Luxor.readpng(filepath_background)
    w = img_graph.width
    h = img_graph.height
    # g_meta_labels = J_Space.spatial_graph(filepath_dataframe_edges, filepath_dataframe_labels)
    g_meta_total_labels = J_Space.spatial_graph(filepath_dataframe_edges, filepath_dataframe_total_labels)
    # Image with Vertices
    @png begin
        Luxor.placeimage(img_graph, 0, 0, 0.8, centered=true)
        sethue("slateblue")
        Karnak.fontsize(7)
        drawgraph(g_meta_total_labels,
            layout = extract_vertex_position(g_meta_total_labels) .+ Karnak.Point(-w/2, -h/2),
            vertexlabels = [get_prop(g_meta_total_labels, v, :name) for v in Graphs.vertices(g_meta_total_labels)],
            vertexfillcolors = extract_vertex_color(g_meta_total_labels),
            edgelines=:none
        )
    end w h filepath_img_graph_vertex
    # Image with Edges
    @png begin
        Luxor.placeimage(img_graph, 0, 0, 0.8, centered=true)
        sethue("slateblue")
        Karnak.fontsize(7)
        drawgraph(g_meta_total_labels,
            layout = extract_vertex_position(g_meta_total_labels) .+ Karnak.Point(-w/2, -h/2),
            vertexlabels = [get_prop(g_meta_total_labels, v, :name) for v in Graphs.vertices(g_meta_total_labels)],
            vertexfillcolors = extract_vertex_color(g_meta_total_labels),
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
    matrix = weighted_graph_to_adjacency_matrix(G, nvertices)
    filepath_matrix = replace(filepath_output, ".tif" => ".txt")
    save_adjacency_matrix(matrix, filepath_matrix)
    df_edges = build_dataframe_as_edgelist(matrix, df_label.label)
    filepath_dataframe_labels = replace(filepath_output, r"....$" => "_dataframe_labels.csv")
    CSV.write(filepath_dataframe_labels, df_label)
    filepath_dataframe_edges = replace(filepath_output, r"....$" => "_dataframe_edges.csv")
    CSV.write(filepath_dataframe_edges, df_edges)
    filepath_seg_png = replace(filepath_output, r"....$" => "_seg.png")
    filepath_background = replace(filepath_output, r"....$" => "_seg-0.png")
    filepath_img_graph_vertex = replace(filepath_output, r"....$" => "_graph_vertex.png")
    filepath_img_graph_edges = replace(filepath_output, r"....$" => "_graph_edges.png")
    save(filepath_seg_png, masked_colored_labels)
    img_graph = Luxor.readpng(filepath_background)
    w = img_graph.width
    h = img_graph.height
    g_meta = J_Space.spatial_graph(filepath_dataframe_edges, filepath_dataframe_labels)
    # Image with Vertices
    @png begin
        Luxor.placeimage(img_graph, 0, 0, 0.8, centered=true)
        sethue("slateblue")
        Karnak.fontsize(7)
        drawgraph(g_meta,
            layout = extract_vertex_position(g_meta) .+ Karnak.Point(-w/2, -h/2),
            vertexlabels = [get_prop(g_meta, v, :name) for v in Graphs.vertices(g_meta)],
            vertexfillcolors = extract_vertex_color(g_meta),
            edgelines=:none
        )
    end w h filepath_img_graph_vertex
    # Image with Edges
    @png begin
        Luxor.placeimage(img_graph, 0, 0, 0.8, centered=true)
        sethue("slateblue")
        Karnak.fontsize(7)
        drawgraph(g_meta,
            layout = extract_vertex_position(g_meta) .+ Karnak.Point(-w/2, -h/2),
            vertexlabels = [get_prop(g_meta, v, :name) for v in Graphs.vertices(g_meta)],
            vertexfillcolors = extract_vertex_color(g_meta),
        )
    end w h filepath_img_graph_edges
end