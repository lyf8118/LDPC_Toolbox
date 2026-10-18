function permutedMsg = permuteV2C(edgeWeight, msgVector, gfMulTable)
% =========================================================================
% FUNCTION: permuteV2c
% DESCRIPTION:
%   Permutes the Variable-to-Check (V2C) message vector according to the 
%   edge weight from the Parity Check Matrix.
%
%   In Non-Binary LDPC, traversing an edge from a Variable Node (VN) to a 
%   Check Node (CN) involves multiplying the VN symbol by the edge weight 'h'.
%   In the probability/LLR domain, this means moving the probability of 
%   symbol 'x' to the position of symbol 'h * x'.
%
%   Mapping Logic: Output[h * x] = Input[x]
%
% INPUTS:
%   edgeWeight : Non-zero GF element (h) representing the edge weight.
%   msgVector  : [1 x gfSize] Original message vector from Variable Node.
%   gfMulTable : [gfSize x gfSize] Pre-computed GF multiplication table.
%
% OUTPUTS:
%   permutedMsg : [1 x gfSize] Permuted message vector ready for Check Node.
% =========================================================================

    % Define Field Constants (Should match global settings)
    gfBits = 6;           % Number of bits per symbol
    gfSize = 2^gfBits;    % Field size (e.g., 64)
    
    % Pre-allocate output array for efficiency
    permutedMsg = zeros(1, gfSize, 'single');
    
    for i = 1:gfSize
        %  Calculate Destination Index
        % Current loop index 'i' corresponds to source symbol 'x' = (i-1).
        % We calculate where this symbol maps to: destination = h * x.
        % Note: gfMulTable is 1-based, so we access (h+1, i).
        destIndex = gfMulTable(edgeWeight + 1, i) + 1;
        
        % Permutation
        % Move the LLR value from the source symbol position 'i' to the 
        % calculated destination position.
        permutedMsg(destIndex) = msgVector(i);
    end
end