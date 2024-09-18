"""
    weighted_cross_entropy_loss(y_hat, y, weight_map)

Calculates the pixel-wise weighted cross-entropy with the weight map w(x).

- `y_hat`: Output of the network (probabilities for each class).
- `y`: Target mask (ground truth labels).
- `weight_map`: Weight map for each pixel.

Returns the scalar loss value.
"""
function weighted_cross_entropy_loss(y_hat, y, weight_map)
    # Apply softmax pixel-wise
    y_hat_softmax = softmax(y_hat, 3)  # Assuming the channel is the third

    # Calculate pixel-wise cross-entropy
    # Avoid log(0) by adding a small epsilon
    epsilon = 1e-7
    log_probs = log.(y_hat_softmax .+ epsilon)

    # Convert y into integers (0 or 1)
    y_int = round.(Int, y)

    # Select the probabilities of the correct class
    p_correct = zeros(size(y_hat_softmax, 1),
                        size(y_hat_softmax, 2),
                        size(y_hat_softmax, 4))

    for i in 1 : size(y_hat_softmax, 1)
        for j in 1 : size(y_hat_softmax, 2)
            for b in 1 : size(y_hat_softmax, 4)  # Batch dimension
                class = y_int[i, j, 1, b] + 1
                p_correct[i, j, b] = log_probs[i, j, class, b]
            end
        end
    end

    # Apply the weight map
    weighted_loss = -weight_map[:, :, 1, :] .* p_correct

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
