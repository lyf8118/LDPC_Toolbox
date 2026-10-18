function neuralParams = snemsTrain(settings, numEpochs, cn0Range)
% =========================================================================
% FUNCTION: snemsTrain 
% DESCRIPTION:
%   Training loop for the Neural-EMS decoder with Layer-Shared Weights.
%   Both C2V and V2C weights are scalars per iteration.
%
% INPUTS:
%   settings    : Configuration structure (messageType, maxIterations, etc.).
%   numEpochs   : Number of training epochs.
%   cn0Range    : Vector of C/N0 values (dB-Hz) for training.
%
% OUTPUTS:
%   neuralParams: Structure containing trained weights:
%                 - .c2vWeights : [1 x 1 x maxIter] (Layer-Shared)
%                 - .vnWeights  : [1 x 1 x maxIter] (Layer-Shared)
% =========================================================================
    %% ================= 1. Graph Dimensions & Initialization =================
    fprintf('[-] Initializing Training for %s (Layer-Shared Weights)...\n', settings.messageType);
    
    % Retrieve H Matrix info (Only needed for verification now)
    % switch settings.messageType
    %     case 'B1C_2'
    %         [hIndexCell, hElementCell, ~] = getHInformationB1C_2();
    %     case 'B1C_3'
    %         [hIndexCell, hElementCell, ~] = getHInformationB1C_3();
    %     case 'B2a'
    %         [hIndexCell, hElementCell, ~] = getHInformationB2a();
    %     case 'B2b'
    %         [hIndexCell, hElementCell, ~] = getHInformationB2b();
    %     otherwise
    %         error('snemsTrain: Unknown messageType "%s"', settings.messageType);
    % end
    % 
    % Initialize Neural Parameters Structure
    neuralParams.isTrainMode = true;
    
    % --- [MODIFIED] Initialize Shared Weights ---
    % C2V Weights: Now Scalar per iteration (Dimension: 1 x 1 x maxIter)
    % Initialize to 1.0
    neuralParams.c2vWeights = ones(1, 1, settings.maxIterations, 'single');
    
    % VN Damping Weights (Beta): Scalar per iteration (Dimension: 1 x 1 x maxIter)
    % Initialize to 1.0
    neuralParams.vnWeights  = ones(1, 1, settings.maxIterations, 'single');
    
    %% ================= 2. Learning Rate Setup =================
    initialLearningRate = 0.01;
    finalLearningRate   = 0.001;
    % Calculate decay factor
    learningRateDecay   = (finalLearningRate / initialLearningRate)^(1 / numEpochs);
    
    %% ================= 3. Training Loop =================
    for epoch = 1:numEpochs
        fprintf('\n=== Epoch %d/%d ===\n', epoch, numEpochs);
        
        % Update Learning Rate for current epoch
        currentLearningRate = initialLearningRate * (learningRateDecay^(epoch - 1));
        neuralParams.learningRate = currentLearningRate;
        
        % Shuffle C/N0 range for robustness
        cn0Sequence = cn0Range(randperm(length(cn0Range)));
        
        for i = 1:length(cn0Sequence)
            currentCn0 = cn0Sequence(i);
            
            % -----------------------------------------------------------
            % Step 1: Generate Random Data
            % -----------------------------------------------------------
            % binaryCodeword : [N x 6] For channel simulation
            % decimalCodeword: [1 x N] For Ground Truth labels
            [binaryCodeword, decimalCodeword] = generateRandomDecimalData(settings);
            
            % -----------------------------------------------------------
            % Step 2: Symbol-Level Correlator Statistics
            % -----------------------------------------------------------
            % llrMatrix: [N x Q] GF-symbol metrics with known noise variance
            llrMatrix = simulatedSignalChannel(binaryCodeword, currentCn0, settings);
            
            % -----------------------------------------------------------
            % Step 3: Prepare Labels
            % -----------------------------------------------------------
            % Pass ground truth to neuralParams for Loss calculation inside decoder
            neuralParams.groundTruth = decimalCodeword; 
            
            % -----------------------------------------------------------
            % Step 4: Run Neural Decoder (Forward + Backward)
            % -----------------------------------------------------------
            % The 'snemsDecode' function handles the Adam update internally 
            % and returns the updated neuralParams.
            % Note: We capture output mainly to update 'neuralParams'
            [~, neuralParams, batchLossHistory] = snemsDecode(llrMatrix, settings, neuralParams);
            
            % Optional: Print specific training step info only if needed
            % (Currently snemsDecode prints loss per iteration)
        end
        
        fprintf('  >> End of Epoch %d. LR: %.5f | Last Batch Loss (End): %.4f\n', ...
            epoch, currentLearningRate, batchLossHistory(end));
            
        % -----------------------------------------------------------
        % Step 5: Save Checkpoint
        % -----------------------------------------------------------
        if mod(epoch, 5) == 0 || epoch == numEpochs
            fileName = sprintf('neural_ems_shared_weights_%s_epoch%d.mat', settings.messageType, epoch);
            
            % Extract weights for saving
            c2vWeights = neuralParams.c2vWeights;
            vnWeights  = neuralParams.vnWeights;
            
            save(fileName, 'c2vWeights', 'vnWeights');
            fprintf('[-] Checkpoint saved: %s\n', fileName);
        end
    end
end
