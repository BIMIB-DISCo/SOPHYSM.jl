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
function weighted_cross_entropy_loss(y_hat, y, weight_map)
    # Crop y and weight_map to match the spatial dimensions of y_hat
    y = @views crop(y_hat, y)
    weight_map = @views crop(y_hat, weight_map)

    # Ensure data types are consistent and cast to Float32
    y_hat = Float32.(y_hat)
    y = Float32.(y)
    weight_map = Float32.(weight_map)

    # Apply softmax along the class dimension to obtain class probabilities
    y_hat_softmax = softmax(y_hat; dims = 3)

    # Convert y to integer class labels starting from 0
    y_int = round.(Int, y)

    # Invert y_int to obtain the complement of the class labels
    y_int_inverted = 1 .- y_int

    # Compute the probability for the correct class
    p_correct = y_hat_softmax[:, :, 2, :] .* y_int .+
                y_hat_softmax[:, :, 1, :] .* y_int_inverted

    # Compute the log probabilities for numerical stability
    log_p_correct = log.(p_correct .+ 1e-15)

    # Compute the weighted cross-entropy loss
    loss = mean(-sum(weight_map .* log_p_correct; dims = 3))

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
                optimizer = Momentum(0.001, 0.99), epochs = 50)
    num_batches = length(img_batches)
    losses = Float32[]
    loss = 0.0f0

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
            loss, gs = Flux.withgradient(Flux.params(model)) do
                y_hat = model(x_batch)
                weighted_cross_entropy_loss(y_hat, y_batch, weight_map_batch)
            end

            # Save the loss from the forward pass
            push!(losses, loss)
            println("Loss: ", loss)

            # Detect loss of Inf or NaN. Print a warning and then skip update!
            if !isfinite(loss)
                @warn "Loss is $loss; skipping update."
                continue
            end

            # Update the model parameters using the gradients
            Flux.update!(optimizer, Flux.params(model), gs)
        end
    end

    println(losses)

    # Save the final model
    @save "final_model.bson" model
    println("Training completed. Final model saved.")   
end
