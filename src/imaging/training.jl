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

    # Reshape y to match the shape of y_hat, if necessary
    if size(y, 3) != size(y_hat, 3)
        y = reshape(y, size(y, 1), size(y, 2), size(y_hat, 3), size(y, 4))
    end

    # Compute the cross-entropy loss using logitcrossentropy
    # y_hat contains logits, and y contains target probabilities (0 or 1)
    ce_loss = logitcrossentropy(y_hat, y; dims = 3)

    # Apply the weight map
    weighted_loss = weight_map .* ce_loss

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

    # Monitor progress
    @showprogress for epoch in 1:epochs
        println("\nEpoch $epoch/$epochs")
        epoch_loss = 0.0

        for (img_batch, mask_batch, weight_batch) in zip(img_batches, 
                                                            mask_batches, 
                                                            weight_batches)
            # Define loss function for the optimizer
            gs = gradient(params(model)) do
                y_hat = model(img_batch)
                loss = weighted_cross_entropy_loss(y_hat,
                                                    mask_batch,
                                                    weight_batch)

                return loss
            end

            # Update model weights
            update!(optimizer, params(model), gs)

            # Calculate the loss for monitoring
            y_hat = model(img_batch)
            batch_loss = weighted_cross_entropy_loss(y_hat,
                                                        mask_batch, 
                                                        weight_batch)
            epoch_loss += batch_loss
        end

        # Calculate average loss for the epoch
        epoch_loss /= length(img_batches)
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
