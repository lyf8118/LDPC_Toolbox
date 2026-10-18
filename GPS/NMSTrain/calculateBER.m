function berValue = calculateBER(decodedCodeword, groundTruthBits)
% =========================================================================
% FUNCTION: calculateBer
% DESCRIPTION:
%   Calculates the Bit Error Rate (BER) for GPS L1C (Binary LDPC).
%   It extracts the systematic information bits (the first K bits) from 
%   the decoded codeword and compares them against the original binary data.
%
% INPUTS:
%   decodedCodeword : [N x 1] Full decoded codeword (Systematic + Parity).
%                     (e.g., 1200 bits for L1C_2).
%   groundTruthBits : [1 x K] Original binary information bits.
%                     (e.g., 600 bits for L1C_2).
%   settings        : Structure containing configuration.
%
% OUTPUTS:
%   berValue        : Bit Error Rate (scalar value, 0.0 to 1.0).
% =========================================================================

    %% 1. Input Validation & Alignment
    % Ensure both vectors are column vectors (N x 1) for consistent processing
    decodedCodeword = decodedCodeword(:);
    groundTruthBits = groundTruthBits(:);

    %% 2. Extract Information Bits (Systematic Part)
    % For GPS L1C, the code is systematic. 
    % The first K bits of the codeword are the information bits.
    % We determine K automatically from the length of the ground truth.
    numInfoBits = length(groundTruthBits);
    
    % Extract the first K bits (Estimated Information Bits)
    estimatedBits = decodedCodeword(1:numInfoBits);
    
    %% 3. Error Calculation
    % Direct bitwise comparison (Since L1C is already binary)
    errorCount = sum(estimatedBits ~= groundTruthBits);
    
    % Calculate final BER
    berValue = errorCount / numInfoBits;
    
end