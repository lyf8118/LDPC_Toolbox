function permutedMsg = permuteV2C(edgeWeight, msgVector, gfMulTable)
%PERMUTEV2C Map VN-domain LLRs to CN domain through a GF edge weight.

if edgeWeight == 1
    permutedMsg = msgVector;
    return;
end

targetIndices = double(gfMulTable(edgeWeight + 1, :)) + 1;
permutedMsg = zeros(size(msgVector), 'like', msgVector);
permutedMsg(targetIndices) = msgVector;
end
