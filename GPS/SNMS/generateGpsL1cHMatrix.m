function hMatrix = generateGpsL1cHMatrix(numRows, numCols, gapSize, coordsA, coordsB, coordsC, coordsD, coordsE, coordsT)
% generateGpsL1cHMatrix Generate GPS L1C binary LDPC parity-check matrix H.
%
% Based on CNAV-2 style block coordinate tables (1-based indices).
% The matrix is constructed from 6 sub-matrices (A, B, C, D, E, T)
% positioned according to specific offsets defined in the ICD.
%
% INPUTS:
%   numRows : Number of rows in the sub-matrix block (parameter 'm').
%   numCols : Total number of columns (parameter 'n').
%   gapSize : Gap size parameter (parameter 'g', usually for separation).
%   coords* : [N x 2] arrays containing 1-based (row, col) indices for each block.
%             (coordsA, coordsB, coordsC, coordsD, coordsE, coordsT)
%
% OUTPUTS:
%   hMatrix : Sparse logical matrix of size [numRows x numCols].
%             Entries are mod-2 aggregated (XOR sum) of inputs.
% =========================================================================

    %% 1. Define Block Offsets
    % Offsets determine where each sub-matrix is placed in the final H matrix.
    % Based on the structure:
    % [ A       B       T ]
    % [ C       D       E ]  <-- (Bottom 'g' rows overlap/extend)
    
    offsetRowA = 0;                  offsetColA = 0;
    offsetRowB = 0;                  offsetColB = numRows;
    offsetRowC = numRows - gapSize;  offsetColC = 0;
    offsetRowD = numRows - gapSize;  offsetColD = numRows;
    offsetRowE = numRows - gapSize;  offsetColE = numRows + gapSize;
    offsetRowT = 0;                  offsetColT = numRows + gapSize;

    %% 2. Aggregate Coordinates
    rowIndices = [];
    colIndices = [];

    % Helper function to append coordinates with offsets
    function appendCoords(coords, rOff, cOff)
        if ~isempty(coords)
            rowIndices = [rowIndices; coords(:, 1) + rOff];
            colIndices = [colIndices; coords(:, 2) + cOff];
        end
    end

    % Append each block
    appendCoords(coordsA, offsetRowA, offsetColA);
    appendCoords(coordsB, offsetRowB, offsetColB);
    appendCoords(coordsC, offsetRowC, offsetColC);
    appendCoords(coordsD, offsetRowD, offsetColD);
    appendCoords(coordsE, offsetRowE, offsetColE);
    appendCoords(coordsT, offsetRowT, offsetColT);

    %% 3. Validate Boundaries
    if ~isempty(rowIndices)
        isRowValid = all(rowIndices >= 1 & rowIndices <= numRows);
        isColValid = all(colIndices >= 1 & colIndices <= numCols);
        assert(isRowValid && isColValid, ...
            'generateGpsL1cHMatrix: Indices out of bounds based on m=%d, n=%d', numRows, numCols);
    end

    %% 4. Construct Sparse Matrix (Modulo-2 Addition)
    % Convert (row, col) pairs to linear indices
    linearIndices = sub2ind([numRows, numCols], rowIndices, colIndices);
    
    % Find unique linear indices and map them
    [uniqueIndices, ~, indexMap] = unique(linearIndices);
    
    % Sum occurrences for each unique index
    counts = accumarray(indexMap, 1);
    
    % Perform Modulo-2 operation (LDPC is defined over GF(2))
    values = mod(counts, 2);
    
    % Map back to row/col subscripts
    [rowsUnique, colsUnique] = ind2sub([numRows, numCols], uniqueIndices);
    
    % Create the sparse logical matrix (keep only non-zero entries)
    % Using 'double' for sparse constructor, then converting to logical is standard safe practice
    hMatrix = sparse(rowsUnique, colsUnique, double(values), numRows, numCols) ~= 0;

end