export compute_centroid_total_cells
export compute_centroid_cells
export compute_centroid_noisy_cells
export filter_dataframe_cells
export filter_dataframe_extras

"""
    compute_centroid_total_cells(s::SegmentedImage,
                                        df_label::DataFrame,
                                        min_threshold::Float32)

Computes the centroids of total cells within regions in a segmented image `s`
and associates them with labels in the provided DataFrame `df_label`.

# Arguments:
- `s::SegmentedImage`: The segmented image containing regions.
- `df_label::DataFrame`: A DataFrame with information about the regions,
including labels and other attributes.
- `min_threshold`: Minimal threshold for considering segments area.

# Return value:
- `df_label::DataFrame`: The input DataFrame `df_label` with an additional
`centroid` column containing the computed centroids of total cells.

# Notes:
The `compute_centroid_total_cells` function iterates through the pixels in the
segmented image `s` to identify total cells within regions.
It calculates the centroids of these total cells and associates
them with their corresponding labels in the `df_label` DataFrame.
The function marks pixels as visited to avoid redundant calculations
and applies a manual threshold to exclude noise by considering only
regions with pixel counts greater than the specified threshold (default = 300 pixels).
"""
function compute_centroid_total_cells(s::SegmentedImage,
                                        df_label::DataFrame,
                                        min_threshold::Float32)
    # # Array to mark the pixels that are already visited
    visited  = fill(false, axes(s.image_indexmap))
    df_centroids = CartesianIndex[]
    df_label_list = Int[]
    df_cells_indices = []
    for p in CartesianIndices(axes(s.image_indexmap))
        # 0.6854407198549426
        if s.segment_means[s.image_indexmap[p]] != 0
            if !visited[p]
                push!(df_cells_indices, p)
                visited[p] = true
                for j in CartesianIndices(axes(s.image_indexmap))
                    if s.image_indexmap[p] == s.image_indexmap[j] && !visited[j]
                        push!(df_cells_indices, j)
                        visited[j] = true
                    end
                end
                # manual threshold for cells dimension in pixel (delete noise)
                if(s.segment_pixel_count[s.image_indexmap[p]] > min_threshold)
                    centroid = div(s.segment_pixel_count[s.image_indexmap[p]], 2)
                    if(!(df_cells_indices[centroid] in df_centroids))
                        push!(df_label_list, s.image_indexmap[p])
                        push!(df_centroids, df_cells_indices[centroid])
                    end
                end
                df_cells_indices = []
            end
        end
    end
    nuclei_list = df_label[!, :label]
    position = 99
    df_centroid_ordered = [CartesianIndex(0,0) for _ in 1:length(nuclei_list)]
    for (index, pointer) in enumerate(df_label_list)
        for j in eachindex(nuclei_list)
            if(nuclei_list[j] == pointer)
                position = j
            end
        end
        df_centroid_ordered[position] = df_centroids[index]
    end
    df_label.centroid = df_centroid_ordered
    df_label
end

"""
    compute_centroid_cells(s::SegmentedImage,
                                df_label::DataFrame,
                                max_threshold::Float32)

Computes the centroids of only cells associated to nuclei
within regions in a segmented image `s` and associates them with labels
in the provided DataFrame `df_label`.

# Arguments:
- `s::SegmentedImage`: The segmented image containing regions.
- `df_label::DataFrame`: A DataFrame with information about the regions,
including labels and other attributes.
- `max_threshold`: Maximal threshold for considering segments area.

# Return value:
- `df_label::DataFrame`: The input DataFrame `df_label` with an additional
`centroid` column containing the computed centroids of cells.
"""
function compute_centroid_cells(s::SegmentedImage,
                                df_label::DataFrame,
                                max_threshold::Float32)
    # Array to mark the pixels that are already visited
    visited  = fill(false, axes(s.image_indexmap))
    df_centroids = CartesianIndex[]
    df_cells_indices = []
    df_label_list = Int[]
    for p in CartesianIndices(axes(s.image_indexmap))
        # 0.6854407198549426
        if s.segment_means[s.image_indexmap[p]] != 0
            if !visited[p]
                push!(df_cells_indices, p)
                visited[p] = true
                for j in CartesianIndices(axes(s.image_indexmap))
                    if s.image_indexmap[p] == s.image_indexmap[j] && !visited[j]
                        push!(df_cells_indices, j)
                        visited[j] = true
                    end
                end
                # manual threshold for cells dimension in pixel (delete noise)
                if(s.segment_pixel_count[s.image_indexmap[p]] > max_threshold)
                    centroid = div(s.segment_pixel_count[s.image_indexmap[p]], 2)
                    if(!(df_cells_indices[centroid] in df_centroids))
                        push!(df_label_list, s.image_indexmap[p])
                        push!(df_centroids, df_cells_indices[centroid])
                    end
                end
                df_cells_indices = []
            end
        end
    end
    nuclei_list = df_label[!, :label]
    position = 99
    df_centroid_ordered = [CartesianIndex(0,0) for _ in 1:length(nuclei_list)]
    for (index, pointer) in enumerate(df_label_list)
        for j in eachindex(nuclei_list)
            if(nuclei_list[j] == pointer)
                position = j
            end
        end
        df_centroid_ordered[position] = df_centroids[index]
    end
    df_label.centroid = df_centroid_ordered
    df_label
end

"""
    compute_centroid_noisy_cells(s::SegmentedImage,
                                        df_label::DataFrame,
                                        min_threshold::Float32,
                                        max_threshold::Float32)

Computes the centroids of extra or noisy within regions in a segmented image `s`
and associates them with labels in the provided DataFrame `df_label`.

# Arguments:
- `s::SegmentedImage`: The segmented image containing regions.
- `df_label::DataFrame`: A DataFrame with information about the regions,
including labels and other attributes.
- `min_threshold`: Minimal threshold for considering segments area.
- `max_threshold`: Maximal threshold for considering segments area.

# Return value:
- `df_label::DataFrame`: The input DataFrame `df_label` with an additional
`centroid` column containing the computed centroids of extra cells.
"""
function compute_centroid_noisy_cells(s::SegmentedImage,
                                        df_label::DataFrame,
                                        min_threshold::Float32,
                                        max_threshold::Float32)
    ## Array to mark the pixels that are already visited
    visited  = fill(false, axes(s.image_indexmap))
    df_centroids = CartesianIndex[]
    df_cells_indices = []
    df_label_list = Int[]
    for p in CartesianIndices(axes(s.image_indexmap))
        # 0.6854407198549426
        if s.segment_means[s.image_indexmap[p]] != 0
            if !visited[p]
                push!(df_cells_indices, p)
                visited[p] = true
                for j in CartesianIndices(axes(s.image_indexmap))
                    if s.image_indexmap[p] == s.image_indexmap[j] && !visited[j]
                        push!(df_cells_indices, j)
                        visited[j] = true
                    end
                end
                # manual threshold for cells dimension in pixel (delete noise)
                if(s.segment_pixel_count[s.image_indexmap[p]] <= max_threshold &&
                    s.segment_pixel_count[s.image_indexmap[p]] > min_threshold)
                    centroid = div(s.segment_pixel_count[s.image_indexmap[p]], 2)
                    if(!(df_cells_indices[centroid] in df_centroids))
                        push!(df_label_list, s.image_indexmap[p])
                        push!(df_centroids, df_cells_indices[centroid])
                    end
                end
                df_cells_indices = []
            end
        end
    end
    nuclei_list = df_label[!, :label]
    position = 99
    df_centroid_ordered = [CartesianIndex(0,0) for _ in 1:length(nuclei_list)]
    for (index, pointer) in enumerate(df_label_list)
        for j in eachindex(nuclei_list)
            if(nuclei_list[j] == pointer)
                position = j
            end
        end
        df_centroid_ordered[position] = df_centroids[index]
    end
    df_label.centroid = df_centroid_ordered
    df_label
end

"""
    filter_dataframe_cells(df_label::DataFrame, max_threshold::Float32)

Filters a DataFrame containing information about regions to retain only cells
with areas greater than a specified threshold.

# Arguments:
- `df_label::DataFrame`: The input DataFrame containing region information.
- `max_threshold`: Maximal threshold for considering segments area.

# Return value:
- `df_filtered::DataFrame`: A filtered DataFrame containing information
about the retained cells, including labels, positions, colors, areas,
and centroids.

# Notes:
The `filter_dataframe_cells` function takes a DataFrame `df_label` as input,
which should contain information about regions, including labels, positions,
colors, areas, and centroids. It filters this DataFrame to retain only those
regions (cells) with areas greater a specified threshold (default = 3000 pixels).
"""
function filter_dataframe_cells(df_label::DataFrame, max_threshold::Float32)
    df_label_filtered = Int[]
    df_cartesian_indices_filtered = CartesianIndex[]
    df_color_indices_filtered = []
    df_area_filtered = Int[]
    df_centroid_filtered = CartesianIndex[]
    df_filtered = DataFrame()
    for i in eachrow(df_label)
        label = i.label
        position_label = i.position_label
        color_label = i.color_label
        area = i.area
        centroid = i.centroid
        if(area > max_threshold)
            push!(df_label_filtered, label)
            push!(df_cartesian_indices_filtered, position_label)
            push!(df_color_indices_filtered, color_label)
            push!(df_area_filtered, area)
            push!(df_centroid_filtered, centroid)
        end
    end
    df_filtered.label = df_label_filtered
    df_filtered.position_label = df_cartesian_indices_filtered
    df_filtered.color_label = df_color_indices_filtered
    df_filtered.area = df_area_filtered
    df_filtered.centroid = df_centroid_filtered
    df_filtered
end

"""
    filter_dataframe_extras(df_label::DataFrame,
                                    min_threshold::Float32,
                                    max_threshold::Float32)

Filters a DataFrame containing information about regions to retain only extra
elements (not cells) with areas between two specified thresholds.
In the default case these are 300 and 3000 pixels.

# Arguments:
- `df_label::DataFrame`: The input DataFrame containing region information.
- `min_threshold`: Minimal threshold for considering segments area.
- `max_threshold`: Maximal threshold for considering segments area.

# Return value:
- `df_filtered::DataFrame`: A filtered DataFrame containing information
about the retained extra elements, including labels, positions, colors, areas,
and centroids.

# Notes:
The `filter_dataframe_extras` function takes a DataFrame `df_label` as input,
which should contain information about regions, including labels, positions,
colors, areas, and centroids. It filters this DataFrame to retain only those
regions that are considered "extras" (not cells) and have areas between
two specified thresholds.
"""
function filter_dataframe_extras(df_label::DataFrame,
                                    min_threshold::Float32,
                                    max_threshold::Float32)
    df_label_filtered = Int[]
    df_cartesian_indices_filtered = CartesianIndex[]
    df_color_indices_filtered = []
    df_area_filtered = Int[]
    df_centroid_filtered = CartesianIndex[]
    df_filtered = DataFrame()
    for i in eachrow(df_label)
        label = i.label
        position_label = i.position_label
        color_label = i.color_label
        area = i.area
        centroid = i.centroid
        if(area <= max_threshold && area > min_threshold)
            push!(df_label_filtered, label)
            push!(df_cartesian_indices_filtered, position_label)
            push!(df_color_indices_filtered, color_label)
            push!(df_area_filtered, area)
            push!(df_centroid_filtered, centroid)
        end
    end
    df_filtered.label = df_label_filtered
    df_filtered.position_label = df_cartesian_indices_filtered
    df_filtered.color_label = df_color_indices_filtered
    df_filtered.area = df_area_filtered
    df_filtered.centroid = df_centroid_filtered
    df_filtered
end

