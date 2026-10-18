function berValue = calculateBER(decodedCodeword, groundTruthBits, settings)
% =========================================================================
% FUNCTION: calculateBer
% DESCRIPTION:
%   Calculates the Bit Error Rate (BER) by comparing the decoded decimal
%   GF symbols against the original binary transmitted data.
%
%   Note: The decoder outputs the full codeword (Systematic + Parity).
%   This function strictly extracts the systematic part (Information Symbols)
%   to compare against the ground truth.
%
% INPUTS:
%   decodedCodeword : [1 x N] Full decoded codeword (e.g., 162 symbols).
%   groundTruthBits : [1 x K*bits] Original binary data (e.g., 81 symbols worth).
%   settings        : Structure containing configuration:
%                     - settings.gfBits : Bits per symbol (6).
%                     - settings.symbolsPerFrame : Number of info symbols (81).
%
% OUTPUTS:
%   berValue        : Bit Error Rate (scalar value, 0.0 to 1.0).
% =========================================================================

    % --- 1. Extract Information Symbols ---
    % The input contains the full codeword (Info + Parity).
    % We only care about the first 'symbolsPerFrame' for BER calculation.
    systematicSymbols = decodedCodeword(1:settings.symbolsPerFrame);
    
    % Ensure systematicSymbols is a column vector for dec2bin processing
    systematicSymbols = systematicSymbols(:);
    
    % --- 2. Symbol to Bit Conversion ---
    % Convert the decimal GF symbols to a binary matrix.
    % dec2bin returns char array, subtraction converts to double [0,1].
    % Result: [symbolsPerFrame x gfBits] matrix
    estimatedBinMatrix = dec2bin(systematicSymbols, settings.gfBits) - '0';
    
    % --- 3. Reshape to Bit Stream ---
    % Transpose and reshape to create a row vector matching groundTruthBits.
    % Order: [Symbol1_Bits, Symbol2_Bits, ...]
    estimatedBits = reshape(estimatedBinMatrix.', 1, []);
    
    % --- 4. Error Calculation ---
    % Ensure groundTruthBits is also a row vector
    groundTruthBits = reshape(groundTruthBits, 1, []);
    
    % Direct comparison
    errorCount = sum(estimatedBits ~= groundTruthBits);
    
    % Calculate final BER
    berValue = errorCount / length(groundTruthBits);
    
end