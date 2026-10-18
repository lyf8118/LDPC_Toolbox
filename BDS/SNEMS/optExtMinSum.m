function combinedLlr = optExtMinSum(llrVec1, llrVec2, settings)
% =========================================================================
% FUNCTION: optExtMinSum
%
% DESCRIPTION:
%   Performs the elementary check node processing for Non-Binary LDPC codes
%   using the Optimized Extended Min-Sum (EMS) algorithm.
%
%   Specifically, this function implements the "L-Shape" (or L-Bubble) 
%   optimization strategy. Instead of computing the full convolution of 
%   two LLR vectors (which is computationally expensive), it sorts the 
%   input vectors and only processes the most reliable message pairs located 
%   along the first row and first column of the permutation matrix.
%
% INPUTS:
%   llrVec1  : [1 x GF_Size] Input LLR vector from the first edge.
%   llrVec2  : [1 x GF_Size] Input LLR vector from the second edge.
%   settings : Configuration structure containing:
%              - settings.nmEms  : Truncation size (n_m).
%              - settings.gfBits : Galois Field order (m).
%
% OUTPUTS:
%   combinedLlr : [1 x GF_Size] The combined/updated LLR vector after 
%                 Check Node processing.
%
% =========================================================================

    %% Basic Setup & Handling Empty Inputs ================================
    if isempty(llrVec1)
        combinedLlr = llrVec2;
        return;
    elseif isempty(llrVec2)
        combinedLlr = llrVec1;
        return;
    end
    
    truncationSize = settings.nmEms;   
    gfSize         = 2^settings.gfBits;
    
    %% Sorting (Crucial Step for EMS/IEMS) ================================
    % Sort LLRs in ascending order.
    % Smallest LLR = Most reliable symbol.
    [sortedLlr1, sortedIndices1] = sort(llrVec1);
    [sortedLlr2, sortedIndices2] = sort(llrVec2);
    
    %% Initialize Output Vector ===========================================
    % Heuristic saturation: Sum of the worst valid LLRs at the truncation limit (nm).
    % This acts as a "soft infinity" for unvisited or low-probability symbols.
    saturationValue = sortedLlr1(truncationSize) + sortedLlr2(truncationSize);
    
    % Initialize the output vector with the saturation value
    combinedLlr = saturationValue * ones(1, gfSize, 'single');
    
    %% "L-Shape" Calculation (Core Optimization)===========================
     
    % --- Part A: Intersection (Top-Left) ---
    % i=1, j=1 is the absolute best candidate (highest probability pair).
    val   = sortedLlr1(1) + sortedLlr2(1);
    idx1  = sortedIndices1(1) - 1; % Convert to 0-based GF symbol index
    idx2  = sortedIndices2(1) - 1;
    xorVal = bitxor(idx1, idx2);
    combinedLlr(xorVal + 1) = val; 
    
    % --- Part B: First Row (Fixed i=1, Iterate j=2 to nm) ---
    idx1_fixed = sortedIndices1(1) - 1;
    val1_fixed = sortedLlr1(1);
    
    for j = 2:truncationSize
        % Calculate LLR Sum
        currentSum = val1_fixed + sortedLlr2(j);
        
        % Calculate GF Symbol Index
        idx2 = sortedIndices2(j) - 1;
        xorVal = bitxor(idx1_fixed, idx2);
        targetIndex = xorVal + 1;
    
        % Update combined vector (Min-Sum rule for collisions)
        if currentSum < combinedLlr(targetIndex)
            combinedLlr(targetIndex) = currentSum;
        end
    end
    
    % --- Part C: First Column (Iterate i=2 to nm, Fixed j=1) ---
    idx2_fixed = sortedIndices2(1) - 1;
    val2_fixed = sortedLlr2(1);
    
    for i = 2:truncationSize
        % Calculate LLR Sum
        currentSum = sortedLlr1(i) + val2_fixed;
        
        % Calculate GF Symbol Index
        idx1 = sortedIndices1(i) - 1;
        xorVal = bitxor(idx1, idx2_fixed);
        targetIndex = xorVal + 1;
        
        % Update and perform minimum check
        if currentSum < combinedLlr(targetIndex)
            combinedLlr(targetIndex) = currentSum;
        end
    end
    
end