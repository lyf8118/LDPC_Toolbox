function [rowIndices, colIndices, edgeWeights, numEdges] = getGraphEdges(hIndices, hElements)
%GETGRAPHEDGES Flatten row-compressed H matrix cells into Tanner graph edges.

[rowIndices, colIndices, edgeWeights, numEdges] = graph_edge(hIndices, hElements);
end
