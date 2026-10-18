function [ldpcOutMsg,iterCount] = ldpcDecoderGPS(normalizedPromptI, sigmaSquaredNorm, settings)
% =========================================================================
% FUNCTION: ldpcDecoderGPS
% DESCRIPTION:
%   Orchestrates the Neural Min-Sum (Neural MS) LDPC decoding process 
%   for GPS L1C (CNAV-2) signals. It initializes the LLR array from 
%   soft decisions, caches pre-trained neural network weights, and 
%   dispatches the core Neural MS decoding kernel.
%
% INPUTS:
%   normalizedPromptI : [1 x N] Normalized soft-decision input from the 
%                       correlator (Prompt I-branch).
%   sigmaSquaredNorm  : Normalized noise variance for LLR scaling.
%   settings          : Configuration structure containing:
%                       - settings.messageType ('L1C_2', etc.)
%                       - settings.maxIterations, network structure, etc.
%
% OUTPUTS:
%   ldpcOutMsg        : [1 x K] Decoded binary message sequence .
%   iterCount         : [Scalar] Actual number of iterations used.
% =========================================================================

    %%  LLR Initialization ================================================
    % Compute initial symbol metrics (Log-Likelihood Ratios) based on 
    % channel observations and noise statistics.
    llr = initLlr(normalizedPromptI,sigmaSquaredNorm);
    %% Load weights (cached)
    persistent cachedType cachedWeights
    if isempty(cachedWeights) || ~strcmp(cachedType, settings.messageType)
    
        weightFile = fullfile(fileparts(mfilename('fullpath')), ...
            sprintf('NMS_Weights_%s_Final.mat', settings.messageType));
    
        s = load(weightFile, 'neuralParams');
        cachedWeights = s.neuralParams.weights;
    
        cachedType = settings.messageType;
    end
    
    neuralParams.weights = cachedWeights;

    %%  Decoder  ==================================================

    [ldpcOutMsg,iterCount] = neuralmsDecode(llr, settings, neuralParams);

end