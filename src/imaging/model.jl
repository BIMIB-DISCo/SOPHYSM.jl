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
function copy_and_crop(x, bridge)
    # Calculate the difference in dimensions
    dx = size(bridge, 1) - size(x, 1)
    dy = size(bridge, 2) - size(x, 2)

    # Ensure that dx and dy are non-negative
    if dx < 0 || dy < 0
        error("The dimension of the bridge feature map is smaller than that of x, cropping not feasible.")
    end

    # Perform centered cropping of bridge
    cropped_bridge = @views bridge[div(dx,2) + 1 : end - div(dx,2), div(dy,2) + 1 : end - div(dy,2), :, :]

    # Concatenate along the channel axis (third dimension)
    return cat(x, cropped_bridge, dims = 3)
end

# A 2x2 max pooling operation with stride 2
function max_pool_2x2()
    MaxPool((2, 2), stride = 2)
end

# A 2x2 up-convolutional layer
function up_conv_2x2(in_ch::Int, out_ch::Int)
    ConvTranspose((2, 2), in_ch => out_ch)
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
       up_conv_2x2(1024, 512),
       up_conv_2x2(512, 256),
       up_conv_2x2(256, 128),
       up_conv_2x2(128, 64)
    )

    unet(downsampling, upsampling)
end

end # module
