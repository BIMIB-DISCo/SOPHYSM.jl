module Model

using Flux

# U-Net architecture
struct UNet
    downsample::Chain
    bottleneck::Chain
    upsample::Chain
    out_layer::Chain
end

# A downsampling step
struct UNetDownBlock
    conv::Chain
    pool::MaxPool
end

# An upsampling step
struct UNetUpBlock
    upconv::Chain
    conv::Chain
end

# Two 3x3 unpadded convolutional layers followed by ReLU activations
function down_conv_3x3(in_chs::Int, out_chs::Int)
    Chain(
        Conv((3, 3), in_chs => out_chs, relu),
        Conv((3, 3), out_chs => out_chs, relu)
    )
end

# Two 3x3 padded convolutional layers followed by ReLU activations
function up_conv_3x3(in_chs::Int, out_chs::Int)
    Chain(
        Conv((3, 3), in_chs => out_chs, relu; pad = SamePad()),
        Conv((3, 3), out_chs => out_chs, relu; pad = SamePad())
    )
end

# Crop and Concatenate the feature map
function copy_and_crop(x, bridge)
    dx = size(bridge, 1) - size(x, 1)
    dy = size(bridge, 2) - size(x, 2)

    cropped_bridge = @views bridge[div(dx, 2) + 1:end - div(dx, 2), div(dy, 2) + 1:end - div(dy, 2), :, :]

    return cat(x, cropped_bridge, dims = 3)
end

# A 2x2 max pooling operation with stride 2
function max_pool_2x2()
    MaxPool((2, 2), stride = 2)
end

# A 2x2 up-convolutional layer
function up_conv_2x2(in_chs::Int, out_chs::Int)
    Chain(
        ConvTranspose((2, 2), in_chs => out_chs)
    )
end

# A 1x1 convolutional layer to finalize the output
function conv_1x1(in_chs::Int, out_chs::Int)
    Chain(
        Conv((1, 1), in_chs => out_chs)
    )
end

# Constructor for downsampling block
function UNetDownBlock(in_chs::Int, out_chs::Int)
    conv = down_conv_3x3(in_chs, out_chs)
    pool = max_pool_2x2()

    UNetDownBlock(conv, pool)
end

# Constructor for upsampling block
function UNetUpBlock(in_chs::Int, out_chs::Int)
    upconv = up_conv_2x2(in_chs, out_chs)
    conv = up_conv_3x3(out_chs, out_chs)

    UNetUpBlock(upconv, conv)
end

# Constructor for U-Net
function UNet()
    downsample = Chain(
        UNetDownBlock(1, 64),
        UNetDownBlock(64, 128),
        UNetDownBlock(128, 256),
        UNetDownBlock(256, 512)
    )

    bottleneck = conv_3x3(512, 1024)

    upsample = Chain(
        UNetUpBlock(1024, 512),
        UNetUpBlock(512, 256),
        UNetUpBlock(256, 128),
        UNetUpBlock(128, 64)
    )

    out_layer = conv_1x1(64, 2)

    UNet(downsample, bottleneck, upsample, out_layer)
end

# Network application to an image
function (model::UNet)(x::AbstractArray)
    x1 = model.downsample.layers[1](x)
    x2 = model.downsample.layers[2](x1)
    x3 = model.downsample.layers[3](x2)
    x4 = model.downsample.layers[4](x3)

    x_bottleneck = model.bottleneck(x4)

    x_up1 = model.upsample.layers[1](x_bottleneck, x4)
    x_up2 = model.upsample.layers[2](x_up1, x3)
    x_up3 = model.upsample.layers[3](x_up2, x2)
    x_up4 = model.upsample.layers[4](x_up3, x1)

    return model.out_layer(x_up4)
end

function Base.show(io::IO, model::UNet)
    println(io, "UNet Structure:")

    println(io, "Downsampling Path:")
    for layer in model.downsample.layers
        println(io, "   ConvBlock: $(size(layer.conv[1].weight))")
    end

    println(io, "\nBottleneck:")
    println(io, "   ConvBlock: $(size(model.bottleneck[1].weight))")

    println(io, "\nUpsampling Path:")
    for layer in model.upsample.layers
        println(io, "   UpConvBlock: $(size(layer.upconv[1].weight))")
    end

    println(io, "\nOutput Layer:")
    println(io, "   ConvBlock: $(size(model.out_layer[1].weight))")
end

end # module
