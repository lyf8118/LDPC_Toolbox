function [rowIndices, colIndices, edgeWeights, numEdges] = getGraphEdges(hIndices, hElements)
% =========================================================================
% FUNCTION: getGraphEdges
% DESCRIPTION:
%   Constructs the edge list for the LDPC Tanner Graph from the compressed
%   Parity Check Matrix (H) information.
%
%   It converts the input Cell Array representation (Row-Compressed) into
%   a Coordinate List (COO) format. This flattens the structure, making 
%   it efficient to iterate over all edges during message passing.
%
% INPUTS:
%   hIndices  : [M x 1] Cell array, i-th cell contains column indices of row i.
%   hElements : [M x 1] Cell array, i-th cell contains GF values for row i.
%
% OUTPUTS:
%   rowIndices  : [1 x N_edges] Array of Check Node indices (rows).
%   colIndices  : [1 x N_edges] Array of Variable Node indices (cols).
%   edgeWeights : [1 x N_edges] Array of Edge weights (GF elements).
%   numEdges    : [Scalar] Total number of edges in the graph.
% =========================================================================

    % --- 1. Calculate Total Edges ---
    % Sum the lengths of all cells to find total non-zero entries.
    totalEdges = sum(cellfun(@length, hIndices));
    
    % --- 2. Pre-allocation ---
    % Pre-allocate memory to prevent dynamic resizing overhead.
    rowIndices  = zeros(1, totalEdges);
    colIndices  = zeros(1, totalEdges);
    edgeWeights = zeros(1, totalEdges);
    
    % --- 3. Flattening Loop ---
    % Iterate through each row of the H matrix and populate the edge lists.
    currentIdx = 1; % Current insertion pointer
    
    for i = 1:length(hIndices)
        % Get the number of edges connected to the current Check Node (row i)
        currentDegree = length(hIndices{i});
        
        % Define the range in the flattened arrays for this row's edges
        insertRange = currentIdx : (currentIdx + currentDegree - 1);
        
        % Assign values (Vectorized assignment for speed)
        rowIndices(insertRange)  = i;             % Check Node index (Row)
        colIndices(insertRange)  = hIndices{i};   % Variable Node indices (Cols)
        edgeWeights(insertRange) = hElements{i};  % GF Edge Weights
        
        % Update the insertion pointer
        currentIdx = currentIdx + currentDegree;
    end
    
    % Return total number of edges
    numEdges = totalEdges;
    
end