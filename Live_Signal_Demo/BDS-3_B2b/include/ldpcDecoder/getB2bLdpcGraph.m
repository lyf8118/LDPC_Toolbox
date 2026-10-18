function graph = getB2bLdpcGraph(settings)
%GETB2BLDPCGRAPH Return cached B2b non-binary LDPC graph data.

settings = prepareB2bLdpcSettings(settings);

persistent cachedGraph
if ~isempty(cachedGraph)
    graph = cachedGraph;
    return;
end

[hIndexCell, hElementCell, hMatrix] = getHInformationB2b();
[rowIndices, colIndices, edgeWeights, numEdges] = getGraphEdges(hIndexCell, hElementCell);

cnConnections = cell(settings.rowH, 1);
for rowIdx = 1:settings.rowH
    cnConnections{rowIdx} = find(rowIndices == rowIdx);
end

vnConnections = cell(settings.colH, 1);
for colIdx = 1:settings.colH
    vnConnections{colIdx} = find(colIndices == colIdx);
end

graph.hMatrix = hMatrix;
graph.rowIndices = rowIndices;
graph.colIndices = colIndices;
graph.edgeWeights = edgeWeights;
graph.numEdges = numEdges;
graph.cnConnections = cnConnections;
graph.vnConnections = vnConnections;

cachedGraph = graph;
end
