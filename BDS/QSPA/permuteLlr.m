function permutedMsg = permuteLlr(msg, weight, mulTable)
% Helper: Fast LLR Permutation using GF Multiplication Table
% Maps LLR(x) -> LLR(weight * x)
    
    if weight == 1
        permutedMsg = msg;
        return;
    end
    
    % weight is 0-based GF value. Table is 1-based index.
    % Row (weight+1) gives the multiplication results: [0*w, 1*w, ..., 63*w]
    % We need to map: value at index (x) moves to index (w*x)
    % MATLAB indices: input index (i) moves to output index (Table(w+1, i) + 1)
    
    targetIndices = mulTable(weight + 1, :) + 1;
    
    permutedMsg = zeros(size(msg), 'like', msg);
    permutedMsg(targetIndices) = msg;
end