function combinedLlr = extMinSum(llrVec1, llrVec2, settings)
% =========================================================================
% FUNCTION: extMinSum
% DESCRIPTION:
%   Performs the "Elementary Check Node Operation" for the Extended Min-Sum
%   (EMS) algorithm using the bubble-check (truncation) method.
%
%   Operation: combinedLlr = llrVec1 [+] llrVec2 (Box-plus in log domain)
%
% INPUTS:
%   llrVec1  : [1 x Q] LLR vector from edge 1.
%   llrVec2  : [1 x Q] LLR vector from edge 2.
%   settings : Config structure (settings.nmEms, settings.gfBits).
%
% OUTPUTS:
%   combinedLlr : [1 x Q] Resulting LLR vector after box-plus operation.
% =========================================================================

    % Extract configuration parameters
    truncationSize = settings.nmEms;   % Number of significant entries (n_m)
    gfBits         = settings.gfBits;  % Bits per symbol (N_GF)
    gfSize         = 2^gfBits;         % Field size (Q_GF)

    % Handle initialization case: 
    % If first vector is empty, the sum is just the second vector.
    if isempty(llrVec1)
        combinedLlr = llrVec2;
        return;
    end

    % --- 1. Sorting (Truncation Preparation) ---
    % Sort LLRs in ascending order (smallest LLR = highest probability).
    [~, sortedIndices1] = sort(llrVec1);
    [~, sortedIndices2] = sort(llrVec2);

    % --- 2. Initialize Output Vector ---
    % Determine a saturation threshold based on the truncation limit.
    % We use the sum of the (truncationSize)-th values as a baseline upper bound.
    % This acts as the initial "Min" value before we find better candidates.
    saturationValue = llrVec1(sortedIndices1(truncationSize)) + ...
                      llrVec2(sortedIndices2(truncationSize));
    
    % Initialize output with the saturation value
    combinedLlr = saturationValue * ones(1, gfSize, 'single');

    % --- 3. Extended Min-Sum Calculation (Bubble Check) ---
    % Iterate only through the top 'truncationSize' entries of both vectors.
    % Complexity reduced from O(Q^2) to O(nmEms^2).
    for i = 1:truncationSize
        for j = 1:truncationSize
            
            % Compute GF Sum (XOR for binary extension fields).
            % Convert 1-based indices to 0-based GF symbols, XOR, then back to 1-based.
            xorVal   = bitxor(sortedIndices1(i)-1, sortedIndices2(j)-1);
            xorIndex = xorVal + 1; 

            % Calculate candidate LLR (Sum of input LLRs)
            currentSum = llrVec1(sortedIndices1(i)) + llrVec2(sortedIndices2(j));

            % Update combined LLR if the new candidate is smaller (Min-Sum rule)
            if currentSum < combinedLlr(xorIndex)
               combinedLlr(xorIndex) = currentSum;
            end
        end
    end
end