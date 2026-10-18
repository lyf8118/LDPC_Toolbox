function permutedMsg = permuteC2V(edgeWeight, msgVector, gfMulTable)
% =========================================================================
% FUNCTION: permuteC2v
% DESCRIPTION:
%   Permutes the Check-to-Variable (C2V) message vector. This operation acts 
%   as the inverse permutation to align the message back to the Variable 
%   Node's domain.
%
%   Mapping Logic: Output[x] = Input[h * x]
%   (We look up what value corresponds to symbol 'x' after being multiplied by 'h')
%
% INPUTS:
%   edgeWeight : Non-zero GF element (h) representing the edge weight.
%   msgVector  : [1 x gfSize] Incoming message vector from Check Node.
%   gfMulTable : [gfSize x gfSize] Pre-computed GF multiplication table.
%
% OUTPUTS:
%   permutedMsg : [1 x gfSize] Inverse-permuted message vector ready for VN.
% =========================================================================

    % Define Field Constants (Should match global settings)
    gfBits = 6;           
    gfSize = 2^gfBits; 
    
    % Pre-allocate output array for efficiency
    permutedMsg = zeros(1, gfSize, 'single');
    
    for i = 1:gfSize
        % 1. Calculate Source Index
        % To find the LLR for symbol 'x' (where x = i-1), we check where 'x' 
        % maps to in the Check Node domain: index = h * x.
        % Note: gfMulTable is 1-based, so we access (h+1, i).
        % Result 'sourceIndex' is 1-based index for the GF product.
        sourceIndex = gfMulTable(edgeWeight + 1, i) + 1;
        
        % 2. Retrieve Value
        % Assign the value from the calculated position in the input vector
        permutedMsg(i) = msgVector(sourceIndex);
    end
end