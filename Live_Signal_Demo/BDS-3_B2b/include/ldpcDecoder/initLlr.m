function llrMatrix = initLlr(receivedSignal, sigmaSquared, settings)
% =========================================================================
% FUNCTION: initLlr
% DESCRIPTION:
%   Calculates initial symbol metrics (LLRs) for Non-Binary LDPC decoding.
%   It produces a non-negative cost table where a lower value indicates 
%   higher probability (0 represents the hard-decision candidate).
% =========================================================================
    % Pre-allocate output matrix
    llrMatrix = zeros(settings.colH, settings.gfSize);
    
    % --- 1. Pre-compute GF Bit Look-Up Table (LUT) ---
    gfBitLut = zeros(settings.gfSize, settings.gfBits);
    for q = 0 : settings.gfSize - 1
        gfBitLut(q + 1, :) = dec2bin(q, settings.gfBits) - '0';
    end
    
    % --- 2. Hard Decision on Received Bits ---
    % BPSK mapping rule: Positive -> 0, Negative -> 1
    hardDecisionBits = receivedSignal < 0;
    
    % --- 3. Build Symbol Metrics ---
    % Calculate reliability scaling factor (2 / sigma^2)
    scalingFactor = 2 / sigmaSquared;
    
    for i = 1 : settings.colH
        % Calculate reliability weights for the current symbol's bits
        % w = |y| * (2 / sigma^2)
        bitReliabilities = abs(receivedSignal(i, :)) * scalingFactor;
        
        for j = 1 : settings.gfSize
            % Identify mismatched bits: XOR candidate symbol vs hard decision
            bitMismatch = xor(gfBitLut(j, :), hardDecisionBits(i, :));
            
            % Sum the reliability of all mismatching bits to get symbol cost
            llrMatrix(i, j) = sum(bitReliabilities .* bitMismatch);
        end
    end
end