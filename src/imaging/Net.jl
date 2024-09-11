module Net

using Augmentor
using Flux
using Flux.Data: DataLoader
using Images
using FileIO
using Random

include("dataloader.jl")
include("model.jl")
    
end # module
