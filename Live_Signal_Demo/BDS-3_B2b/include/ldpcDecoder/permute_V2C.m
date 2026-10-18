function permutedMsg = permute_V2C(edgeWeight, msgVector)
%PERMUTE_V2C Compatibility wrapper for permuteV2C.

permutedMsg = permuteV2C(edgeWeight, msgVector, getGfTable());
end
