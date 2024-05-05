module Model

using Flux

# Two 3x3 unpadded convolutional layers followed by ReLu activations
function conv_3x3(in_ch::Int, out_ch::Int)
    Chain(
        Conv((3, 3), in_ch => out_ch, relu),
        Conv((3, 3), out_ch => out_ch, relu)
    )
end

# Crop and Concatenate the feature map
function copy_and_crop(x, contracting_x)
    # TODO
end

# A 2x2 max pooling operation with stride 2
function max_pool_2x2()
    MaxPool((2, 2), stride = 2)
end

# A 2x2 convolutional layer
function up_conv_2x2(in_ch::Int, out_ch::Int)
    Conv((2, 2), in_ch => out_ch)
end

# A 1x1 convolutional layer
function conv_1x1(in_ch::Int, out_ch::Int)
    Chain(
        Conv((1, 1), in_ch => out_ch),
    )
end

# U-Net
struct unet
    downsampling
    upsampling
end

# U-Net constructor
function build_unet()
    downsampling = Chain(
        conv_3x3(1, 64),
        max_pool_2x2(),
        conv_3x3(64, 128),
        max_pool_2x2(),
        conv_3x3(128, 256),
        max_pool_2x2(),
        conv_3x3(256, 512),
        max_pool_2x2(),
        conv_3x3(512, 1024)
    )

    upsampling = Chain(
        # TODO
    )

    unet(downsampling, upsampling)
end

end # module
