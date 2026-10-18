function neuralParams = nemsTrain(settings, numEpochs, cn0Range)
% =========================================================================
% FUNCTION: nemsTrain
% DESCRIPTION:
%   Training loop for the Neural-EMS decoder.
%   It iterates through Epochs and C/N0 levels, generating random data,
%   simulating the channel, and updating decoder weights via Adam.
%
% INPUTS:
%   settings    : Configuration structure (messageType, maxIterations, etc.).
%   numEpochs   : Number of training epochs.
%   cn0Range    : Vector of C/N0 values (dB-Hz) for training.
%
% OUTPUTS:
%   neuralParams: Structure containing trained weights:
%                 - .c2vWeights : [numEdges x 1 x maxIter]
%                 - .vnWeights  : [1 x 1 x maxIter]
% =========================================================================

    %%  Graph Dimensions & Initialization =================================
    fprintf('[-] Initializing Training for %s...\n', settings.messageType);
    
    % Retrieve H Matrix info to determine number of edges (numEdges)
    % This is needed to pre-allocate the weight matrices.
    switch settings.messageType
        case 'B1C_2'
            [hIndexCell, hElementCell, ~] = getHInformationB1C_2();
        case 'B1C_3'
            [hIndexCell, hElementCell, ~] = getHInformationB1C_3();
        case 'B2a'
            [hIndexCell, hElementCell, ~] = getHInformationB2a();
        case 'B2b'
            [hIndexCell, hElementCell, ~] = getHInformationB2b();
        otherwise
            error('nemsTrain: Unknown messageType "%s"', settings.messageType);
    end
    
    % Get graph edges count
    [~, ~, ~, numEdges] = getGraphEdges(hIndexCell, hElementCell);
    
    % Initialize Neural Parameters Structure
    neuralParams.isTrainMode = true;
    
    % Initialize Weights (One per edge per iteration)
    % C2V Weights: Initialize to 1.0
    neuralParams.c2vWeights = ones(numEdges, 1, settings.maxIterations, 'single');
    
    % VN Damping Weights (Beta): Initialize to 1.0 (Scalar per iteration)
    neuralParams.vnWeights  = ones(1, 1, settings.maxIterations, 'single');
    
    %% Learning Rate Setup ================================================
    initialLearningRate = 0.01;
    finalLearningRate   = 0.001;
    % Calculate decay factor
    learningRateDecay   = (finalLearningRate / initialLearningRate)^(1 / numEpochs);
    
    %%  Training Loop =====================================================
    for epoch = 1:numEpochs
        fprintf('\n=== Epoch %d/%d ===\n', epoch, numEpochs);
        
        % Update Learning Rate for current epoch
        currentLearningRate = initialLearningRate * (learningRateDecay^(epoch - 1));
        neuralParams.learningRate = currentLearningRate;
        
        % Shuffle C/N0 range for robustness
        cn0Sequence = cn0Range(randperm(length(cn0Range)));
        
        for i = 1:length(cn0Sequence)
            currentCn0 = cn0Sequence(i);
            fprintf('  >> Training C/N0: %.1f dB-Hz | LR: %.5f\n', currentCn0, currentLearningRate);
            
            % ------------------Generate Random Data-----------------------        
            % binaryCodeword : [N x 6] For channel simulation
            % decimalCodeword: [1 x N] For Ground Truth labels
            [binaryCodeword, decimalCodeword] = generateRandomDecimalData(settings);
            

            % -------- Symbol-Level Correlator Statistics -----------------
            % llrMatrix: [N x Q] GF-symbol metrics with known noise variance
            llrMatrix = simulatedSignalChannel(binaryCodeword, currentCn0, settings);
            

            % --------------------- Prepare Labels-------------------------
            % Pass ground truth to neuralParams for Loss calculation inside decoder
            neuralParams.groundTruth = decimalCodeword; % Ensure [1 x N] or [N x 1] matches usage
            
            % --------------- Run Neural Decoder (Forward + Backward)------
            % The 'nemsDecode' function handles the Adam update internally 
            % and returns the updated neuralParams.
            [~, neuralParams, ~] = nemsDecode(llrMatrix, settings, neuralParams);
            
        end
        

        % --------------------------Save Checkpoint------------------------
        if mod(epoch, 5) == 0 || epoch == numEpochs
            fileName = sprintf('neural_ems_weights_%s_epoch%d.mat', settings.messageType, epoch);
            
            % Extract weights for saving
            c2vWeights = neuralParams.c2vWeights;
            vnWeights  = neuralParams.vnWeights;
            
            save(fileName, 'c2vWeights', 'vnWeights');
            fprintf('[-] Checkpoint saved: %s\n', fileName);
        end
    end
end
