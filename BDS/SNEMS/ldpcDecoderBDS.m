function [ldpcOutMsg, iterCount] = ldpcDecoderBDS(normalizedPromptI, sigmaSquaredNorm, settings)
% =========================================================================
% FUNCTION: ldpcDecoderBDS
% DESCRIPTION:
%   Orchestrates the LDPC decoding process for BDS GNSS signals.
%   Automatically loads Neural-EMS weights based on signal type.
%
% INPUTS:
%   normalizedPromptI : [N x M] Normalized soft-decision input.
%   sigmaSquaredNorm  : Normalized noise variance.
%   settings          : Configuration structure.
%
% OUTPUTS:
%   ldpcOutMsg        : [1 x K] Decoded GF symbol sequence (Hard Decision).
% =========================================================================

    %%  1. LLR Initialization =============================================
    % Compute initial symbol metrics (Log-Likelihood Ratios)
    llrMatrix = initLlr(normalizedPromptI, sigmaSquaredNorm, settings);

    %%  2. Load Neural Weights (Cached) ===================================
    % 'persistent' allows variables to retain memory between function calls.
    % We load weights only once to improve simulation speed.
    persistent neuralParamsCached;
    persistent lastMessageType;

    % Check if we need to load/reload weights
    % (Reload if cache is empty OR if messageType changed)
    if isempty(neuralParamsCached) || ~strcmp(lastMessageType, settings.messageType)
        
        weightFileName = sprintf('neural_ems_%s_final.mat', settings.messageType);
        
        if exist(weightFileName, 'file')
            % fprintf('[-] ldpcDecoderBDS: Loading weights from %s...\n', weightFileName);
            loadedData = load(weightFileName);
            
            % Reconstruct structure
            neuralParamsCached.c2vWeights  = loadedData.c2vWeights;
            neuralParamsCached.vnWeights   = loadedData.vnWeights;
            neuralParamsCached.isTrainMode = false; % Force Inference Mode
        else
            warning('Weight file "%s" not found. Falling back to Standard EMS (Weights=1.0).', weightFileName);
            neuralParamsCached = []; % Passing empty triggers default weights (1.0)
        end
        
        lastMessageType = settings.messageType; % Update cache tag
    end

    %%  3. Decoder Execution ==============================================
    % Use the inference-only SNEMS decoder.
    % Passing the cached weights
    [ldpcOutMsg, iterCount] = snemsDecode(llrMatrix, settings, neuralParamsCached);
