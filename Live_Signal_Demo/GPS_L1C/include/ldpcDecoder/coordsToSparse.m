function sparseMat = coordsToSparse(coords, numRows, numCols)
% coordsToSparse Converts coordinate list to sparse matrix (Binary).
    rows = coords(:, 1);
    cols = coords(:, 2);
    vals = ones(size(rows));
    
    sparseMat = sparse(rows, cols, vals, numRows, numCols);
end