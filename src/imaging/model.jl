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
    out_layer::Chain
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

    # Crop `bridge` to the same size as `x` and concatenate them.
    cropped_bridge = @views bridge[
                                div(dx, 2) + 1:end - div(dx, 2),
                                div(dy, 2) + 1:end - div(dy, 2),
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
    conv = conv_3x3(out_chs, out_chs)

    UNetUpBlock(upconv, conv)
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

    out_layer = conv_1x1(64, labels)

    UNet(downsample, bottleneck, upsample, out_layer)
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
    x1 = model.downsample.layers[1].pool(model.downsample.layers[1].conv(x))
    println("After downsample layer 1: ", size(x1))
    
    x2 = model.downsample.layers[2].pool(model.downsample.layers[2].conv(x1))
    println("After downsample layer 2: ", size(x2))

    x3 = model.downsample.layers[3].pool(model.downsample.layers[3].conv(x2))
    println("After downsample layer 3: ", size(x3))

    x4 = model.downsample.layers[4].pool(model.downsample.layers[4].conv(x3))
    println("After downsample layer 4: ", size(x4))

    # Bottleneck
    x_bottleneck = model.bottleneck.layers[1].conv(x4)
    println("After bottleneck: ", size(x_bottleneck))

    # Upsampling path
    x_up1 = model.upsample.layers[1].conv(model.upsample.layers[1].upconv(x_bottleneck))
    println("After upsample layer 1: ", size(x_up1))
    
    x_up2 = model.upsample.layers[2].conv(model.upsample.layers[2].upconv(x_up1))
    println("After upsample layer 2: ", size(x_up2))

    x_up3 = model.upsample.layers[3].conv(model.upsample.layers[3].upconv(x_up2))
    println("After upsample layer 3: ", size(x_up3))

    x_up4 = model.upsample.layers[4].conv(model.upsample.layers[4].upconv(x_up3))
    println("After upsample layer 4: ", size(x_up4))

    # Output layer
    output = model.out_layer(x_up4)
    println("Output size: ", size(output))
    
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
    println()

    # Downsampling Path
    println(io, "Downsampling Path:")
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
    if typeof(model.out_layer[1]) <: Flux.Conv
        println(io, "   ConvBlock: $(size(model.out_layer[1].weight))")
    else
        println(io, "   Unknown layer type")
    end
end
