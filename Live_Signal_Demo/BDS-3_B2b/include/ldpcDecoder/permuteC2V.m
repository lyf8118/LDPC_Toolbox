function permutedMsg = permuteC2V(edgeWeight, msgVector, gfMulTable)
%PERMUTEC2V Inverse-map CN-domain LLRs back to the VN symbol domain.

if edgeWeight == 1
    permutedMsg = msgVector;
    return;
end

sourceIndices = double(gfMulTable(edgeWeight + 1, :)) + 1;
permutedMsg = msgVector(sourceIndices);
end
