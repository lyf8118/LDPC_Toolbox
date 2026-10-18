function [berNeural, berBaseline, avgIterNeural, avgIterBaseline] = snmsTest(settings, neuralParams, cn0Range, numTests)
% =========================================================================
% FUNCTION: snmsTest
% =========================================================================

    %% 1. Initialization
    if isempty(neuralParams)
        weightFileName = sprintf('SNMS_SharedWeights_%s_Final.mat', settings.messageType);
        if exist(weightFileName, 'file')
            fprintf('[-] Loading weights: %s\n', weightFileName);
            loadedData = load(weightFileName);
            neuralParams = loadedData.neuralParams;
        else
            warning('Weights not found. Using Default.');
            neuralParams.c2vWeights = 0.75 * ones(1,1,settings.maxIterations);
            neuralParams.vnWeights  = 1.0 * ones(1,1,settings.maxIterations);
        end
    end
    
    neuralParams.isTrainMode = false;
    neuralParams.groundTruth = []; 
    
    % Baseline Params
    baselineParams.isTrainMode = false;
    baselineParams.c2vWeights = 0.75 * ones(1, 1, settings.maxIterations, 'single');
    baselineParams.vnWeights  = 1.0  * ones(1, 1, settings.maxIterations, 'single');
    
    berNeural       = zeros(size(cn0Range));
    berBaseline     = zeros(size(cn0Range));
    avgIterNeural   = zeros(size(cn0Range));
    avgIterBaseline = zeros(size(cn0Range));
    
    fprintf('[-] Starting Parallel Test: MaxIter=%d, Trials=%d\n', ...
            settings.maxIterations, numTests);
    
    %% 2. Test Loop
    for i = 1:length(cn0Range)
        currentCn0 = cn0Range(i);
        
        frameErrNeural   = zeros(numTests, 1);
        frameErrBaseline = zeros(numTests, 1);
        frameInfoBits    = zeros(numTests, 1);
        frameIterNeural  = zeros(numTests, 1);
        frameIterBaseline = zeros(numTests, 1);

        fprintf('  |-- Running C/N0: %.1f dB-Hz (%d parallel trials)\n', ...
                currentCn0, numTests);

        parfor testIdx = 1:numTests
            
            % Generate Data
            [modMsg, originalBits] = ldpcEncoder(settings);
            [rxSignal, noiseVar] = sigSim(modMsg, currentCn0, settings);
            llrInput = initLlr(rxSignal, noiseVar);
            
            % Decode
            [decodedNeuralBits, ~, ~, iterN] = snmsDecode(llrInput, settings, neuralParams);
            [decodedBaselineBits, ~, ~, iterB] = snmsDecode(llrInput, settings, baselineParams);
            
            % Metrics
            frameIterNeural(testIdx)   = iterN;
            frameIterBaseline(testIdx) = iterB;
            
            K = length(originalBits);
            neuralInfo   = decodedNeuralBits(1:K);
            baselineInfo = decodedBaselineBits(1:K);
            
            frameErrNeural(testIdx) = sum(neuralInfo(:) ~= originalBits(:));
            frameErrBaseline(testIdx) = sum(baselineInfo(:) ~= originalBits(:));
            frameInfoBits(testIdx) = K;
        end

        totalInfoBits = sum(frameInfoBits);
        berNeural(i)   = sum(frameErrNeural) / totalInfoBits;
        berBaseline(i) = sum(frameErrBaseline) / totalInfoBits;
        avgIterNeural(i)   = mean(frameIterNeural);
        avgIterBaseline(i) = mean(frameIterBaseline);
        
        fprintf('  |-- C/N0: %.1f dB | BER: %.2e vs %.2e | Iter: %.1f vs %.1f\n', ...
                currentCn0, berNeural(i), berBaseline(i), avgIterNeural(i), avgIterBaseline(i));
    end
end
