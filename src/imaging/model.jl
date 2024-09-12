"""
    UNet

    Defines the complete U-Net architecture comprising separate components for
    different phases of the network.

    - The downsampling path reduces spatial dimensions and increases feature
      channels.
    - The bottleneck is the deepest part where feature abstraction is maximum.
    - The upsampling path increases spatial dimensions and merges features from
      the downsampling path.
    - The final output layer maps the deep features to the desired number of
      output classes or channels.
"""
struct UNet
    downsample::Chain
    bottleneck::Chain
    upsample::Chain
    output::Chain
end

"""
    UNetDownBlock

    Represents a single block in the downsampling path containing convolutional
    and pooling layers.

    - Sequential convolutional layers for feature extraction.
    - Max pooling layer to reduce spatial dimensions by taking the maximum
      value in a local neighborhood.
"""
struct UNetDownBlock
    conv::Chain
    pool::MaxPool
end

"""
    UNetBottleneck

    Represents the bottleneck block in the U-Net architecture.

    - Applies convolutional layers.
    - Focuses on maximum feature abstraction at the deepest point of the
      network.
    - Bridges the downsampling and upsampling paths.
"""
struct UNetBottleneckBlock
    conv::Chain
end

"""
    UNetUpBlock

    Represents a block in the upsampling path that uses transposed convolutions
    to increase spatial dimensions.

    - Transposed convolutional layer to upscale the feature map.
    - Regular convolutional layers to refine features after upsampling.
"""
struct UNetUpBlock
    upconv::Chain
    conv::Chain
end

"""
    UNetOutputBlock

    Represents the output block of the U-Net.
    
    - A 1x1 convolution to map the deep feature maps to the desired number of
      output channels.
"""
struct UNetOutputBlock
    conv::Chain
end

"""
    kaiming_init(out_chs, in_chs, filter)

    Initializes the weights for convolutional layers using the Kaiming
    initialization method.

    - This method sets the weights based on a normal distribution with a
      standard deviation of sqrt(2 / number of input channels), which helps
      maintain the variance of activations through the layers.
"""
function kaiming_init(out_chs, in_chs, filter)
    std_dev = sqrt(2 / in_chs)

    return (dims...) -> randn(Float32, filter..., out_chs, in_chs) * std_dev
end

"""
    conv_3x3(in_chs::Int, out_chs::Int)

    Constructs two consecutive 3x3 convolutional layers without padding,
    reducing the spatial size by 2 pixels.

    - First convolution reduces dimension and applies ReLU.
    - Second convolution further processes the feature map.
"""
function conv_3x3(in_chs::Int, out_chs::Int)
    Chain(
        Conv((3, 3), in_chs => out_chs, relu;
            init = kaiming_init(in_chs, out_chs, (3, 3))
        ),
        BatchNorm(out_chs),
        Conv((3, 3), out_chs => out_chs, relu;
            init = kaiming_init(out_chs, out_chs, (3, 3))
        ),
        BatchNorm(out_chs)
    )
end

"""
    copy_and_crop(x, bridge)

    Adjusts the size of the 'bridge' feature map (from downsampling path) to
    match 'x' using slicing and concatenates them along the third dimension,
    which represents the channels.

    - This step is crucial for merging features from downsampling and
      upsampling paths.
"""
function copy_and_crop(x, bridge)
    dx = size(bridge, 1) - size(x, 1)
    dy = size(bridge, 2) - size(x, 2)

    cropped_bridge = @views bridge[
        div(dx, 2) + 1:end - div(dx, 2) - (dx % 2),
        div(dy, 2) + 1:end - div(dy, 2) - (dy % 2),
        :,
        :
    ]

    return cat(x, cropped_bridge, dims = 3)
end

"""
    max_pool_2x2()

    Implements a 2x2 max pooling layer with a stride of 2 to reduce the spatial
    dimensions of the feature map by half.
"""
function max_pool_2x2()
    MaxPool((2, 2), stride = 2)
end

"""
    up_conv_2x2(in_chs::Int, out_chs::Int)

    Defines a transposed convolutional layer that increases the spatial
    dimensions of the feature maps.

    - Used in upsampling to recover the original dimensions of the image.
    - Transposed convolution increases the size of the feature map.
"""
function up_conv_2x2(in_chs::Int, out_chs::Int)
    Chain(
        ConvTranspose((2, 2), out_chs => in_chs, relu;
            stride = 2,
            init = kaiming_init(out_chs, in_chs, (2, 2))
        ),
        BatchNorm(out_chs)
    )
end

"""
    conv_1x1(in_chs::Int, out_chs::Int)

    A 1x1 convolutional layer reduces the number of feature channels to the
    desired output channels.

    - Used as the final layer to map features to segmentation classes or
      predictions.
    - The 1x1 convolution adjusts the number of channels.
"""
function conv_1x1(in_chs::Int, out_chs::Int)
    Chain(
        Conv((1, 1), in_chs => out_chs;
            init = kaiming_init(in_chs, out_chs, (1, 1))
        )
    )
end

"""
    UNetDownBlock(in_chs::Int, out_chs::Int)

    Constructor function to create a downsampling block with specified channels.
"""
function UNetDownBlock(in_chs::Int, out_chs::Int)
    conv = conv_3x3(in_chs, out_chs)
    pool = max_pool_2x2()

    UNetDownBlock(conv, pool)
end

"""
    UNetBottleneckBlock(in_chs::Int, out_chs::Int)

    Constructor function to create a downsampling block with specified channels.
"""
function UNetBottleneckBlock(in_chs::Int, out_chs::Int)
    conv = conv_3x3(in_chs, out_chs)

    UNetBottleneckBlock(conv)
end

"""
    UNetUpBlock(in_chs::Int, out_chs::Int)

    Constructor function to create an upsampling block with specified channels.
"""
function UNetUpBlock(in_chs::Int, out_chs::Int)
    upconv = up_conv_2x2(in_chs, out_chs)
    conv = conv_3x3(in_chs, out_chs)

    UNetUpBlock(upconv, conv)
end

"""
    UNetOutputBlock(in_chs::Int, out_chs::Int)

    Constructor function to create an output block with a 1x1 convolution layer.
"""
function UNetOutputBlock(in_chs::Int, out_chs::Int)
    conv = conv_1x1(in_chs, out_chs)

    UNetOutputBlock(conv)
end

"""
    UNet()

    Constructor for U-Net which initializes the downsampling, bottleneck,
    upsampling and output layers.
"""
function UNet(channels::Int = 1, labels::Int = 2)
    downsample = Chain(
        UNetDownBlock(channels, 64),
        UNetDownBlock(64, 128),
        UNetDownBlock(128, 256),
        UNetDownBlock(256, 512)
    )

    bottleneck = Chain(
        UNetBottleneckBlock(512, 1024)
    )

    upsample = Chain(
        UNetUpBlock(1024, 512),
        UNetUpBlock(512, 256),
        UNetUpBlock(256, 128),
        UNetUpBlock(128, 64)
    )

    output = Chain(
        UNetOutputBlock(64, labels)
    )

    UNet(downsample, bottleneck, upsample, output)
end

"""
    (model::UNet)(x::AbstractArray)

    Applies the entire U-Net model to process an input image through various
    layers to produce a segmented output.

    - Processes the input through the downsampling path.
    - Passes the downsampled features through the bottleneck.
    - Processes the bottleneck features through the upsampling path.
    - Produces the final output through the output layer.
"""
function (model::UNet)(x::AbstractArray)
    println("Input size: ", size(x))
    
    # Downsampling path
    x1 = model.downsample.layers[1].conv(x)
    println("\nAfter downsample layer 1 (conv): ", size(x1))

    x1_pool = model.downsample.layers[1].pool(x1)
    println("After downsample layer 1 (max pool): ", size(x1_pool))

    x2 = model.downsample.layers[2].conv(x1_pool)
    println("\nAfter downsample layer 2 (conv): ", size(x2))

    x2_pool = model.downsample.layers[2].pool(x2)
    println("After downsample layer 2 (max pool): ", size(x2_pool))

    x3 = model.downsample.layers[3].conv(x2_pool)
    println("\nAfter downsample layer 3 (conv): ", size(x3))

    x3_pool = model.downsample.layers[3].pool(x3)
    println("After downsample layer 3 (max pool): ", size(x3_pool))

    x4 = model.downsample.layers[4].conv(x3_pool)
    println("\nAfter downsample layer 4 (conv): ", size(x4))

    x4_pool = model.downsample.layers[4].pool(x4)
    println("After downsample layer 4 (max pool): ", size(x4_pool))

    # Bottleneck
    x_bottleneck = model.bottleneck.layers[1].conv(x4_pool)
    println("\nAfter bottleneck: ", size(x_bottleneck))

    # Upsampling path
    x_up1_conv = model.upsample.layers[1].upconv(x_bottleneck)
    println("\nAfter upsample layer 1 (upconv): ", size(x_up1_conv))

    x_up1 = model.upsample.layers[1].conv(copy_and_crop(x_up1_conv, x4))
    println("After upsample layer 1 (conv): ", size(x_up1))

    x_up2_conv = model.upsample.layers[2].upconv(x_up1)
    println("\nAfter upsample layer 2 (upconv): ", size(x_up2_conv))

    x_up2 = model.upsample.layers[2].conv(copy_and_crop(x_up2_conv, x3))
    println("After upsample layer 2 (conv): ", size(x_up2))

    x_up3_conv = model.upsample.layers[3].upconv(x_up2)
    println("\nAfter upsample layer 3 (upconv): ", size(x_up3_conv))

    x_up3 = model.upsample.layers[3].conv(copy_and_crop(x_up3_conv, x2))
    println("After upsample layer 3 (conv): ", size(x_up3))

    x_up4_conv = model.upsample.layers[4].upconv(x_up3)
    println("\nAfter upsample layer 4 (upconv): ", size(x_up4_conv))

    x_up4 = model.upsample.layers[4].conv(copy_and_crop(x_up4_conv, x1))
    println("After upsample layer 4 (conv): ", size(x_up4))

    # Output layer
    output = model.output[1].conv(x_up4)
    println("\nOutput size: ", size(output))

    println()
    output
end

"""
    Base.show(io::IO, model::UNet)

    Customizes the display of the U-Net model's structure, showing the
    dimensions of convolutional layers at each stage.

    - `io`: The I/O stream to print to.
    - `model`: The U-Net model instance.

    Prints the dimensions of the convolutional layers in the downsampling path,
    the bottleneck, the upsampling path and the output layer.
"""
function Base.show(io::IO, model::UNet)
    println(io, "UNet Structure:")

    # Downsampling Path
    println(io, "\nDownsampling Path:")

    for (i, layer) in enumerate(model.downsample.layers)
        println(io, "   Layer $i:")

        if typeof(layer) <: UNetDownBlock
            println(io, "      ConvBlock 1: $(size(layer.conv[1].weight))")
            println(io, "      ConvBlock 2: $(size(layer.conv[3].weight))")
            println(io, "      Max Pooling: 2x2")
        else
            println(io, "      Unknown layer type")
        end
    end

    # Bottleneck
    println(io, "\nBottleneck:")

    for (i, layer) in enumerate(model.bottleneck.layers)
        println(io, "   Layer $i:")

        if typeof(layer) <: UNetBottleneckBlock
            println(io, "      ConvBlock: $(size(layer.conv[1].weight))")
        else
            println(io, "      Unknown layer type")
        end
    end

    # Upsampling Path
    println(io, "\nUpsampling Path:")

    for (i, layer) in enumerate(model.upsample.layers)
        println(io, "   Layer $i:")

        if typeof(layer) <: UNetUpBlock
            println(io, "      UpConvBlock: $(size(layer.upconv[1].weight))")
            println(io, "      ConvBlock: $(size(layer.conv[1].weight))")
        else
            println(io, "      Unknown layer type")
        end
    end

    # Output Layer
    println(io, "\nOutput Layer:")

    for (i, layer) in enumerate(model.output.layers)
        println(io, "   Layer $i:")

        if typeof(layer) <: UNetOutputBlock
            println(io, "      ConvBlock 1: $(size(layer.conv[1].weight))")
        else
            println(io, "      Unknown layer type")
        end
    end
end
