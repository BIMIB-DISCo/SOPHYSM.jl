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
    accuracy(model, img_batches, mask_batches)

Calculates the accuracy of the model on a given dataset.

- `model`: The U-Net model.
- `img_batches`: List of image batches.
- `mask_batches`: List of mask batches.

Returns:
- The average accuracy on the dataset.
"""
function accuracy(model, img_batches, mask_batches)
    total_correct = 0
    total_pixels = 0

    for (x_batch, y_batch) in zip(img_batches, mask_batches)
        # Get the model predictions
        y_hat = model(x_batch)

        # Apply softmax to obtain probabilities
        y_hat_softmax = softmax(y_hat; dims = 3)

        # Select the class with the highest probability
        y_pred = argmax(y_hat_softmax, dims = 3)
        y_pred = getindex.(y_pred, 3)

        # Convert the ground truth masks to integers
        y_true = @views crop(y_hat, y_batch)
        y_true = round.(Int, y_true) .+ 1

        # Compare the predictions with the true labels
        correct = sum(y_pred .== y_true)
        total_correct += correct
        total_pixels += length(y_true)
    end

    # Calculate the average accuracy
    accuracy = total_correct / total_pixels

    return accuracy * 100
end

"""
    train!(model, img_batches, mask_batches, weight_batches;
           optimizer = Momentum(0.001, 0.99), epochs = 50, 
           patience = 5, min_delta = 0.001,
           val_img_batches = nothing, val_mask_batches = nothing)

Trains the U-Net model on image, mask, and weight map batches with optional
validation and early stopping.

# Arguments:
- `model`: The U-Net model to be trained.
- `img_batches`: A list of batches of input images.
- `mask_batches`: A list of batches of corresponding target masks.
- `weight_batches`: A list of batches of weight maps.
- `optimizer`: The optimizer to use during training.
- `epochs`: The number of training epochs.
- `patience`: Number of epochs to wait for improvement in validation accuracy
  before stopping early.
- `min_delta`: Minimum change in validation accuracy required to reset patience.
- `val_img_batches`: A list of validation image batches.
- `val_mask_batches`: A list of validation mask batches.
"""
function train!(model, img_batches, mask_batches, weight_batches;
                optimizer = Momentum(0.001, 0.99), epochs = 50, 
                patience = 5, min_delta = 0.1,
                val_img_batches = nothing, val_mask_batches = nothing)
    
    num_batches = length(img_batches)
    losses = Float32[]
    val_accuracies = Float32[]
    best_accuracy = 0.0
    epochs_without_improvement = 0

    for epoch in 1:epochs
        println("\nEpoch $epoch/$epochs")
        
        # Shuffle the batches at the beginning of each epoch
        shuffled_indices = shuffle(1:num_batches)
        img_batches_shuffled = img_batches[shuffled_indices]
        mask_batches_shuffled = mask_batches[shuffled_indices]
        weight_batches_shuffled = weight_batches[shuffled_indices]

        # Iterate over each batch of training data
        for (x_batch, y_batch, weight_map_batch) in zip(img_batches_shuffled,
                                                        mask_batches_shuffled,
                                                        weight_batches_shuffled)
            # Compute the loss and gradients
            loss, grads = Flux.withgradient(Flux.params(model)) do
                y_hat = model(x_batch)
                weighted_cross_entropy_loss(y_hat, y_batch, weight_map_batch)
            end

            # Save the loss from the forward pass
            push!(losses, loss)
            println("Loss: ", loss)

            # Skip update if loss is Inf or NaN (due to numerical instability)
            if !isfinite(loss)
                @warn "Loss is $loss; skipping update."
                continue
            end

            # Update model parameters with the computed gradients
            Flux.update!(optimizer, Flux.params(model), grads)
        end

        # Optional validation accuracy computation
        if val_img_batches !== nothing && val_mask_batches !== nothing
            acc = accuracy(model, val_img_batches, val_mask_batches)
            push!(val_accuracies, acc)
            println("Validation Accuracy: ", acc)

            # Check if validation accuracy has improved
            if acc > best_accuracy + min_delta
                best_accuracy = acc
                epochs_without_improvement = 0
                
                # Save the best model so far
                @save "best_model.bson" model
                println("New best model saved.")
            else
                # Increment the counter for epochs without improvement
                epochs_without_improvement += 1
                println("Epochs without improvement: ", epochs_without_improvement)

                # Early stopping if no improvement for `patience` epochs
                if epochs_without_improvement >= patience
                    println("Early stopping after $epoch epochs.")
                    break
                end
            end
        end
    end

    println("Training completed.")
    println(losses)
end
