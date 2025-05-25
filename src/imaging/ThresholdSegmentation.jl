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
include("segmentationManager.jl")
include("graphManager.jl")
include("noiseManager.jl")
include("tessellationManager.jl")


function start_segmentation_SOPHYSM_tessellation(filepath_input::AbstractString,
                                    filepath_output::AbstractString,
                                    thresholdGray::Float64,
                                    thresholdMarker::Float64,
                                    min_threshold::Float32,
                                    max_threshold::Float32)
    apply_segmentation_SOPHYSM_tessellation(filepath_input,
                                filepath_output,
                                thresholdGray,
                                thresholdMarker,
                                min_threshold,
                                max_threshold)
                                
    return filepath_output
end

function start_segmentation_SOPHYSM_graph(filepath_input::AbstractString,
                                    filepath_output::AbstractString,
                                    thresholdGray::Float64,
                                    thresholdMarker::Float64,
                                    min_threshold::Float32,
                                    max_threshold::Float32)    
    apply_segmentation_SOPHYSM_graph(filepath_input,
                                filepath_output,
                                thresholdGray,
                                thresholdMarker,
                                min_threshold,
                                max_threshold)
                                
    return filepath_output
end

end
