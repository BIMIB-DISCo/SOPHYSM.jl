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

    num_batches = length(img_batches)

    println("\nCalculating accuracy...")
    for i in ProgressBar(1:num_batches)
        x_batch = img_batches[i] |> gpu
        y_batch = mask_batches[i] |> gpu

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

    CUDA.reclaim()

    # Calculate the average accuracy
    accuracy = total_correct / total_pixels

    return accuracy * 100
end

"""
    train!(model, img_batches, mask_batches, weight_batches;
            initial_lr = 0.0001, max_lr = 0.001, decay_factor = 0.5,
            warmup_epochs = 5, decay_epochs = 5,
            early_stopping_start = 25, patience = 7, min_delta = 0.001,
            epochs = 50,
            val_img_batches = nothing, val_mask_batches = nothing)

Trains the U-Net model on batches of images, masks, and weight maps with
learning rate warm-up, decay, optional validation, and early stopping.

# Arguments:
- `model`: The U-Net model to be trained.
- `img_batches`: A list of batches of input images.
- `mask_batches`: A list of batches of corresponding target masks.
- `weight_batches`: A list of batches of weight maps.
- `initial_lr`: The initial learning rate for warm-up.
- `max_lr`: The maximum learning rate to reach during warm-up.
- `decay_factor`: Factor by which the learning rate is reduced after
  `decay_epochs` without improvement.
- `warmup_epochs`: Number of epochs to perform learning rate warm-up.
- `decay_epochs`: Number of epochs without improvement before applying learning
  rate decay.
- `early_stopping_start`: Epoch at which to start considering early stopping
  based on validation accuracy.
- `patience`: Number of epochs to wait without improvement in validation
  accuracy before stopping early.
- `min_delta`: Minimum change in validation accuracy required to reset patience.
- `epochs`: Total number of training epochs.
- `val_img_batches`: A list of validation image batches.
- `val_mask_batches`: A list of validation mask batches.
"""

function train!(model, img_batches, mask_batches, weight_batches;
                initial_lr = 0.0001, max_lr = 0.001, decay_factor = 0.5,
                warmup_epochs = 5, decay_epochs = 5,
                early_stopping_start = 15, patience = 8, min_delta = 0.001,
                epochs = 30,
                val_img_batches = nothing, val_mask_batches = nothing,
                test_img_batches = nothing, test_mask_batches = nothing)
    CUDA.reclaim()

    model = model |> gpu
    lr = initial_lr
    optimizer = Adam(lr)
    num_batches = length(img_batches)
    best_accuracy = 0.0
    epochs_without_improvement = 0

    # Initialize data for the plots
    training_losses = Float32[]
    validation_accuracies = Float32[]

    # Create empty plots
    loss_plot = nothing
    acc_plot = nothing

    for epoch in 1:epochs
        println("\nEpoch $epoch/$epochs")

        # Learning Rate Warm-up and Decay
        if epoch ≤ warmup_epochs
            lr = initial_lr * exp(epoch / warmup_epochs *
                                    log(max_lr / initial_lr))
            optimizer = Adam(lr)       

            println("Warm-up learning rate: $lr")
        elseif epochs_without_improvement != 0 &&
                epochs_without_improvement % decay_epochs == 0
                
            lr *= decay_factor
            optimizer = Adam(lr)

            println("Learning rate decayed to: $lr")
        else
            println("Current learning rate: $lr")
        end

        trainmode!(model)
        
        # Shuffle the batches at the beginning of each epoch
        shuffled_indices = shuffle(1:num_batches)
        img_batches_shuffled = img_batches[shuffled_indices]
        mask_batches_shuffled = mask_batches[shuffled_indices]
        weight_batches_shuffled = weight_batches[shuffled_indices]

        pbar = ProgressBar(1:num_batches)

        epoch_loss = 0.0

        # Iterate over each batch of training data
        for i in pbar
            x_batch = img_batches_shuffled[i] |> gpu
            y_batch = mask_batches_shuffled[i] |> gpu
            weight_map_batch = weight_batches_shuffled[i] |> gpu
        
            # Compute the loss and gradients
            loss, grads = Flux.withgradient(Flux.params(model)) do
                y_hat = model(x_batch)
                weighted_cross_entropy_loss(y_hat, y_batch, weight_map_batch)
            end
        
            # Accumulate the loss
            epoch_loss += loss

            # Skip update if loss is Inf or NaN
            if !isfinite(loss)
                @warn "Loss is $loss; skipping update."
                continue
            end

            set_postfix(pbar, Loss = @sprintf("%.4f", loss))
        
            # Update model parameters
            Flux.update!(optimizer, Flux.params(model), grads)
        end

        CUDA.reclaim()

        # Calculate the average loss of the epoch
        avg_epoch_loss = epoch_loss / num_batches
        push!(training_losses, avg_epoch_loss)
        println("Average Training Loss: ", @sprintf("%.4f", avg_epoch_loss))

        # Optional validation accuracy computation
        if val_img_batches !== nothing && val_mask_batches !== nothing
            testmode!(model)

            acc = accuracy(model, val_img_batches, val_mask_batches)
            push!(validation_accuracies, acc)

            # Check if validation accuracy has improved
            if acc > best_accuracy + min_delta
                best_accuracy = acc
                epochs_without_improvement = 0

                println("New best accuracy: ", @sprintf("%.3f", acc), "%")
                
                model = model |> cpu
                # Save the best model so far
                @save "best_model.bson" model
                println("New best model saved.")

                model = model |> gpu
            elseif epoch >= early_stopping_start
                println("Accuracy: ", @sprintf("%.3f", acc), "%")
                println("Current best accuracy: ",
                        @sprintf("%.3f", best_accuracy), "%")

                # Increment the counter for epochs without improvement
                epochs_without_improvement += 1
                println("Epochs without improvement: ",
                        epochs_without_improvement)

                # Early stopping, if no improvement for `patience` epochs
                if epochs_without_improvement >= patience
                    println("Early stopping after $epoch epochs.")

                    loss_plot = lineplot(1:epoch, training_losses;
                        title="Training Loss",
                        xlabel="Epoch",
                        ylabel="Loss")
                    display(loss_plot)

                    println()

                    acc_plot = lineplot(1:epoch, validation_accuracies;
                                title="Validation Accuracy",
                                xlabel="Epoch",
                                ylabel="Accuracy (%)")
                    display(acc_plot)
                    break
                end
            else
                println("Accuracy: ", @sprintf("%.3f", acc), "%")
                println("Current best accuracy: ",
                        @sprintf("%.3f", best_accuracy), "%")

                # Increment the counter for epochs without improvement
                epochs_without_improvement += 1
                println("Epochs without improvement: ",
                        epochs_without_improvement)
            end
        end

        if epoch > 1
            loss_plot = lineplot(1:epoch, training_losses;
                        title="Training Loss",
                        xlabel="Epoch",
                        ylabel="Loss")
            display(loss_plot)

            println()

            if val_img_batches !== nothing && val_mask_batches !== nothing
                acc_plot = lineplot(1:epoch, validation_accuracies;
                            title="Validation Accuracy",
                            xlabel="Epoch",
                            ylabel="Accuracy (%)")
                display(acc_plot)
            end
        end
    end

    # Optional test accuracy computation
    if test_img_batches !== nothing && test_mask_batches !== nothing
        testmode!(model)

        test_acc = accuracy(model, test_img_batches, test_mask_batches)
        println("Test Accuracy: ", @sprintf("%.3f", test_acc), "%")
    end

    CUDA.reclaim()
    println("Training completed.")
end
