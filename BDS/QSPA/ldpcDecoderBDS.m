function [ldpcOutMsg,iterCount] = ldpcDecoderBDS(normalizedPromptI, sigmaSquaredNorm, settings)
% =========================================================================
% FUNCTION: ldpcDecoderBDS
% DESCRIPTION:
%   Orchestrates the LDPC decoding process for BDS GNSS signals.
%   It initializes the LLR matrix and dispatches the appropriate EMS 
%   decoding algorithm based on the configured message type.
%
% INPUTS:
%   normalizedPromptI : [N x M] Normalized soft-decision input from the 
%                       correlator (Prompt I-branch).
%   sigmaSquaredNorm  : Normalized noise variance for LLR scaling.
%   settings          : Configuration structure containing:
%                       - settings.messageType ('B1C_2', 'B2a', etc.)
%                       - settings.gfBits, settings.colH, etc.
%
% OUTPUTS:
%   ldpcOutMsg        : [1 x K] Decoded GF symbol sequence (Hard Decision).
% =========================================================================

    %%  LLR Initialization ================================================
    % Compute initial symbol metrics (Log-Likelihood Ratios) based on 
    % channel observations and noise statistics.
    symbolProbabilities = initQspaProbabilities(normalizedPromptI, sigmaSquaredNorm, settings);

    %%  Decoder  ==================================================
     [ldpcOutMsg,iterCount] = qspaDecode(symbolProbabilities, settings);   
     
end