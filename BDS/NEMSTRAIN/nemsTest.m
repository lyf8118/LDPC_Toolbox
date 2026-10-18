function [berNeural, berBaseline] = nemsTest(settings, neuralParams, cn0Range, numTests)
% =========================================================================
% FUNCTION: nemsTest
% DESCRIPTION:
%   Performance comparison benchmark: Neural-EMS vs. Conventional EMS.
%   Performs parallel Monte Carlo simulations across a C/N0 range.
%
%   If 'neuralParams' is empty, the function attempts to load weights from
%   a file named 'neural_ems_[TYPE]_final.mat'.
%
% INPUTS:
%   settings     : Configuration structure.
%   neuralParams : Structure containing .c2vWeights and .vnWeights. 
%                  (Pass [] to auto-load from file).
%   cn0Range     : Vector of C/N0 values (dB-Hz).
%   numTests     : Number of trials per C/N0 point.
%
% OUTPUTS:
%   berNeural    : [1 x N] BER vector for Neural-EMS.
%   berBaseline  : [1 x N] BER vector for Conventional EMS.
% =========================================================================

    %% Initialization & Weight Loading ====================================
    
    % --- Automatic Weight Loading Logic ---
    if isempty(neuralParams)
        % Construct expected filename based on signal type
        weightFileName = sprintf('neural_ems_%s_final.mat', settings.messageType);
        
        if exist(weightFileName, 'file')
            fprintf('[-] Loading trained weights from: %s\n', weightFileName);
            loadedData = load(weightFileName);
            
            % Reconstruct neuralParams structure
            neuralParams.c2vWeights = loadedData.c2vWeights;
            neuralParams.vnWeights  = loadedData.vnWeights;
        else
            error('nemsTest: Weight file "%s" not found. Please train first or pass params.', weightFileName);
        end
    end

    % Ensure Neural Decoder is in Inference Mode (No training updates)
    neuralParams.isTrainMode = false;
    
    % Initialize Result Arrays
    berNeural   = zeros(size(cn0Range));
    berBaseline = zeros(size(cn0Range));
    
    fprintf('[-] Starting Performance Test for %s\n', settings.messageType);
    fprintf('    Iter Max: %d, Trials: %d\n', settings.maxIterations, numTests);

    %%  Main Loop (C/N0) ==================================================
    numInfoSymbols = settings.symbolsPerFrame;
    messageType = settings.messageType;

    for i = 1:length(cn0Range)
        currentCn0 = cn0Range(i);

        % Store one BER value per independent frame. Using sliced arrays
        % avoids shared-state updates inside the parallel loop.
        frameBerNeural   = zeros(numTests, 1);
        frameBerBaseline = zeros(numTests, 1);

        fprintf('  |-- Running C/N0: %.1f dB-Hz (%d parallel trials)\n', ...
                currentCn0, numTests);

        %%  Parallel Monte Carlo Trials ===================================
        parfor testIdx = 1:numTests
            
            % --------- Data Generation & Channel Simulation ------------- 
            % binaryCodeword: [N x 6] (used for Ground Truth Bits)
            [binaryCodeword, ~] = generateRandomDecimalData(settings);
            
            % Prepare Ground Truth Bits for BER Calculation
            % Reshape [N x 6] -> [1 x 6N]

            infoPartBinary = binaryCodeword(1:numInfoSymbols, :);
   
            groundTruthBits = reshape(infoPartBinary.', 1, []);
            
            % Generate LLRs
            llrMatrix = simulatedSignalChannel(binaryCodeword, currentCn0, settings);
            
            % -------  Algorithm 1 Neural-EMS Decoding --------------------
            % Uses trained weights from neuralParams
            decodedNeural = nemsDecode(llrMatrix, settings, neuralParams);
            
            % -------  Algorithm 2 Conventional EMS Decoding --------------
            decodedBaseline = decodeEmsBaseline(llrMatrix, settings, messageType);
            
            % -------------- Error Calculation ----------------------------
            % Calculate BER for Neural-EMS
            frameBerNeural(testIdx) = ...
                calculateBER(decodedNeural, groundTruthBits, settings);
            
            % Calculate BER for Baseline EMS
            frameBerBaseline(testIdx) = ...
                calculateBER(decodedBaseline, groundTruthBits, settings);
        end
        
        %%  Average BER for Current C/N0 ==================================
        berNeural(i)   = mean(frameBerNeural);
        berBaseline(i) = mean(frameBerBaseline);
        
        % Log to Console
        fprintf('  |-- C/N0: %.1f dB | Neural BER: %.5e | EMS BER: %.5e\n', ...
                currentCn0, berNeural(i), berBaseline(i));
    end

end

function decodedCodeword = decodeEmsBaseline(llrMatrix, settings, messageType)
%DECODEEMSBASELINE Dispatch the conventional EMS decoder for one frame.
    switch messageType
        case {'B1C_2', 'B1C_3'}
            decodedCodeword = emsB1CDecode(llrMatrix, settings);
        case 'B2a'
            decodedCodeword = emsB2aDecode(llrMatrix, settings);
        case 'B2b'
            decodedCodeword = emsB2bDecode(llrMatrix, settings);
        otherwise
            error('nemsTest:UnknownMessageType', ...
                'Unknown messageType "%s".', messageType);
    end
end
