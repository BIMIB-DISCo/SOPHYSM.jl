module Model

using Flux

# Two 3x3 convolutional layers with 0 padding followed by ReLu activations
function conv_block(in_ch::Int, out_ch::Int)
    Chain(
        Conv((3, 3), in_ch => out_ch, relu),
        Conv((3, 3), in_ch => out_ch, relu)
    )
end

# A 2x2 max pooling layer
function down_sample()
    MaxPool((2, 2))
end

end # module
