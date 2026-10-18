function neuralParams = snmsTrain(messageType, iterMax, numEpochs, cn0Range)
% =========================================================================
% FUNCTION: snmsTrain (Rational & Mixed Training Edition)
% DESCRIPTION: 
%   1. Init: Beta starts at 0.6 (Damping) to ensure stability.
%   2. Loop: Mixed Training (1 Hard Example + 1 Random Example).
% =========================================================================

    %% 1. Initialization
    fprintf('[-] Initializing Training for %s (Rational Mode)...\n', messageType);
    
    settings = initSettings(messageType); 
    settings.maxIterations = iterMax;
    gpsCnav2LdpcTables; 
    
    %% 2. Setup Neural Parameters (Rational Strategy)
    neuralParams.isTrainMode = true;
    
    % --- [核心修改 1]：理性回归初始化 ---
    % Beta: 0.60 -> 1.80 (第一步阻尼保稳，后期放大加速)
    % Alpha: 0.75 -> 1.00 (标准 Min-Sum 附近的微调)
    fprintf('    [Strategy] Rational Ramp-up: Beta 0.6->1.8 | Alpha 0.75->1.0\n');
    
    initAlpha = linspace(0.75, 0.9, iterMax);
    initBeta  = linspace(0.60, 1.0, iterMax); 
    
    neuralParams.c2vWeights = reshape(single(initAlpha), [1, 1, iterMax]);
    neuralParams.vnWeights  = reshape(single(initBeta),  [1, 1, iterMax]);
    
    % Adam State
    neuralParams.adamState.mAlpha = zeros(1, 1, iterMax, 'single');
    neuralParams.adamState.vAlpha = zeros(1, 1, iterMax, 'single');
    neuralParams.adamState.mBeta  = zeros(1, 1, iterMax, 'single');
    neuralParams.adamState.vBeta  = zeros(1, 1, iterMax, 'single');
    neuralParams.adamState.time   = 0;
    
    % Learning Rate (Moderate start)
    initialLr = 0.005; 
    neuralParams.learningRate = initialLr;

    %% 3. Training Loop
    fprintf('[-] Starting Training: %d Epochs\n', numEpochs);
    
    % Mining Settings
    targetBatchesPerEpoch = 50; 
    maxMiningAttempts     = 5000;
    
    for epoch = 1:numEpochs
        tic;
        % Cosine Annealing LR
        neuralParams.learningRate = initialLr * 0.5 * (1 + cos((epoch-1)/numEpochs * pi));
        
        fprintf('\n=== Epoch %d/%d (LR: %.5f) ===\n', epoch, numEpochs, neuralParams.learningRate);
        fprintf('    Mining Hard Examples + Mixed Regularization...\n');
        
        totalLoss = 0;
        trainedBatches = 0;
        miningAttempts = 0;
        
        % Dynamic SNR Range for Mining
        activeCn0 = cn0Range;
        
        while trainedBatches < targetBatchesPerEpoch && miningAttempts < maxMiningAttempts
            miningAttempts = miningAttempts + 1;
            
            % --- Step 1: Mine Hard Example ---
            currentCn0 = activeCn0(randi(length(activeCn0)));
            
            [modMsg, ~] = ldpcEncoder(settings);
            % Direct symbol-level correlator statistics (known noise variance)
            [rxSignal, noiseVar] = sigSim(modMsg, currentCn0, settings);
            llrInput = initLlr(rxSignal, noiseVar);
            trueCodeword = (1 - modMsg) / 2;
            
            % Inference Check (No Train)
            neuralParams.isTrainMode = false;
            [decodedBits, ~, ~, ~] = snmsDecode(llrInput, settings, neuralParams);
            hasError = any(decodedBits(:) ~= trueCodeword(:));
            
            if hasError
                % --- FOUND HARD EXAMPLE -> START MIXED TRAINING ---
                neuralParams.isTrainMode = true;
                
                % A. Train on the Hard Example
                neuralParams.groundTruth = trueCodeword;
                [~, neuralParams, histHard, ~] = snmsDecode(llrInput, settings, neuralParams);
                
                % B. Train on a Random "Easy" Example (Regularization)
                % Randomly pick low SNR (16-18dB) to maintain robustness
                regCn0 = 16.0 + rand()*2.0; 
                [modReg, ~] = ldpcEncoder(settings);
                [rxReg, varReg] = sigSim(modReg, regCn0, settings);
                llrReg = initLlr(rxReg, varReg);
                neuralParams.groundTruth = (1 - modReg) / 2;
                
                [~, neuralParams, histEasy, ~] = snmsDecode(llrReg, settings, neuralParams);
                
                % Track Loss
                totalLoss = totalLoss + 0.5*(mean(histHard) + mean(histEasy));
                trainedBatches = trainedBatches + 1;
                
                if mod(trainedBatches, 5) == 0, fprintf('x'); end
            else
                % Discard easy sample
                if mod(miningAttempts, 200) == 0, fprintf('.'); end
            end
        end
        
        t_elap = toc;
        avgLoss = totalLoss / max(1, trainedBatches);
        
        % Monitor Weights
        firstAlpha = neuralParams.c2vWeights(1,1,1);
        lastAlpha  = neuralParams.c2vWeights(1,1,end);
        firstBeta  = neuralParams.vnWeights(1,1,1);
        lastBeta   = neuralParams.vnWeights(1,1,end);
        
        fprintf('\n    [Summary] Trained %d Pairs (Scanned %d). Avg Loss: %.4f | Time: %.2fs', ...
            trainedBatches, miningAttempts, avgLoss, t_elap);
        fprintf('\n    [Weights] A: %.2f->%.2f | B: %.2f->%.2f', firstAlpha, lastAlpha, firstBeta, lastBeta);
        
        if trainedBatches == 0
            fprintf('\n    [Warning] No errors found. Reducing SNR range.');
            activeCn0 = max(16, activeCn0 - 0.5); 
        end
        
        % Save
        if mod(epoch, 5) == 0 || epoch == numEpochs
            fileName = sprintf('SNMS_SharedWeights_%s_Final.mat', messageType);
            save(fileName, 'neuralParams');
        end
    end
    
    fprintf('\n[-] Mixed Training Completed.\n');
    neuralParams.isTrainMode = false;
    neuralParams.groundTruth = [];
end
