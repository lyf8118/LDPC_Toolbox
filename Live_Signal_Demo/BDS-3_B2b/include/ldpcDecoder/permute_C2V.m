function permutedMsg = permute_C2V(edgeWeight, msgVector)
%PERMUTE_C2V Compatibility wrapper for permuteC2V.

permutedMsg = permuteC2V(edgeWeight, msgVector, getGfTable());
end
