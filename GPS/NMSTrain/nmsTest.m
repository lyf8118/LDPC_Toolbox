function [berNeural, berBaseline] = nmsTest(settings, neuralParams, cn0Range, numTests)
% =========================================================================
% FUNCTION: nmsTest
% DESCRIPTION:
%   Performance comparison benchmark: Neural Min-Sum vs. Standard Min-Sum.
%   Performs parallel Monte Carlo simulations for GPS L1C signals.
%
% INPUTS:
%   settings     : Configuration structure (from initSettings).
%   neuralParams : Structure containing trained .weights (1 x MaxIter).
%                  (Pass [] to auto-load from 'NMS_Weights_[TYPE]_Final.mat').
%   cn0Range     : Vector of C/N0 values (dB-Hz).
%   numTests     : Number of trials per C/N0 point.
%
% OUTPUTS:
%   berNeural    : [1 x N] BER vector for Neural Min-Sum.
%   berBaseline  : [1 x N] BER vector for Standard Min-Sum.
% =========================================================================

    %% Initialization & Weight Loading ====================================
    
    % -------------- Automatic Weight Loading Logic -----------------------
    if isempty(neuralParams)
        % Construct expected filename based on signal type
        weightFileName = sprintf('NMS_Weights_%s_Final.mat', settings.messageType);
        
        if exist(weightFileName, 'file')
            fprintf('[-] Loading trained weights from: %s\n', weightFileName);
            loadedData = load(weightFileName);
            
            % Check for 'neuralParams' structure
            if isfield(loadedData, 'neuralParams')
                neuralParams = loadedData.neuralParams;
            else
                % Fallback: try to find 'weights' variable directly
                if isfield(loadedData, 'weights')
                    neuralParams.weights = loadedData.weights;
                else
                    error('nmsTest: Could not find "neuralParams" or "weights" in file.');
                end
            end
        else
            error('nmsTest: Weight file "%s" not found. Please train first or pass params.', weightFileName);
        end
    end
    
    % Ensure Neural Decoder is in Inference Mode 
    neuralParams.isTrainMode = false;
    neuralParams.groundTruth = []; 
    
    % Initialize Result Arrays
    berNeural   = zeros(size(cn0Range));
    berBaseline = zeros(size(cn0Range));
    
    fprintf('[-] Starting Performance Test for %s\n', settings.messageType);
    fprintf('    Max Iterations: %d\n', settings.maxIterations);
    fprintf('    Trials per C/N0: %d\n', numTests);
    
    %% Main Loop (C/N0) ===================================================
    for i = 1:length(cn0Range)
        currentCn0 = cn0Range(i);

        frameBerNeural   = zeros(numTests, 1);
        frameBerBaseline = zeros(numTests, 1);

        fprintf('  |-- Running C/N0: %.1f dB-Hz (%d parallel trials)\n', ...
                currentCn0, numTests);

        %%  Parallel Monte Carlo Trials ===================================
        parfor testIdx = 1:numTests
            
            % ---------- Data Generation & Channel Simulation -------------
            %  Generate L1C Signal (Bits & Modulated Symbols)
            % originalData: [1 x K] binary info bits
            % ldpcInMsg:    [1 x N] modulated symbols (+1/-1)
            [ldpcInMsg, originalData] = ldpcEncoder(settings);
            
            % Simulate Channel (AWGN)
            % rxSignal: Normalized received signal
            % noiseVar: Noise variance
            [rxSignal, noiseVar] = sigSim(ldpcInMsg, currentCn0, settings);
            
            % -----------Calculate LLRs------------------------------------
            llrValues = initLlr(rxSignal, noiseVar);
            
            % --- Algorithm 1 Neural Min-Sum Decoding ---------------------

            decodedNeural = nmsDecode(llrValues, settings, neuralParams);
            
            % --- Algorithm 2 Standard Min-Sum Decoding -------------------

            decodedBaseline = msDecode(llrValues, settings);
            
            % ---------------Error Calculation ----------------------------
            % Calculate BER for Neural-EMS
            frameBerNeural(testIdx) = calculateBER(decodedNeural, originalData);
            
            % Calculate BER for Baseline EMS
            frameBerBaseline(testIdx) = calculateBER(decodedBaseline, originalData);
        end
        
        %%  Average BER for Current C/N0 ==================================
        berNeural(i)   = mean(frameBerNeural);
        berBaseline(i) = mean(frameBerBaseline);
        
        % Log to Console
        fprintf('  |-- C/N0: %.1f dB | Neural BER: %.5e | Baseline BER: %.5e\n', ...
                currentCn0, berNeural(i), berBaseline(i));
    end

    %%  Optional: Plot Results ============================================
    figure;
    semilogy(cn0Range, berBaseline, '-o', 'DisplayName', 'Standard MS');
    hold on;
    semilogy(cn0Range, berNeural, '-x', 'LineWidth', 2, 'DisplayName', 'Neural MS (Proposed)');
    grid on; legend show;
    xlabel('C/N0 (dB-Hz)'); ylabel('BER');
    title(['Performance Comparison: ', settings.messageType]);
    figName = sprintf('BER_Comparison_%s.fig', settings.messageType);
    savefig(gcf, figName);
end
