"""
    crop(logit, mask)

Crops the `mask` to match the spatial dimensions of `logit`.

- `logit`: The output of the network.
- `mask`: The mask or weight map to be cropped.

Returns:
- The cropped `mask` with spatial dimensions matching `logit`.
"""
function crop(logit, mask)
    # Calculate the margins to crop along height and width
    dx = size(mask, 1) - size(logit, 1)
    dy = size(mask, 2) - size(logit, 2)

    # Crop the mask to match the spatial dimensions of logit
    return mask[
                div(dx, 2) + 1 : end - div(dx, 2) - (dx % 2),
                div(dy, 2) + 1 : end - div(dy, 2) - (dy % 2),
                :,
                :
            ]
end

"""
    weighted_cross_entropy_loss(logit, mask, weight_map)

Calculates the pixel-wise weighted cross-entropy loss using the weight map.

- `logit`: Output of the network.
- `mask`: Target mask.
- `weight_map`: Weight map for each pixel.

Returns:
- The scalar loss value computed as the weighted cross-entropy loss over the
  batch.
"""
function weighted_cross_entropy_loss(logit, mask, weight_map)
    # Crop the mask and weight map to match the spatial dimensions of the logit
    mask = @views crop(logit, mask)
    weight_map = @views crop(logit, weight_map)

    # Convert mask to integer labels and adjust labels to start from 1
    mask = round.(Int, mask)
    mask = mask .+ 1

    # Get dimensions
    W, H, C, B = size(logit)
    N = W * H * B  # Total number of pixels in the batch

    # Remove the singleton dimension from mask and weight_map
    mask = dropdims(mask, dims=3)
    weight_map = dropdims(weight_map, dims=3)

    # Compute probabilities with softmax over the class dimension
    probabilities = softmax(logit, dims = 3)

    # Rearrange dimensions to (W, H, B, C) to facilitate reshaping
    probabilities = permutedims(probabilities, (1, 2, 4, 3))
    probabilities_flat = reshape(probabilities, N, C)

    # Flatten mask and weight_map
    mask_flat = reshape(mask, N)
    weight_map_flat = reshape(weight_map, N)

    # Extract probabilities corresponding to the true labels for each pixel
    p_true = probabilities_flat[CartesianIndex.(1:N, mask_flat)]

    # Avoid log(0) by setting a minimum value
    p_true = max.(p_true, 1e-15)

    # Compute the logarithm of the true probabilities
    log_p_true = log.(p_true)

    # Compute the weighted cross-entropy loss
    loss = -sum(weight_map_flat .* log_p_true)

    return loss
end

"""
    train!(model, img_batches, mask_batches, weight_batches;
           optimizer = Momentum(0.01, 0.99), epochs = 50)

Trains the U-Net model on the image and mask batches.

- `model`: The U-Net model.
- `img_batches`: List of image batches.
- `mask_batches`: List of mask batches.
- `weight_batches`: List of weight map batches.
- `optimizer`: The optimizer to use.
- `epochs`: Number of epochs for training.

Saves the best model weights based on validation loss.
"""
function train!(model, img_batches, mask_batches, weight_batches;
                optimizer = Momentum(0.01, 0.99), epochs = 50)
    opt_state = Flux.setup(optimizer, model)
    num_batches = length(img_batches)
    losses = Float32[]

    for epoch in 1:epochs
        println("\nEpoch $epoch/$epochs")
        
        # Shuffle the batches at the beginning of each epoch
        shuffled_indices = shuffle(1:num_batches)
        img_batches_shuffled = img_batches[shuffled_indices]
        mask_batches_shuffled = mask_batches[shuffled_indices]
        weight_batches_shuffled = weight_batches[shuffled_indices]

        for (x_batch, y_batch, weight_map_batch) in zip(img_batches_shuffled,
                                                        mask_batches_shuffled,
                                                        weight_batches_shuffled)
            # Compute the loss and gradients
            l, gs = Flux.withgradient(Flux.params(model)) do
                y_hat = model(x_batch)
                weighted_cross_entropy_loss(y_hat, y_batch, weight_map_batch)
            end

            # Save the loss from the forward pass
            push!(losses, l)
            println("Loss: ", l)

            # Detect loss of Inf or NaN. Print a warning and then skip update!
            if !isfinite(l)
                @warn "Loss is $l; skipping update."
                continue
            end

            # Update the model parameters using the gradients
            Flux.Optimise.update!(optimizer, Flux.params(model), gs)
        end
    end

    println(losses)

    # Save the final model
    @save "final_model.bson" model
    println("Training completed. Final model saved.")   
end
