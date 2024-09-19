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
    p_correct = zeros(size(y_hat_softmax, 1),
                        size(y_hat_softmax, 2),
                        1,
                        size(y_hat_softmax, 4))

    for i in 1 : size(y_hat_softmax, 1)
        for j in 1 : size(y_hat_softmax, 2)
            for b in 1 : size(y_hat_softmax, 4)
                class = y_int[i, j, 1, b] + 1
                p_correct[i, j, 1, b] = log_probs[i, j, class, b]
            end
        end
    end

    # Apply the weight map
    weighted_loss = -weight_map .* p_correct

    return Float32(sum(weighted_loss))
end

"""
    train!(model, img_batches, mask_batches, weight_batches;
           optimizer, epochs = 50, patience = 5, min_delta = 0.001)

Trains the U-Net model on the image and mask batches.

- `model`: The U-Net model.
- `img_batches`: List of image batches.
- `mask_batches`: List of mask batches.
- `weight_batches`: List of weight map batches.
- `optimizer`: The optimizer to use.
- `epochs`: Number of epochs for training.
- `patience`: Number of epochs for early stopping.
- `min_delta`: Minimum improvement to consider a reduction in loss.

Saves the best model weights based on validation loss.
"""
function train!(model, img_batches, mask_batches, weight_batches;
                optimizer = Momentum(0.01, 0.99), epochs = 50,
                patience = 5, min_delta = 0.001)
    # Initialize for early stopping
    best_loss = Inf
    epochs_without_improvement = 0

    # Number of batches
    num_batches = length(img_batches)

    # Monitor progress
    for epoch in 1:epochs
        println("\nEpoch $epoch/$epochs")
        epoch_loss = 0.0

        # Shuffle the batches at the beginning of each epoch
        shuffled_indices = shuffle(1:num_batches)
        img_batches_shuffled = img_batches[shuffled_indices]
        mask_batches_shuffled = mask_batches[shuffled_indices]
        weight_batches_shuffled = weight_batches[shuffled_indices]

        for (img_batch, mask_batch, weight_batch) in zip(img_batches_shuffled, 
                                                         mask_batches_shuffled, 
                                                         weight_batches_shuffled)
            # Ensure data types are Float32
            img_batch = Float32.(img_batch)
            mask_batch = Float32.(mask_batch)
            weight_batch = Float32.(weight_batch)

            # Compute gradients
            gs = gradient(() -> begin
                y_hat = model(img_batch)
                loss = weighted_cross_entropy_loss(y_hat, mask_batch, weight_batch)

                return loss
            end, params(model))

            # Update model weights
            update!(optimizer, params(model), gs)

            # Calculate the loss for monitoring
            y_hat = model(img_batch)
            batch_loss = weighted_cross_entropy_loss(y_hat, mask_batch, weight_batch)
            epoch_loss += batch_loss
        end

        # Calculate average loss for the epoch
        epoch_loss /= num_batches
        println("Loss: $epoch_loss")

        # Early stopping check
        if epoch_loss + min_delta < best_loss
            best_loss = epoch_loss
            epochs_without_improvement = 0

            # Save the best model weights
            @save "best_model.bson" model
            println("Improvement found, model saved.")
        else
            epochs_without_improvement += 1
            println("No improvement for $epochs_without_improvement epochs.")

            if epochs_without_improvement >= patience
                println("Early stopping after $epoch epochs.")
                break
            end
        end
    end

    # Save the final model
    @save "final_model.bson" model
    println("Training completed. Final model saved.")
end
