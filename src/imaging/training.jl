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
    weighted_cross_entropy_loss(y_hat, y, weight_map)

Calculates the pixel-wise weighted cross-entropy loss using the weight map.

- `y_hat`: Output of the network (logits for each class).
- `y`: Target mask (ground truth labels).
- `weight_map`: Weight map for each pixel.

Returns:
- The scalar loss value computed as the average weighted cross-entropy loss
  over the batch.
"""
function weighted_cross_entropy_loss(y_hat, y, weight_map)
    # Crop y and weight_map to match y_hat dimensions
    y = @views crop(y_hat, y)
    weight_map = @views crop(y_hat, weight_map)

    # Apply softmax along the class dimension to obtain probabilities
    y_hat_softmax = softmax(y_hat, dims = 3)

    # Compute the log probabilities, adding a small epsilon to prevent log(0)
    epsilon = 1e-7
    log_probs = log.(y_hat_softmax .+ epsilon)

    # Convert y into integer class labels starting from 0
    y_int = round.(Int, y)

    # Select the probabilities of the correct class
    p_correct = @views log_probs[:, :, y_int .+ 1, :]

    # Apply the weight map
    weighted_loss = -weight_map .* p_correct

    return Float32(sum(weighted_loss))
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
    num_batches = length(img_batches)  # Total number of batches
    losses = Float32[]
    my_log = []

    for epoch in 1 : epochs
        println("\nEpoch $epoch/$epochs")
        
        # Shuffle the batches at the beginning of each epoch
        shuffled_indices = shuffle(1 : num_batches)
        img_batches_shuffled = img_batches[shuffled_indices]
        mask_batches_shuffled = mask_batches[shuffled_indices]
        weight_batches_shuffled = weight_batches[shuffled_indices]

        for (x_batch, y_batch, weight_map_batch) in zip(img_batches_shuffled,
                                            mask_batches_shuffled,
                                            weight_batches_shuffled)
            
            loss, grads = Flux.withgradient(model) do m
                y_hat = m(x_batch)
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

            Flux.update!(opt_state, model, grads[1])
        end
#=
        # Compute accuracy on training data
        acc = my_accuracy(model, train_set)
        println("acc: ", acc, ", losses: ", losses)
        push!(my_log, (; acc, losses))

        # Stop training when some criterion is reached
        if  acc > 0.95
            println("Stopping early at epoch $epoch due to high accuracy.")
            break
        end
=#
    end

    println(losses)

    # Save the final model
    @save "final_model.bson" model
    println("Training completed. Final model saved.")   
end
