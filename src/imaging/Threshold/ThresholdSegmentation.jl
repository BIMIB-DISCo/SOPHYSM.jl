module ThresholdSegmentation

### Packages
using DataFrames
using Images
using ImageSegmentation
using ImageMagick
using FileIO
using Random
using IndirectArrays
using Graphs
using SimpleWeightedGraphs
using CSV
using J_Space
using Luxor
using Karnak
using MetaGraphs
using Plots
using VoronoiCells
using GeometryBasics

### Exported Functions
export start_segmentation_SOPHYSM_tessellation
export start_segmentation_SOPHYSM_graph

### Included Files
include("utils/segmentationManager.jl")
include("utils/graphManager.jl")
include("utils/noiseManager.jl")
include("utils/tessellationManager.jl")

"""
    start_segmentation_SOPHYSM_tessellation(filepath_input::AbstractString,
                                filepath_output::AbstractString,
                                thresholdGray::Float64,
                                thresholdMarker::Float64,
                                min_threshold::Float32,
                                max_threshold::Float32)

Starts the SOPHYSM tessellation-based segmentation process with given parameters.

# Arguments
- `filepath_input`: Path to the input image file
- `filepath_output`: Path where output will be saved
- `thresholdGray`: Threshold for grayscale conversion
- `thresholdMarker`: Threshold for marker-based segmentation
- `min_threshold`: Minimum area threshold for segments
- `max_threshold`: Maximum area threshold for segments

# Returns
- The filepath of the generated output
"""
function start_segmentation_SOPHYSM_tessellation(
    filepath_input::AbstractString,
    filepath_output::AbstractString,
    thresholdGray::Float64,
    thresholdMarker::Float64,
    min_threshold::Float32,
    max_threshold::Float32)
    
    apply_segmentation_SOPHYSM_tessellation(
        filepath_input,
        filepath_output,
        thresholdGray,
        thresholdMarker,
        min_threshold,
        max_threshold)
                                
    return filepath_output
end

"""
    start_segmentation_SOPHYSM_graph(filepath_input::AbstractString,
                                    filepath_output::AbstractString,
                                    thresholdGray::Float64,
                                    thresholdMarker::Float64,
                                    min_threshold::Float32,
                                    max_threshold::Float32)

    Starts the SOPHYSM graph-based segmentation process with given parameters.
    # Arguments
    - `filepath_input`: Path to the input image file
    - `filepath_output`: Path where output will be saved
    - `thresholdGray`: Threshold for grayscale conversion
    - `thresholdMarker`: Threshold for marker-based segmentation
    - `min_threshold`: Minimum area threshold for segments
    - `max_threshold`: Maximum area threshold for segments
    # Returns
    - The filepath of the generated output
"""
function start_segmentation_SOPHYSM_graph(
    filepath_input::AbstractString,
    filepath_output::AbstractString,
    thresholdGray::Float64,
    thresholdMarker::Float64,
    min_threshold::Float32,
    max_threshold::Float32)
    
    apply_segmentation_SOPHYSM_graph(
        filepath_input,
        filepath_output,
        thresholdGray,
        thresholdMarker,
        min_threshold,
        max_threshold)

    return filepath_output
end

end
