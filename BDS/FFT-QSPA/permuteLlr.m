function permutedMsg = permuteLlr(msg, weight, gfMulTable)
% Helper: Fast LLR Permutation using GF Multiplication Table
% Maps LLR(x) -> LLR(weight * x)
    
    if weight == 1
        permutedMsg = msg;
        return;
    end
    
    % weight is 0-based GF value. Table is 1-based index.
    % targetIndices = weight * x (for all x)
    targetIndices = gfMulTable(weight + 1, :) + 1;
    
    permutedMsg = zeros(size(msg), 'like', msg);
    permutedMsg(targetIndices) = msg;
end