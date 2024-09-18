module Net

using Augmentor
using BSON: @save
using FileIO
using Flux
using Flux: params
using Flux.Losses: logitcrossentropy
using Flux.Optimise: Momentum
using Images
using ProgressMeter
using Random
using Statistics

include("dataloader.jl")
include("model.jl")
include("training.jl")
    
end # module
