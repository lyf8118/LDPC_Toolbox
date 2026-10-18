function permutedMsg = permuteLlr(msgVector, edgeWeight, gfMulTable)
%PERMUTELLR Probability/log-probability permutation for QSPA messages.

permutedMsg = permuteV2C(edgeWeight, msgVector, gfMulTable);
end
