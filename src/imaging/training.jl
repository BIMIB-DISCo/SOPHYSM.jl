""""
    weighted_cross_entropy_loss(y_hat, y, weight_map)

Calculates the pixel-wise weighted cross-entropy using the weight map w(x).

- `y_hat`: Output of the network (logits for each class).
- `y`: Target mask (ground truth labels).
- `weight_map`: Weight map for each pixel.

Returns the scalar loss value.
"""
function weighted_cross_entropy_loss(y_hat, y, weight_map)
    # Ensure data types are consistent and in Float32
    y_hat = Float32.(y_hat)
    y = Float32.(y)
    weight_map = Float32.(weight_map)

    # Remove singleton dimension along dimension 3 in y, if necessary
    if size(y, 3) == 1
        y = reshape(y, size(y, 1), size(y, 2), size(y, 4))  # y has shape (H, W, B)
    end

    # Convert y into integer labels starting from 1
    y_int = round.(Int, y) .+ 1  # y_int has values 1 or 2

    # Remove singleton dimension along dimension 3 in weight_map, if necessary
    if size(weight_map, 3) == 1
        weight_map = reshape(weight_map, size(weight_map, 1), size(weight_map, 2), size(weight_map, 4))
    end

    # Compute the cross-entropy loss using logitcrossentropy
    # y_hat: shape (H, W, C, B)
    # y_int: shape (H, W, B)
    ce_loss = logitcrossentropy(y_hat, y_int; dims=3)  # ce_loss has shape (H, W, B)

    # Apply the weight map
    weighted_loss = weight_map .* ce_loss  # Both have shape (H, W, B)

    # Calculate the average loss over the batch
    return mean(weighted_loss)
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
    @showprogress for epoch in 1:epochs
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

            # Set model to training mode (important if using batch normalization)
            Flux.train!(model)

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
