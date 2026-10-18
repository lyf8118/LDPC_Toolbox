function symbolProbabilities = initQspaProbabilities(receivedSignal, sigmaSquared, settings)
% =========================================================================
% FUNCTION: initQspaProbabilities
% DESCRIPTION:
%   Initializes the symbol probability matrix (P) for QSPA decoding.
%   Converts channel soft information (Normalized I/Q or Bit Values) into 
%   GF(q) symbol probabilities.
%
% INPUTS:
%   receivedSignal : [numVarNodes x gfBits] Normalized received soft bits.
%   sigmaSquared   : Noise variance (scalar).
%   settings       : Configuration structure.
%
% OUTPUTS:
%   symbolProbabilities : [numVarNodes x gfSize] Probability matrix.
%                         (Sum of each row equals 1).
% =========================================================================

    %% ================= 1. Constants & Setup =================
    % Use settings directly as requested
    numVarNodes = size(receivedSignal, 1);
    llrLimit    = 20; 
    
    % Pre-allocate output matrix [N x 64]
    symbolProbabilities = zeros(numVarNodes, settings.gfSize, 'double');
    
    % Generate GF binary table: [64 x 6] (0 to 63)
    % 'left-msb' corresponds to the transmission order usually
    gfBinaryTable = de2bi(0:(settings.gfSize-1), settings.gfBits, 'left-msb'); 
    
    %% ================= 2. Calculate Bit Probabilities =================
    % 2.1 Calculate Bit LLRs: L = 2 * y / sigma^2
    bitLlrs = 2 * receivedSignal / sigmaSquared;
    
    % 2.2 Saturation (Clipping)
    bitLlrs(bitLlrs > llrLimit)  = llrLimit;
    bitLlrs(bitLlrs < -llrLimit) = -llrLimit;
    
    % 2.3 Convert LLR to Probability P(b=0) and P(b=1)
    % P(b=0) = 1 / (1 + e^(-L))
    probBitZero = 1 ./ (1 + exp(-bitLlrs));
    probBitOne  = 1 - probBitZero;
    
    % 2.4 Numerical Stability (Avoid pure 0 or 1)
    probBitZero = max(probBitZero, 1e-15);
    probBitOne  = max(probBitOne, 1e-15);
    
    %% ================= 3. Compute Symbol Probabilities =================
    % Optimization: Loop through GF elements (0..63) instead of Rows.
    % This vectorizes the calculation across all Variable Nodes at once.
    
    for j = 1:settings.gfSize
        % Get the binary representation of the current GF symbol
        % e.g., if j=1 (symbol 0), bits = [0 0 0 0 0 0]
        bits = gfBinaryTable(j, :); 
        
        % Initialize probability for this symbol across all rows
        currentSymProb = ones(numVarNodes, 1);
        
        % Compute product of bit probabilities corresponding to this symbol
        for k = 1:settings.gfBits
            if bits(k) == 0
                currentSymProb = currentSymProb .* probBitZero(:, k);
            else
                currentSymProb = currentSymProb .* probBitOne(:, k);
            end
        end
        
        % Assign to the matrix
        symbolProbabilities(:, j) = currentSymProb;
    end
    
    %% ================= 4. Normalization =================
    % Ensure sum of probabilities for each variable node equals 1
    rowSums = sum(symbolProbabilities, 2);
    
    % Handle potential zero sums (rare due to epsilon above, but safe to keep)
    validRows = rowSums > 0;
    
    % Normalize valid rows
    symbolProbabilities(validRows, :) = symbolProbabilities(validRows, :) ./ rowSums(validRows);
    
    % Fallback for invalid rows (uniform distribution)
    if any(~validRows)
        symbolProbabilities(~validRows, :) = 1 / settings.gfSize;
    end
    
end