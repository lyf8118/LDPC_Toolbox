function symbolProbabilities = initQspaProbabilities(receivedSignal, sigmaSquaredNorm, settings)
% =========================================================================
% FUNCTION: initQspaProbabilities
% DESCRIPTION:
%   Initializes symbol probabilities for QSPA decoding using Log-Domain calculation.
%   Converts channel soft bits (LLRs) into GF(q) symbol probabilities.
%
% INPUTS:
%   receivedSignal   : [numVarNodes x gfBits] Normalized received soft bits.
%   sigmaSquaredNorm : Noise variance (scalar).
%   settings         : Configuration structure.
%
% OUTPUTS:
%   symbolProbabilities : [numVarNodes x gfSize] Normalized Probability matrix.
% =========================================================================

    % 1. Constants
    gfBits = settings.gfBits;   % e.g., 6
    gfSize = settings.gfSize;   % e.g., 64
    
    % 2. GF Binary Expansion Table [gfSize x gfBits]
    % Maps each GF element (0..63) to its binary representation
    % 'left-msb' matches the transmission order
    gfBinaryTable = de2bi(0:(gfSize-1), gfBits, 'left-msb');
    
    % 3. Calculate Bit-wise LLRs
    % L = 2 * y / sigma^2
    bitLlrs = 2 * receivedSignal ./ sigmaSquaredNorm;
    
    % Clipping to prevent numerical overflow in exp()
    llrLimit = 20;
    bitLlrs = max(min(bitLlrs, llrLimit), -llrLimit);
    
    % 4. Calculate Log-Probabilities for Bits
    % P(b=0) = 1 / (1 + exp(-L))
    % P(b=1) = 1 - P(b=0)
    probBitZero = 1 ./ (1 + exp(-bitLlrs));
    probBitOne  = 1 - probBitZero;
    
    % Avoid log(0)
    probBitZero = max(probBitZero, realmin);
    probBitOne  = max(probBitOne, realmin);
    
    logProbZero = log(probBitZero); % [N x 6]
    logProbOne  = log(probBitOne);  % [N x 6]
    
    % 5. Compute Log-Likelihoods for Symbols
    % Matrix Multiplication Strategy:
    % P(sym) = Product(P(bits)) => log(P(sym)) = Sum(log(P(bits)))
    %
    % logLikelihoods [N x 64] = 
    %   logProbZero * (1 - bits)' + logProbOne * (bits)'
    %
    % Explanation:
    % If a bit in gfBinaryTable is 0, we sum logProbZero.
    % If a bit in gfBinaryTable is 1, we sum logProbOne.
    
    % (1 - gfBinaryTable)' creates a mask where 0s become 1s (selecting logProbZero)
    % gfBinaryTable'       creates a mask where 1s stay 1s (selecting logProbOne)
    
    logLikelihoods = logProbZero * (1 - gfBinaryTable).' + logProbOne * (gfBinaryTable.');
    
    % 6. Log-Sum-Exp Normalization (Numerical Stability)
    % P = exp(logP - max(logP)) / sum(exp(logP - max(logP)))
    
    maxLog = max(logLikelihoods, [], 2);
    logLikelihoods = logLikelihoods - maxLog; % Shift max to 0
    
    unnormalizedProbs = exp(logLikelihoods);
    rowSums = sum(unnormalizedProbs, 2);
    
    symbolProbabilities = unnormalizedProbs ./ rowSums;
    
end