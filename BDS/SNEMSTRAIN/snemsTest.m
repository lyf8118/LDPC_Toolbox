function [berNeural, berBaseline] = snemsTest(settings, neuralParams, cn0Range, numTests)
% =========================================================================
% FUNCTION: snemsTest 
% DESCRIPTION:
%   Performance comparison benchmark: Neural-EMS (Shared) vs. Conventional EMS.
%   Performs parallel Monte Carlo simulations across a C/N0 range.
%
%   Note: If neuralParams is empty, it looks for a file named:
%         'neural_ems_shared_weights_[TYPE]_final.mat'
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
    %% ================= Block 1: Initialization & Weight Loading =================
    
    % --- Automatic Weight Loading Logic ---
    if isempty(neuralParams)
        % [MODIFIED] Update filename pattern to match 'snemsTrain' output
        % Tip: You may need to rename your best epoch file (e.g., epoch20) to '_final'
        weightFileName = sprintf('neural_ems_shared_weights_%s_final.mat', settings.messageType);
        
        if exist(weightFileName, 'file')
            fprintf('[-] Loading trained weights from: %s\n', weightFileName);
            loadedData = load(weightFileName);
            
            % Reconstruct neuralParams structure
            neuralParams.c2vWeights = loadedData.c2vWeights;
            neuralParams.vnWeights  = loadedData.vnWeights;
        else
            error('snemsTest: Weight file "%s" not found. \nPlease rename your best training epoch file (e.g., "...epoch20.mat") to "...final.mat" or pass params directly.', weightFileName);
        end
    end
    
    % --- [Safety Check] Ensure Weights are Scalar (Type-1) ---
    % If user accidentally loads old Type-2 weights (matrix), we collapse them
    % to prevent dimension mismatch errors in the new snemsDecode.
    if size(neuralParams.c2vWeights, 1) > 1
        warning('snemsTest: Loaded C2V weights are Type-2 (Per-Edge). Converting to Type-1 (Scalar) by averaging.');
        neuralParams.c2vWeights = mean(neuralParams.c2vWeights, 1); 
    end
    
    % Ensure Neural Decoder is in Inference Mode (No training updates)
    neuralParams.isTrainMode = false;
    
    % Initialize Result Arrays
    berNeural   = zeros(size(cn0Range));
    berBaseline = zeros(size(cn0Range));
    
    fprintf('[-] Starting Performance Test for %s (Shared Weights)\n', settings.messageType);
    fprintf('    Iter Max: %d, Trials: %d\n', settings.maxIterations, numTests);
    
    %% ================= Block 2: Main Loop (C/N0) =================
    numInfoSymbols = settings.symbolsPerFrame;
    messageType = settings.messageType;

    for i = 1:length(cn0Range)
        currentCn0 = cn0Range(i);

        frameBerNeural   = zeros(numTests, 1);
        frameBerBaseline = zeros(numTests, 1);

        fprintf('  |-- Running C/N0: %.1f dB-Hz (%d parallel trials)\n', ...
                currentCn0, numTests);

        %% ================= Block 3: Parallel Monte Carlo Trials =========
        parfor testIdx = 1:numTests
            
            % --- 3.2 Data Generation & Channel Simulation ---
            % binaryCodeword: [N x 6] (used for Ground Truth Bits)
            [binaryCodeword, ~] = generateRandomDecimalData(settings);
            
            % Prepare Ground Truth Bits for BER Calculation
            % Reshape [N x 6] -> [1 x 6N]
            infoPartBinary = binaryCodeword(1:numInfoSymbols, :);
            groundTruthBits = reshape(infoPartBinary.', 1, []);
            
            % Generate LLRs
            llrMatrix = simulatedSignalChannel(binaryCodeword, currentCn0, settings);
            
            % --- 3.3 Algorithm 1: Neural-EMS Decoding (Proposed) ---
            % Uses trained scalar weights from neuralParams
            decodedNeural = snemsDecode(llrMatrix, settings, neuralParams);
            
            % --- 3.4 Algorithm 2: Conventional EMS Decoding (Baseline) ---
            decodedBaseline = decodeEmsBaseline(llrMatrix, settings, messageType);
            
            % --- 3.5 Error Calculation ---
            % Calculate BER for Neural-EMS
            frameBerNeural(testIdx) = ...
                calculateBER(decodedNeural, groundTruthBits, settings);
            
            % Calculate BER for Baseline EMS
            frameBerBaseline(testIdx) = ...
                calculateBER(decodedBaseline, groundTruthBits, settings);
        end
        
        %% ================= Block 4: Average BER for Current C/N0 =================
        berNeural(i)   = mean(frameBerNeural);
        berBaseline(i) = mean(frameBerBaseline);
        
        % Log to Console
        fprintf('  |-- C/N0: %.1f dB | SNEMS BER: %.5e | EMS BER: %.5e\n', ...
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
            error('snemsTest:UnknownMessageType', ...
                'Unknown messageType "%s".', messageType);
    end
end
