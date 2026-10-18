function result = boxPlus(llra, llrb, gfSize)
% Helper: BoxPlus Operation (Convolution in GF domain)
% Input: Two LLR vectors
% Output: LLR vector of the sum

    % 1. Normalize inputs to prevent overflow during exp()
    a = llra - max(llra);
    b = llrb - max(llrb);
    
    % 2. Convert LLR to Probability
    probA = exp(a);
    probB = exp(b);
    
    % 3. Normalize Probabilities (Sum to 1)
    probA = probA / sum(probA);
    probB = probB / sum(probB);
    
    % 4. GF Convolution (Probabilistic Domain Add)
    % Since GF addition is Bitwise XOR, we sum probabilities where i^j = k
    resultProb = zeros(1, gfSize);
    
    % This double loop is O(Q^2). For Q=64, 4096 ops.
    % (Can be optimized via FHT, but kept as requested)
    for i = 1:gfSize
        pA = probA(i);
        if pA < 1e-20, continue; end % Optimization: skip negligible
        
        for j = 1:gfSize
            % GF Add: (i-1) XOR (j-1)
            % MATLAB indices are 1-based, values are 0-based
            sumVal = bitxor(i-1, j-1);
            sumIdx = sumVal + 1;
            
            resultProb(sumIdx) = resultProb(sumIdx) + pA * probB(j);
        end
    end
    
    % 5. Stability & Normalization
    resultProb = max(resultProb, 1e-20); % Avoid log(0)
    resultProb = resultProb / sum(resultProb);
    
    % 6. Convert back to LLR
    % LLR definition: log( P(x) / P(0) )
    prob0 = resultProb(1);
    % result = zeros(1, gfSize);
    
    if prob0 > 1e-20
        result = log(resultProb / prob0);
    else
        % Fallback if P(0) is extremely small
        result = log(resultProb) - log(1e-20);
    end
    
    % 7. Final Normalization (Max-Log shift)
    result = result - max(result);
end