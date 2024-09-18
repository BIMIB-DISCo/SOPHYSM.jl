module Net

using Augmentor
using BSON: @save
using FileIO
using Flux: params
using Images
using ProgressMeter
using Random
using Statistics

include("dataloader.jl")
include("model.jl")
include("training.jl")
    
end # module
