function neuralParams = nmsTrain(messageType, iterMax, numEpochs, cn0Range)
% =========================================================================
% FUNCTION: nmsTrain
% DESCRIPTION:
%   Training loop for the Type-3 Neural/Scaled Min-Sum (NMS) decoder.
%   It iterates through Epochs and C/N0 levels, generating random data,
%   simulating the channel, and updating degree-dependent scaling weights
%   via Adam.
%
% INPUTS:
%   messageType : Char/string specifying the signal ('L1C_2' or 'L1C_3').
%   iterMax     : Unfolding depth / max decoding iterations for training.
%   numEpochs   : Number of training epochs.
%   cn0Range    : Vector of C/N0 values (dB-Hz) for training batches.
%
% OUTPUTS:
%   neuralParams: Structure containing trained parameters:
%                 - .weights : [maxDegree x iterMax] scaling matrix.
%                 - .adam    : Optimizer state (m, v, t).
% =========================================================================
    %% Initialize & Pre-calculate Graph Properties=========================
    fprintf('[-] Initializing Training for %s (Type-3 NMS)...\n', messageType);
    
    settings = initSettings(messageType);
    settings.maxIterations = iterMax;
    
    gpsCnav2LdpcTables; 
    switch messageType
        case 'L1C_2'
            tempH = generateGpsL1cHMatrix(settings.ldpcM, settings.ldpcN, 1, ...
                    H_CNV2_SF2_A, H_CNV2_SF2_B, H_CNV2_SF2_C, ...
                    H_CNV2_SF2_D, H_CNV2_SF2_E, H_CNV2_SF2_T);
        case 'L1C_3'
            tempH = generateGpsL1cHMatrix(settings.ldpcM, settings.ldpcN, 1, ...
                    H_CNV2_SF3_A, H_CNV2_SF3_B, H_CNV2_SF3_C, ...
                    H_CNV2_SF3_D, H_CNV2_SF3_E, H_CNV2_SF3_T);
    end
    
    cnDegrees = full(sum(tempH, 2)); 
    maxDegree = double(max(cnDegrees));
    fprintf('    Graph Analysis: Max Check Node Degree = %d\n', maxDegree);
    clear tempH; 

    %%  Setup Neural Parameters============================================
    neuralParams.isTrainMode = true;
    
    neuralParams.weights = 0.8 * ones(maxDegree, iterMax);
    
    neuralParams.adam.m = zeros(maxDegree, iterMax);
    neuralParams.adam.v = zeros(maxDegree, iterMax);
    neuralParams.adam.t = 0;
    
    initialLr = 0.01; 
    finalLr   = 0.001;
    lrDecay   = (finalLr / initialLr)^(1 / numEpochs);
    neuralParams.learningRate = initialLr;

    %% 3. Training Loop====================================================
    fprintf('[-] Starting Training: %d Epochs, Total Batches/Epoch: %d\n', numEpochs, length(cn0Range));
    
    for epoch = 1:numEpochs
        tic;
        if epoch > 1
            neuralParams.learningRate = neuralParams.learningRate * lrDecay;
        end
        
        fprintf('\n=== Epoch %d/%d (LR: %.5f) ===\n', epoch, numEpochs, neuralParams.learningRate);
        
        % Shuffle the (already weighted) range
        shuffledCn0 = cn0Range(randperm(length(cn0Range)));
        
        totalLoss = 0;
        totalBer  = 0;
        
        for i = 1:length(shuffledCn0)
            currentCn0 = shuffledCn0(i);
            
            % --------------------Generate Data----------------------------
            [modMsg, originalBits] = ldpcEncoder(settings); 
            trueCodeword = (1 - modMsg) / 2; 
            neuralParams.groundTruth = trueCodeword;
            
            % Direct symbol-level correlator statistics (known noise variance)
            [rxSignal, noiseVar] = sigSim(modMsg, currentCn0, settings);
            llrInput = initLlr(rxSignal, noiseVar);
            
            % -----------------------Train Step----------------------------
            [decodedBits, neuralParams, stepLossHistory] = nmsDecode(llrInput, settings, neuralParams);
            
            % ----------------------- Metrics------------------------------
            totalLoss = totalLoss + mean(stepLossHistory);
            ber = calculateBER(decodedBits, originalBits);
            totalBer = totalBer + ber;
             
            if mod(i, 20) == 0
                fprintf('.'); 
            end
        end
        
        avgLoss = totalLoss / length(shuffledCn0);
        avgBer  = totalBer / length(shuffledCn0);
        t_elap = toc;
        
        fprintf('\n    Avg Loss: %.4f | Avg BER: %.5f | Time: %.2fs', avgLoss, avgBer, t_elap);
        
        %------------------------ Save Checkpoint--------------------------
        if mod(epoch, 5) == 0 || epoch == numEpochs
            fileName = sprintf('NMS_Weights_%s_Final.mat', messageType);
            save(fileName, 'neuralParams');
            fprintf(' [Saved]');
        end
    end
    
    fprintf('\n[-] Training Completed.\n');
    neuralParams.isTrainMode = false;
    neuralParams.groundTruth = [];
end
