module Net

using Augmentor
using BSON: @save
using FileIO
using Flux
using Flux: @functor
using Flux.Optimise: Momentum, update!
using Images
using Random
using Statistics

include("dataloader.jl")
include("model.jl")
include("training.jl")
    
end # module
